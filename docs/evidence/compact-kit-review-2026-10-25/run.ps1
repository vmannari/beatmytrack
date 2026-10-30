param(
    [ValidateSet('construction','geometry','catalog','aero','incremental','workflow','focus','capture','diagnostic','parser')]
    [string]$Job = 'construction',
    [ValidateSet('gl_compatibility','mobile')][string]$Renderer = 'gl_compatibility'
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
Set-Location -LiteralPath $repo
$env:APPDATA = Join-Path $repo 'build/compact-kit-review/appdata'
$env:LOCALAPPDATA = Join-Path $repo 'build/compact-kit-review/localappdata'
New-Item -ItemType Directory -Force $env:APPDATA,$env:LOCALAPPDATA | Out-Null
$scripts = @{
    construction='test_compact_kit_construction.gd'
    geometry='test_compact_kit_geometry.gd'
    catalog='test_expanded_compact_catalog.gd'
    aero='test_compact_aero_variety.gd'
    incremental='test_incremental_compact_kits.gd'
    workflow='test_compact_kits.gd'
    focus='test_customisation_carousel.gd'
    capture='capture_compact_kit_review.gd'
    diagnostic='review_compact_kits.gd'
    parser='test_script_parse.gd'
}
$folder = "$Job-$Renderer"
$testArgs = @("--evidence-root=res://../docs/evidence/compact-kit-review-2026-10-25/$folder")
if ($Job -eq 'geometry') { $testArgs += '--parts-only' }
$parameters = @{
    ScriptPath="res://tests/$($scripts[$Job])"
    Graphical=($Job -in @('capture','diagnostic','workflow','focus'))
    RenderingMethod=$Renderer
    TestArgument=$testArgs
    CommandTimeoutSeconds=600
}
if ($Renderer -eq 'mobile') { $parameters.RenderingDriver = 'vulkan' }
$result = 0
try { & ./scripts/dev.ps1 TestScript @parameters; $result = $LASTEXITCODE }
catch { Write-Host $_; $result = 1 }
$log = "$repo/build/logs/TestScript-$PID/test-script.log"
if (Test-Path -LiteralPath $log) { Copy-Item -LiteralPath $log -Destination "$PSScriptRoot/$folder.log" }
@{job=$Job; renderer=$Renderer; script=$scripts[$Job]; arguments=$testArgs; exit_code=$result; log="build/logs/TestScript-$PID/test-script.log"} | ConvertTo-Json | Set-Content "$PSScriptRoot/$folder-command.json"
exit $result
