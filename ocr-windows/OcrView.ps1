param([string]$SavePath,[string]$SnapshotRoot,[string]$ModuleRoot)
Import-Module (Join-Path $ModuleRoot 'SetupDetection.psm1') -DisableNameChecking
Import-Module (Join-Path $ModuleRoot 'WindowsTitleOcr.psm1')
Import-Module (Join-Path $ModuleRoot '..\setup-engineer\SetupEngine.psm1')
[xml]$xaml=@'
<UserControl xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
 <ScrollViewer VerticalScrollBarVisibility="Auto"><StackPanel Margin="12">
  <TextBlock FontSize="20" Text="Détection du setup — prototype local"/>
  <TextBlock TextWrapping="Wrap" Margin="0,8" Text="Le titre indique un nom chargé, sans prouver son application. Aucun lien automatique avec les chronos. La voiture reste confirmée manuellement. Une sélection rouge n'est jamais une preuve."/>
  <CheckBox x:Name="Enabled" Content="Activer les captures et l'OCR local Windows (facultatif)"/>
  <WrapPanel Margin="0,10"><TextBlock Text="Voiture : " VerticalAlignment="Center"/><ComboBox x:Name="Car" Width="240"/><Button x:Name="Reload" Content="Relire les snapshots" Margin="8,0"/></WrapPanel>
  <CheckBox x:Name="CarConfirmed" Content="Je confirme que cette voiture est utilisée dans le jeu"/>
  <CheckBox x:Name="LoadConfirmed" Margin="0,8" Content="Je viens de confirmer « Charger le préréglage » (valable pour la prochaine capture)"/>
  <TextBlock TextWrapping="Wrap" Text="Zone du titre uniquement, en % de la fenêtre du jeu. Ajuster l'aperçu pour exclure les listes et boutons. Les captures se font sur demande, sans surveillance permanente."/>
  <WrapPanel Margin="0,8">
   <TextBlock Text="X % "/><TextBox x:Name="X" Text="2" Width="45"/>
   <TextBlock Text=" Y % "/><TextBox x:Name="Y" Text="5" Width="45"/>
   <TextBlock Text=" Largeur % "/><TextBox x:Name="W" Text="75" Width="45"/>
   <TextBlock Text=" Hauteur % "/><TextBox x:Name="H" Text="7" Width="45"/>
  </WrapPanel>
  <WrapPanel><TextBlock Text="Processus autorisés : "/><TextBox x:Name="Processes" Text="acr,acr-Win64-Shipping" Width="280"/></WrapPanel>
  <WrapPanel Margin="0,8"><Button x:Name="Capture" Content="Capturer dans 3 secondes" Padding="8,4"/><Button x:Name="Import" Content="Tester une image du titre déjà recadrée" Padding="8,4" Margin="8,0"/></WrapPanel>
  <TextBlock x:Name="State" FontWeight="Bold" FontSize="16" Text="Arrêté — OCR désactivé"/>
  <Image x:Name="Preview" Height="65" Stretch="Uniform" HorizontalAlignment="Left" Margin="0,8"/>
  <TextBox x:Name="Result" IsReadOnly="True" TextWrapping="Wrap" Height="80" VerticalScrollBarVisibility="Auto"/>
  <TextBlock x:Name="Match" TextWrapping="Wrap" Margin="0,8"/>
  <WrapPanel Margin="0,8"><ComboBox x:Name="ManualSnapshot" Width="470"/><Button x:Name="Manual" Content="Choisir ce snapshot manuellement" Margin="8,0"/></WrapPanel>
  <CheckBox x:Name="Applied" Content="J'ai utilisé « Revenir et appliquer » et quitté le menu de configuration"/>
  <CheckBox x:Name="Unchanged" Margin="0,8" Content="Je confirme que les réglages correspondent au snapshot et n'ont pas été modifiés depuis le chargement"/>
  <WrapPanel><Button x:Name="Confirm" Content="Déclarer pour la prochaine tentative (manuel)" Padding="8,4"/><Button x:Name="Dirty" Content="J'ai modifié un réglage — invalider" Padding="8,4" Margin="8,0"/></WrapPanel>
  <TextBlock Margin="0,10" TextWrapping="Wrap" Text="Une modification non sauvegardée peut laisser le titre inchangé : la signaler ici. La vérification du SAV détecte seulement les divergences enregistrées. La déclaration est une preuve locale, elle ne renseigne aucune tentative SQLite, ancienne ou nouvelle."/>
  <TextBlock x:Name="Log" TextWrapping="Wrap"/>
 </StackPanel></ScrollViewer>
