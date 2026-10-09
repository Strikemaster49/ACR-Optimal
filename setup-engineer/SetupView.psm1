# Each embedded view owns its module session: callbacks never share dashboard state.
function New-AcrSetupView {
 param([string]$SavePath,[string]$SnapshotRoot)
 $content=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'SetupView.ps1') -Raw
 $module=New-Module -Name ('AcrSetupView_'+[guid]::NewGuid().ToString('N')) -ScriptBlock ([scriptblock]::Create($content)) -ArgumentList $SavePath,$SnapshotRoot,(Join-Path $PSScriptRoot 'SetupEngine.psm1')
 $view=& $module { Get-AcrSetupRoot }
 return [pscustomobject]@{View=$view;Lifetime=$module}
}
Export-ModuleMember -Function New-AcrSetupView
