param([string]$Job = 'model', [string]$Renderer = 'gl_compatibility')
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
Set-Location $repo
$env:APPDATA = Join-Path $repo 'build/kart-driver-shape/appdata'
$env:LOCALAPPDATA = Join-Path $repo 'build/kart-driver-shape/localappdata'
New-Item -ItemType Directory -Force $env:APPDATA,$env:LOCALAPPDATA | Out-Null
$folder = if ($Renderer -eq 'mobile') { "$Job-mobile" } else { $Job }
$testArgs = @("--evidence-root=res://../docs/evidence/kart-driver-shape-2026-10-25/$folder")
$script = 'test_kart_model.gd'
$graphical = $true
$kartSharedPaths = @('game/vehicle/vehicle_simulation.gd','game/vehicle/handling_config.gd','game/resources/cars/electric.tres','game/resources/cars/kart.tres','game/ui/garage_customisation_camera.gd')
function Get-KartSharedHashes {
    $kartHashes = @{}
    foreach ($kartSource in $kartSharedPaths) { $kartHashes[$kartSource] = (Get-FileHash -LiteralPath $kartSource -Algorithm SHA256).Hash.ToLower() }
    return $kartHashes
}
$kartSourcesBefore = Get-KartSharedHashes
switch ($Job) {
    'shape' { $script = 'test_kart_driver_shape.gd'; $graphical = $false }
    'shape-draft' { $script = 'test_kart_driver_shape.gd'; $graphical = $false; $testArgs += '--unbaked' }
    'shape-before' { $script = 'test_kart_driver_shape.gd'; $graphical = $false; $testArgs += '--old-shape-source' }
    'construction' { $script = 'test_kart_construction.gd'; $graphical = $false }
    'construction-before' { $script = 'test_kart_construction.gd'; $graphical = $false; $testArgs += '--old-task-source' }
    'construction-draft' { $script = 'test_kart_construction.gd'; $graphical = $false; $testArgs += '--unbaked' }
    'review' { $script = 'review_kart_model.gd' }
    'review-draft' { $script = 'review_kart_model.gd'; $testArgs += '--unbaked' }
    'proportions' { $script = 'test_kart_driver_proportions.gd'; $graphical = $false }
    'proportions-before' { $script = 'test_kart_driver_proportions.gd'; $graphical = $false }
    'proportions-draft' { $script = 'test_kart_driver_proportions.gd'; $graphical = $false; $testArgs += '--unbaked' }
    'before-model' { $testArgs += '--baseline' }
    'draft' { $testArgs += '--unbaked' }
    'fit' { $script = 'test_kart_driver_fit.gd' }
    'fit-before' { $script = 'test_kart_driver_fit.gd' }
    'fit-revised' { $script = 'test_kart_driver_fit.gd'; $testArgs += '--unbaked' }
    'draft-revised' { $testArgs += '--unbaked' }
    'fit-draft' { $script = 'test_kart_driver_fit.gd'; $testArgs += '--unbaked' }
    'retained' { $script = 'test_kart_model_fixes.gd' }
    'bake' { $script = 'bake_kart_model.gd'; $graphical = $false }
    'native' { $script = 'test_kart_refinement_ui.gd' }
    'art' { $script = 'test_kart_refinement_ui.gd'; $testArgs += '--bake-art' }
    'liveries' { $script = 'bake_livery_previews.gd'; $testArgs += '--vehicle=kart' }
    'news' { $script = 'bake_news_car_photos.gd'; $testArgs += '--vehicle=kart' }
    'parser' { $script = 'test_script_parse.gd'; $graphical = $false }
    'integrity' { $graphical = $false }
    'handling' { $script = 'test_kart.gd'; $graphical = $false }
    'import' {
        & ./scripts/dev.ps1 Import
        $result = $LASTEXITCODE
        Copy-Item -LiteralPath "$repo/build/logs/Import-$PID/import.log" -Destination "$PSScriptRoot/import.log"
        exit $result
    }
}
$parameters = @{ ScriptPath="res://tests/$script"; Graphical=$graphical; RenderingMethod=$Renderer; TestArgument=$testArgs }
if ($Renderer -eq 'mobile') { $parameters.RenderingDriver = 'vulkan' }
& ./scripts/dev.ps1 TestScript @parameters
$result = $LASTEXITCODE
Copy-Item -LiteralPath "$repo/build/logs/TestScript-$PID/test-script.log" -Destination "$PSScriptRoot/$folder.log"
@{job=$Job; renderer=$Renderer; script=$script; arguments=$testArgs; exit_code=$result; log="build/logs/TestScript-$PID/test-script.log"; shared_sources_before=$kartSourcesBefore; shared_sources_after=(Get-KartSharedHashes)} | ConvertTo-Json | Set-Content "$PSScriptRoot/$folder-command.json"
exit $result
