$ErrorActionPreference = 'Stop'
$entry = Join-Path (Get-Location) 'scripts/dev.ps1'
$logs = Join-Path (Get-Location) 'docs/evidence/hovercraft-sport-redesign-2026-10-29/runs'
function Keep-Log([string]$Name) {
    Copy-Item -LiteralPath (Join-Path (Get-Location) "build/logs/TestScript-$PID/test-script.log") -Destination (Join-Path $logs "$Name.log") -Force
}
& $entry -Action TestScript -ScriptPath res://tests/bake_garage_cars.gd -Graphical -RenderingMethod gl_compatibility
$code = $LASTEXITCODE; Keep-Log 'garage-bake'
if ($code -ne 0) { throw 'Garage bake failed' }
& $entry -Action TestScript -ScriptPath res://tests/bake_hovercraft_art.gd -Graphical -RenderingMethod gl_compatibility
$code = $LASTEXITCODE; Keep-Log 'hovercraft-art'
if ($code -ne 0) { throw 'Hovercraft art bake failed' }
& $entry -Action TestScript -ScriptPath res://tests/bake_livery_previews.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--vehicle=hovercraft')
$code = $LASTEXITCODE; Keep-Log 'livery-bake'
if ($code -ne 0) { throw 'Livery bake failed' }
& $entry -Action TestScript -ScriptPath res://tests/bake_news_car_photos.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--vehicle=hovercraft','--evidence-root=res://../docs/evidence/hovercraft-sport-redesign-2026-10-29/news')
$code = $LASTEXITCODE; Keep-Log 'news-bake'
if ($code -ne 0) { throw 'News photo bake failed' }
& $entry -Action Import
if ($LASTEXITCODE -ne 0) { throw 'Import failed' }
