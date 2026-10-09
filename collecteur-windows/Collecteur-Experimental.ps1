[CmdletBinding()]
param(
 [string]$SavePath=(Join-Path $env:LOCALAPPDATA 'acr\Saved\SaveGames\PlayerDataSaveSlot.sav'),
 [string]$StageId='AlsaceS4SaverneShort1Forward',[string]$CarId='SkodaFabiaRSRally2',
 [string]$Profile='joueur-local',
 [string]$DatabasePath=(Join-Path $env:LOCALAPPDATA 'ACR-Optimal\Experimental\acr-experimental.sqlite3'),
 [ValidateRange(1,120)][int]$Minutes=15,
 [switch]$Once
)
$ErrorActionPreference='Stop'
if ($env:OS -ne 'Windows_NT' -or -not [Environment]::Is64BitProcess) {throw 'Windows 10/11 x64 requis.'}
Write-Host 'COLLECTEUR EXPERIMENTAL : surveillance en lecture seule des sauvegardes, sans acces memoire/reseau.'
Write-Host 'Decodage limite a la speciale/voiture indiquees. Mode, validite et penalites ne sont PAS detectes.'
Write-Host 'Chaque nouvelle tentative restera en quarantaine. Fermer cette fenetre pour arreter.'
if ((Read-Host 'Tapez TT uniquement si votre session est en contre-la-montre') -cne 'TT') {throw 'Mode TT non confirme.'}
if ($Profile -notmatch '^[\p{L}\p{N} _.\-]{1,64}$') {throw 'Profil invalide.'}
Write-Host "Source : $SavePath"
Write-Host "Speciale : $StageId | Voiture : $CarId"
$reader=Join-Path $PSScriptRoot '..\diagnostic-windows\Lire-Sauvegarde-Secteurs.ps1'
if (-not (Test-Path -LiteralPath $reader -PathType Leaf)) {throw 'Lecteur absent. Extraire tout le depot.'}
$item=Get-Item -LiteralPath $SavePath
if ($item.PSIsContainer -or $item.Length -gt 8MB -or $item.Attributes -band [IO.FileAttributes]::ReparsePoint) {throw 'Fichier reel attendu, limite 8 MiB, sans lien.'}
Import-Module (Join-Path $PSScriptRoot '..\stockage-windows\Stockage.psm1') -Force
$root=Join-Path $env:LOCALAPPDATA ('ACR-Optimal\CollectorEvidence\'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $root -Force|Out-Null
@{StartedUtc=[DateTime]::UtcNow.ToString('o');Source=$SavePath;Stage=$StageId;Car=$CarId;Profile=$Profile;Mode='user-declared-TT';AutomaticAcquisitionVerified=$false}|ConvertTo-Json|Set-Content (Join-Path $root 'session.json') -Encoding UTF8
function HashData([byte[]]$Bytes) {$h=[Security.Cryptography.SHA256]::Create();try{return [BitConverter]::ToString($h.ComputeHash($Bytes)).Replace('-','').ToLowerInvariant()}finally{$h.Dispose()}}
function ReadStableSource {
 $info=Get-Item -LiteralPath $SavePath
 if ($info.Length -gt 8MB -or $info.Attributes -band [IO.FileAttributes]::ReparsePoint) {throw 'Source trop grande ou lien refuse.'}
 $stream=[IO.File]::Open($SavePath,[IO.FileMode]::Open,[IO.FileAccess]::Read,([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
 try {
  $memory=New-Object IO.MemoryStream;$stream.CopyTo($memory)
  try {if($memory.Length -gt 8MB){throw 'Source trop grande.'};return ,$memory.ToArray()}finally{$memory.Dispose()}
 }finally{$stream.Dispose()}
}
$last='';$count=0;$total=0;$deadline=[DateTime]::UtcNow.AddMinutes($Minutes)
$db=Open-AcrDatabase $DatabasePath
try {
 while([DateTime]::UtcNow -lt $deadline) {
  try {
   $a=ReadStableSource;$hash=HashData $a
   if($hash -ne $last) {
    Start-Sleep -Milliseconds 600
    $b=ReadStableSource
    if ((HashData $b) -eq $hash) {
     if($count -ge 500 -or $total+$b.Length -gt 100MB){throw 'Limite de capture atteinte.'}
     $count++;$copy=Join-Path $root ('{0:000000}.sav' -f $count);[IO.File]::WriteAllBytes($copy,$b);$total+=$b.Length
     $out=Join-Path $root ('export-{0:000000}' -f $count)
     try {
      & $reader -SavePath $copy -StageId $StageId -CarId $CarId -OutputRoot $out
      $csv=@(Get-ChildItem -LiteralPath $out -Filter secteurs.csv -Recurse -File|Select-Object -ExpandProperty FullName)
      $r=Import-AcrExports $db $csv $Profile
      $message="Import : $($r.Inserted) nouvelles, $($r.Repeated) connues, $($r.Conflicts) conflits. Nouvelles en attente de validation."
      if($r.Conflicts -gt 0){throw 'Conflit sauvegarde : collecteur arrete pour examen.'}
     }catch {
      if($_.Exception.Message -like 'Conflit sauvegarde*'){throw}
      $message="Capture conservee, lecture/import refuse : $($_.Exception.Message)"
     }
     [pscustomobject]@{Utc=[DateTime]::UtcNow.ToString('o');Copy=$copy;SourceSHA256=$hash;Result=$message}|Export-Csv (Join-Path $root 'collecteur.csv') -Append -NoTypeInformation -Encoding UTF8
     Write-Host $message;$last=$hash
    }
   }
  }catch {
   if($_.Exception.Message -like 'Limite de capture*' -or $_.Exception.Message -like 'Conflit sauvegarde*'){throw}
   Write-Warning "Lecture differee : $($_.Exception.Message)"
  }
  if ($Once) { break }
  Start-Sleep -Milliseconds 1000
 }
 Write-Host "Capture terminee : $root"
}finally{$db.Dispose();Write-Host "Preuves conservees : $root"}
