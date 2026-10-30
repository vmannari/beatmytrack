$ErrorActionPreference = 'Stop'
$entry = Join-Path (Get-Location) 'scripts/dev.ps1'
$logs = Join-Path (Get-Location) 'docs/evidence/hovercraft-model-rebuild-2026-10-28/runs'
New-Item -ItemType Directory -Force -Path $logs | Out-Null
function Keep-Log([string]$Label) {
    Copy-Item -LiteralPath (Join-Path (Get-Location) "build/logs/TestScript-$PID/test-script.log") -Destination (Join-Path $logs "$Label.log") -Force
}
& $entry -Action TestScript -ScriptPath res://tests/review_hovercraft_prepared.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--hovercraft-only')
Keep-Log 'prepared-effective'
if ($LASTEXITCODE -ne 0) { throw 'Scoped native Garage regression failed' }
& $entry -Action TestScript -ScriptPath res://tests/review_hovercraft_prepared.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--hovercraft-only','--wrong-hover-glass')
Keep-Log 'prepared-wrong-glass'
if ($LASTEXITCODE -eq 0) { throw 'Wrong-glass negative control was not rejected' }
& $entry -Action TestScript -ScriptPath res://tests/inspect_hovercraft_template_context.gd
Keep-Log 'template-context'
& $entry -Action TestScript -ScriptPath res://tests/test_script_parse.gd
Keep-Log 'parser'
