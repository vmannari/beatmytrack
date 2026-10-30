$ErrorActionPreference = 'Stop'
$entry = Join-Path (Get-Location) 'scripts/dev.ps1'
# Electric's concurrent author has already published its matching current scene.
foreach ($vehicle in @('compact','pickup','kart','forklift','hovercraft')) {
    & $entry -Action TestScript -ScriptPath res://tests/bake_garage_cars.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @("--vehicle=$vehicle")
    if ($LASTEXITCODE -ne 0) { throw "Template refresh failed: $vehicle" }
}
& $entry -Action TestScript -ScriptPath res://tests/test_garage_prepared_cars.gd
if ($LASTEXITCODE -ne 0) { throw 'Garage regression failed' }
& $entry -Action TestScript -ScriptPath res://tests/inspect_hovercraft_template_context.gd
if ($LASTEXITCODE -ne 0) { throw 'Template inspection failed' }
& $entry -Action TestScript -ScriptPath res://tests/test_script_parse.gd
if ($LASTEXITCODE -ne 0) { throw 'Parser regression failed' }
