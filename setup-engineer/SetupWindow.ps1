[CmdletBinding()]
param([string]$SavePath=(Join-Path $env:LOCALAPPDATA 'acr\Saved\SaveGames\CarSetupsDataSaveSlot.sav'),[string]$SnapshotRoot=(Join-Path $env:LOCALAPPDATA 'ACR-Optimal\SetupEngineer\Snapshots'))
$ErrorActionPreference='Stop'
if($env:OS -ne 'Windows_NT' -or -not [Environment]::Is64BitProcess){throw 'Windows 10/11 x64 requis.'}
Import-Module (Join-Path $PSScriptRoot 'SetupEngine.psm1') -Force
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
[xml]$xaml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="ACR Setup Engineer - prototype" Width="1100" Height="760" MinWidth="850" MinHeight="550" Background="#101827" Foreground="#E2E8F0" FontFamily="Segoe UI">
 <Window.Resources><Style TargetType="Button"><Setter Property="Padding" Value="10,7"/><Setter Property="Margin" Value="5"/></Style><Style TargetType="DataGrid"><Setter Property="IsReadOnly" Value="True"/><Setter Property="CanUserAddRows" Value="False"/><Setter Property="AutoGenerateColumns" Value="True"/><Setter Property="Foreground" Value="#101827"/></Style></Window.Resources>
 <Grid Margin="20"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
 <StackPanel><TextBlock Text="ACR Setup Engineer" FontSize="28" FontWeight="Bold"/><TextBlock Text="Lecture seule | Format observe | Unites et plages non confirmees" Margin="0,8" Foreground="#93C5FD"/></StackPanel>
 <DockPanel Grid.Row="1"><Button x:Name="Browse" Content="Choisir SAV" DockPanel.Dock="Right"/><Button x:Name="Read" Content="Lire et conserver" DockPanel.Dock="Right"/><TextBox x:Name="Source" Margin="5" VerticalContentAlignment="Center"/></DockPanel>
 <DockPanel Grid.Row="2"><Button x:Name="History" Content="Ouvrir une version JSON" DockPanel.Dock="Right"/><ComboBox x:Name="Setup" Margin="5" MinWidth="500" Foreground="#101827"/></DockPanel>
 <TabControl Grid.Row="3" Foreground="#101827">
  <TabItem Header="Reglages"><DataGrid x:Name="Parameters"/></TabItem>
  <TabItem Header="Comparer versions"><Grid><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions><StackPanel Orientation="Horizontal"><ComboBox x:Name="A" Width="370" Margin="5"/><ComboBox x:Name="B" Width="370" Margin="5"/><Button x:Name="Compare" Content="Comparer"/></StackPanel><TextBlock x:Name="CompareNote" Grid.Row="1" TextWrapping="Wrap" Margin="5"/><DataGrid x:Name="Differences" Grid.Row="2"/></Grid></TabItem>
  <TabItem Header="Comportement et hypotheses"><Grid><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions><StackPanel Orientation="Horizontal"><ComboBox x:Name="Surface" Width="140" Margin="5"/><ComboBox x:Name="Behaviour" Width="190" Margin="5"/><ComboBox x:Name="Phase" Width="150" Margin="5"/><Button x:Name="Advice" Content="Analyser le ressenti"/></StackPanel><TextBox x:Name="AdviceText" Grid.Row="1" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Margin="5"/></Grid></TabItem>
 </TabControl><TextBlock x:Name="Status" Grid.Row="4" Margin="5,12" TextWrapping="Wrap" Foreground="#94A3B8"/>
 </Grid>
