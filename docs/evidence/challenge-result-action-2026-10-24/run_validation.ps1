param(
    [string]$Test = 'test_challenge_result_action',
    [ValidateSet('headless', 'gl_compatibility', 'mobile')][string]$Mode = 'headless'
)
$ErrorActionPreference = 'Stop'
$challengeRepo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$env:APPDATA = Join-Path $challengeRepo "build/challenge-result-action-2026-10-24/$Test-$Mode/appdata"
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
$challengeEngine = 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe'
if ((& $challengeEngine --version).Trim() -ne (Get-Content -LiteralPath (Join-Path $challengeRepo 'godot-version.txt') -Raw).Trim()) { throw 'Pinned Godot version mismatch.' }
$challengeArgs = @('--path', (Join-Path $challengeRepo 'game'), '--log-file', (Join-Path $PSScriptRoot "$Test-$Mode.log"), '--script', "res://tests/$Test.gd", '--audio-driver', 'Dummy')
if ($Mode -eq 'headless') { $challengeArgs += '--headless' }
else { $challengeArgs += @('--rendering-method', $Mode, '--max-fps', '60') }
if ($Mode -eq 'mobile') { $challengeArgs += @('--rendering-driver', 'vulkan') }
& $challengeEngine @challengeArgs
exit $LASTEXITCODE
