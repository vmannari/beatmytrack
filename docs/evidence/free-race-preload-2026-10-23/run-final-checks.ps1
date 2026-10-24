$ErrorActionPreference = 'Stop'
$env:APPDATA = Join-Path (Get-Location) 'build/free-race-preload-user'
$logDirectory = Join-Path (Get-Location) 'docs/evidence/free-race-preload-2026-10-23/logs'
foreach ($case in @(@{Name='focused-headless'; Script='test_free_race_preload.gd'},@{Name='discovery-pages'; Script='test_discovery_pages.gd'})) {
    & ./scripts/dev.ps1 -Action TestScript -ScriptPath ('res://tests/'+$case.Script)
    $testExit = $LASTEXITCODE
    Copy-Item -LiteralPath (Join-Path (Get-Location) "build/logs/TestScript-$PID/test-script.log") -Destination (Join-Path $logDirectory ($case.Name+'.log'))
    if ($testExit -ne 0) { throw "Validation failed: $($case.Name), exit $testExit" }
}
