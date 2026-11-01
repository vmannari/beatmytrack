param([ValidateSet('component','component-mobile','compatibility','mobile','first-draw-final','samplers')][string]$Mode = 'component')
$ErrorActionPreference = 'Stop'
$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Set-Location -LiteralPath $repoRoot
$env:APPDATA = Join-Path $repoRoot "build/shader-variant-consolidation-20261031/$Mode"
$env:BMT_API_URL = ''
$env:BMT_VARIANT_FINAL = '1'
$env:BMT_VARIANT_THEMES = 'desert,storm,night_city'
$env:BMT_VARIANT_FOLDER = Join-Path $PSScriptRoot "final-$Mode"
$env:BMT_VARIANT_OUTPUT = Join-Path $PSScriptRoot "$Mode.json"
New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
$testScript = 'test_shader_variant_consolidation.gd'
$rendererArguments = @()
if ($Mode -eq 'component-mobile') { $rendererArguments = @('-Graphical','-RenderingMethod','mobile') }
if ($Mode -in @('compatibility','mobile')) {
    $testScript = 'review_shader_variant_consolidation.gd'
    $rendererArguments = @('-Graphical','-RenderingMethod',$(if ($Mode -eq 'mobile') { 'mobile' } else { 'gl_compatibility' }))
}
if ($Mode -eq 'first-draw-final') {
    $testScript = 'profile_variant_first_draw.gd'
    $rendererArguments = @('-Graphical','-RenderingMethod','gl_compatibility')
}
if ($Mode -eq 'samplers') { $testScript = 'test_terrain_sampler_budget.gd' }
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath "res://tests/$testScript" @rendererArguments -CommandTimeoutSeconds 420 *> (Join-Path $PSScriptRoot "$Mode.log")
exit $LASTEXITCODE
