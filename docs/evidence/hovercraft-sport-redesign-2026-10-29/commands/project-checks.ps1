$ErrorActionPreference = 'Continue'
$entry = Join-Path (Get-Location) 'scripts/dev.ps1'
$logs = Join-Path (Get-Location) 'docs/evidence/hovercraft-sport-redesign-2026-10-29/runs'
& $entry -Action TestScript -ScriptPath res://tests/inspect_hovercraft_sport_templates.gd
$inspection = $LASTEXITCODE
Copy-Item -LiteralPath (Join-Path (Get-Location) "build/logs/TestScript-$PID/test-script.log") -Destination (Join-Path $logs 'template-context.log') -Force
& $entry -Action CheckScript *> (Join-Path $logs 'preferred-check-runner.log')
$preferred = $LASTEXITCODE
$parseLog = Join-Path (Get-Location) "build/logs/CheckScript-$PID/parse.log"
if (Test-Path -LiteralPath $parseLog) { Copy-Item -LiteralPath $parseLog -Destination (Join-Path $logs 'preferred-check.log') -Force }
& $entry -Action TestScript -ScriptPath res://tests/test_script_parse.gd
$full = $LASTEXITCODE
Copy-Item -LiteralPath (Join-Path (Get-Location) "build/logs/TestScript-$PID/test-script.log") -Destination (Join-Path $logs 'full-parser.log') -Force
@{ template_inspection = $inspection; preferred_check = $preferred; full_parser = $full } | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path (Get-Location) 'docs/evidence/hovercraft-sport-redesign-2026-10-29/project-checks.json')
Write-Host "PROJECT_CHECKS: templates=$inspection preferred=$preferred full_parser=$full"
if ($inspection -ne 0 -or $preferred -ne 0) { exit 1 }
