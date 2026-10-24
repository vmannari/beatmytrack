param(
    [string]$Test = 'test_challenge_result_view',
    [ValidateSet('headless', 'gl_compatibility', 'mobile')][string]$Mode = 'headless',
    [switch]$VerboseEngine
)
$ErrorActionPreference = 'Stop'
$resultRepo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$env:APPDATA = Join-Path $resultRepo "build/challenge-results-redesign-2026-10-24/$Test-$Mode/appdata"
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
$resultEngine = 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$resultVersion = (& $resultEngine --version).Trim()
if ($resultVersion -ne (Get-Content -LiteralPath (Join-Path $resultRepo 'godot-version.txt') -Raw).Trim()) { throw 'Pinned Godot version mismatch.' }
$resultArgs = @('--path', (Join-Path $resultRepo 'game'), '--log-file', (Join-Path $PSScriptRoot "$Test-$Mode.log"), '--script', "res://tests/$Test.gd", '--audio-driver', 'Dummy')
if ($Mode -eq 'headless') { $resultArgs += '--headless' }
else { $resultArgs += @('--rendering-method', $Mode, '--max-fps', '60') }
if ($Mode -eq 'mobile') { $resultArgs += @('--rendering-driver', 'vulkan') }
if ($VerboseEngine) { $resultArgs += '--verbose' }
& $resultEngine @resultArgs
exit $LASTEXITCODE

