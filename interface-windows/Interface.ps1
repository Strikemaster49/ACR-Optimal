[CmdletBinding()]
param([string]$DatabasePath=(Join-Path $env:LOCALAPPDATA 'ACR-Optimal\Experimental\acr-experimental.sqlite3'),[string]$Profile='joueur-local',
 [ValidateSet('Chronos','Performances','Setup','Historique')][string]$InitialPage='Chronos',
 [string]$SavePath=(Join-Path $env:LOCALAPPDATA 'acr\Saved\SaveGames\CarSetupsDataSaveSlot.sav'),
 [string]$SnapshotRoot=(Join-Path $env:LOCALAPPDATA 'ACR-Optimal\SetupEngineer\Snapshots'))
$ErrorActionPreference='Stop'
if ($env:OS -ne 'Windows_NT' -or -not [Environment]::Is64BitProcess) { throw 'Windows 10/11 x64 requis.' }
Import-Module (Join-Path $PSScriptRoot 'Presentation.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\stockage-windows\Stockage.psm1') -Force
if (-not ('ACROptimal.Experimental.Database' -as [type])) { Add-Type -Path (Join-Path $PSScriptRoot '..\stockage-windows\SqliteNative.cs') }
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
$db=$null
try {
 if (Test-Path -LiteralPath $DatabasePath -PathType Leaf) {
  $db=New-Object ACROptimal.Experimental.Database($DatabasePath,$true)
  if ($db.Query('PRAGMA application_id',@())[0]['application_id'] -ne 1094931032 -or $db.Query('PRAGMA user_version',@())[0]['user_version'] -ne 1) { throw 'Base ACR experimentale version 1 requise.' }
  $db.Exec('PRAGMA busy_timeout=5000',@())
 }
 [xml]$xaml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="ACR-Optimal" Width="1160" Height="800" MinWidth="850" MinHeight="600" Background="#101827" Foreground="#E2E8F0" FontFamily="Segoe UI">
 <Window.Resources>
  <Style TargetType="Button"><Setter Property="Padding" Value="14,8"/><Setter Property="Margin" Value="5"/></Style>
  <Style TargetType="DataGrid"><Setter Property="IsReadOnly" Value="True"/><Setter Property="AutoGenerateColumns" Value="True"/><Setter Property="CanUserAddRows" Value="False"/><Setter Property="Background" Value="#F1F5F9"/><Setter Property="Foreground" Value="#101827"/><Setter Property="RowHeight" Value="30"/></Style>
 </Window.Resources>
 <Grid Margin="22"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
 <StackPanel><TextBlock Text="ACR-Optimal" FontSize="30" FontWeight="Bold"/><TextBlock Text="Donnees experimentales | validation manuelle | lecture seule" Foreground="#94A3B8" Margin="0,4,0,14"/></StackPanel>
 <DockPanel x:Name="ContextBar" Grid.Row="1"><Button x:Name="Refresh" Content="Actualiser" DockPanel.Dock="Right"/><ComboBox x:Name="Context" MinWidth="500" Margin="0,5,10,5" Foreground="#101827"/></DockPanel>
 <Border x:Name="RecordsCard" Grid.Row="2" Background="#1E293B" Padding="18" CornerRadius="10" Margin="0,10"><StackPanel><TextBlock x:Name="Summary" FontSize="23" FontWeight="SemiBold"/><TextBlock x:Name="Counts" Margin="0,10,0,0" Foreground="#93C5FD"/></StackPanel></Border>
 <TabControl x:Name="Navigation" Grid.Row="3" Foreground="#101827">
  <TabItem Header="Chronométrage"><Grid><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="110"/></Grid.RowDefinitions>
 <StackPanel Margin="5"><WrapPanel><CheckBox x:Name="ConfirmTT" Content="Je confirme le contre-la-montre" VerticalAlignment="Center" Margin="5"/><Button x:Name="StartCollector" Content="Démarrer la collecte"/><Button x:Name="StopCollector" Content="Arrêter" IsEnabled="False"/><TextBlock Text="Durée test (min, 0 = illimitée)" VerticalAlignment="Center"/><TextBox x:Name="CollectorMinutes" Text="0" Width="45" Margin="5" VerticalContentAlignment="Center"/></WrapPanel>
 <WrapPanel><TextBlock Text="Processus du jeu :" VerticalAlignment="Center"/><TextBox x:Name="GameNames" Text="acr,acr-Win64-Shipping" Width="250" Margin="5"/><TextBlock Text="Spéciale/voiture : sélection ci-dessus, ou Obersteigen/Fabia si aucune donnée." VerticalAlignment="Center" TextWrapping="Wrap"/></WrapPanel>
 <TextBlock x:Name="CollectorState" Text="Collecteur : arrêté" TextWrapping="Wrap"/><TextBlock x:Name="CollectorLast" Text="Aucun événement reçu." TextWrapping="Wrap"/><TextBlock x:Name="CollectorInfo" TextWrapping="Wrap"/>
 </StackPanel><DataGrid x:Name="Attempts" Grid.Row="1"/><TextBox x:Name="Details" Grid.Row="2" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/></Grid></TabItem>
  <TabItem Header="Performances"><TabControl>
   <TabItem Header="Meilleurs secteurs"><DataGrid x:Name="Sectors"/></TabItem>
   <TabItem Header="Progression"><Grid><Grid.RowDefinitions><RowDefinition Height="230"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions><Canvas x:Name="Chart" Background="#1E293B" ClipToBounds="True"/><TextBlock Grid.Row="1" Text="Bleu : chrono complet | Vert : optimal connu. Ordre d'import, pas date de course." Margin="10"/><DataGrid Grid.Row="2" x:Name="Progress"/></Grid></TabItem>
   <TabItem Header="Comparer les tentatives"><Grid><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions><StackPanel Orientation="Horizontal"><ComboBox x:Name="Left" Width="330" Margin="10"/><ComboBox x:Name="Right" Width="330" Margin="10"/><Button x:Name="Compare" Content="Comparer"/></StackPanel><TextBlock x:Name="CompareNote" Grid.Row="1" Margin="10" TextWrapping="Wrap"/><DataGrid x:Name="Comparison" Grid.Row="2"/></Grid></TabItem>
  </TabControl></TabItem>
  <TabItem Header="Setup Engineer"><TabControl><TabItem Header="Versions et comparaison"><ContentControl x:Name="SetupHost"/></TabItem><TabItem Header="Détection OCR (expérimentale)"><ContentControl x:Name="OcrHost"/></TabItem></TabControl></TabItem>
  <TabItem Header="Historique"><TabControl>
   <TabItem Header="Toutes les tentatives"><DataGrid x:Name="HistoryAttempts"/></TabItem>
   <TabItem Header="Versions de setups"><DockPanel><TextBlock DockPanel.Dock="Top" Margin="10" Text="Versions JSON conservées. Comparaison disponible dans Setup Engineer. Aucun lien historique supposé avec les chronos." TextWrapping="Wrap"/><DataGrid x:Name="HistorySetups"/></DockPanel></TabItem>
  </TabControl></TabItem>
 </TabControl>
 <TextBlock Grid.Row="4" x:Name="Footer" Foreground="#94A3B8" Margin="0,12,0,0" TextWrapping="Wrap"/>
 </Grid>
</Window>
'@
 $window=[Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $xaml))
 $ui=@{};foreach($name in @('ConfirmTT','StartCollector','StopCollector','CollectorMinutes','GameNames','CollectorState','CollectorLast','CollectorInfo','Navigation','ContextBar','RecordsCard','SetupHost','OcrHost','HistoryAttempts','HistorySetups','Refresh','Context','Summary','Counts','Sectors','Attempts','Details','Progress','Chart','Left','Right','Compare','Comparison','CompareNote','Footer')) { $ui[$name]=$window.FindName($name) }
 $script:collector=$null;$script:collectorTimer=$null;$script:collectorLastEvent='';
 $script:contexts=@();$script:rows=@();$script:progress=@();$script:loading=$false
 function GridRows($control,$rows) { $control.ItemsSource=@($rows) }
 function DrawChart {
  $canvas=$ui.Chart;$canvas.Children.Clear();$points=@($script:progress)
  if ($points.Count -eq 0 -or $canvas.ActualWidth -lt 80) { return }
  $values=@($points | ForEach-Object { $_.FullSeconds; $_.OptimalSoFar });$lo=($values|Measure-Object -Minimum).Minimum;$hi=($values|Measure-Object -Maximum).Maximum;$span=[Math]::Max(0.01,$hi-$lo)
  foreach($series in @(@('FullSeconds','#60A5FA'),@('OptimalSoFar','#34D399'))) {
   $line=New-Object Windows.Shapes.Polyline;$line.Stroke=$series[1];$line.StrokeThickness=2
   for($i=0;$i -lt $points.Count;$i++) {
    $x=50+($canvas.ActualWidth-80)*$i/[Math]::Max(1,$points.Count-1);$y=30+($canvas.ActualHeight-60)*(1-($points[$i].($series[0])-$lo)/$span)
    $line.Points.Add((New-Object Windows.Point($x,$y)))
    $dot=New-Object Windows.Shapes.Ellipse;$dot.Width=6;$dot.Height=6;$dot.Fill=$series[1];[Windows.Controls.Canvas]::SetLeft($dot,$x-3);[Windows.Controls.Canvas]::SetTop($dot,$y-3);$canvas.Children.Add($dot)|Out-Null
   };$canvas.Children.Add($line)|Out-Null
  }
  foreach($label in @(@(5,(Format-AcrTime $hi)),@(190,(Format-AcrTime $lo)))) {
   $text=New-Object Windows.Controls.TextBlock;$text.Text=$label[1];$text.Foreground='White';[Windows.Controls.Canvas]::SetTop($text,$label[0]);$canvas.Children.Add($text)|Out-Null
  }
 }
 function ShowContext {
  if ($script:loading -or $ui.Context.SelectedIndex -lt 0) {return}
  $c=$script:contexts[$ui.Context.SelectedIndex]
  $script:rows=@($script:allRows | Where-Object {$_['stage'] -eq $c.stage -and $_['car'] -eq $c.car -and $_['layout'] -eq $c.layout})
  $s=@($script:summaries|Where-Object {$_.Stage -eq $c.stage -and $_.Car -eq $c.car -and $_.Layout -eq $c.layout})
  $eligible=@($script:rows|Where-Object {$_['eligible'] -eq 1}).Count
  $ui.Counts.Text="$($script:rows.Count) conservees | $eligible admissibles | profil $Profile"
  $ui.Summary.Text='Aucun chrono admissible : validation requise'
  if ($s.Count) {$ui.Summary.Text="Meilleur : $(Format-AcrTime $s[0].BestCompleteSeconds)    Optimal : $(Format-AcrTime $s[0].OptimalSeconds)    Gain : $(Format-AcrGain $s[0].GainSeconds)"}
  GridRows $ui.Sectors @(foreach($g in $script:gains|Where-Object {$_.Stage -eq $c.stage -and $_.Car -eq $c.car -and $_.Layout -eq $c.layout}|Sort-Object GainSeconds -Descending){[pscustomobject]@{Secteur=$g.SectorIndex;Meilleur=(Format-AcrTime $g.HistoricalBestSeconds);Reference=(Format-AcrTime $g.BestCompleteSectorSeconds);Gain=(Format-AcrGain $g.GainSeconds)}})
  GridRows $ui.Attempts @(foreach($a in $script:rows){[pscustomobject]@{ID=$a['id'];Bloc=$a['block_token'];Tentative=([int]$a['run_index']+1);DernierCumul=(Format-AcrTime $a['raw_final']);ChronoOfficiel=(Format-AcrTime $a['official_final']);Statut=(Get-AcrDisplayStatus $a)}})
  $script:progress=@($script:progressAll|Where-Object {$_.Stage -eq $c.stage -and $_.Car -eq $c.car -and $_.Layout -eq $c.layout})
  GridRows $ui.Progress @(foreach($p in $script:progress){[pscustomobject]@{OrdreImport=$p.ImportOrder;Chrono=(Format-AcrTime $p.FullSeconds);Record=(Format-AcrTime $p.BestSoFar);Optimal=(Format-AcrTime $p.OptimalSoFar)}})
  foreach($combo in @($ui.Left,$ui.Right)) {$combo.Items.Clear();foreach($a in $script:rows){$combo.Items.Add("ID $($a['id']) | $(Get-AcrDisplayStatus $a)")|Out-Null};if($script:rows.Count){$combo.SelectedIndex=0}}
  $ui.Comparison.ItemsSource=@();$ui.CompareNote.Text='Selectionner deux tentatives du meme contexte. Les non admissibles restent explicitement experimentales.';DrawChart
 }
 function RefreshData {
  $script:loading=$true
  try {
   if ($null -eq $db -and (Test-Path -LiteralPath $DatabasePath -PathType Leaf)) {
    $db=New-Object ACROptimal.Experimental.Database($DatabasePath,$true)
    if($db.Query('PRAGMA application_id',@())[0]['application_id'] -ne 1094931032 -or $db.Query('PRAGMA user_version',@())[0]['user_version'] -ne 1){$db.Dispose();$db=$null;throw 'Base incompatible.'}
    $db.Exec('PRAGMA busy_timeout=5000',@())
   }
   if ($null -eq $db) {
    $ui.Summary.Text='Aucune base : importer des exports avec le lanceur de stockage.'
    $ui.Counts.Text='Setup Engineer reste disponible. Aucune base créée ou remplacée.'
    $ui.Footer.Text="Base absente : $DatabasePath";RefreshHistory;return
   }
   $report=Export-AcrStatistics $db $Profile (Join-Path $env:LOCALAPPDATA 'ACR-Optimal\Experimental\InterfaceRapports')
   $script:summaries=@(Read-AcrJsonRecords (Join-Path $report 'resume.json'));$script:gains=@(Read-AcrJsonRecords (Join-Path $report 'gains-secteurs.json'));$script:progressAll=@(Read-AcrJsonRecords (Join-Path $report 'progression.json'))
   $script:allRows=@($db.Query('SELECT a.*,CASE WHEN e.id IS NULL THEN 0 ELSE 1 END AS eligible FROM attempts a LEFT JOIN eligible_attempts e ON e.id=a.id WHERE a.profile=? ORDER BY a.id',@($Profile)))
   $script:contexts=@($script:allRows|ForEach-Object {[pscustomobject]@{stage=$_['stage'];car=$_['car'];layout=$_['layout']}}|Sort-Object stage,car,layout -Unique)
   $ui.Context.Items.Clear();foreach($c in $script:contexts){$ui.Context.Items.Add("$($c.stage) / $($c.car) / secteurs $($c.layout)")|Out-Null}
   $ui.Footer.Text="Base en lecture seule : $DatabasePath. Acquisition automatique non validee. Les valeurs brutes restent intactes."
   if($script:contexts.Count){$ui.Context.SelectedIndex=0}else{$ui.Summary.Text='Base vide pour ce profil.'}
  } finally {$script:loading=$false};ShowContext;RefreshHistory
 }
 function ShowError($errorRecord) {[Windows.MessageBox]::Show($errorRecord.Exception.Message,'ACR-Optimal - erreur')|Out-Null}
 $ui.Refresh.Add_Click({try {RefreshData}catch {ShowError $_}})
 $ui.Navigation.Add_SelectionChanged({ param($sender,$eventArgs)
  if ($eventArgs.Source -ne $ui.Navigation) {return}
  $show=$ui.Navigation.SelectedIndex -lt 2
  $visibility=[Windows.Visibility]::Collapsed;if($show){$visibility=[Windows.Visibility]::Visible}
  $ui.ContextBar.Visibility=$visibility;$ui.RecordsCard.Visibility=$visibility
  if($ui.Navigation.SelectedIndex -eq 3){try{RefreshHistory}catch{ShowError $_}}
 })
 $ui.Context.Add_SelectionChanged({try {ShowContext}catch {ShowError $_}})
 $ui.Chart.Add_SizeChanged({DrawChart})
 $ui.Attempts.Add_SelectionChanged({if($ui.Attempts.SelectedItem){$id=$ui.Attempts.SelectedItem.ID;$a=@($script:rows|Where-Object {$_['id'] -eq $id})[0];$ui.Details.Text="Mode : $($a['mode']) | Validite : $($a['validity']) | Complete : $($a['complete']) | Secteurs verifies : $($a['sectors_verified']) | Penalite : $($a['penalty'])`nCle : $($a['attempt_key'])`nDernier cumul = chrono final uniquement si l'arrivee est confirmee. Validation par le lanceur de stockage."}})
 $ui.Compare.Add_Click({try {
  if($ui.Left.SelectedIndex -lt 0 -or $ui.Right.SelectedIndex -lt 0){return}
  $a=$script:rows[$ui.Left.SelectedIndex];$b=$script:rows[$ui.Right.SelectedIndex]
  $sa=@($db.Query('SELECT sector_index,duration FROM sectors WHERE attempt_id=? ORDER BY sector_index',@($a['id'])));$sb=@($db.Query('SELECT sector_index,duration FROM sectors WHERE attempt_id=? ORDER BY sector_index',@($b['id'])))
  GridRows $ui.Comparison @(foreach($i in @(@($sa|ForEach-Object {$_['sector_index']})+@($sb|ForEach-Object {$_['sector_index']})|Sort-Object -Unique)){
   $va=@($sa|Where-Object {$_['sector_index'] -eq $i});$vb=@($sb|Where-Object {$_['sector_index'] -eq $i});$delta='Indisponible';$ta=$null;$tb=$null
   if($va.Count){$ta=$va[0]['duration']};if($vb.Count){$tb=$vb[0]['duration']};if($va.Count -and $vb.Count){$delta=Format-AcrGain ($tb-$ta)}
   [pscustomobject]@{Secteur=$i;A=(Format-AcrTime $ta);B=(Format-AcrTime $tb);EcartBmoinsA=$delta}
  })
  $ui.CompareNote.Text="A : $(Get-AcrDisplayStatus $a) | B : $(Get-AcrDisplayStatus $b). Ecart positif : B plus lente. Comparaison brute ; seuls les admissibles alimentent les records."
 }catch {ShowError $_}})
 function RefreshHistory {
  GridRows $ui.HistoryAttempts @(foreach($a in $script:allRows){[pscustomobject]@{ID=$a['id'];Speciale=$a['stage'];Voiture=$a['car'];ChronoOfficiel=(Format-AcrTime $a['official_final']);Statut=(Get-AcrDisplayStatus $a);PremiereObservation=$a['first_seen']}})
  GridRows $ui.HistorySetups @(Get-AcrSetupHistory -Root $SnapshotRoot)
 }
 $script:allRows=@()
 Import-Module (Join-Path $PSScriptRoot '..\setup-engineer\SetupView.psm1') -Force
 Import-Module (Join-Path $PSScriptRoot '..\setup-engineer\SetupHistory.psm1') -Force
 $setupView=New-AcrSetupView -SavePath $SavePath -SnapshotRoot $SnapshotRoot
 $ui.SetupHost.Content=$setupView.View
 Import-Module (Join-Path $PSScriptRoot '..\ocr-windows\OcrView.psm1')
 $ocrView=New-AcrSetupOcrView -SavePath $SavePath -SnapshotRoot $SnapshotRoot
 $ui.OcrHost.Content=$ocrView.View
 Import-Module (Join-Path $PSScriptRoot '..\collecteur-windows\CollectorControl.psm1')
 $ui.StartCollector.Add_Click({try {
  if($null -ne $script:collector -and -not $script:collector.Process.HasExited){return}
  if(-not $ui.ConfirmTT.IsChecked){throw 'Confirme le contre-la-montre avant de démarrer.'}
  $minutes=0;if(-not [int]::TryParse($ui.CollectorMinutes.Text,[ref]$minutes) -or $minutes -lt 0 -or $minutes -gt 1440){throw 'Durée : entier entre 0 et 1440. 0 = illimitée.'}
  $stage='AlsaceS4SaverneShort1Forward';$car='SkodaFabiaRSRally2'
  if($ui.Context.SelectedIndex -ge 0){$c=$script:contexts[$ui.Context.SelectedIndex];$stage=$c.stage;$car=$c.car}
  $answer=[Windows.MessageBox]::Show("Démarrer pour $stage / $car ? Un processus PowerShell de collecte utilisera une autorisation temporaire Bypass, sans modifier la politique permanente. Les nouvelles tentatives resteront en attente de validation.",'ACR-Optimal',[Windows.MessageBoxButton]::YesNo)
  if($answer -ne [Windows.MessageBoxResult]::Yes){return}
  $names=@($ui.GameNames.Text.Split(',')|ForEach-Object {$_.Trim()}|Where-Object {$_})
  $script:collector=Start-AcrCollector -SavePath (Join-Path $env:LOCALAPPDATA 'acr\Saved\SaveGames\PlayerDataSaveSlot.sav') -StageId $stage -CarId $car -Profile $Profile -DatabasePath $DatabasePath -Minutes $minutes -GameProcessNames $names
  $script:collectorLastEvent='';$ui.CollectorState.Text='Collecteur : démarrage';$ui.StartCollector.IsEnabled=$false;$ui.StopCollector.IsEnabled=$true
  $ui.CollectorInfo.Text="Journaux : $($script:collector.Root)"
 }catch{ShowError $_}})
 $ui.StopCollector.Add_Click({try{Stop-AcrCollector $script:collector;$ui.CollectorState.Text='Arrêt demandé, fin de la transaction en cours.'}catch{ShowError $_}})
 $script:collectorTimer=New-Object Windows.Threading.DispatcherTimer
 $script:collectorTimer.Interval=[TimeSpan]::FromSeconds(1)
 $script:collectorTimer.Add_Tick({try {
  if($null -eq $script:collector){return}
  $state=Read-AcrCollectorStatus $script:collector
  if($null -ne $state){
   $labels=@{Arrete='arrêté';Demarrage='démarrage';ConnecteAuJeu='connecté au jeu';EnAttenteDuJeu='en attente du jeu';CollecteActive='collecte active';Erreur='erreur'}
   $ui.CollectorState.Text="Collecteur : $($labels[$state.State]) | $($state.Attempts) conservées | $($state.Eligible) admissibles"
   $stamp=[DateTime]::Parse($state.LastEventUtc).ToLocalTime().ToString('HH:mm:ss')
   $ui.CollectorLast.Text="Dernier événement ($stamp) : $($state.LastEvent)"
   if($state.Error){$ui.CollectorLast.Text+=" | $($state.Error)"}
   if($null -ne $state.LastAttempt){$ui.CollectorInfo.Text="Dernière tentative ajoutée : ID $($state.LastAttempt.Id), $(Format-AcrTime $state.LastAttempt.Seconds), en attente. Journaux : $($script:collector.Root)"}
   if($state.LastEventUtc -ne $script:collectorLastEvent){$script:collectorLastEvent=$state.LastEventUtc;RefreshData}
  }
  if($script:collector.Process.HasExited){
   $ui.StartCollector.IsEnabled=$true;$ui.StopCollector.IsEnabled=$false
   if($script:collector.Process.ExitCode -ne 0 -or $null -eq $state){$ui.CollectorState.Text="Collecteur : erreur. Consulter stderr.log et errors.csv : $($script:collector.Root)"}
  }
 }catch{$ui.CollectorState.Text="Collecteur : erreur de suivi : $($_.Exception.Message)"}})
 $script:collectorTimer.Start()
 $window.Add_Closing({try{Stop-AcrCollector $script:collector}catch{}})
 RefreshData
 $ui.Navigation.SelectedIndex=[Array]::IndexOf(@('Chronos','Performances','Setup','Historique'),$InitialPage)
 $window.ShowDialog()|Out-Null
} finally {
 if($null -ne $script:collectorTimer){$script:collectorTimer.Stop()}
 if($null -ne $script:collector){Stop-AcrCollector $script:collector;[void]$script:collector.Process.WaitForExit(5000)}
 if ($null -ne $db) {$db.Dispose()}
}
