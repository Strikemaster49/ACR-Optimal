# Requires Windows PowerShell 5.1 or PowerShell 7 on Windows.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateRange(1,2147483647)][int]$GameProcessId,
    [string[]]$WatchPath = @(),
    [ValidateRange(1,10)][int]$IntervalSeconds = 2,
    [ValidateRange(1,180)][int]$DurationMinutes = 15,
    [string]$OutputRoot = (Join-Path $env:LOCALAPPDATA 'ACR-Optimal\Diagnostics')
)
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'Ce diagnostic necessite Windows.' }
$game = Get-Process -Id $GameProcessId -ErrorAction Stop
$gameStart = $game.StartTime.ToUniversalTime()
$roots = @($WatchPath | ForEach-Object {
    $item = Get-Item -LiteralPath $_ -ErrorAction Stop
    if (-not $item.PSIsContainer) { throw "Dossier attendu : $_" }
    $item.FullName
})
$session = Join-Path $OutputRoot ([DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $session -Force | Out-Null
foreach ($root in $roots) {
    if ($session.StartsWith($root.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Le dossier de sortie doit etre hors des dossiers observes.'
    }
}
function Write-Record([string]$File, [hashtable]$Data) {
    [pscustomobject]$Data | Export-Csv -LiteralPath (Join-Path $session $File) -Append -NoTypeInformation -Encoding UTF8
}
function Write-Issue([string]$Area, [string]$Message) {
    Write-Record 'errors.csv' @{Utc=[DateTime]::UtcNow.ToString('o'); Area=$Area; Message=$Message}
}
@{Schema=1; ProcessId=$GameProcessId; ProcessName=$game.ProcessName; ProcessStartUtc=$gameStart.ToString('o');
  StartedUtc=[DateTime]::UtcNow.ToString('o'); WatchPaths=$roots; IntervalSeconds=$IntervalSeconds;
  Meaning='Diagnostic only. No automatic sector timing, game-mode detection or payload decoding.'} |
    ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $session 'session.json') -Encoding UTF8
$previousFiles = @{}
$previousNetwork = @{}
$attempt = 0
$deadline = [DateTime]::UtcNow.AddMinutes($DurationMinutes)
Write-Host "Resultats : $session"
Write-Host 'Dans cette console : D=depart, S=passage secteur, F=arrivee, R=abandon/redemarrage, C=classement, Q=quitter.'
Write-Host 'Ces reperes sont manuels et ne constituent pas des chronos du jeu.'
try {
    while ([DateTime]::UtcNow -lt $deadline) {
        $current = Get-Process -Id $GameProcessId -ErrorAction SilentlyContinue
        if (-not $current -or $current.StartTime.ToUniversalTime() -ne $gameStart) {
            Write-Issue 'process' 'Processus termine ou PID reutilise.'
            break
        }
        $utc = [DateTime]::UtcNow.ToString('o')
        $network = @{}
        foreach ($protocol in @('TCP','UDP')) {
            try {
                if ($protocol -eq 'TCP') { $endpoints = @(Get-NetTCPConnection -ErrorAction Stop | Where-Object OwningProcess -eq $GameProcessId) }
                else { $endpoints = @(Get-NetUDPEndpoint -ErrorAction Stop | Where-Object OwningProcess -eq $GameProcessId) }
                foreach ($ep in $endpoints) {
                    $remote = ''; $remotePort = ''; $state = ''
                    if ($protocol -eq 'TCP') { $remote=$ep.RemoteAddress; $remotePort=$ep.RemotePort; $state=[string]$ep.State }
                    $key = "$protocol|$($ep.LocalAddress)|$($ep.LocalPort)|$remote|$remotePort|$state"
                    $row = @{Utc=$utc; Event='present'; Protocol=$protocol; LocalAddress=$ep.LocalAddress;
                        LocalPort=$ep.LocalPort; RemoteAddress=$remote; RemotePort=$remotePort; State=$state}
                    $network[$key]=$row
                    if (-not $previousNetwork.ContainsKey($key)) { Write-Record 'network.csv' $row }
                }
                foreach ($key in @($previousNetwork.Keys)) {
                    if ($previousNetwork[$key].Protocol -eq $protocol -and -not $network.ContainsKey($key)) {
                        $row=$previousNetwork[$key].Clone(); $row.Utc=$utc; $row.Event='absent'
                        Write-Record 'network.csv' $row
                    }
                }
            } catch {
                Write-Issue "network-$protocol" $_.Exception.Message
                foreach ($key in @($previousNetwork.Keys)) {
                    if ($previousNetwork[$key].Protocol -eq $protocol) { $network[$key]=$previousNetwork[$key] }
                }
            }
        }
        $previousNetwork=$network
        foreach ($root in $roots) {
            $scanErrors = @()
            $files = @(Get-ChildItem -LiteralPath $root -File -Recurse -Force -ErrorAction SilentlyContinue -ErrorVariable scanErrors)
            foreach ($err in $scanErrors) { Write-Issue 'files' $err.ToString() }
            foreach ($file in $files) {
                $fingerprint = "$($file.Length)|$($file.LastWriteTimeUtc.Ticks)"
                $key = $file.FullName
                if (-not $previousFiles.ContainsKey($key) -or $previousFiles[$key] -ne $fingerprint) {
                    $kind = 'changed'
                    if (-not $previousFiles.ContainsKey($key)) { $kind='first-seen' }
                    Write-Record 'files.csv' @{Utc=$utc; Event=$kind; Path=$key; Bytes=$file.Length; ModifiedUtc=$file.LastWriteTimeUtc.ToString('o')}
                    $previousFiles[$key]=$fingerprint
                }
            }
        }
        # Small waits keep manual markers responsive. No global keyboard hook.
        for ($step=0; $step -lt ($IntervalSeconds * 10); $step++) {
            if (-not [Console]::IsInputRedirected -and [Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true).Key.ToString()
                $label = @{D='start'; S='sector'; F='finish'; R='restart-or-retire'; C='leaderboard'; Q='stop'}[$key]
                if ($label) {
                    if ($key -eq 'D') { $attempt++ }
                    Write-Record 'markers.csv' @{Utc=[DateTime]::UtcNow.ToString('o'); Attempt=$attempt; Marker=$label; Source='manual-console'}
                    Write-Host "Tentative $attempt : $label"
                    if ($key -eq 'Q') { return }
                }
            }
            Start-Sleep -Milliseconds 100
        }
    }
} finally {
    [DateTime]::UtcNow.ToString('o') | Set-Content -LiteralPath (Join-Path $session 'ended.txt') -Encoding UTF8
    Write-Host "Diagnostic termine : $session"
}
