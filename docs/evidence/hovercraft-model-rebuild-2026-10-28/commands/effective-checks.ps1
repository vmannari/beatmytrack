$ErrorActionPreference = 'Stop'
$entry = Join-Path (Get-Location) 'scripts/dev.ps1'
& $entry -Action TestScript -ScriptPath res://tests/review_hovercraft_prepared.gd -Graphical -RenderingMethod gl_compatibility
if ($LASTEXITCODE -ne 0) { throw 'Effective native Garage regression failed' }
& $entry -Action TestScript -ScriptPath res://tests/review_hovercraft_prepared.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--wrong-hover-glass')
if ($LASTEXITCODE -eq 0) { throw 'Wrong-glass negative control was not rejected' }
& $entry -Action TestScript -ScriptPath res://tests/inspect_hovercraft_template_context.gd
if ($LASTEXITCODE -ne 0) { throw 'Template inspection failed' }
& $entry -Action TestScript -ScriptPath res://tests/test_script_parse.gd
if ($LASTEXITCODE -ne 0) { throw 'Parser regression failed' }
