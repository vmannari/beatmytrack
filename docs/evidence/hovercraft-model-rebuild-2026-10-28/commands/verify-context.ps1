$ErrorActionPreference = 'Stop'
$entry = Join-Path (Get-Location) 'scripts/dev.ps1'
& $entry -Action TestScript -ScriptPath res://tests/test_garage_prepared_cars.gd -Graphical -RenderingMethod gl_compatibility
if ($LASTEXITCODE -ne 0) { throw 'Native Garage regression failed' }
& $entry -Action TestScript -ScriptPath res://tests/inspect_hovercraft_template_context.gd
if ($LASTEXITCODE -ne 0) { throw 'Template inspection failed' }
& $entry -Action TestScript -ScriptPath res://tests/test_script_parse.gd
if ($LASTEXITCODE -ne 0) { throw 'Parser regression failed' }
