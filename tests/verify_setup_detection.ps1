param([string]$Root=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
Import-Module (Join-Path $Root 'ocr-windows/SetupDetection.psm1') -Force
function Assert($condition,[string]$message){if(-not $condition){throw $message}}
function Refused([scriptblock]$Operation){$refused=$false;try{& $Operation|Out-Null}catch{$refused=$true};Assert $refused 'Operation aurait du etre refusee'}
$s=[pscustomobject]@{CarId='Polo';Name='GPT';VersionId='one'}
$state=New-AcrSetupDetectionState
$e=Update-AcrSetupDetection $state 'GPT' 'Polo' $true @($s) $true
Assert (-not $e.TitleFound -and $null -eq $state.Candidate) 'Selection rouge acceptee'
$e=Update-AcrSetupDetection $state 'CONFIGURATION DE LA VOITURE | Equilibre' 'Polo' $true @($s)
Assert ($state.State -eq 'Selectionne') 'Baseline consideree chargee'
$e=Update-AcrSetupDetection $state 'CONFIGURATION DE LA VOITURE | GPT' 'Polo' $false @($s)
Assert ($state.State -eq 'ChargeDetecte' -and $null -eq $state.Candidate) 'Voiture non confirmee acceptee'
$e=Update-AcrSetupDetection $state 'CONFIGURATION DE LA VOITURE | GPT' 'Polo' $true @($s)
Assert ($state.State -eq 'AppliqueNonConfirme' -and $e.MatchedVersionId -eq 'one') 'Titre et voiture ne correspondent pas'
Refused {Confirm-AcrSetupDeclaration $state $false $true}
Refused {Confirm-AcrSetupDeclaration $state $true $false}
$d=Confirm-AcrSetupDeclaration $state $true $true
Assert ($d.Scope -eq 'next-attempt-only' -and $null -eq $d.AttemptKey -and -not $d.AutomaticAssociation) 'Association chrono ou retroactive'
$e=Invalidate-AcrSetupDetection $state 'Reglage modifie sans sauvegarde'
Assert ($e.InvalidatesDeclarationId -eq $d.Id) 'Invalidation ne reference pas la declaration precedente'
Refused {Confirm-AcrSetupDeclaration $state $true $true}
$e=Update-AcrSetupDetection $state 'CONFIGURATION DE LA VOITURE | GPT' 'Polo' $true @($s)
Assert ($state.State -eq 'CorrespondanceInvalidee') 'Titre inchange efface modification'
$e=Update-AcrSetupDetection $state 'CONFIGURATION DE LA VOITURE | GPT' 'Polo' $true @($s) $true
Assert ($state.State -eq 'AppliqueNonConfirme') 'Rechargement manuel non reconnu'
$other=[pscustomobject]@{CarId='Polo';Name='GPT';VersionId='two'}
$e=Update-AcrSetupDetection $state 'CONFIGURATION DE LA VOITURE | GPT' 'Polo' $true @($s,$other)
Assert ($e.Ambiguous -and $null -eq $state.Candidate) 'Historique ambigu arbitrairement resolu'
Assert (Test-AcrSavedSetupMatch $s @($s)) 'Version identique refusee'
Assert (-not (Test-AcrSavedSetupMatch $s @($other))) 'Version modifiee acceptee'
$e=Select-AcrManualSetupCandidate $state $s 'Polo' $true
Assert ($e.Source -eq 'manual-snapshot-choice') 'Preuve manuelle confondue avec OCR'
Refused {Select-AcrManualSetupCandidate $state $s 'Skoda' $true}
$d=Confirm-AcrSetupDeclaration $state $true $true
$e=Update-AcrSetupDetection $state 'Titre illisible' 'Polo' $true @($s)
Assert ($null -eq $state.Declaration -and $null -eq $state.Candidate -and $state.State -eq 'Selectionne') 'Preuve perimee apres titre perdu'
$e=Update-AcrSetupDetection $state 'CONFIGURATION DE LA VOITURE | GPT' 'Skoda' $true @($s) $true
Assert ($null -eq $state.Candidate) 'Mauvaise voiture acceptee'
Assert ($e.Utc -and $null -eq $e.Confidence.Score -and -not $e.AutomaticAssociation) 'Preuve sans heure ou probabilite inventee'
Write-Host 'PASS detection : baseline, selection, titre, voiture, ambiguite, modification, rechargement, confirmation, absence de lien chrono'
