param([string]$ModulePath)
$ErrorActionPreference='Stop'
Import-Module $ModulePath -Force
function Check($a,$b) {if($a -ne $b){throw "Attendu '$b', obtenu '$a'"}}
Check (Format-AcrTime 137.4130096435547) '2:17.413'
Check (Format-AcrTime 59.9996) '1:00.000'
Check (Format-AcrTime 3599.9996) '60:00.000'
Check (Format-AcrTime $null) '--:--.---'
Check (Format-AcrGain -0.0000096435547) '0.000 s'
Check (Format-AcrGain -0.883) '-0.883 s'
Check (Format-AcrGain 0.0005) '0.001 s'
Check (Get-AcrDisplayStatus @{conflicted=0;eligible=1;review_origin='user-attested'}) 'Confirmee - admissible'
Check (Get-AcrDisplayStatus @{conflicted=1;eligible=1;review_origin='user-attested'}) 'Conflit - exclue'
Check (Get-AcrDisplayStatus @{conflicted=0;eligible=0;review_origin='none'}) 'En attente de validation'
[Threading.Thread]::CurrentThread.CurrentCulture=[Globalization.CultureInfo]::GetCultureInfo('fr-FR')
Check (Format-AcrGain 0.883) '0.883 s'
Check (Format-AcrTime 137.4130096435547) '2:17.413'
Write-Host 'PASS: millisecondes, retenues, zero signe, locale, statuts'
