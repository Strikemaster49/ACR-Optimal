# Run on Windows PowerShell 5.1 x64/STA; uses a COPY of your setup save.
param([string]$Root,[string]$SavePath,[string]$WorkDir)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
Import-Module (Join-Path $Root 'setup-engineer/SetupView.psm1') -Force
$before=(Get-FileHash $SavePath).Hash
$a=New-AcrSetupView -SavePath $SavePath -SnapshotRoot $WorkDir
if($a.View -isnot [Windows.Controls.UserControl]){throw 'Vue non integrable'}
$read=$a.View.FindName('Read')
$read.RaiseEvent((New-Object Windows.RoutedEventArgs([Windows.Controls.Button]::ClickEvent)))
if($a.View.FindName('Setup').Items.Count -lt 1){throw 'Lecture integree echouee'}
$b=New-AcrSetupView -SavePath $SavePath -SnapshotRoot $WorkDir
if($b.View.FindName('Setup').Items.Count -ne $a.View.FindName('Setup').Items.Count){throw 'Historique non recharge'}
$count=$a.View.FindName('Setup').Items.Count
$b.View.FindName('ReloadHistory').RaiseEvent((New-Object Windows.RoutedEventArgs([Windows.Controls.Button]::ClickEvent)))
if($b.View.FindName('Setup').Items.Count -ne $count){throw 'Doublons dans historique'}
if($a.View.FindName('Setup').Items.Count -ne $count){throw 'Etats des vues melanges'}
$b.View.FindName('B').SelectedIndex=$b.View.FindName('A').SelectedIndex
$b.View.FindName('Compare').RaiseEvent((New-Object Windows.RoutedEventArgs([Windows.Controls.Button]::ClickEvent)))
if(@($b.View.FindName('Differences').ItemsSource).Count -eq 0){throw 'Comparaison integree echouee'}
if((Get-FileHash $SavePath).Hash -ne $before){throw 'SAV modifie'}
Write-Host 'PASS Windows : UserControl, callbacks, lecture, historique, isolation, comparaison, source intacte'
