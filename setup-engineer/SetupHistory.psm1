Import-Module (Join-Path $PSScriptRoot 'SetupEngine.psm1')
function Get-AcrSetupHistory {
 param([string]$Root)
 if(-not (Test-Path -LiteralPath $Root -PathType Container)){return @()}
 return @(foreach($file in Get-ChildItem -LiteralPath $Root -Filter 'setup-*.json' -File|Sort-Object LastWriteTimeUtc,Name){
  try {
   $snapshot=Read-AcrSetupSnapshot $file.FullName
   foreach($s in $snapshot.Setups){[pscustomobject]@{Voiture=$s.CarId;Nom=$s.Name;Version=$s.VersionId;CaptureUTC=$snapshot.CapturedUtc;VersionJeu=$s.GameVersion;Etat='Conservee';Fichier=$file.FullName}}
  }catch{[pscustomobject]@{Voiture='';Nom='';Version='';CaptureUTC='';VersionJeu='';Etat=('Illisible : '+$_.Exception.Message);Fichier=$file.FullName}}
 })
}
Export-ModuleMember -Function Get-AcrSetupHistory
