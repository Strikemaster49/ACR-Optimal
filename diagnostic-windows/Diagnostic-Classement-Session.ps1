# Windows PowerShell 5.1. Read-only observation of user-selected folders and endpoints.
[CmdletBinding()]
param(
    [string[]]$WatchPath = @(),
    [switch]$CopyCandidates,
    [ValidateRange(1,64)][int]$MaxFileMiB = 4,
    [ValidateRange(1,512)][int]$MaxSnapshotMiB = 50,
    [string]$OutputRoot = (Join-Path $env:LOCALAPPDATA 'ACR-Optimal\SessionDiagnostic')
)
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'Windows requis.' }
$mode = Read-Host 'Confirmez le mode contre-la-montre en tapant TT'
if ($mode -cne 'TT') { throw 'Diagnostic reserve au contre-la-montre. Mode non confirme.' }
$stage = Read-Host 'Speciale exacte et sens'
$car = Read-Host 'Voiture exacte'
if ([string]::IsNullOrWhiteSpace($stage) -or [string]::IsNullOrWhiteSpace($car)) { throw 'Speciale et voiture requises.' }
if ($WatchPath.Count -eq 0) {
    Write-Host 'Indiquez un petit dossier de logs/sauvegardes du jeu, ou Entree pour le reseau seul.'
    $folder = Read-Host 'Chemin du dossier'
    if (-not [string]::IsNullOrWhiteSpace($folder)) { $WatchPath=@($folder) }
}
$roots = @($WatchPath | ForEach-Object {
    $item=Get-Item -LiteralPath $_
    if (-not $item.PSIsContainer) { throw "Dossier requis : $_" }
    $item.FullName.TrimEnd('\')
} | Select-Object -Unique)
$run=Join-Path $OutputRoot ([DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $run -Force | Out-Null
foreach ($root in $roots) {
    if ($run.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Sortie situee dans un dossier observe.' }
}
function Record([string]$Name,[hashtable]$Row) {
    [pscustomobject]$Row | Export-Csv -LiteralPath (Join-Path $run $Name) -Append -NoTypeInformation -Encoding UTF8
}
@{Schema=1; Stage=$stage; Car=$car; Mode='TT'; ModeSource='user-confirmed-not-detected';
    Roots=$roots; CopyCandidates=[bool]$CopyCandidates; StartedUtc=[DateTime]::UtcNow.ToString('o');
    Limitation='Snapshots and textual hints only; no sector decoding or automatic game-mode detection.'} |
    ConvertTo-Json -Depth 4 | Set-Content (Join-Path $run 'session.json') -Encoding UTF8
$phases = @(
    @('01-avant-speciale','Restez au menu avant une nouvelle session TT.'),
    @('02-apres-a','Terminez la tentative A. Notez le chrono global, sans ouvrir le classement de session.'),
    @('03-apres-b','Terminez B, plus lente au total mais meilleure sur un secteur si possible. Ne consultez pas encore le classement.'),
    @('04-classement-ouvert','Ouvrez le CLASSEMENT DE SESSION avec les secteurs de A et B. Conservez une capture et les valeurs exactes.'),
    @('05-classement-ferme','Fermez uniquement ce classement, restez dans la meme session.'),
    @('06-session-quitte','Quittez la session puis fermez normalement le jeu.'),
    @('07-jeu-relance','Relancez ACR et cherchez les anciennes tentatives dans le classement de session. Ne faites pas de nouveau run.')
)
$previous=@{}
try {
    foreach ($phase in $phases) {
        $name=$phase[0]
        Write-Host "`n$name : $($phase[1])"
        $note=Read-Host 'Une fois cette etape atteinte, Entree pour observer (ou une note puis Entree)'
        $utc=[DateTime]::UtcNow.ToString('o')
        Record 'phases.csv' @{Phase=$name; Utc=$utc; Note=$note}
        $processes=@(Get-Process -Name acr -ErrorAction SilentlyContinue)
        foreach ($p in $processes) {
            Record 'processes.csv' @{Phase=$name; Utc=$utc; ProcessId=$p.Id; Name=$p.ProcessName}
            foreach ($proto in @('TCP','UDP')) {
                try {
                    if ($proto -eq 'TCP') { $eps=@(Get-NetTCPConnection -ErrorAction Stop | Where-Object OwningProcess -eq $p.Id) }
                    else { $eps=@(Get-NetUDPEndpoint -ErrorAction Stop | Where-Object OwningProcess -eq $p.Id) }
                    foreach ($ep in $eps) {
                        $remote=''; $port=''; $state=''
                        if ($proto -eq 'TCP') { $remote=$ep.RemoteAddress; $port=$ep.RemotePort; $state=[string]$ep.State }
                        Record 'network.csv' @{Phase=$name; Utc=$utc; ProcessId=$p.Id; Protocol=$proto; LocalAddress=$ep.LocalAddress;
                            LocalPort=$ep.LocalPort; RemoteAddress=$remote; RemotePort=$port; State=$state}
                    }
                } catch { Record 'errors.csv' @{Phase=$name; Area='network'; Message=$_.Exception.Message} }
            }
        }
        $current=@{}; $copied=0L; $fileCount=0; $complete=$true
        foreach ($root in $roots) {
            $scanErrors=@()
            $files=@(Get-ChildItem -LiteralPath $root -File -Recurse -Force -ErrorAction SilentlyContinue -ErrorVariable scanErrors)
            foreach ($e in $scanErrors) { $complete=$false; Record 'errors.csv' @{Phase=$name; Area='scan'; Message=$e.ToString()} }
            foreach ($f in $files) {
                $fileCount++
                if ($fileCount -gt 5000) { throw 'Plus de 5000 fichiers : choisissez des dossiers plus precis.' }
                $hash=''; $status='metadata-only'; $copy=''; $hints=0; $timeHints=0
                $eligible=$f.Extension.ToLowerInvariant() -in @('.log','.txt','.json','.csv','.ini','.xml','.sav','.db','.sqlite','.sqlite3','.wal','.shm') -or $f.Name -match '(?i)-(wal|shm)$'
                try {
                    if ($eligible -and $f.Length -le ($MaxFileMiB*1MB)) {
                        # Shared read; compare and copy the SAME bytes. No writes to game files.
                        $stream=[IO.File]::Open($f.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
                        try {
                            $buffer=New-Object byte[] (($MaxFileMiB*1MB)+1)
                            $read=0
                            while ($read -lt $buffer.Length) {
                                $n=$stream.Read($buffer,$read,$buffer.Length-$read)
                                if ($n -eq 0) { break }; $read+=$n
                            }
                        } finally { $stream.Dispose() }
                        if ($read -gt ($MaxFileMiB*1MB)) { throw 'Fichier depassant la limite pendant la lecture.' }
                        $bytes=New-Object byte[] $read
                        [Array]::Copy($buffer,$bytes,$read)
                        $sha=[Security.Cryptography.SHA256]::Create()
                        try { $hash=[BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-','').ToLowerInvariant() } finally { $sha.Dispose() }
                        $status='hashed-not-decoded'
                        if ($f.Extension.ToLowerInvariant() -in @('.log','.txt','.json','.csv','.ini','.xml')) {
                            $text=[Text.Encoding]::UTF8.GetString($bytes)
                            $hints=[regex]::Matches($text,'(?i)sector|split|rally|race.?time|lap.?time|leaderboard').Count
                            $timeHints=[regex]::Matches($text,'\b\d{1,2}:\d{2}[.,]\d{1,3}\b').Count
                        }
                        if ($CopyCandidates -and ($copied+$read) -le ($MaxSnapshotMiB*1MB)) {
                            $dest=Join-Path $run ('snapshots\'+$name)
                            New-Item -ItemType Directory -Path $dest -Force | Out-Null
                            $copy=Join-Path $dest ($fileCount.ToString('D5')+$f.Extension)
                            [IO.File]::WriteAllBytes($copy,$bytes); $copied+=$read
                        } elseif ($CopyCandidates) { $status+=';copy-budget-exceeded' }
                    }
                } catch { $status='read-failed'; Record 'errors.csv' @{Phase=$name; Area=$f.FullName; Message=$_.Exception.Message} }
                $fingerprint="$hash|$($f.Length)|$($f.LastWriteTimeUtc.Ticks)"
                $event='first-seen'
                if ($previous.ContainsKey($f.FullName)) {
                    $event='unchanged'
                    if ($previous[$f.FullName] -ne $fingerprint) { $event='changed' }
                }
                $current[$f.FullName]=$fingerprint
                Record 'files.csv' @{Phase=$name; Utc=$utc; Path=$f.FullName; Bytes=$f.Length; ModifiedUtc=$f.LastWriteTimeUtc.ToString('o');
                    SHA256=$hash; Event=$event; Status=$status; Snapshot=$copy; KeywordHints=$hints; TimePatternHints=$timeHints}
            }
        }
        if ($complete) {
            foreach ($path in @($previous.Keys)) {
                if (-not $current.ContainsKey($path)) { Record 'removed-files.csv' @{Phase=$name; Utc=$utc; Path=$path} }
            }
            $previous=$current
        } else {
            # Avoid treating unreadable paths as deletions.
            foreach ($path in $current.Keys) { $previous[$path]=$current[$path] }
        }
        Write-Host "$fileCount fichiers observes ; $copied octets copies. Les indices textuels ne sont pas des chronos verifies."
    }
} finally {
    [DateTime]::UtcNow.ToString('o') | Set-Content (Join-Path $run 'ended.txt') -Encoding UTF8
    Write-Host "Resultats : $run"
}
