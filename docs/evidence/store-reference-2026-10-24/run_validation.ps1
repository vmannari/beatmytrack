param(
    [string]$Test = 'test_store_reference',
    [ValidateSet('headless', 'gl_compatibility', 'mobile')][string]$Mode = 'headless',
    [switch]$VerboseEngine
)
$ErrorActionPreference = 'Stop'
$storeRepo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$env:APPDATA = Join-Path $storeRepo "build/store-reference-2026-10-24/$Test-$Mode/appdata"
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
$storeEngine = 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$storeVersion = (& $storeEngine --version).Trim()
if ($storeVersion -ne (Get-Content -LiteralPath (Join-Path $storeRepo 'godot-version.txt') -Raw).Trim()) { throw 'Pinned Godot version mismatch.' }
$storeArgs = @('--path', (Join-Path $storeRepo 'game'), '--log-file', (Join-Path $PSScriptRoot "$Test-$Mode.log"), '--script', "res://tests/$Test.gd", '--audio-driver', 'Dummy')
if ($Mode -eq 'headless') { $storeArgs += '--headless' }
else { $storeArgs += @('--rendering-method', $Mode, '--max-fps', '60') }
if ($Mode -eq 'mobile') { $storeArgs += @('--rendering-driver', 'vulkan') }
if ($VerboseEngine) { $storeArgs += '--verbose' }
& $storeEngine @storeArgs
exit $LASTEXITCODE