</UserControl>
'@
$reader=New-Object System.Xml.XmlNodeReader $xaml
$view=[Windows.Markup.XamlReader]::Load($reader)
$ui=@{};foreach($n in @('Enabled','Car','Reload','CarConfirmed','LoadConfirmed','X','Y','W','H','Processes','Capture','Import','State','Preview','Result','Match','ManualSnapshot','Manual','Applied','Unchanged','Confirm','Dirty','Log')){$ui[$n]=$view.FindName($n)}
$detection=New-AcrSetupDetectionState
$snapshots=@();$lastPath=$null;$busy=$false
$evidenceRoot=Join-Path $env:LOCALAPPDATA ('ACR-Optimal\SetupOcrEvidence\'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N'))
function SaveProof($Object) {
 [void][IO.Directory]::CreateDirectory($evidenceRoot)
 $path=Join-Path $evidenceRoot ([DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-fff')+'-'+[guid]::NewGuid().ToString('N')+'.json')
 $bytes=[Text.Encoding]::UTF8.GetBytes(($Object|ConvertTo-Json -Depth 15))
 $stream=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
 try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
 $ui.Log.Text='Preuve locale : '+$path
 return $path
}
function ResetChecks {$ui.Applied.IsChecked=$false;$ui.Unchanged.IsChecked=$false}
function ReportError($ErrorRecord) {
 $reason=[string]$ErrorRecord
 $e=Invalidate-AcrSetupDetection $detection ('Erreur : '+$reason)
 try{[void](SaveProof $e)}catch{$ui.Log.Text='Journal indisponible : '+[string]$_}
 $ui.State.Text='Erreur — correspondance invalidée';$ui.Result.Text=$reason;ResetChecks
}
function LoadSnapshots {
 $script:snapshots=@()
 if(Test-Path -LiteralPath $SnapshotRoot -PathType Container){
  foreach($f in Get-ChildItem -LiteralPath $SnapshotRoot -Filter 'setup-*.json'){
   try{$s=Read-AcrSetupSnapshot -Path $f.FullName;$script:snapshots+=@($s.Setups)}catch{$ui.Log.Text='Snapshot ignoré : '+$f.Name+' : '+[string]$_}
  }
 }
 $old=[string]$ui.Car.SelectedItem
 $ui.Car.Items.Clear();$ui.ManualSnapshot.Items.Clear()
 foreach($snapshot in $script:snapshots){[void]$ui.ManualSnapshot.Items.Add(($snapshot.CarId+' / '+$snapshot.Name+' / '+$snapshot.VersionId))}
 foreach($carId in @($script:snapshots|ForEach-Object {$_.CarId}|Sort-Object -Unique)){[void]$ui.Car.Items.Add($carId)}
 if($ui.Car.Items.Contains($old)){$ui.Car.SelectedItem=$old}elseif($ui.Car.Items.Count -gt 0){$ui.Car.SelectedIndex=0}
}
function ProcessTitle([string]$Path,[string]$Origin) {
 if(-not $ui.Enabled.IsChecked){throw 'Activer explicitement le prototype OCR avant une capture.'}
 $image=New-Object Windows.Media.Imaging.BitmapImage
 $image.BeginInit();$image.CacheOption=[Windows.Media.Imaging.BitmapCacheOption]::OnLoad;$image.UriSource=[Uri]$Path;$image.EndInit();$image.Freeze()
 # Reject ordinary full-screen inputs. Calibration still requires checking the preview.
 if($image.PixelHeight -gt 300 -or $image.PixelWidth/[double]$image.PixelHeight -lt 3){throw 'Image refusée : sélectionner uniquement une bande recadrée contenant le titre.'}
 $ui.Preview.Source=$image
 $text=Read-AcrTitleOcr -Path $Path
 $load=[bool]$ui.LoadConfirmed.IsChecked;$ui.LoadConfirmed.IsChecked=$false
 $e=Update-AcrSetupDetection -State $detection -Text $text -CarId ([string]$ui.Car.SelectedItem) -CarConfirmed ([bool]$ui.CarConfirmed.IsChecked) -Snapshots $snapshots -LoadConfirmed $load
 $savedCheck='not-checked';$savedHash=$null
 if($null -ne $detection.Candidate){
  try {
   $fresh=Read-AcrSetups -Path $SavePath;$savedHash=$fresh.SourceSHA256
   if(-not (Test-AcrSavedSetupMatch $detection.Candidate $fresh.Setups)){
    $invalid=Invalidate-AcrSetupDetection $detection 'Le SAV actuel ne contient plus cette version unique de setup.'
    [void](SaveProof $invalid);$savedCheck='divergent';$e.State=$detection.State;$e.ParametersVerified=$false
   }else{$savedCheck='saved-version-matches-active-unknown'}
  }catch{$savedCheck='unavailable: '+[string]$_}
 }
 $e|Add-Member NoteProperty CaptureUtc ((Get-Item -LiteralPath $Path).LastWriteTimeUtc.ToString('o'))
 $e|Add-Member NoteProperty SavedSourceSHA256 $savedHash
 $e|Add-Member NoteProperty ImagePath $Path
 $e|Add-Member NoteProperty ImageSHA256 ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash)
 $e|Add-Member NoteProperty CaptureSource $Origin
 $e|Add-Member NoteProperty SavedVersionCheck $savedCheck
 $script:lastPath=SaveProof $e
 $labels=@{Selectionne='Nom observé — chargement non établi';ChargeDetecte='Chargé détecté — version non confirmée';AppliqueNonConfirme='Chargé détecté — application non confirmée';CorrespondanceInvalidee='Correspondance invalidée'}
 $ui.Result.Text=$text;$ui.State.Text=$labels[$detection.State]
 if($null -ne $detection.Candidate){$ui.Match.Text='Version candidate : '+$detection.Candidate.Name+' / '+$detection.Candidate.CarId+' / '+$detection.Candidate.VersionId}else{$ui.Match.Text='Aucune version unique vérifiée. Nom ambigu, voiture non confirmée, titre absent ou correspondance invalidée.'}
 $ui.Match.Text+=' | Vérification SAV : '+$savedCheck
 ResetChecks
}
$timer=New-Object Windows.Threading.DispatcherTimer
$timer.Interval=[TimeSpan]::FromSeconds(3)
$timer.Add_Tick({
 $timer.Stop()
 try {
  if(-not $ui.Enabled.IsChecked){return}
  if(-not ('ACROptimal.Ocr.TitleCapture' -as [type])){Add-Type -AssemblyName System.Drawing;Add-Type -Path (Join-Path $ModuleRoot 'TitleCapture.cs') -ReferencedAssemblies 'System.dll','System.Core.dll','System.Drawing.dll'}
  [void][IO.Directory]::CreateDirectory($evidenceRoot)
  $path=Join-Path $evidenceRoot ('titre-'+[guid]::NewGuid().ToString('N')+'.png')
  $names=@($ui.Processes.Text -split ','|ForEach-Object {$_.Trim()}|Where-Object {$_})
  $culture=[Globalization.CultureInfo]::InvariantCulture
  $x=[double]::Parse($ui.X.Text.Replace(',','.'),$culture);$y=[double]::Parse($ui.Y.Text.Replace(',','.'),$culture)
  $w=[double]::Parse($ui.W.Text.Replace(',','.'),$culture);$h=[double]::Parse($ui.H.Text.Replace(',','.'),$culture)
  $source=[ACROptimal.Ocr.TitleCapture]::Capture($path,$names,$x,$y,$w,$h)
  ProcessTitle $path ('foreground-game: '+$source)
 }catch{ReportError $_}finally{$script:busy=$false;$ui.Capture.IsEnabled=$true}
})
$ui.Capture.Add_Click({
 if(-not $ui.Enabled.IsChecked){$ui.State.Text='OCR désactivé : cocher son activation pour tester.';return}
 if($busy){return};$script:busy=$true;$ui.Capture.IsEnabled=$false;$ui.State.Text='Capture dans 3 secondes : mettre le jeu au premier plan.';$timer.Start()
})
$ui.Import.Add_Click({
 if(-not $ui.Enabled.IsChecked){$ui.State.Text='OCR désactivé.';return}
 try {
  $d=New-Object Microsoft.Win32.OpenFileDialog;$d.Filter='Titre recadré PNG|*.png'
  if($d.ShowDialog()){
   [void][IO.Directory]::CreateDirectory($evidenceRoot)
   $path=Join-Path $evidenceRoot ('titre-import-'+[guid]::NewGuid().ToString('N')+'.png')
   [IO.File]::Copy($d.FileName,$path,$false);ProcessTitle $path 'manual-cropped-image'
  }
 }catch{ReportError $_}
})
$ui.Manual.Add_Click({
 try {
  $index=$ui.ManualSnapshot.SelectedIndex
  if($index -lt 0){throw 'Choisir explicitement une version de snapshot.'}
  $e=Select-AcrManualSetupCandidate $detection $snapshots[$index] ([string]$ui.Car.SelectedItem) ([bool]$ui.CarConfirmed.IsChecked)
  $script:lastPath=SaveProof $e;ResetChecks
  $ui.State.Text='Appliqué non confirmé — choix manuel, sans preuve OCR'
  $ui.Match.Text='Version choisie manuellement : '+$detection.Candidate.Name+' / '+$detection.Candidate.VersionId
 }catch{$ui.Result.Text=[string]$_}
})
$ui.Confirm.Add_Click({
 try {
  if(-not $ui.CarConfirmed.IsChecked){throw 'Voiture confirmée nécessaire.'}
  $d=Confirm-AcrSetupDeclaration $detection ([bool]$ui.Applied.IsChecked) ([bool]$ui.Unchanged.IsChecked)
  $d.EvidencePath=$lastPath;[void](SaveProof $d);$ui.State.Text='Confirmé manuellement pour la prochaine tentative — aucune association aux chronos'
 }catch{$ui.Result.Text=[string]$_}
})
$ui.Dirty.Add_Click({[void](SaveProof (Invalidate-AcrSetupDetection $detection 'Modification déclarée par le joueur'));$ui.State.Text='Correspondance invalidée : recharger le setup et confirmer ce chargement.';ResetChecks})
$ui.Reload.Add_Click({try{LoadSnapshots;[void](SaveProof (Invalidate-AcrSetupDetection $detection 'Snapshots relus : refaire la détection et confirmer le chargement.'));ResetChecks;$ui.State.Text='Snapshots relus — nouvelle détection nécessaire'}catch{ReportError $_}})
$ui.Car.Add_SelectionChanged({$detection.Candidate=$null;$detection.Declaration=$null;$detection.PreviousName=$null;$detection.LoadedObserved=$false;$ui.CarConfirmed.IsChecked=$false;ResetChecks})
$ui.CarConfirmed.Add_Unchecked({$detection.Candidate=$null;$detection.Declaration=$null;ResetChecks;$ui.State.Text='Voiture non confirmée — refaire une capture'})
$ui.Enabled.Add_Unchecked({$timer.Stop();$script:busy=$false;$ui.Capture.IsEnabled=$true;$detection.Candidate=$null;$detection.Declaration=$null;$detection.PreviousName=$null;$detection.LoadedObserved=$false;ResetChecks;$ui.State.Text='Arrêté — OCR désactivé'})
$view.Add_Unloaded({$timer.Stop();$script:busy=$false;$ui.Capture.IsEnabled=$true})
try{LoadSnapshots}catch{ReportError $_}
function Get-AcrSetupOcrRoot {return $view}
Export-ModuleMember -Function Get-AcrSetupOcrRoot
