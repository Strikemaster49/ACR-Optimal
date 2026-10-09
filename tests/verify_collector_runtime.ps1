param([string]$ModulePath,[string]$WorkDir)
$ErrorActionPreference='Stop'
Import-Module $ModulePath -Force
function Assert($v,$m){if(-not $v){throw $m}}
$start=[DateTime]::UtcNow
Assert (-not (Test-AcrCollectorDeadline $start 0 $start.AddDays(30))) 'Mode normal limite'
Assert (-not (Test-AcrCollectorDeadline $start 20 $start.AddMinutes(16))) 'Fin prematuree du test'
Assert (Test-AcrCollectorDeadline $start 20 $start.AddMinutes(20)) 'Duree de test ignoree'
Assert ((Get-AcrCollectorState $false $false $false $false '') -eq 'Arrete') 'Arrete'
Assert ((Get-AcrCollectorState $true $false $false $true '') -eq 'Demarrage') 'Demarrage'
Assert ((Get-AcrCollectorState $true $false $false $false '') -eq 'EnAttenteDuJeu') 'Attente'
Assert ((Get-AcrCollectorState $true $true $false $false '') -eq 'ConnecteAuJeu') 'Connecte'
Assert ((Get-AcrCollectorState $true $true $true $false '') -eq 'CollecteActive') 'Collecte'
Assert ((Get-AcrCollectorState $true $true $true $false 'error') -eq 'Erreur') 'Erreur'
New-Item -ItemType Directory -Path $WorkDir -Force|Out-Null
$path=Join-Path $WorkDir 'status.json'
Write-AcrCollectorJson @{State='Demarrage'} $path
Write-AcrCollectorJson @{State='CollecteActive'} $path
Assert ((Get-Content $path -Raw|ConvertFrom-Json).State -eq 'CollecteActive') 'Publication atomique'
Assert (@(Get-ChildItem $WorkDir -Filter '*.tmp').Count -eq 0) 'Fichiers temporaires non nettoyes'
Write-Host 'PASS duree illimitee/test configurable, six etats, JSON atomique'
