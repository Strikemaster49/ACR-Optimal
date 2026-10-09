[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$RequestPath)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'CollectorRuntime.psm1')
$request=Get-Content -LiteralPath $RequestPath -Raw|ConvertFrom-Json
if(-not $request.TTConfirmed){throw 'Contre-la-montre non confirme.'}
if($request.Profile -notmatch '^[\p{L}\p{N} _.\-]{1,64}$'){throw 'Profil invalide.'}
$root=[IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($RequestPath))
$statusPath=Join-Path $root 'status.json';$stopPath=Join-Path $root 'stop'
$started=[DateTime]::UtcNow;$db=$null;$lock=$null;$last='';$game='';$errors='';$retryAt=[DateTime]::MinValue
$segment=0;$count=0;$total=0;$evidence=$null;$fatal=$false
$pendingHash='';$pendingCopy=$null;$pendingOut=$null;$pendingCsv=$null
$status=[ordered]@{State='Demarrage';Running=$true;Connected=$false;Ready=$false;HeartbeatUtc=$started.ToString('o');
 StartedUtc=$started.ToString('o');LastEvent='Demarrage';LastEventUtc=$started.ToString('o');LastAttempt=$null;
 Attempts=0;Eligible=0;Conflicts=0;Error=$null;GameSignature='';EvidencePath=$null;Minutes=[int]$request.Minutes}
