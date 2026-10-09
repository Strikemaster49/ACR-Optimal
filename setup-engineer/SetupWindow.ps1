# Compatibility entry point: all launchers now open the same ACR-Optimal shell.
[CmdletBinding()]
param([string]$SavePath=(Join-Path $env:LOCALAPPDATA 'acr\Saved\SaveGames\CarSetupsDataSaveSlot.sav'),[string]$SnapshotRoot=(Join-Path $env:LOCALAPPDATA 'ACR-Optimal\SetupEngineer\Snapshots'))
& (Join-Path $PSScriptRoot '..\interface-windows\Interface.ps1') -InitialPage Setup -SavePath $SavePath -SnapshotRoot $SnapshotRoot
