param([string]$Root,[string]$SavePath,[string]$WorkDir)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $Root 'setup-engineer/SetupEngine.psm1') -Force
Import-Module (Join-Path $Root 'setup-engineer/SetupHistory.psm1') -Force
New-Item -ItemType Directory -Path $WorkDir -Force|Out-Null
$s=Read-AcrSetups $SavePath
$a=Save-AcrSetupSnapshot $s $WorkDir
$b=Save-AcrSetupSnapshot $s $WorkDir
$before=@((Get-FileHash $a).Hash,(Get-FileHash $b).Hash)
$history=@(Get-AcrSetupHistory $WorkDir)
if($history.Count -ne 4){throw 'Historique incomplet : deux versions x deux voitures attendues'}
if(@(Get-AcrSetupHistory (Join-Path $WorkDir 'absent')).Count -ne 0){throw 'Historique absent non gere'}
Set-Content (Join-Path $WorkDir 'setup-bad.json') '{invalid'
$history=@(Get-AcrSetupHistory $WorkDir)
if($history.Count -ne 5 -or @($history|Where-Object {$_.Etat -like 'Illisible*'}).Count -ne 1){throw 'Erreur JSON masque les versions valides'}
if((Get-FileHash $a).Hash -ne $before[0] -or (Get-FileHash $b).Hash -ne $before[1]){throw 'Historique modifie les snapshots'}
Write-Host 'PASS historique existant, plusieurs versions, repertoire absent, JSON illisible signale, sources intactes'
