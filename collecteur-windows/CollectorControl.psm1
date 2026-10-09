Import-Module (Join-Path $PSScriptRoot 'CollectorRuntime.psm1')
function Start-AcrCollector {
 param([string]$SavePath,[string]$StageId,[string]$CarId,[string]$Profile,[string]$DatabasePath,[int]$Minutes=0,[string[]]$GameProcessNames=@('acr','acr-Win64-Shipping'))
 if($Minutes -lt 0 -or $Minutes -gt 1440){throw 'Duree invalide (0 a 1440 minutes).'}
 if($GameProcessNames.Count -eq 0 -or @($GameProcessNames|Where-Object {$_ -notmatch '^[A-Za-z0-9_.-]+$'}).Count){throw 'Noms de processus invalides.'}
 $root=Join-Path $env:LOCALAPPDATA ('ACR-Optimal\CollectorEvidence\'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
 New-Item -ItemType Directory -Path $root|Out-Null
 $owner=Get-Process -Id $PID
 $request=@{SavePath=$SavePath;StageId=$StageId;CarId=$CarId;Profile=$Profile;DatabasePath=$DatabasePath;Minutes=$Minutes;Once=$false;TTConfirmed=$true;GameProcessNames=$GameProcessNames;OwnerId=$PID;OwnerTicks=$owner.StartTime.ToUniversalTime().Ticks}
 $path=Join-Path $root 'session.json';Write-AcrCollectorJson $request $path
 $exe=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
 $worker=Join-Path $PSScriptRoot 'CollectorWorker.ps1'
 $process=Start-Process -FilePath $exe -ArgumentList @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$worker+'"'),'-RequestPath',('"'+$path+'"')) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $root 'stdout.log') -RedirectStandardError (Join-Path $root 'stderr.log')
 return [pscustomobject]@{Process=$process;Root=$root;StatusPath=(Join-Path $root 'status.json');StopPath=(Join-Path $root 'stop')}
}
function Stop-AcrCollector($Handle) {
 if($null -ne $Handle){[IO.File]::WriteAllText($Handle.StopPath,'stop',[Text.Encoding]::UTF8)}
}
function Read-AcrCollectorStatus($Handle) {
 if($null -eq $Handle){return $null}
 if(Test-Path -LiteralPath $Handle.StatusPath){return (Get-Content -LiteralPath $Handle.StatusPath -Raw|ConvertFrom-Json)}
 return $null
}
Export-ModuleMember -Function Start-AcrCollector,Stop-AcrCollector,Read-AcrCollectorStatus
