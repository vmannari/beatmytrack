param([ValidateSet('Bake','Export','Install','Launch')][string]$Step)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$work = Join-Path $repo 'build/tablet-garage-liveries-2026-10-28'
$source = Join-Path $work 'source'
$env:GIT_DIR = Join-Path $repo '.git'
$env:GIT_WORK_TREE = $source
$env:APPDATA = Join-Path $work 'appdata'
$env:BMT_API_URL = ''
$env:BMT_DEV_AUTH_KEY = ''
$entry = Join-Path $source 'scripts/dev.ps1'
switch ($Step) {
    'Bake' { & $entry -Action TestScript -ScriptPath res://tests/task_bake_garage_previews.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 300 }
    'Export' { & $entry -Action ExportAndroid -QuickValidation -CommandTimeoutSeconds 900 }
    'Install' { & $entry -Action InstallAndroid -DeviceSerial f0ba474a -CommandTimeoutSeconds 300 }
    'Launch' { & $entry -Action LaunchAndroid -DeviceSerial f0ba474a -CommandTimeoutSeconds 120 }
}
if ($LASTEXITCODE) { exit $LASTEXITCODE }
