param([string]$ModulePath,[string]$SavePath,[string]$WorkDir)
$ErrorActionPreference='Stop'
Import-Module $ModulePath -Force
New-Item -ItemType Directory -Path $WorkDir -Force|Out-Null
function Assert($test,[string]$message){if(-not $test){throw $message}}
$hash=(Get-FileHash $SavePath).Hash
$s=Read-AcrSetups $SavePath
Assert ($s.Setups.Count -eq 2) 'Deux setups attendus dans la copie connue'
Assert (@($s.Setups|Where-Object {$_.ParameterCount -eq 65}).Count -eq 2) '65 reglages chacun'
$fabia=@($s.Setups|Where-Object {$_.CarId -eq 'SkodaFabiaRSRally2'})[0]
Assert ($fabia.Name -eq 'alsace 06' -and $fabia.StageHint -eq 'Saverne') 'Contexte Fabia'
$p=@($fabia.Parameters|Where-Object {$_.Key -eq 'Brakes.BrakesMain.FrontBias'})[0]
Assert ($p.Value -eq 0.53 -and $p.RawValue -eq '0.530000') 'Valeur brute bias'
Assert ($null -eq $p.Unit -and $p.AllowedRange.Status -eq 'unknown') 'Unites/plages inventees'
$a=Save-AcrSetupSnapshot $s $WorkDir;$b=Save-AcrSetupSnapshot $s $WorkDir
Assert ($a -ne $b) 'Snapshot ecrase'
$loaded=Read-AcrSetupSnapshot $a
Assert ($loaded.Setups[1].VersionId -eq $fabia.VersionId) 'Version change apres persistence'
$equal=@(Compare-AcrSetups $fabia $loaded.Setups[1])
Assert ($equal.Count -eq 65 -and @($equal|Where-Object {$_.Status -ne 'unchanged'}).Count -eq 0) 'Comparaison relecture'
$raw=[IO.File]::ReadAllBytes($SavePath)
$patched=[byte[]]$raw.Clone();$text=[Text.Encoding]::ASCII.GetString($patched);$at=$text.IndexOf('55000.000000')
Assert ($at -gt 0) 'Valeur fixture introuvable'
[Text.Encoding]::ASCII.GetBytes('56000.000000').CopyTo($patched,$at)
$copy=Join-Path $WorkDir 'synthetic-change.sav';[IO.File]::WriteAllBytes($copy,$patched)
$changed=Read-AcrSetups $copy
$other=@($changed.Setups|Where-Object {$_.CarId -eq 'SkodaFabiaRSRally2'})[0]
$diff=@(Compare-AcrSetups $fabia $other|Where-Object {$_.Status -eq 'changed'})
Assert ($diff.Count -eq 1 -and $diff[0].Key -eq 'Suspensions.FrontLeft.SpringStiffness' -and $diff[0].DeltaRaw -eq 1000) 'Difference synthetique incorrecte'
Assert ($fabia.VersionId -ne $other.VersionId) 'Version modifiee fusionnee'
$refused=$false;try{Compare-AcrSetups $s.Setups[0] $fabia|Out-Null}catch{$refused=$true};Assert $refused 'Voitures differentes acceptees'
$shift=Join-Path $WorkDir 'synthetic-offset.sav'
[IO.File]::WriteAllBytes($shift,([byte[]]($raw[0..255]+(New-Object byte[] 16)+$raw[256..($raw.Length-1)])))
$moved=Read-AcrSetups $shift
Assert ($moved.Setups[1].VersionId -eq $fabia.VersionId) 'Offset change la version'
$truncated=Join-Path $WorkDir 'synthetic-truncated.sav';[IO.File]::WriteAllBytes($truncated,$raw[0..($raw.Length-15)])
$t=Read-AcrSetups $truncated
Assert ($t.Setups.Count -eq 1 -and $t.RejectedCandidates.Count -gt 0) 'Bloc tronque accepte'
foreach($behaviour in @('understeer','oversteer','braking','traction','stability','bumps')){
 $advice=Get-AcrSetupAdvice $fabia 'gravel' $behaviour 'mid-corner'
 Assert ($advice.Evidence -eq 'driver-report-not-telemetry' -and $null -eq $advice.NumericTarget -and -not $advice.UnitAndRangeVerified -and $advice.Applicable) 'Conseil invente ou mauvais filtrage'
}
$link=New-AcrSetupLinkTemplate $fabia
Assert (-not $link.ConfirmedUsed -and $null -eq $link.AttemptKey -and $null -eq $link.StageId) 'Liaison historique inventee'
Assert ((Get-FileHash $SavePath).Hash -eq $hash) 'Source modifiee'
Write-Host 'PASS: 2 setups reels/130 reglages, versions persistantes, comparaison, mutation et troncature synthetiques, hypotheses conditionnelles, aucune liaison inventee, source intacte'
