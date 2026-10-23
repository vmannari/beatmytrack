$ErrorActionPreference = 'Stop'
$env:APPDATA = Join-Path (Get-Location) 'build/discovery-native-profile'
$folder = 'docs/evidence/discovery-indexed-2026-10-22'
foreach ($renderer in @('gl_compatibility', 'mobile')) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_discovery_windows.gd -Graphical -RenderingMethod $renderer -CommandTimeoutSeconds 120 2>&1 | Tee-Object "$folder/native-$renderer-final.log"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
foreach ($test in @('discovery_pages', 'free_race_list', 'publication_discovery', 'challenge_discovery')) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath "res://tests/test_$test.gd" -CommandTimeoutSeconds 180 2>&1 | Tee-Object "$folder/native-$test-regression.log"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
& powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 180 2>&1 | Tee-Object "$folder/parser-scripts-final.log"
exit $LASTEXITCODE
