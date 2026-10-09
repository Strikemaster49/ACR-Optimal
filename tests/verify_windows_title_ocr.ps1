# Windows PowerShell 5.1 x64/STA. Real local OCR, no game interaction required.
param([string]$Root=(Split-Path $PSScriptRoot -Parent),[string]$TitleImage,[string]$ExpectedName)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Drawing
Import-Module (Join-Path $Root 'ocr-windows/SetupDetection.psm1')
Import-Module (Join-Path $Root 'ocr-windows/WindowsTitleOcr.psm1')
Import-Module (Join-Path $Root 'ocr-windows/OcrView.psm1')
Add-Type -Path (Join-Path $Root 'ocr-windows/TitleCapture.cs') -ReferencedAssemblies 'System.dll','System.Core.dll','System.Drawing.dll'
$work=Join-Path $env:TEMP ('acr-ocr-test-'+[guid]::NewGuid().ToString('N'))
$a=New-AcrSetupOcrView -SavePath (Join-Path $work 'absent.sav') -SnapshotRoot $work
if($a.View -isnot [Windows.Controls.UserControl]){throw 'Vue non integrable'}
if($a.View.FindName('Enabled').IsChecked){throw 'OCR actif par defaut'}
$a.View.FindName('Capture').RaiseEvent((New-Object Windows.RoutedEventArgs([Windows.Controls.Button]::ClickEvent)))
if(Test-Path $work){throw 'La vue inactive a cree des fichiers'}
# Exercise actual WPF callbacks using a synthetic snapshot, without an OCR call.
[void][IO.Directory]::CreateDirectory($work)
$seed=@{Schema='acr-setup-snapshot-v1';Setups=@(@{CarId='TestCar';Name='TestSetup';VersionId='test-version'})}
[IO.File]::WriteAllText((Join-Path $work 'setup-test.json'),($seed|ConvertTo-Json -Depth 5))
$b=New-AcrSetupOcrView -SavePath (Join-Path $work 'absent.sav') -SnapshotRoot $work
$b.View.FindName('CarConfirmed').IsChecked=$true
$b.View.FindName('ManualSnapshot').SelectedIndex=0
function Click($control){$control.RaiseEvent((New-Object Windows.RoutedEventArgs([Windows.Controls.Button]::ClickEvent)))}
Click $b.View.FindName('Manual')
if($b.View.FindName('State').Text -notmatch 'choix manuel'){throw 'Choix manuel non fonctionnel'}
$b.View.FindName('Applied').IsChecked=$true;$b.View.FindName('Unchanged').IsChecked=$true
Click $b.View.FindName('Confirm')
if($b.View.FindName('State').Text -notmatch 'Confirm'){throw 'Confirmation manuelle non fonctionnelle'}
if($a.View.FindName('Car').Items.Count -ne 0){throw 'Etats des vues partages'}
Click $b.View.FindName('Dirty')
if($b.View.FindName('State').Text -notmatch 'invalid'){throw 'Invalidation manuelle non fonctionnelle'}
if(-not $TitleImage){
 $d=New-Object Microsoft.Win32.OpenFileDialog;$d.Filter='Titre seul PNG|*.png'
 if(-not $d.ShowDialog()){throw 'Test annule : une image de titre recadree est necessaire.'}
 $TitleImage=$d.FileName
}
$image=New-Object Windows.Media.Imaging.BitmapImage
$image.BeginInit();$image.CacheOption=[Windows.Media.Imaging.BitmapCacheOption]::OnLoad;$image.UriSource=[Uri]([IO.Path]::GetFullPath($TitleImage));$image.EndInit()
if($image.PixelHeight -gt 300 -or $image.PixelWidth/[double]$image.PixelHeight -lt 3){throw 'Fournir uniquement une bande du titre, pas une capture complete.'}
$before=(Get-FileHash -LiteralPath $TitleImage).Hash
$text=Read-AcrTitleOcr -Path $TitleImage
Write-Host ('Texte OCR : '+$text)
$title=Test-AcrSetupTitle $text
if(-not $title.Found){throw 'Titre non reconnu. Corriger le recadrage/langue ; ne pas activer une association.'}
if(-not $ExpectedName){$ExpectedName=Read-Host 'Nom exact attendu dans le titre du jeu'}
if($title.Name -cne (Normalize-AcrSetupName $ExpectedName)){throw 'Le nom OCR differe du nom attendu'}
if((Get-FileHash -LiteralPath $TitleImage).Hash -ne $before){throw 'Image source modifiee'}
Write-Host 'PASS Windows : capture compilee, vue integree inactive, callbacks manuels isoles, vrai OCR local du titre, nom controle, source intacte'
Write-Host 'Ce test ne demontre ni le clic de chargement, ni le setup applique, ni une association aux chronos.'
