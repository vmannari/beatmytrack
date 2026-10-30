$ErrorActionPreference = 'Stop'
$entry = Join-Path (Get-Location) 'scripts/dev.ps1'
$logs = Join-Path (Get-Location) 'docs/evidence/hovercraft-sport-redesign-2026-10-29/runs'
New-Item -ItemType Directory -Force -Path $logs | Out-Null
function Keep-Log([string]$Name) {
    Copy-Item -LiteralPath (Join-Path (Get-Location) "build/logs/TestScript-$PID/test-script.log") -Destination (Join-Path $logs "$Name.log") -Force
}
foreach ($method in @('gl_compatibility','mobile')) {
    & $entry -Action TestScript -ScriptPath res://tests/review_hovercraft_sport.gd -Graphical -RenderingMethod $method
    $code = $LASTEXITCODE
    Keep-Log "model-$method"
    if ($code -ne 0) { throw "Sport model review failed: $method" }
}
& $entry -Action TestScript -ScriptPath res://tests/review_hovercraft_sport_liveries.gd -Graphical -RenderingMethod mobile
$code = $LASTEXITCODE
Keep-Log 'liveries-mobile'
if ($code -ne 0) { throw 'Desktop Mobile livery review failed' }
& $entry -Action TestScript -ScriptPath res://tests/bake_hovercraft_sport_surfaces.gd
$code = $LASTEXITCODE
Keep-Log 'mesh-bake'
if ($code -ne 0) { throw 'Sport surface bake failed' }
