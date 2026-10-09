Set-StrictMode -Version 2
function Get-AcrCollectorState([bool]$Running,[bool]$Connected,[bool]$Ready,[bool]$Starting,[string]$ErrorMessage) {
 if(-not $Running){return 'Arrete'}
 if($ErrorMessage){return 'Erreur'}
 if($Starting){return 'Demarrage'}
 if(-not $Connected){return 'EnAttenteDuJeu'}
 if(-not $Ready){return 'ConnecteAuJeu'}
 return 'CollecteActive'
}
function Test-AcrCollectorDeadline([DateTime]$StartedUtc,[int]$Minutes,[DateTime]$NowUtc) {
 return ($Minutes -gt 0 -and $NowUtc -ge $StartedUtc.AddMinutes($Minutes))
}
function Get-AcrGameSignature([string[]]$Names) {
 $ids=@(foreach($name in $Names){
  foreach($p in Get-Process -Name ($name -replace '\.exe$','') -ErrorAction SilentlyContinue){
   try {'{0}:{1}' -f $p.Id,$p.StartTime.ToUniversalTime().Ticks}catch {'{0}:unknown' -f $p.Id}
  }
 })
 return (@($ids|Sort-Object -Unique) -join ',')
}
function Write-AcrCollectorJson($Value,[string]$Path) {
 $temp=$Path+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
 try {
  [IO.File]::WriteAllText($temp,(ConvertTo-Json -InputObject $Value -Depth 8),[Text.Encoding]::UTF8)
  if([IO.File]::Exists($Path)){[IO.File]::Replace($temp,$Path,[System.Management.Automation.Language.NullString]::Value)}else{[IO.File]::Move($temp,$Path)}
 }finally{if([IO.File]::Exists($temp)){[IO.File]::Delete($temp)}}
}
function Read-AcrCollectorBytes([string]$Path) {
 $info=Get-Item -LiteralPath $Path
 if($info.PSIsContainer -or $info.Length -gt 8MB -or $info.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Source trop grande, dossier ou lien refuse.'}
 $stream=[IO.File]::Open($info.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
 $memory=New-Object IO.MemoryStream
 try {
  $buffer=New-Object byte[] 65536
  while(($n=$stream.Read($buffer,0,$buffer.Length)) -gt 0){
   if($memory.Length+$n -gt 8MB){throw 'Source trop grande.'};$memory.Write($buffer,0,$n)
  }
  return ,$memory.ToArray()
 }finally{$memory.Dispose();$stream.Dispose()}
}
function Get-AcrCollectorHash([byte[]]$Bytes) {
 $sha=[Security.Cryptography.SHA256]::Create()
 try{return [BitConverter]::ToString($sha.ComputeHash($Bytes)).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
}
Export-ModuleMember -Function Get-AcrCollectorState,Test-AcrCollectorDeadline,Get-AcrGameSignature,Write-AcrCollectorJson,Read-AcrCollectorBytes,Get-AcrCollectorHash
