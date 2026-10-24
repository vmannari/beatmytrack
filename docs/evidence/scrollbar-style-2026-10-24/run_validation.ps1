param(
    [string]$Test = 'test_scrollbar_style',
    [ValidateSet('headless', 'gl_compatibility', 'mobile')][string]$Mode = 'headless',
    [string]$Phase = 'final'
)
$ErrorActionPreference = 'Stop'
$scrollRepo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$scrollOutput = Join-Path $PSScriptRoot "$Phase/$Mode/$Test"
$env:APPDATA = Join-Path $scrollRepo "build/scrollbar-style-2026-10-24/$Phase-$Test-$Mode/appdata"
$env:BMT_STORE_EVIDENCE_DIR = Join-Path $PSScriptRoot "$Phase/store"
$env:BMT_SCROLLBAR_EVIDENCE_DIR = $scrollOutput
New-Item -ItemType Directory -Force -Path $env:APPDATA, $scrollOutput | Out-Null
$scrollEngine = 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe'
if ((& $scrollEngine --version).Trim() -ne (Get-Content -LiteralPath (Join-Path $scrollRepo 'godot-version.txt') -Raw).Trim()) { throw 'Pinned Godot version mismatch.' }
$scrollArgs = @('--path', (Join-Path $scrollRepo 'game'), '--log-file', (Join-Path $scrollOutput 'engine.log'), '--script', "res://tests/$Test.gd", '--audio-driver', 'Dummy')
if ($Mode -eq 'headless') { $scrollArgs += '--headless' }
else { $scrollArgs += @('--rendering-method', $Mode, '--max-fps', '60') }
if ($Mode -eq 'mobile') { $scrollArgs += @('--rendering-driver', 'vulkan') }
$scrollArgs += @('--', "--evidence-root=$scrollOutput", "--capture-rivalry-result=$scrollOutput")
& $scrollEngine @scrollArgs
exit $LASTEXITCODE
