# Deploy the debug game and sync saved PC tracks. Full regression is opt-in.
[CmdletBinding()]
param(
    [string]$TracksPath = (Join-Path $env:APPDATA 'Circuit01Lab/tracks'),
    [string]$DeviceSerial = '',
    [string]$AdbPath = $env:ADB_BIN,
    [string]$GodotPath = $env:GODOT_BIN,
    [switch]$FullValidation
)
& (Join-Path $PSScriptRoot 'dev.ps1') -Action DeployAndroidWithTracks -TracksPath $TracksPath -DeviceSerial $DeviceSerial -AdbPath $AdbPath -GodotPath $GodotPath -QuickValidation:(-not $FullValidation)
exit $LASTEXITCODE
