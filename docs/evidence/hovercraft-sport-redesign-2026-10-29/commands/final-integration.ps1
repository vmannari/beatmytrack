$ErrorActionPreference = 'Stop'
$entry = Join-Path (Get-Location) 'scripts/dev.ps1'
$logs = Join-Path (Get-Location) 'docs/evidence/hovercraft-sport-redesign-2026-10-29/runs'
$root = 'res://../docs/evidence/hovercraft-sport-redesign-2026-10-29'
New-Item -ItemType Directory -Force -Path (Join-Path (Get-Location) 'docs/evidence/hovercraft-sport-redesign-2026-10-29/recovered') | Out-Null
function Keep-Log([string]$Name) {
    Copy-Item -LiteralPath (Join-Path (Get-Location) "build/logs/TestScript-$PID/test-script.log") -Destination (Join-Path $logs "$Name.log") -Force
}
foreach ($method in @('gl_compatibility','mobile')) {
    & $entry -Action TestScript -ScriptPath res://tests/review_hovercraft_sport_app.gd -Graphical -RenderingMethod $method
    $code = $LASTEXITCODE; Keep-Log "app-$method"
    if ($code -ne 0) { throw "Sport actual-App review failed: $method" }
    & $entry -Action TestScript -ScriptPath res://tests/capture_hovercraft_ufo_drive.gd -Graphical -RenderingMethod $method -TestArgument @("--evidence-root=$root/game")
    $code = $LASTEXITCODE; Keep-Log "game-$method"
    if ($code -ne 0) { throw "Sport actual-Game review failed: $method" }
}
& $entry -Action TestScript -ScriptPath res://tests/review_hovercraft_sport_prepared.gd -Graphical -RenderingMethod gl_compatibility
$code = $LASTEXITCODE; Keep-Log 'prepared-effective'
if ($code -ne 0) { throw 'Effective six-car prepared review failed' }
& $entry -Action TestScript -ScriptPath res://tests/review_hovercraft_sport_integration.gd
$code = $LASTEXITCODE; Keep-Log 'integration'
if ($code -ne 0) { throw 'Hovercraft retained integration failed' }
& $entry -Action TestScript -ScriptPath res://tests/test_racing_car_models.gd -TestArgument @('--vehicle=hovercraft',"--evidence-root=$root/racing")
$code = $LASTEXITCODE; Keep-Log 'racing'
if ($code -ne 0) { throw 'Hovercraft racing review failed' }
& $entry -Action TestScript -ScriptPath res://tests/test_garage_appearance_recovery.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @("--output=$root/recovered")
$code = $LASTEXITCODE; Keep-Log 'saved-appearance-recovery'
if ($code -ne 0) { throw 'Saved appearance recovery failed' }
