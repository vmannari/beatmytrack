param(
    [string]$Test = 'test_touch_slide_activation',
    [ValidateSet('headless', 'gl_compatibility', 'mobile')][string]$Mode = 'headless'
)
$ErrorActionPreference = 'Stop'
$taskRepo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$env:APPDATA = Join-Path $taskRepo "build/touch-slide-activation-2026-10-23/$Test-$Mode/appdata"
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
$engine = 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$testArgs = @('--path', (Join-Path $taskRepo 'game'), '--log-file', (Join-Path $PSScriptRoot "$Test-$Mode.log"), '--script', "res://tests/$Test.gd")
if ($Mode -eq 'headless') {
    $testArgs += '--headless'
} else {
    $testArgs += @('--rendering-method', $Mode, '--audio-driver', 'Dummy', '--max-fps', '60')
    if ($Mode -eq 'mobile') { $testArgs += @('--rendering-driver', 'vulkan') }
}
& $engine @testArgs
exit $LASTEXITCODE
