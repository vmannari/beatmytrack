param([ValidateSet('component','samplers','consolidation','compatibility','mobile','first-draw')][string]$Mode = 'component')
$ErrorActionPreference = 'Stop'
$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Set-Location -LiteralPath $repoRoot
$env:APPDATA = Join-Path $repoRoot "build/sampler-budget-fix-20261031/$Mode"
$env:BMT_API_URL = ''
$env:BMT_SAMPLER_AUDIT = ''
$env:BMT_SAMPLER_OUTPUT = Join-Path $PSScriptRoot "$Mode.json"
$env:BMT_VARIANT_OUTPUT = Join-Path $PSScriptRoot "$Mode.json"
$env:BMT_VARIANT_FOLDER = Join-Path $PSScriptRoot $Mode
$env:BMT_VARIANT_FINAL = '1'
$env:BMT_VARIANT_THEMES = 'pine,winter,desert,storm,night_city'
New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
$testScript = 'test_sampler_pruning.gd'
$rendererArguments = @()
if ($Mode -eq 'samplers') { $testScript = 'test_terrain_sampler_budget.gd' }
if ($Mode -eq 'consolidation') { $testScript = 'test_shader_variant_consolidation.gd' }
if ($Mode -in @('compatibility','mobile')) {
    $testScript = 'review_sampler_pruning.gd'
    $rendererArguments = @('-Graphical','-RenderingMethod',$(if ($Mode -eq 'mobile') { 'mobile' } else { 'gl_compatibility' }))
}
if ($Mode -eq 'first-draw') {
    $testScript = 'profile_sampler_first_draw.gd'
    $env:BMT_VARIANT_THEMES = 'desert,storm,night_city'
    $rendererArguments = @('-Graphical','-RenderingMethod','gl_compatibility')
}
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath "res://tests/$testScript" @rendererArguments -CommandTimeoutSeconds 600 *> (Join-Path $PSScriptRoot "$Mode.log")
exit $LASTEXITCODE
