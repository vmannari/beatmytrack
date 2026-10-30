$ErrorActionPreference = 'Stop'
$entry = Join-Path (Get-Location) 'scripts/dev.ps1'
foreach ($method in @('gl_compatibility','mobile')) {
    & $entry -Action TestScript -ScriptPath res://tests/review_hovercraft_model.gd -Graphical -RenderingMethod $method
    if ($LASTEXITCODE -ne 0) { throw "Model review failed: $method" }
    & $entry -Action TestScript -ScriptPath res://tests/review_hovercraft_app.gd -Graphical -RenderingMethod $method
    if ($LASTEXITCODE -ne 0) { throw "Actual App review failed: $method" }
    & $entry -Action TestScript -ScriptPath res://tests/capture_hovercraft_ufo_drive.gd -Graphical -RenderingMethod $method -TestArgument @('--evidence-root=res://../docs/evidence/hovercraft-model-rebuild-2026-10-28/game')
    if ($LASTEXITCODE -ne 0) { throw "Actual Game review failed: $method" }
}
& $entry -Action TestScript -ScriptPath res://tests/test_racing_car_models.gd -TestArgument @('--vehicle=hovercraft','--evidence-root=res://../docs/evidence/hovercraft-model-rebuild-2026-10-28/racing')
if ($LASTEXITCODE -ne 0) { throw 'Racing regression failed' }
& $entry -Action TestScript -ScriptPath res://tests/test_garage_prepared_cars.gd
if ($LASTEXITCODE -ne 0) { throw 'Garage regression failed' }
& $entry -Action TestScript -ScriptPath res://tests/test_script_parse.gd
if ($LASTEXITCODE -ne 0) { throw 'Parser regression failed' }
