$ErrorActionPreference='Stop'
function Wait-AcrWinRt($Operation,[type]$Type) {
 $method=[System.WindowsRuntimeSystemExtensions].GetMethods()|Where-Object {$_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetGenericArguments().Count -eq 1 -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'}|Select-Object -First 1
 if($null -eq $method){throw 'Adaptateur WinRT indisponible dans cette version de PowerShell.'}
 $task=$method.MakeGenericMethod($Type).Invoke($null,@($Operation))
 if(-not $task.Wait(15000)){throw 'OCR Windows : delai de 15 secondes depasse.'}
 return $task.Result
}
function Read-AcrTitleOcr([string]$Path) {
 if($env:OS -ne 'Windows_NT'){throw 'OCR local Windows requis.'}
 Add-Type -AssemblyName System.Runtime.WindowsRuntime
 $null=[Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime]
 $null=[Windows.Storage.Streams.IRandomAccessStream,Windows.Storage.Streams,ContentType=WindowsRuntime]
 $null=[Windows.Graphics.Imaging.BitmapDecoder,Windows.Graphics.Imaging,ContentType=WindowsRuntime]
 $null=[Windows.Graphics.Imaging.SoftwareBitmap,Windows.Graphics.Imaging,ContentType=WindowsRuntime]
 $null=[Windows.Media.Ocr.OcrEngine,Windows.Foundation,ContentType=WindowsRuntime]
 $null=[Windows.Media.Ocr.OcrResult,Windows.Foundation,ContentType=WindowsRuntime]
 $file=Wait-AcrWinRt ([Windows.Storage.StorageFile]::GetFileFromPathAsync([IO.Path]::GetFullPath($Path))) ([Windows.Storage.StorageFile])
 $stream=Wait-AcrWinRt ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
 $bitmap=$null
 try {
  $decoder=Wait-AcrWinRt ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
  $bitmap=Wait-AcrWinRt ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
  if($bitmap.PixelHeight -gt 300 -or $bitmap.PixelWidth/[double]$bitmap.PixelHeight -lt 3){throw 'OCR refuse : fournir uniquement la bande recadree du titre.'}
  if($bitmap.PixelWidth -gt [Windows.Media.Ocr.OcrEngine]::MaxImageDimension -or $bitmap.PixelHeight -gt [Windows.Media.Ocr.OcrEngine]::MaxImageDimension){throw 'Zone OCR trop grande : reduire uniquement la zone du titre.'}
  $engine=[Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
  if($null -eq $engine){throw 'Aucun moteur OCR local. Installer une langue OCR depuis les parametres Windows (francais conseille).'}
  $result=Wait-AcrWinRt ($engine.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult])
  return ($result.Lines|ForEach-Object {$_.Text}) -join "`n"
 }finally{if($null -ne $bitmap){$bitmap.Dispose()};$stream.Dispose()}
}
Export-ModuleMember -Function Read-AcrTitleOcr
