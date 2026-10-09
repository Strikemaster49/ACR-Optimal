Set-StrictMode -Version 2
$ErrorActionPreference='Stop'
$moduleRoot=$PSScriptRoot
function HashText([string]$Text) {
    $sha=[Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))).Replace('-','').ToLowerInvariant() }
    finally { $sha.Dispose() }
}
function Number([object]$Value) {
    $text=[string]$Value
    if ($text -notmatch '^\d+([.,]\d+)?([eE][+-]?\d+)?$') { throw "Nombre invalide : $text" }
    $n=[double]::Parse($text.Replace(',','.'),[Globalization.CultureInfo]::InvariantCulture)
    if ([double]::IsNaN($n) -or [double]::IsInfinity($n) -or $n -gt 86400) { throw 'Temps hors limites.' }
    return $n
}
function FloatBits([double]$n) { return [BitConverter]::ToString([BitConverter]::GetBytes([single]$n)).Replace('-','').ToLowerInvariant() }
function Open-AcrDatabase([string]$Path) {
    if (-not ('ACROptimal.Experimental.Database' -as [type])) {
        Add-Type -Path (Join-Path $moduleRoot 'SqliteNative.cs')
    }
    $full=[IO.Path]::GetFullPath($Path)
    New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($full)) -Force | Out-Null
    try { $db=New-Object ACROptimal.Experimental.Database($full) }
    catch { throw "SQLite inaccessible. Windows 10/11 et winsqlite3.dll sont requis. $($_.Exception.Message)" }
    try {
        $id=$db.Query('PRAGMA application_id',@())[0]['application_id']
        $tables=$db.Query("SELECT COUNT(*) AS n FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",@())[0]['n']
        if ($tables -gt 0 -and $id -ne 1094931032) { throw 'Cette base appartient a une autre application : aucune modification autorisee.' }
        if ($id -eq 1094931032 -and $db.Query('PRAGMA user_version',@())[0]['user_version'] -ne 1) { throw 'Version de schema non prise en charge.' }
        $db.Exec('PRAGMA foreign_keys=ON',@()); $db.Exec('PRAGMA busy_timeout=5000',@())
        if ($tables -eq 0) {
            $db.Exec('BEGIN IMMEDIATE',@())
            try {
                foreach ($sql in (Get-Content (Join-Path $moduleRoot 'schema.sql') -Raw).Split(';')) {
                    if (-not [string]::IsNullOrWhiteSpace($sql)) { $db.Exec($sql,@()) }
                }
                $db.Exec('COMMIT',@())
            } catch { $db.Exec('ROLLBACK',@()); throw }
        }
        return $db
    } catch { $db.Dispose(); throw }
}
function Read-Attempts([string]$Path) {
    $all=@(Import-Csv -LiteralPath $Path)
    if ($all.Count -eq 0) { throw 'Export vide.' }
    foreach ($name in @('AttemptKeyCandidate','BlockToken','RawAttemptSHA256','RunIndex','StageId','CarId','SectorIndex','DurationSeconds','CumulativeSeconds')) {
        if ($all[0].PSObject.Properties.Name -notcontains $name) { throw "Colonne requise absente : $name. Utilisez le nouveau lecteur." }
    }
    foreach ($group in @($all | Group-Object AttemptKeyCandidate)) {
        $first=$group.Group[0]
        if ($first.AttemptKeyCandidate -notmatch '^[0-9a-f]{64}$' -or $first.RawAttemptSHA256 -notmatch '^[0-9a-f]{64}$' -or $first.BlockToken -notmatch '^[0-9a-f]{16}$') { throw 'Identifiant ou hash invalide.' }
        if ($first.RunIndex -notmatch '^\d{1,6}$') { throw 'Index de tentative invalide.' }
        $run=[int]$first.RunIndex
        foreach ($label in @($first.StageId,$first.CarId)) { if ([string]::IsNullOrWhiteSpace($label) -or $label.Length -gt 256 -or $label -match '[\x00-\x1f]') { throw 'Contexte invalide.' } }
        $key=HashText (ConvertTo-Json -InputObject @('acr-attempt-candidate-v1',$first.BlockToken,$first.StageId,$first.CarId,[string]$run) -Compress)
        if ($key -ne $first.AttemptKeyCandidate) { throw 'Cle ne correspondant pas au contexte exporte.' }
        $sectors=@{}
        foreach ($row in $group.Group) {
            foreach ($name in @('BlockToken','RawAttemptSHA256','RunIndex','StageId','CarId')) {
                if ($row.$name -cne $first.$name) { throw 'Contexte incoherent dans une tentative.' }
            }
            if ($row.SectorIndex -notmatch '^\d{1,2}$' -or [int]$row.SectorIndex -lt 1 -or [int]$row.SectorIndex -gt 32) { throw 'Index secteur invalide.' }
            # This protocol contains Float32 values. Reconstruct them so 15/17-digit
            # CSV formatting across PowerShell versions cannot create false conflicts.
            $index=[int]$row.SectorIndex; $duration=[double][single](Number $row.DurationSeconds); $cumulative=[double][single](Number $row.CumulativeSeconds)
            if ($duration -le 0 -or $cumulative -le 0) { throw 'Temps non positif.' }
            if ($sectors.ContainsKey($index) -and ($sectors[$index].duration -ne $duration -or $sectors[$index].cumulative -ne $cumulative)) { throw 'Deux valeurs pour un meme secteur.' }
            $sectors[$index]=[pscustomobject]@{index=$index; duration=$duration; cumulative=$cumulative}
        }
        $ordered=@($sectors.Values | Sort-Object index); $prior=0.0; $expected=1
        foreach ($s in $ordered) {
            if ($s.index -ne $expected -or [Math]::Abs(($s.cumulative-$prior)-$s.duration) -gt 0.005) { throw 'Secteurs non consecutifs ou cumul/duree incoherents (tolerance experimentale 5 ms).' }
            $prior=$s.cumulative; $expected++
        }
        $layout=($ordered | ForEach-Object { $_.index }) -join ','
        $payload=@($first.BlockToken,$first.StageId,$first.CarId,[string]$run,$first.RawAttemptSHA256)
        foreach ($s in $ordered) { $payload+=@([string]$s.index,(FloatBits $s.cumulative),(FloatBits $s.duration)) }
        [pscustomobject]@{key=$key; token=$first.BlockToken; stage=$first.StageId; car=$first.CarId; run=$run;
            rawHash=$first.RawAttemptSHA256; payloadHash=(HashText (ConvertTo-Json -InputObject $payload -Compress));
            layout=$layout; final=$prior; sectors=$ordered}
    }
}
function Import-AcrExports($Db,[string[]]$Paths,[string]$Profile) {
    if ([string]::IsNullOrWhiteSpace($Profile)) { throw 'Profil requis.' }
    $inserted=0; $repeated=0; $conflicts=0
    # All files in this invocation are parsed before a single atomic import transaction.
    $batches=@(foreach ($path in $Paths) {
        $full=(Get-Item -LiteralPath $path).FullName
        $sha=(Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash.ToLowerInvariant()
        $attempts=@(Read-Attempts $full)
        if ($sha -ne (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash.ToLowerInvariant()) { throw 'Export modifie pendant la lecture.' }
        [pscustomobject]@{path=$full; hash=$sha; attempts=$attempts}
    })
    if ($batches.Count -eq 0) { throw 'Aucun export.' }
    $Db.Exec('BEGIN IMMEDIATE',@())
    try {
        foreach ($batch in $batches) {
            foreach ($a in $batch.attempts) {
                $now=[DateTime]::UtcNow.ToString('o')
                $existing=$Db.Query('SELECT id,payload_hash FROM attempts WHERE profile=? AND attempt_key=?',@($Profile,$a.key))
                if ($existing.Count -gt 0) {
                    $id=$existing[0]['id']
                    if ($existing[0]['payload_hash'] -ne $a.payloadHash) {
                        $Db.Exec('INSERT OR IGNORE INTO conflicts(attempt_id,incoming_payload_hash,incoming_raw_hash,export_path,seen_at) VALUES(?,?,?,?,?)',@($id,$a.payloadHash,$a.rawHash,$batch.path,$now))
                        $Db.Exec('UPDATE attempts SET conflicted=1 WHERE id=?',@($id)); $conflicts++; continue
                    }
                    $repeated++
                } else {
                    $Db.Exec('INSERT INTO attempts(profile,attempt_key,block_token,run_index,stage,car,raw_hash,payload_hash,layout,raw_final,first_seen) VALUES(?,?,?,?,?,?,?,?,?,?,?)',@($Profile,$a.key,$a.token,$a.run,$a.stage,$a.car,$a.rawHash,$a.payloadHash,$a.layout,$a.final,$now))
                    $id=$Db.Query('SELECT last_insert_rowid() AS id',@())[0]['id']
                    foreach ($s in $a.sectors) { $Db.Exec('INSERT INTO sectors(attempt_id,sector_index,cumulative,duration) VALUES(?,?,?,?)',@($id,$s.index,$s.cumulative,$s.duration)) }
                    $inserted++
                }
                $Db.Exec('INSERT OR IGNORE INTO observations(attempt_id,export_sha,export_path,seen_at) VALUES(?,?,?,?)',@($id,$batch.hash,$batch.path,$now))
            }
        }
        $Db.Exec('COMMIT',@())
    } catch { $Db.Exec('ROLLBACK',@()); throw }
    return [pscustomobject]@{Inserted=$inserted; Repeated=$repeated; Conflicts=$conflicts}
}
function New-AcrReviewTemplate($Db,[string]$Profile,[string]$Path) {
    if (Test-Path -LiteralPath $Path) { throw 'Le fichier existe deja : choisissez un nouveau nom.' }
    $items=@(foreach ($a in $Db.Query('SELECT * FROM attempts WHERE profile=? ORDER BY id',@($Profile))) {
        [ordered]@{AttemptKey=$a['attempt_key']; RawHash=$a['raw_hash']; PayloadHash=$a['payload_hash'];
            Stage=$a['stage']; Car=$a['car']; BlockToken=$a['block_token']; RunIndex=$a['run_index'];
            RawFinalSeconds=$a['raw_final']; Mode='unknown'; Validity='unknown'; Complete=$null;
            SectorsVerified=$false; ExpectedSectorCount=$null; PenaltySeconds=$null; OfficialFinalSeconds=$null;
            ConfirmAgainstGame=$false; Note='Verifier contre les resultats du jeu ; ne pas valider en bloc.'}
    })
    @{Schema=1; Profile=$Profile; Decisions=$items} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $Path -Encoding UTF8
}
function Set-AcrReviews($Db,[string]$Profile,[string]$Path) {
    $review=Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($review.Schema -ne 1 -or $review.Profile -ne $Profile) { throw 'Schema ou profil de revue incorrect.' }
    $Db.Exec('BEGIN IMMEDIATE',@())
    try {
        foreach ($d in @($review.Decisions)) {
            if ($d.ConfirmAgainstGame -isnot [bool] -or -not $d.ConfirmAgainstGame) { continue }
            $found=$Db.Query('SELECT * FROM attempts WHERE profile=? AND attempt_key=?',@($Profile,$d.AttemptKey))
            if ($found.Count -ne 1) { throw 'Tentative de revue inconnue.' }; $a=$found[0]
            if ($a['raw_hash'] -ne $d.RawHash -or $a['payload_hash'] -ne $d.PayloadHash) { throw 'Revue obsolete ou contenu different.' }
            if ($d.Mode -notin @('TT','other','unknown') -or $d.Validity -notin @('valid','invalid','abandoned','unknown')) { throw 'Mode ou validite de revue incorrect.' }
            if ($d.SectorsVerified -isnot [bool]) { throw 'SectorsVerified doit etre un booleen JSON.' }
            $complete=$null; if ($null -ne $d.Complete) { if ($d.Complete -isnot [bool]) { throw 'Complete doit etre un booleen.' }; $complete=[int]$d.Complete }
            $expected=$null; if ($null -ne $d.ExpectedSectorCount) { if ([string]$d.ExpectedSectorCount -notmatch '^\d{1,2}$' -or $d.ExpectedSectorCount -lt 1 -or $d.ExpectedSectorCount -gt 32) { throw 'Nombre de secteurs attendu invalide.' }; $expected=[int]$d.ExpectedSectorCount }
            $penalty=$null; if ($null -ne $d.PenaltySeconds) { $penalty=Number $d.PenaltySeconds }
            $official=$null; if ($null -ne $d.OfficialFinalSeconds) { $official=Number $d.OfficialFinalSeconds; if ($official -le 0) { throw 'Chrono officiel invalide.' } }
            $count=$Db.Query('SELECT COUNT(*) AS n FROM sectors WHERE attempt_id=?',@($a['id']))[0]['n']
            if ($complete -eq 1 -and ($null -eq $expected -or $expected -ne $count)) { throw 'Tentative annoncee complete avec un nombre de secteurs incompatible.' }
            if ($null -ne $official -and $null -ne $penalty -and [Math]::Abs($official-($a['raw_final']+$penalty)) -gt 0.005) { throw 'Chrono officiel incompatible avec cumul brut + penalite (5 ms).' }
            $Db.Exec('UPDATE attempts SET mode=?,validity=?,complete=?,sectors_verified=?,expected_sectors=?,penalty=?,official_final=?,review_origin=? WHERE id=?',@($d.Mode,$d.Validity,$complete,[int]$d.SectorsVerified,$expected,$penalty,$official,'user-attested',$a['id']))
            $Db.Exec('INSERT INTO reviews(attempt_id,review_json,applied_at) VALUES(?,?,?)',@($a['id'],(ConvertTo-Json -InputObject $d -Compress -Depth 5),[DateTime]::UtcNow.ToString('o')))
        }
        $Db.Exec('COMMIT',@())
    } catch { $Db.Exec('ROLLBACK',@()); throw }
}
function Get-AcrCounts($Db,[string]$Profile) {
    return [pscustomobject]@{Attempts=$Db.Query('SELECT COUNT(*) AS n FROM attempts WHERE profile=?',@($Profile))[0]['n'];
        Eligible=$Db.Query('SELECT COUNT(*) AS n FROM eligible_attempts WHERE profile=?',@($Profile))[0]['n'];
        Conflicts=$Db.Query('SELECT COUNT(*) AS n FROM conflicts c JOIN attempts a ON a.id=c.attempt_id WHERE a.profile=?',@($Profile))[0]['n']}
}
function Save-Csv($Rows,[string]$Path) {
    if (@($Rows).Count -gt 0) { $Rows | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding UTF8 }
    else { '' | Set-Content -LiteralPath $Path -Encoding UTF8 }
}
function RecordObject($Dictionary) {
    $record=[ordered]@{}
    foreach ($key in $Dictionary.Keys) { $record[$key]=$Dictionary[$key] }
    return [pscustomobject]$record
}
function Export-AcrStatistics($Db,[string]$Profile,[string]$Root) {
    $output=Join-Path $Root ([DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Path $output -Force | Out-Null
    # One read transaction gives a consistent report even if another process imports.
    $Db.Exec('BEGIN',@())
    try {
        $summary=New-Object 'System.Collections.Generic.List[object]'
        $gains=New-Object 'System.Collections.Generic.List[object]'
        $progress=New-Object 'System.Collections.Generic.List[object]'
        foreach ($context in $Db.Query('SELECT DISTINCT stage,car,layout FROM eligible_attempts WHERE profile=?',@($Profile))) {
            $runs=$Db.Query('SELECT * FROM eligible_attempts WHERE profile=? AND stage=? AND car=? AND layout=? ORDER BY id',@($Profile,$context['stage'],$context['car'],$context['layout']))
            $best=@($runs | Sort-Object { $_['full_time'] },{ $_['id'] })[0]; $mins=@{}; $progressBest=[double]::PositiveInfinity; $order=0
            foreach ($a in $runs) {
                $order++
                foreach ($s in $Db.Query('SELECT * FROM sectors WHERE attempt_id=? ORDER BY sector_index',@($a['id']))) {
                    $i=[int]$s['sector_index']; if (-not $mins.ContainsKey($i) -or $s['duration'] -lt $mins[$i]) { $mins[$i]=[double]$s['duration'] }
                }
                $progressBest=[Math]::Min($progressBest,$a['full_time']); $optimal=($mins.Values | Measure-Object -Sum).Sum
                $progress.Add([pscustomobject]@{Stage=$context['stage'];Car=$context['car'];Layout=$context['layout'];ImportOrder=$order;Chronology='first-import-order-not-game-finish';
                    AttemptKey=$a['attempt_key'];FirstSeen=$a['first_seen'];FullSeconds=$a['full_time'];BestSoFar=$progressBest;OptimalSoFar=$optimal})
            }
            $theory=($mins.Values | Measure-Object -Sum).Sum; $sumBest=0.0
            foreach ($s in $Db.Query('SELECT * FROM sectors WHERE attempt_id=? ORDER BY sector_index',@($best['id']))) {
                $sumBest+=$s['duration']
                $gains.Add([pscustomobject]@{Stage=$context['stage'];Car=$context['car'];Layout=$context['layout'];SectorIndex=$s['sector_index'];
                    BestCompleteSectorSeconds=$s['duration'];HistoricalBestSeconds=$mins[[int]$s['sector_index']];GainSeconds=($s['duration']-$mins[[int]$s['sector_index']]);ReferenceKey=$best['attempt_key']})
            }
            $summary.Add([pscustomobject]@{Stage=$context['stage'];Car=$context['car'];Layout=$context['layout'];Attempts=$runs.Count;BestCompleteSeconds=$best['full_time'];
                OptimalSeconds=$theory;GainSeconds=($best['full_time']-$theory);SectorSumDifferenceSeconds=($best['full_time']-$sumBest);ReferenceKey=$best['attempt_key'];Validation='user-attested'})
        }
        $all=@(foreach ($a in $Db.Query('SELECT * FROM attempts WHERE profile=? ORDER BY id',@($Profile))) { RecordObject $a })
        $conflictRows=@(foreach ($c in $Db.Query('SELECT c.* FROM conflicts c JOIN attempts a ON a.id=c.attempt_id WHERE a.profile=?',@($Profile))) { RecordObject $c })
        $counts=Get-AcrCounts $Db $Profile
        $Db.Exec('COMMIT',@())
    } catch { $Db.Exec('ROLLBACK',@()); throw }
    Save-Csv $summary.ToArray() (Join-Path $output 'resume.csv'); Save-Csv $gains.ToArray() (Join-Path $output 'gains-secteurs.csv')
    Save-Csv $progress.ToArray() (Join-Path $output 'progression.csv'); Save-Csv $all (Join-Path $output 'tentatives.csv')
    Save-Csv $conflictRows (Join-Path $output 'conflits.csv')
    ConvertTo-Json -InputObject @($summary.ToArray()) -Depth 5 | Set-Content (Join-Path $output 'resume.json') -Encoding UTF8
    ConvertTo-Json -InputObject @($gains.ToArray()) -Depth 5 | Set-Content (Join-Path $output 'gains-secteurs.json') -Encoding UTF8
    ConvertTo-Json -InputObject @($progress.ToArray()) -Depth 5 | Set-Content (Join-Path $output 'progression.json') -Encoding UTF8
    @{Profile=$Profile;Counts=$counts;Statistics='User-attested complete valid TT attempts with verified sectors and zero penalty only';
        TimeToleranceSeconds=0.005;AutomaticAcquisition=$false;ProgressChronology='First import order, not verified game timestamps'} |
        ConvertTo-Json -Depth 4 | Set-Content (Join-Path $output 'rapport.json') -Encoding UTF8
    return $output
}
Export-ModuleMember -Function Open-AcrDatabase,Import-AcrExports,New-AcrReviewTemplate,Set-AcrReviews,Get-AcrCounts,Export-AcrStatistics
