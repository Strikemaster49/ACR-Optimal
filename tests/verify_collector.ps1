# Integration harness. On Linux use a COPY with only native DLL name adapted.
param([string]$Root,[string]$WorkDir,[string]$BaselineSave,[string]$NewSave)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Path $WorkDir -Force|Out-Null
$env:LOCALAPPDATA=Join-Path $WorkDir 'local'
# Platform declaration only for this offline harness. No game or WPF is simulated.
$env:OS='Windows_NT'
function global:Read-Host {param($Prompt);return 'TT'}
$database=Join-Path $WorkDir 'collector.sqlite3'
$collector=Join-Path $Root 'collecteur-windows/Collecteur-Experimental.ps1'
$beforeA=(Get-FileHash $BaselineSave).Hash;$beforeB=(Get-FileHash $NewSave).Hash
& $collector -SavePath $BaselineSave -DatabasePath $database -Profile 'test-captures' -Once
& $collector -SavePath $BaselineSave -DatabasePath $database -Profile 'test-captures' -Once
& $collector -SavePath $NewSave -DatabasePath $database -Profile 'test-captures' -Once
Import-Module (Join-Path $Root 'stockage-windows/Stockage.psm1') -Force
$db=Open-AcrDatabase $database
try{
 $counts=Get-AcrCounts $db 'test-captures'
 if($counts.Attempts -ne 8 -or $counts.Eligible -ne 0 -or $counts.Conflicts -ne 0){throw 'Capture/import/quarantaine incorrects'}
 if($db.Query('PRAGMA integrity_check',@())[0]['integrity_check'] -ne 'ok'){throw 'Integrite SQLite'}
}finally{$db.Dispose()}
$hash=(Get-FileHash $database).Hash
$ro=New-Object ACROptimal.Experimental.Database($database,$true)
try{
 $failed=$false
 try{$ro.Exec("UPDATE attempts SET validity='valid'",@())}catch{$failed=$true}
 if(-not $failed){throw 'Lecture seule ne protege pas la base'}
 $report=Export-AcrStatistics $ro 'test-captures' (Join-Path $WorkDir 'reports')
 if((Get-Content (Join-Path $report 'rapport.json') -Raw|ConvertFrom-Json).Counts.Attempts -ne 8){throw 'Rapport readonly incorrect'}
}finally{$ro.Dispose()}
if((Get-FileHash $database).Hash -ne $hash){throw 'Base modifiee en lecture seule'}
if((Get-FileHash $BaselineSave).Hash -ne $beforeA -or (Get-FileHash $NewSave).Hash -ne $beforeB){throw 'Sauvegardes sources modifiees'}
Write-Host 'PASS: collecteur offline, import initial/reitere/nouveau, 8 inconnues, SQLite readonly et sources intactes'
