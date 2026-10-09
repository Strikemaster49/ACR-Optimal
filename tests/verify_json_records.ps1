param([string]$ModulePath,[string]$WorkDir)
$ErrorActionPreference='Stop'
Import-Module $ModulePath -Force
New-Item -ItemType Directory -Path $WorkDir -Force|Out-Null
$path=Join-Path $WorkDir 'progression.json'
Set-Content $path '[{"FullSeconds":138.296},{"FullSeconds":137.413}]'
# Reproduce Windows PowerShell 5.1 pipeline behaviour with PS7's -NoEnumerate.
$old=@(Get-Content $path -Raw|ConvertFrom-Json -NoEnumerate)
$reproduced=$false
try {foreach($r in $old){Format-AcrTime $r.FullSeconds|Out-Null}}catch{$reproduced=$true}
if(-not $reproduced){throw 'The original Object[] -> Double failure was not reproduced'}
function CheckRecords {
 $r=@(Read-AcrJsonRecords $path)
 if($r.Count -ne 2 -or (Format-AcrTime $r[0].FullSeconds) -ne '2:18.296' -or (Format-AcrTime $r[1].FullSeconds) -ne '2:17.413'){throw 'Records remain nested'}
 Set-Content $path '[]'
 if(@(Read-AcrJsonRecords $path).Count -ne 0){throw 'Empty array not handled'}
 Set-Content $path '[{"FullSeconds":137.413}]'
 $one=@(Read-AcrJsonRecords $path)
 if($one.Count -ne 1 -or (Format-AcrTime $one[0].FullSeconds) -ne '2:17.413'){throw 'Single record not handled'}
 Set-Content $path '[{"FullSeconds":138.296},{"FullSeconds":137.413}]'
}
CheckRecords
# Substitute only the JSON cmdlet's output enumeration inside the module.
$module=Get-Module Presentation
& $module {
 function script:ConvertFrom-Json {
  param([Parameter(ValueFromPipeline=$true)][string]$InputObject)
  process {$InputObject|Microsoft.PowerShell.Utility\ConvertFrom-Json -NoEnumerate}
 }
}
CheckRecords
Write-Host 'PASS: original failure reproduced, JSON empty/single/multiple records under PS7 and PS5.1 enumeration semantics'
