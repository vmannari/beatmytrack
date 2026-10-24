$ErrorActionPreference = 'Stop'
$taskRepo = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $taskRepo
$env:APPDATA = Join-Path $taskRepo 'build/parking-hall/regression-userdata'
foreach ($taskTest in @('test_driving','test_editor_practice','test_garage_carousel','test_app')) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath "res://tests/$taskTest.gd" -CommandTimeoutSeconds 300 | Tee-Object -FilePath "docs/evidence/parking-hall-2026-10-23/logs/$taskTest.log"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