function Event([string]$Message,[string]$ErrorText='') {
 Write-Host $Message
 if($ErrorText){Write-Warning $ErrorText}
 $status.LastEvent=$Message;$status.LastEventUtc=[DateTime]::UtcNow.ToString('o');$status.Error=$ErrorText
 [pscustomobject]@{Utc=$status.LastEventUtc;Event=$Message;Error=$ErrorText}|Export-Csv (Join-Path $root 'events.csv') -Append -NoTypeInformation -Encoding UTF8
 if($ErrorText){[pscustomobject]@{Utc=$status.LastEventUtc;Message=$Message;Error=$ErrorText}|Export-Csv (Join-Path $root 'errors.csv') -Append -NoTypeInformation -Encoding UTF8}
}
function Publish {
 $status.HeartbeatUtc=[DateTime]::UtcNow.ToString('o')
 $status.State=Get-AcrCollectorState $status.Running $status.Connected $status.Ready ($null -eq $db -and -not $fatal) $status.Error
 Write-AcrCollectorJson $status $statusPath
}
try {
 # A database-specific OS file lock prevents competing GUI/CLI collectors.
 $dbPath=[IO.Path]::GetFullPath($request.DatabasePath)
 New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($dbPath)) -Force|Out-Null
 $lock=[IO.File]::Open($dbPath+'.collector.lock',[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
 Import-Module (Join-Path $PSScriptRoot '..\stockage-windows\Stockage.psm1')
 $db=Open-AcrDatabase $dbPath
 Event 'Collecteur pret. Nouvelles tentatives en attente de validation.'
 while(-not (Test-Path -LiteralPath $stopPath) -and -not (Test-AcrCollectorDeadline $started ([int]$request.Minutes) ([DateTime]::UtcNow))) {
  if($request.OwnerId -gt 0){
   try{$owner=Get-Process -Id $request.OwnerId -ErrorAction Stop;if([long]$request.OwnerTicks -gt 0 -and $owner.StartTime.ToUniversalTime().Ticks -ne [long]$request.OwnerTicks){break}}catch{break}
  }
  $signature=Get-AcrGameSignature @($request.GameProcessNames)
  $status.Connected=([string]::IsNullOrEmpty($signature) -eq $false)
  if($signature -ne $game){
   if($signature){Event 'Processus du jeu detecte ou redemarre : reprise de la surveillance.'}else{Event 'Jeu ferme : attente du prochain lancement.'}
   $game=$signature;$last='';$errors='';$retryAt=[DateTime]::MinValue
  }
  $status.GameSignature=$signature;$status.Ready=$false
  try {
   # Read changes even after game exit: a final save may arrive during shutdown.
   if(Test-Path -LiteralPath $request.SavePath -PathType Leaf){
    $a=Read-AcrCollectorBytes $request.SavePath;$hash=Get-AcrCollectorHash $a
    if($hash -ne $last -and [DateTime]::UtcNow -ge $retryAt){
     Start-Sleep -Milliseconds 600
     $b=Read-AcrCollectorBytes $request.SavePath
     if((Get-AcrCollectorHash $b) -eq $hash){
      if($pendingHash -ne $hash -or $null -eq $pendingCopy){
       if($null -eq $evidence -or $count -ge 500 -or $total+$b.Length -gt 100MB){
        $segment++;$count=0;$total=0;$evidence=Join-Path $root ('evidence-{0:000}' -f $segment)
        New-Item -ItemType Directory -Path $evidence|Out-Null;$status.EvidencePath=$evidence
       }
       $count++;$copy=Join-Path $evidence ('{0:000000}.sav' -f $count);[IO.File]::WriteAllBytes($copy,$b);$total+=$b.Length
       $pendingHash=$hash;$pendingCopy=$copy;$pendingOut=Join-Path $evidence ('export-{0:000000}' -f $count);$pendingCsv=$null
      }
      $copy=$pendingCopy;$out=$pendingOut
      $before=[long]$db.Query('SELECT COALESCE(MAX(id),0) AS n FROM attempts WHERE profile=?',@($request.Profile))[0]['n']
      if($null -eq $pendingCsv){
       & (Join-Path $PSScriptRoot '..\diagnostic-windows\Lire-Sauvegarde-Secteurs.ps1') -SavePath $copy -StageId $request.StageId -CarId $request.CarId -OutputRoot $out | Out-Null
       $pendingCsv=@(Get-ChildItem -LiteralPath $out -Filter secteurs.csv -Recurse -File|Select-Object -ExpandProperty FullName)
      }
      $csv=$pendingCsv
      $r=Import-AcrExports $db $csv $request.Profile
      $new=$db.Query('SELECT id,attempt_key,block_token,run_index,stage,car,raw_final FROM attempts WHERE profile=? AND id>? ORDER BY id DESC LIMIT 1',@($request.Profile,$before))
      if($new.Count){$row=$new[0];$status.LastAttempt=[ordered]@{Id=$row['id'];Key=$row['attempt_key'];Block=$row['block_token'];RunIndex=$row['run_index'];Stage=$row['stage'];Car=$row['car'];Seconds=$row['raw_final'];Validation='En attente'}}
      Event ("Import : $($r.Inserted) nouvelles, $($r.Repeated) connues, $($r.Conflicts) conflits.")
      [pscustomobject]@{Utc=[DateTime]::UtcNow.ToString('o');Copy=$copy;SourceSHA256=$hash;Inserted=$r.Inserted;Repeated=$r.Repeated;Conflicts=$r.Conflicts}|Export-Csv (Join-Path $root 'collecteur.csv') -Append -NoTypeInformation -Encoding UTF8
      $last=$hash;$errors='';$retryAt=[DateTime]::MinValue
      if($r.Conflicts -gt 0){$c=Get-AcrCounts $db $request.Profile;$status.Attempts=$c.Attempts;$status.Eligible=$c.Eligible;$status.Conflicts=$c.Conflicts;$fatal=$true;throw 'Conflit conserve : arreter pour examen, aucun contenu remplace.'}
     }
    }
    $status.Ready=$true
    if(-not $errors){$status.Error=$null}
   }else{
    if($errors -ne 'absent'){Event 'Sauvegarde absente : attente de sa creation.';$errors='absent'}
   }
  }catch{
   $message=$_.Exception.Message
   if($errors -ne $message){Event 'Lecture/import differe.' $message;$errors=$message}
   $retryAt=[DateTime]::UtcNow.AddSeconds(10)
   if($fatal){throw}
  }
  $counts=Get-AcrCounts $db $request.Profile
  $status.Attempts=$counts.Attempts;$status.Eligible=$counts.Eligible;$status.Conflicts=$counts.Conflicts
  Publish
  if($request.Once){break}
  Start-Sleep -Milliseconds 1000
 }
 $status.Running=$false;Event 'Collecteur arrete (commande, application fermee ou duree de test atteinte).';Publish
}catch{
 $fatal=$true;$status.Error=$_.Exception.Message;$status.State='Erreur';$status.Running=$false
 try{Event 'Erreur du collecteur.' $_.Exception.Message;Write-AcrCollectorJson $status $statusPath}catch{}
 exit 1
}finally{if($null -ne $db){$db.Dispose()};if($null -ne $lock){$lock.Dispose()}}
