Set-StrictMode -Version 2
$ErrorActionPreference='Stop'
function Get-SetupHash([byte[]]$Bytes) {
 $sha=[Security.Cryptography.SHA256]::Create()
 try{return [BitConverter]::ToString($sha.ComputeHash($Bytes)).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
}
function Read-SetupString([byte[]]$Bytes,[int]$Offset) {
 if($Offset -lt 0 -or $Offset+4 -gt $Bytes.Length){throw 'Chaine tronquee.'}
 $n=[BitConverter]::ToInt32($Bytes,$Offset)
 if($n -eq 0){return [pscustomobject]@{Text='';Next=($Offset+4)}}
 if($n -gt 0){$size=$n;$terminator=1;$encoding=New-Object Text.UTF8Encoding($false,$true)}else{$size=-2*[long]$n;$terminator=2;$encoding=New-Object Text.UnicodeEncoding($false,$false,$true)}
 if($size -lt $terminator -or $size -gt 4096 -or $Offset+4+$size -gt $Bytes.Length){throw 'Longueur de chaine non prise en charge.'}
 for($i=0;$i -lt $terminator;$i++){if($Bytes[$Offset+4+$size-1-$i] -ne 0){throw 'Terminaison absente.'}}
 $text=$encoding.GetString($Bytes,$Offset+4,[int]$size-$terminator)
 if($text -match '[\x00-\x08\x0B\x0C\x0E-\x1F]'){throw 'Caracteres de controle refuses.'}
 return [pscustomobject]@{Text=$text;Next=($Offset+4+[int]$size)}
}
function Get-SetupParameter([string]$Key,[string]$Raw,[int]$Offset) {
 $value=$null;$kind='enum'
 if($Raw -match '^[+-]?\d+(\.\d+)?$'){
  $value=[double]::Parse($Raw,[Globalization.CultureInfo]::InvariantCulture)
  if([double]::IsNaN($value) -or [double]::IsInfinity($value)){throw 'Valeur numerique non finie.'}
  $kind='number'
 }
 $suggested=$null
 switch -Regex ($Key) {
  'TyrePressure$' {$suggested='psi (a verifier dans le jeu)'}
  '\.Camber$' {$suggested='degres (a verifier dans le jeu)'}
  '\.SpringStiffness$|\.ARBStiffness$' {$suggested='N/m (hypothese, conversion interdite sans validation)'}
  '\.FrontBias$' {$suggested='fraction avant (hypothese)'}
 }
 return [pscustomobject]@{Key=$Key;RawValue=$Raw;Value=$value;Kind=$kind;Unit=$null;UnitStatus='unknown';UnitCandidate=$suggested;
  AllowedRange=[pscustomobject]@{Minimum=$null;Maximum=$null;Step=$null;Choices=@();Status='unknown'};
  ByteOffset=$Offset;Validation='extracted-unconfirmed'}
}
function Read-AcrSetups([string]$Path) {
 $info=Get-Item -LiteralPath $Path
 if($info.PSIsContainer -or $info.Length -gt 8MB -or $info.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Fichier reel attendu, limite 8 MiB.'}
 $stream=[IO.File]::Open($info.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
 try{$memory=New-Object IO.MemoryStream;try{$stream.CopyTo($memory);$bytes=$memory.ToArray()}finally{$memory.Dispose()}}finally{$stream.Dispose()}
 $after=Get-Item -LiteralPath $info.FullName
 if($after.Length -ne $info.Length -or $after.LastWriteTimeUtc -ne $info.LastWriteTimeUtc){throw 'Sauvegarde modifiee pendant la lecture : recommencer apres stabilisation.'}
 if($bytes.Length -gt 8MB -or $bytes.Length -lt 4 -or [Text.Encoding]::ASCII.GetString($bytes,0,4) -ne 'GVAS'){throw 'Signature GVAS attendue.'}
 $hash=Get-SetupHash $bytes;$setups=New-Object 'System.Collections.Generic.List[object]';$rejected=New-Object 'System.Collections.Generic.List[object]'
 # Locate length-prefixed version strings, then validate the full observed record.
 for($p=4;$p -lt $bytes.Length-20;$p++){
  if($bytes[$p+4] -lt 48 -or $bytes[$p+4] -gt 57){continue}
  try{$ver=Read-SetupString $bytes $p}catch{continue}
  if($ver.Text -notmatch '^\d+\.\d+\.\d+\.\d+$'){continue}
  try{
   $car=Read-SetupString $bytes $ver.Next;$track=Read-SetupString $bytes $car.Next
   if($car.Text -notmatch '^[A-Za-z0-9_]{3,80}$' -or [string]::IsNullOrWhiteSpace($track.Text)){throw 'Contexte non reconnu.'}
   $driver=$null;$name=$null;$tokenStart=$p-8
   # Walk backwards by checking actual FString boundaries, never guess by line order.
   for($q=[Math]::Max(4,$tokenStart-1028);$q -lt $tokenStart;$q++){
    try{$candidate=Read-SetupString $bytes $q;if($candidate.Next -eq $tokenStart -and $candidate.Text.Length -gt 0){$driver=$candidate.Text;$driverStart=$q;break}}catch{}
   }
   if($null -eq $driver){throw 'Auteur/nom non delimite.'}
   for($q=[Math]::Max(4,$driverStart-1028);$q -lt $driverStart;$q++){
    try{$candidate=Read-SetupString $bytes $q;if($candidate.Next -eq $driverStart -and $candidate.Text.Length -gt 0){$name=$candidate.Text;break}}catch{}
   }
   if($null -eq $name){throw 'Nom du setup non delimite.'}
   $cursor=$track.Next
   if($cursor+16 -gt $bytes.Length){throw 'Bloc tronque.'}
   for($i=0;$i -lt 12;$i++){if($bytes[$cursor+$i] -ne 0){throw 'Entete non prise en charge.'}}
   $cursor+=12;$count=[BitConverter]::ToUInt32($bytes,$cursor);$cursor+=4
   if($count -lt 1 -or $count -gt 256){throw 'Nombre de reglages non reconnu.'}
   $parameters=New-Object 'System.Collections.Generic.List[object]';$keys=@{}
   for($i=0;$i -lt $count;$i++){
    $offset=$cursor;$key=Read-SetupString $bytes $cursor;$raw=Read-SetupString $bytes $key.Next;$cursor=$raw.Next
    if($key.Text -notmatch '^(Gearbox|Brakes|Differentials|Suspensions|Axles|Wheels|Other|Dampers)\.[A-Za-z0-9_.]+$' -or $keys.ContainsKey($key.Text)){throw 'Reglage inconnu ou duplique.'}
    $keys[$key.Text]=$true;$parameters.Add((Get-SetupParameter $key.Text $raw.Text $offset))
   }
   $token=[BitConverter]::ToString($bytes,$tokenStart,8).Replace('-','').ToLowerInvariant()
   $identity=@($car.Text,$name,$driver,$ver.Text,$track.Text,@($parameters|ForEach-Object {@($_.Key,$_.RawValue)}))|ConvertTo-Json -Depth 6 -Compress
   $setups.Add([pscustomobject]@{VersionId=(Get-SetupHash ([Text.Encoding]::UTF8.GetBytes($identity)));CarId=$car.Text;Name=$name;Driver=$driver;
    GameVersion=$ver.Text;StageHint=$track.Text;StageId=$null;Surface='unknown';SourceToken=$token;ByteOffset=$p;ParameterCount=$count;
    Validation='extracted-unconfirmed';Parameters=@($parameters.ToArray());PerformanceLinks=@()})
  }catch{$rejected.Add([pscustomobject]@{Offset=$p;Version=$ver.Text;Reason=$_.Exception.Message})}
 }
 if($setups.Count -eq 0){throw 'Aucun setup compatible. Aucun reglage invente.'}
 return [pscustomobject]@{Schema='acr-setup-snapshot-v1';SourcePath=$info.FullName;SourceSHA256=$hash;CapturedUtc=[DateTime]::UtcNow.ToString('o');
  Acquisition='read-only-experimental';Setups=@($setups.ToArray());RejectedCandidates=@($rejected.ToArray());ActiveSetupKnown=$false}
}
function Save-AcrSetupSnapshot($Snapshot,[string]$Root) {
 New-Item -ItemType Directory -Path $Root -Force|Out-Null
 $path=Join-Path $Root ('setup-'+[guid]::NewGuid().ToString('N')+'.json')
 $text=ConvertTo-Json -InputObject $Snapshot -Depth 12
 # CreateNew ensures versioned evidence cannot overwrite an earlier snapshot.
 $stream=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write)
 try{$bytes=[Text.Encoding]::UTF8.GetBytes($text);$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
 return $path
}
function Read-AcrSetupSnapshot([string]$Path) {
 $info=Get-Item -LiteralPath $Path
 if($info.PSIsContainer -or $info.Length -gt 16MB){throw 'Snapshot JSON attendu, limite 16 MiB.'}
 $s=Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json
 if($s.Schema -ne 'acr-setup-snapshot-v1' -or @($s.Setups).Count -eq 0){throw 'Format snapshot invalide.'}
 return $s
}
function Compare-AcrSetups($SetupA,$SetupB) {
 if($SetupA.CarId -ne $SetupB.CarId){throw 'Comparer deux setups de la meme voiture.'}
 $left=@{};$right=@{};foreach($p in $SetupA.Parameters){$left[$p.Key]=$p};foreach($p in $SetupB.Parameters){$right[$p.Key]=$p}
 return @(foreach($key in @(@($left.Keys)+@($right.Keys)|Sort-Object -Unique)){
  $a=$left[$key];$b=$right[$key];$av=$null;$bv=$null;$delta=$null;$status='unchanged'
  if($null -ne $a){$av=$a.RawValue};if($null -ne $b){$bv=$b.RawValue}
  if($null -eq $a){$status='added'}elseif($null -eq $b){$status='removed'}elseif($av -cne $bv){$status='changed'}
  if($null -ne $a -and $null -ne $b -and $a.Kind -eq 'number' -and $b.Kind -eq 'number'){$delta=$b.Value-$a.Value}
  [pscustomobject]@{Key=$key;A=$av;B=$bv;DeltaRaw=$delta;Status=$status;Unit='unknown';Range='unknown';ComparableGameVersion=($SetupA.GameVersion -eq $SetupB.GameVersion)}
 })
}
function Get-AcrSetupAdvice($Setup,[string]$Surface,[string]$Behaviour,[string]$Phase) {
 $supported=@('understeer','oversteer','braking','traction','stability','bumps')
 if($Behaviour -notin $supported -or $Surface -notin @('tarmac','gravel','snow','unknown') -or $Phase -notin @('entry','mid-corner','exit','straight','unknown')){throw 'Comportement/surface/phase invalide.'}
 $pattern='';$test='';$risk=''
 switch($Behaviour){
  'understeer' {$pattern='Axles.Front.ARBStiffness';$test='Tester une barre avant moins raide si le sous-virage apparait en appui etabli.';$risk='Peut augmenter le roulis et ralentir la reponse.'}
  'oversteer' {$pattern='Axles.Rear.ARBStiffness';$test='Tester une barre arriere moins raide en appui etabli.';$risk='Peut reduire la rotation et provoquer du sous-virage.'}
  'braking' {$pattern='Brakes.BrakesMain.FrontBias';$test='Verifier quelle roue bloque. Si blocage arriere confirme, tester davantage de repartition avant.';$risk='Davantage de repartition avant peut bloquer les roues avant.'}
  'traction' {$pattern='Differentials.';$test='Distinguer patinage d une roue, des deux roues et perte de contact avant de modifier le differentiel.';$risk='Davantage de verrouillage peut accentuer le sous-virage et reduire la rotation.'}
  'stability' {$pattern='Wheels.Rear';$test='Verifier le sens du pincement affiche dans le jeu avant tout essai de stabilite arriere.';$risk='Sens et unite du toe non verifies : aucune direction numerique proposee.'}
  'bumps' {$pattern='Dampers.';$test='Si les chocs rapides sont transmis au chassis sans talonnage, tester moins de compression rapide.';$risk='Si la voiture talonne, reduire l amortissement peut aggraver le probleme.'}
 }
 $applicable=@($Setup.Parameters|Where-Object {$_.Key.StartsWith($pattern)})
 $conditional=$true
 if($Behaviour -in @('understeer','oversteer') -and $Phase -ne 'mid-corner'){$test='Analyser d abord la phase : la regle de barre antiroulis ci-dessus ne suffit pas en entree ou en sortie.'}
 if($Surface -eq 'unknown'){$surfaceNote='Surface inconnue : confirmer avant essai.'}elseif($Surface -eq 'tarmac'){$surfaceNote='Asphalte : surveiller appui etabli, blocages et temperatures pneus.'}else{$surfaceNote='Surface meuble : prioriser contact au sol et compliance ; verifier avant/apres sur le meme troncon.'}
 return [pscustomobject]@{CarId=$Setup.CarId;SetupVersionId=$Setup.VersionId;Surface=$Surface;ReportedBehaviour=$Behaviour;Phase=$Phase;
  Evidence='driver-report-not-telemetry';Applicable=($applicable.Count -gt 0);Parameters=@($applicable|Select-Object -ExpandProperty Key);
  Hypothesis=$test;SurfaceNotes=$surfaceNote;Tradeoff=$risk;NumericTarget=$null;UnitAndRangeVerified=$false;Conditional=$conditional;
  TestProtocol='Une modification a la fois, uniquement dans les limites du menu du jeu ; meme voiture/surface, plusieurs tentatives confirmees.'}
}
function New-AcrSetupLinkTemplate($Setup) {
 return [pscustomobject]@{Schema='acr-setup-performance-link-v1';SetupVersionId=$Setup.VersionId;CarId=$Setup.CarId;
  Profile=$null;AttemptKey=$null;StageId=$null;ConfirmedUsed=$false;Evidence=$null;
  Note='Ne renseigner que si le setup effectivement utilise pour cette tentative a ete observe. Aucune association historique par date ou nom.'}
}
Export-ModuleMember -Function Read-AcrSetups,Save-AcrSetupSnapshot,Read-AcrSetupSnapshot,Compare-AcrSetups,Get-AcrSetupAdvice,New-AcrSetupLinkTemplate
