$ErrorActionPreference = 'Continue'
$env:APPDATA = Join-Path (Get-Location) 'build/discovery-native-profile'
$folder = 'docs/evidence/discovery-indexed-2026-10-22'
# Reproduce the existing publication fixture failure with task-original Cloud.
& 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path game --script res://../docs/evidence/discovery-indexed-2026-10-22/publication_baseline_probe.gd --log-file (Join-Path (Get-Location) "$folder/publication-baseline-engine.log") 2>&1 | Tee-Object "$folder/publication-baseline.log"
$ErrorActionPreference = 'Stop'
foreach ($renderer in @('', 'gl_compatibility', 'mobile')) {
    $arguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File','scripts/dev.ps1','-Action','TestScript','-ScriptPath','res://tests/test_discovery_windows.gd','-CommandTimeoutSeconds','120')
    $label = 'headless'
    if ($renderer) { $arguments += @('-Graphical','-RenderingMethod',$renderer); $label = $renderer }
    & powershell @arguments 2>&1 | Tee-Object "$folder/native-$label-complete.log"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
& powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_challenge_discovery.gd -CommandTimeoutSeconds 120 2>&1 | Tee-Object "$folder/native-challenge_discovery-final.log"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 180 2>&1 | Tee-Object "$folder/parser-scripts-final.log"
exit $LASTEXITCODE
