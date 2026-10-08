[CmdletBinding()]
param(
    [string[]]$WatchPath=@(),
    [switch]$CopyCandidates,
    [ValidateRange(1,60)][int]$DurationMinutes=10,
    [ValidateRange(100,5000)][int]$IntervalMilliseconds=500,
    [ValidateRange(1,512)][int]$MaxCaptureMiB=100,
    [string]$OutputRoot=(Join-Path $env:LOCALAPPDATA 'ACR-Optimal\SectorEvidence')
)
$ErrorActionPreference='Stop'
if ($env:OS -ne 'Windows_NT') { throw 'Windows requis.' }
if ((Read-Host 'Tapez TT pour confirmer le contre-la-montre') -cne 'TT') { throw 'Mode TT non confirme.' }
$stage=Read-Host 'Speciale exacte et sens'; $car=Read-Host 'Voiture exacte'
if ([string]::IsNullOrWhiteSpace($stage) -or [string]::IsNullOrWhiteSpace($car)) { throw 'Speciale et voiture requises.' }
if ($WatchPath.Count -eq 0) {
    $folder=Read-Host 'Petit dossier reel de logs/sauvegardes ACR a observer'
    if ([string]::IsNullOrWhiteSpace($folder)) { throw 'Dossier requis pour cette observation de fichiers.' }
    $WatchPath=@($folder)
}
$roots=@($WatchPath | ForEach-Object {
    $item=Get-Item -LiteralPath $_
    if (-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Choisir un dossier reel, sans lien.' }
    $item.FullName.TrimEnd('\')
} | Select-Object -Unique)
if (-not $CopyCandidates) {
    $answer=Read-Host 'Conserver localement les copies des petits fichiers candidats ? O/N (N par defaut)'
    $CopyCandidates=($answer -ieq 'O')
}
$run=Join-Path $OutputRoot ([DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
foreach ($root in $roots) {
    if ($run.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Le dossier de sortie doit etre hors des dossiers observes.' }
}
New-Item -ItemType Directory -Path $run -Force | Out-Null
function Record([string]$File,[hashtable]$Row) {
    [pscustomobject]$Row | Export-Csv -LiteralPath (Join-Path $run $File) -Append -NoTypeInformation -Encoding UTF8
}
@{Schema=1; Stage=$stage; Car=$car; Mode='TT'; ModeSource='manual'; StartedUtc=[DateTime]::UtcNow.ToString('o');
    Roots=$roots; CopyCandidates=[bool]$CopyCandidates; MaxCaptureMiB=$MaxCaptureMiB;
    Meaning='File evidence only. No decoded sectors, automatic finish or leaderboard detection.'} |
    ConvertTo-Json -Depth 4 | Set-Content (Join-Path $run 'session.json') -Encoding UTF8
$previous=@{}; $attempt=0; $phase='before'; $used=0L; $sequence=0; $scans=0
$deadline=[DateTime]::UtcNow.AddMinutes($DurationMinutes)
Write-Host "Resultats : $run"
Write-Host 'Dans CETTE console : D=depart, A=arrivee SANS classement, O=classement ouvert, F=classement ferme, Q=fin.'
Write-Host 'Ne pressez aucune touche pendant la conduite. Un second operateur ou une video peut fournir les reperes.'
try {
    while ([DateTime]::UtcNow -lt $deadline) {
        $scans++
        if (-not [Console]::IsInputRedirected) {
            while ([Console]::KeyAvailable) {
                $key=[Console]::ReadKey($true).Key.ToString()
                $label=@{D='start';A='finish-without-leaderboard';O='leaderboard-open';F='leaderboard-closed';Q='stop'}[$key]
                if ($label) {
                    if ($key -eq 'D') { $attempt++ }
                    $phase=$label
                    Record 'markers.csv' @{Utc=[DateTime]::UtcNow.ToString('o'); Attempt=$attempt; Marker=$label; Source='manual-console'}
                    Write-Host "Tentative $attempt : $phase"
                    if ($key -eq 'Q') { return }
                }
            }
        }
        $current=@{}; $complete=$true; $fileCount=0
        foreach ($root in $roots) {
            $scanErrors=@()
            $files=@(Get-ChildItem -LiteralPath $root -File -Recurse -Force -ErrorAction SilentlyContinue -ErrorVariable scanErrors)
            foreach ($e in $scanErrors) { $complete=$false; Record 'errors.csv' @{Utc=[DateTime]::UtcNow.ToString('o'); Path=$root; Message=$e.ToString()} }
            foreach ($f in $files) {
                $fileCount++
                if ($fileCount -gt 2000) { throw 'Plus de 2000 fichiers : choisir des dossiers plus precis.' }
                if ($f.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
                $hash=''; $copy=''; $status='metadata-only'; $keywords=0
                $eligible=$f.Extension.ToLowerInvariant() -in @('.log','.txt','.json','.csv','.ini','.xml','.sav','.db','.sqlite','.sqlite3','.wal','.shm') -or $f.Name -match '(?i)-(wal|shm)$'
                try {
                    if ($eligible -and $f.Length -le 4MB) {
                        $before=$f.LastWriteTimeUtc.Ticks
                        $stream=[IO.File]::Open($f.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
                        try {
                            $memory=New-Object IO.MemoryStream
                            try {
                                $buffer=New-Object byte[] 65536
                                while (($n=$stream.Read($buffer,0,$buffer.Length)) -gt 0) {
                                    if (($memory.Length+$n) -gt 4MB) { throw 'Fichier devenu trop grand.' }
                                    $memory.Write($buffer,0,$n)
                                }
                                $bytes=$memory.ToArray()
                            } finally { $memory.Dispose() }
                        } finally { $stream.Dispose() }
                        $f.Refresh()
                        if ($f.LastWriteTimeUtc.Ticks -ne $before -or $f.Length -ne $bytes.Length) { throw 'Fichier modifie pendant la lecture : retry au prochain scan.' }
                        $sha=[Security.Cryptography.SHA256]::Create()
                        try { $hash=[BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-','').ToLowerInvariant() } finally { $sha.Dispose() }
                        $status='hashed-not-decoded'
                    }
                    $fingerprint="$hash|$($f.Length)|$($f.LastWriteTimeUtc.Ticks)"
                    $current[$f.FullName]=$fingerprint
                    if ($previous.ContainsKey($f.FullName) -and $previous[$f.FullName] -eq $fingerprint) { continue }
                    $event='first-seen'; if ($previous.ContainsKey($f.FullName)) { $event='changed' }
                    if ($hash) {
                        if ($f.Extension.ToLowerInvariant() -in @('.log','.txt','.json','.csv','.ini','.xml')) {
                            $keywords=[regex]::Matches([Text.Encoding]::UTF8.GetString($bytes),'(?i)sector|split|race.?time|leaderboard').Count
                        }
                        if ($CopyCandidates -and ($used+$bytes.Length) -le ($MaxCaptureMiB*1MB)) {
                            $sequence++
                            $dest=Join-Path $run 'snapshots'; New-Item -ItemType Directory -Path $dest -Force | Out-Null
                            $copy=Join-Path $dest ($sequence.ToString('D6')+$f.Extension)
                            [IO.File]::WriteAllBytes($copy,$bytes); $used+=$bytes.Length
                        } elseif ($CopyCandidates) { $status+=';capture-budget-exceeded' }
                    }
                    Record 'files.csv' @{Utc=[DateTime]::UtcNow.ToString('o'); Attempt=$attempt; Phase=$phase; Event=$event; Path=$f.FullName;
                        Bytes=$f.Length; ModifiedUtc=$f.LastWriteTimeUtc.ToString('o'); SHA256=$hash; Snapshot=$copy; Status=$status; KeywordHints=$keywords}
                } catch {
                    $complete=$false
                    if ($previous.ContainsKey($f.FullName)) { $current[$f.FullName]=$previous[$f.FullName] }
                    Record 'errors.csv' @{Utc=[DateTime]::UtcNow.ToString('o'); Path=$f.FullName; Message=$_.Exception.Message}
                }
            }
        }
        if ($complete) {
            foreach ($path in @($previous.Keys)) {
                if (-not $current.ContainsKey($path)) { Record 'removed-files.csv' @{Utc=[DateTime]::UtcNow.ToString('o'); Attempt=$attempt; Phase=$phase; Path=$path} }
            }
            $previous=$current
        } else { foreach ($path in $current.Keys) { $previous[$path]=$current[$path] } }
        Start-Sleep -Milliseconds $IntervalMilliseconds
    }
} finally {
    @{EndedUtc=[DateTime]::UtcNow.ToString('o'); Scans=$scans; CopiedBytes=$used; DecodedAttempts=0} |
        ConvertTo-Json | Set-Content (Join-Path $run 'ended.json') -Encoding UTF8
    Write-Host "Termine : $run"
}