</Window>
'@
$window=[Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $xaml))
$ui=@{};foreach($n in @('Browse','Read','Source','History','Setup','Parameters','A','B','Compare','CompareNote','Differences','Surface','Behaviour','Phase','Advice','AdviceText','Status')){$ui[$n]=$window.FindName($n)}
# Keep state in a closure local to this window to avoid overwriting dashboard state.
$state=@{Versions=(New-Object 'System.Collections.Generic.List[object]');Loading=$false}
$ui.Source.Text=$SavePath
foreach($v in @('tarmac','gravel','snow','unknown')){$ui.Surface.Items.Add($v)|Out-Null};$ui.Surface.SelectedIndex=3
foreach($v in @('understeer','oversteer','braking','traction','stability','bumps')){$ui.Behaviour.Items.Add($v)|Out-Null};$ui.Behaviour.SelectedIndex=0
foreach($v in @('entry','mid-corner','exit','straight','unknown')){$ui.Phase.Items.Add($v)|Out-Null};$ui.Phase.SelectedIndex=4
function AddVersions($snapshot,$path){
 $state.Loading=$true
 try{
  foreach($s in $snapshot.Setups){
   $entry=[pscustomobject]@{Setup=$s;SnapshotPath=$path;SourceHash=$snapshot.SourceSHA256;CapturedUtc=$snapshot.CapturedUtc}
   $state.Versions.Add($entry)
   $label="$($s.CarId) / $($s.Name) / $($s.VersionId.Substring(0,8)) / $($snapshot.CapturedUtc)"
   foreach($combo in @($ui.Setup,$ui.A,$ui.B)){$combo.Items.Add($label)|Out-Null}
  }
  if($state.Versions.Count){$ui.Setup.SelectedIndex=$state.Versions.Count-1;$ui.A.SelectedIndex=0;$ui.B.SelectedIndex=$state.Versions.Count-1}
 }finally{$state.Loading=$false};ShowParameters
}
function ShowParameters {
 if($state.Loading -or $ui.Setup.SelectedIndex -lt 0){return}
 $s=$state.Versions[$ui.Setup.SelectedIndex].Setup
 $ui.Parameters.ItemsSource=@($s.Parameters|ForEach-Object {[pscustomobject]@{Reglage=$_.Key;ValeurBrute=$_.RawValue;ValeurNumerique=$_.Value;Unite='Inconnue';HypotheseUnite=$_.UnitCandidate;PlageAutorisee='Inconnue';Validation=$_.Validation}})
 $ui.Status.Text="$($s.CarId) | $($s.Name) | version jeu $($s.GameVersion) | indication speciale $($s.StageHint) (pas un identifiant de speciale prouve). Setup actif inconnu."
}
function ErrorDialog($e){[Windows.MessageBox]::Show($e.Exception.Message,'Setup Engineer - erreur')|Out-Null}
$ui.Browse.Add_Click({$d=New-Object Microsoft.Win32.OpenFileDialog;$d.Filter='Sauvegardes ACR (*.sav)|*.sav';if($d.ShowDialog()){$ui.Source.Text=$d.FileName}})
$ui.Read.Add_Click({try{$snapshot=Read-AcrSetups $ui.Source.Text;$path=Save-AcrSetupSnapshot $snapshot $SnapshotRoot;AddVersions $snapshot $path;$ui.Status.Text="Version conservee : $path. Parametres extraits a verifier dans le jeu."}catch{ErrorDialog $_}})
$ui.History.Add_Click({try{$d=New-Object Microsoft.Win32.OpenFileDialog;$d.Filter='Versions setup (*.json)|*.json';if(Test-Path $SnapshotRoot){$d.InitialDirectory=$SnapshotRoot};if($d.ShowDialog()){$snapshot=Read-AcrSetupSnapshot $d.FileName;AddVersions $snapshot $d.FileName}}catch{ErrorDialog $_}})
$ui.Setup.Add_SelectionChanged({try{ShowParameters}catch{ErrorDialog $_}})
$ui.Compare.Add_Click({try{
 if($ui.A.SelectedIndex -lt 0 -or $ui.B.SelectedIndex -lt 0){throw 'Charger deux versions puis choisir A et B.'}
 $a=$state.Versions[$ui.A.SelectedIndex].Setup;$b=$state.Versions[$ui.B.SelectedIndex].Setup
 $ui.Differences.ItemsSource=@(Compare-AcrSetups $a $b)
 $ui.CompareNote.Text='Delta = B moins A, en valeur brute. Unite et plage inconnues. Une difference ne prouve aucun gain de performance.'
 if($a.GameVersion -ne $b.GameVersion){$ui.CompareNote.Text+=' ATTENTION : versions du jeu differentes ; equivalence physique non prouvee.'}
}catch{ErrorDialog $_}})
$ui.Advice.Add_Click({try{
 if($ui.Setup.SelectedIndex -lt 0){throw 'Lire ou ouvrir un setup.'}
 $a=Get-AcrSetupAdvice $state.Versions[$ui.Setup.SelectedIndex].Setup ([string]$ui.Surface.SelectedItem) ([string]$ui.Behaviour.SelectedItem) ([string]$ui.Phase.SelectedItem)
 $ui.AdviceText.Text="Ressenti declare : $($a.ReportedBehaviour), phase $($a.Phase). Pas de diagnostic par telemetrie.`n`nHypothese : $($a.Hypothesis)`n`nSurface : $($a.SurfaceNotes)`n`nCompromis : $($a.Tradeoff)`n`nReglages presents : $($a.Parameters -join ', ')`n`n$($a.TestProtocol)`n`nAucune cible numerique : unites et limites non confirmees. Aucun appel a un service IA. Aucun lien historique automatique avec les chronos."
}catch{ErrorDialog $_}})
$ui.Status.Text="Snapshots : $SnapshotRoot. Aucun fichier du jeu ni aucune base de chronos ne sera modifie."
$window.ShowDialog()|Out-Null
