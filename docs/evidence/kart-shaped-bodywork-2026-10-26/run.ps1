param([string]$Job = 'model', [string]$Renderer = 'gl_compatibility')
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
Set-Location $repo
$env:APPDATA = Join-Path $repo 'build/kart-shaped-bodywork/appdata'
$env:LOCALAPPDATA = Join-Path $repo 'build/kart-shaped-bodywork/localappdata'
New-Item -ItemType Directory -Force $env:APPDATA,$env:LOCALAPPDATA | Out-Null
$folder = "$Job-$Renderer"
$testArgs = @("--evidence-root=res://../docs/evidence/kart-shaped-bodywork-2026-10-26/$folder")
$script = 'test_kart_model.gd'
$graphical = $false
switch ($Job) {
    'before' { $graphical = $true }
    'draft' { $graphical = $true; $testArgs += '--unbaked' }
    'bodywork' { $script = 'test_kart_bodywork.gd' }
    'bodywork-view' { $script = 'test_kart_bodywork.gd'; $graphical = $true }
    'bodywork-draft' { $script = 'test_kart_bodywork.gd'; $testArgs += '--unbaked' }
    'bodywork-before' { $script = 'test_kart_bodywork.gd'; $testArgs += '--before-shapes' }
    'model' { $graphical = $true }
    'retained' { $script = 'test_kart_model_fixes.gd' }
    'shape' { $script = 'test_kart_driver_shape.gd' }
    'fit' { $script = 'test_kart_driver_fit.gd' }
    'construction' { $script = 'test_kart_construction.gd' }
    'proportions' { $script = 'test_kart_driver_proportions.gd' }
    'bake' { $script = 'bake_kart_model.gd' }
    'garage-template' { $script = 'bake_garage_cars.gd'; $graphical = $true; $testArgs += '--vehicle=kart' }
    'native' { $script = 'test_kart_refinement_ui.gd'; $graphical = $true }
    'art' { $script = 'test_kart_refinement_ui.gd'; $graphical = $true; $testArgs += '--bake-art' }
    'liveries' { $script = 'bake_livery_previews.gd'; $graphical = $true; $testArgs += '--vehicle=kart' }
    'news' { $script = 'bake_news_car_photos.gd'; $graphical = $true; $testArgs += '--vehicle=kart' }
    'header' { $script = 'bake_kart_finishing_art.gd'; $graphical = $true }
    'handling' { $script = 'test_kart.gd' }
    'parser' { $script = 'test_script_parse.gd' }
    'import' {
        try { & ./scripts/dev.ps1 Import }
        finally { Copy-Item -LiteralPath "$repo/build/logs/Import-$PID/import.log" -Destination "$PSScriptRoot/$folder.log" }
        if ($LASTEXITCODE -ne 0) { throw 'Import failed' }
        exit 0
    }
    default { throw "Unknown job $Job" }
}
$parameters = @{ ScriptPath="res://tests/$script"; Graphical=$graphical; RenderingMethod=$Renderer; TestArgument=$testArgs }
if ($Renderer -eq 'mobile') { $parameters.RenderingDriver = 'vulkan' }
$result = 1
try {
    & ./scripts/dev.ps1 TestScript @parameters
    $result = $LASTEXITCODE
} finally {
    Copy-Item -LiteralPath "$repo/build/logs/TestScript-$PID/test-script.log" -Destination "$PSScriptRoot/$folder.log"
    @{job=$Job; renderer=$Renderer; script=$script; arguments=$testArgs; exit_code=$result} | ConvertTo-Json | Set-Content "$PSScriptRoot/$folder-command.json"
}
exit $result
