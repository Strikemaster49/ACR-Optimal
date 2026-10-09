[CmdletBinding()]
param(
 [string]$SavePath=(Join-Path $env:LOCALAPPDATA 'acr\Saved\SaveGames\PlayerDataSaveSlot.sav'),
 [string]$StageId='AlsaceS4SaverneShort1Forward',[string]$CarId='SkodaFabiaRSRally2',
 [string]$Profile='joueur-local',
 [string]$DatabasePath=(Join-Path $env:LOCALAPPDATA 'ACR-Optimal\Experimental\acr-experimental.sqlite3'),
 [ValidateRange(0,1440)][int]$Minutes=0,[switch]$Once,
 [string[]]$GameProcessNames=@('acr','acr-Win64-Shipping')
)
$ErrorActionPreference='Stop'
if($env:OS -ne 'Windows_NT' -or -not [Environment]::Is64BitProcess){throw 'Windows 10/11 x64 requis.'}
Write-Host 'Collecte passive : aucune ecriture dans le jeu, nouvelles tentatives en attente de validation.'
Write-Host "Duree : $Minutes minute(s), 0 = sans limite. Fermer la console pour arreter."
if((Read-Host 'Tapez TT uniquement pour une session contre-la-montre') -cne 'TT'){throw 'Mode TT non confirme.'}
Import-Module (Join-Path $PSScriptRoot 'CollectorRuntime.psm1')
$root=Join-Path $env:LOCALAPPDATA ('ACR-Optimal\CollectorEvidence\'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $root|Out-Null
$request=@{SavePath=$SavePath;StageId=$StageId;CarId=$CarId;Profile=$Profile;DatabasePath=$DatabasePath;Minutes=$Minutes;Once=[bool]$Once;TTConfirmed=$true;GameProcessNames=$GameProcessNames;OwnerId=0;OwnerTicks=0}
Write-AcrCollectorJson $request (Join-Path $root 'session.json')
Write-Host "Source : $SavePath | Speciale : $StageId | Voiture : $CarId"
Write-Host "Preuves et etat : $root"
& (Join-Path $PSScriptRoot 'CollectorWorker.ps1') -RequestPath (Join-Path $root 'session.json')
