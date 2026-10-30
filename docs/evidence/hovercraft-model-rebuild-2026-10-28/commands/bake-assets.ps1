$ErrorActionPreference = 'Stop'
$entry = Join-Path (Get-Location) 'scripts/dev.ps1'
& $entry -Action TestScript -ScriptPath res://tests/bake_garage_cars.gd -Graphical -RenderingMethod gl_compatibility
if ($LASTEXITCODE -ne 0) { throw 'Garage bake failed' }
& $entry -Action TestScript -ScriptPath res://tests/bake_hovercraft_art.gd -Graphical -RenderingMethod gl_compatibility
if ($LASTEXITCODE -ne 0) { throw 'Art bake failed' }
& $entry -Action TestScript -ScriptPath res://tests/bake_livery_previews.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--vehicle=hovercraft')
if ($LASTEXITCODE -ne 0) { throw 'Livery bake failed' }
& $entry -Action TestScript -ScriptPath res://tests/bake_news_car_photos.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--vehicle=hovercraft','--evidence-root=res://../docs/evidence/hovercraft-model-rebuild-2026-10-28/news')
if ($LASTEXITCODE -ne 0) { throw 'News bake failed' }
& $entry -Action Import
if ($LASTEXITCODE -ne 0) { throw 'Import failed' }
