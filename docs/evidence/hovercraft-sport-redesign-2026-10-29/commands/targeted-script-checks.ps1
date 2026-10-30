$ErrorActionPreference = 'Continue'
$entry = Join-Path (Get-Location) 'scripts/dev.ps1'
$logs = Join-Path (Get-Location) 'docs/evidence/hovercraft-sport-redesign-2026-10-29/runs'
$outcomes = @{}
foreach ($target in @(@('app','res://core/app.gd'),@('model','res://vehicle/hovercraft_model.gd'))) {
    & $entry -Action CheckScript -ScriptPath $target[1] *> (Join-Path $logs "check-$($target[0])-runner.log")
    $outcomes[$target[0]] = $LASTEXITCODE
    $parseLog = Join-Path (Get-Location) "build/logs/CheckScript-$PID/parse.log"
    if (Test-Path -LiteralPath $parseLog) { Copy-Item -LiteralPath $parseLog -Destination (Join-Path $logs "check-$($target[0]).log") -Force }
}
& $entry -Action TestScript -ScriptPath res://tests/inspect_hovercraft_sport_templates.gd
$outcomes.templates = $LASTEXITCODE
Copy-Item -LiteralPath (Join-Path (Get-Location) "build/logs/TestScript-$PID/test-script.log") -Destination (Join-Path $logs 'template-context-final.log') -Force
$outcomes | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path (Get-Location) 'docs/evidence/hovercraft-sport-redesign-2026-10-29/targeted-checks.json')
Write-Host "TARGETED_CHECKS: app=$($outcomes.app) model=$($outcomes.model) templates=$($outcomes.templates)"
if ($outcomes.app -ne 0 -or $outcomes.model -ne 0 -or $outcomes.templates -ne 0) { exit 1 }
