$ErrorActionPreference = 'Stop'
$entry = Join-Path (Get-Location) 'scripts/dev.ps1'
$logs = Join-Path (Get-Location) 'docs/evidence/hovercraft-model-rebuild-2026-10-28/runs'
function Keep-Log([string]$Label) {
    Copy-Item -LiteralPath (Join-Path (Get-Location) "build/logs/TestScript-$PID/test-script.log") -Destination (Join-Path $logs "$Label.log") -Force
}
& $entry -Action TestScript -ScriptPath res://tests/review_hovercraft_prepared.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--hovercraft-only','--wrong-hover-glass')
Keep-Log 'prepared-wrong-glass-final'
if ($LASTEXITCODE -eq 0) { throw 'Wrong-glass negative control was not rejected' }
foreach ($method in @('gl_compatibility','mobile')) {
    & $entry -Action TestScript -ScriptPath res://tests/review_hovercraft_app.gd -Graphical -RenderingMethod $method
    Keep-Log "app-final-$method"
    if ($LASTEXITCODE -ne 0) { throw "Actual App failed: $method" }
}
