function New-AcrSetupOcrView {
 param([string]$SavePath,[string]$SnapshotRoot)
 $content=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'OcrView.ps1') -Raw
 $module=New-Module -Name ('AcrSetupOcr_'+[guid]::NewGuid().ToString('N')) -ScriptBlock ([scriptblock]::Create($content)) -ArgumentList $SavePath,$SnapshotRoot,$PSScriptRoot
 return [pscustomobject]@{View=(& $module {Get-AcrSetupOcrRoot});Lifetime=$module}
}
Export-ModuleMember -Function New-AcrSetupOcrView
