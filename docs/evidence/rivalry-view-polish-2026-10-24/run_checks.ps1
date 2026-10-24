param([ValidateSet('headless','gl_compatibility','mobile','before','parser','supplemental')][string]$Mode = 'headless')
$ErrorActionPreference = 'Continue'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$env:APPDATA = Join-Path $repo "build/rivalry-polish-userdata-$Mode"
$env:LOCALAPPDATA = Join-Path $repo "build/rivalry-polish-local-$Mode"
$env:BMT_RIVALRY_CARS_EVIDENCE_DIR = 'res://../docs/evidence/rivalry-view-polish-2026-10-24/cars'
$env:BMT_RIVALRY_EVIDENCE_DIR = "res://../docs/evidence/rivalry-view-polish-2026-10-24/app-$Mode"
$tests = @('test_rivalry_view_polish')
if ($Mode -eq 'parser') { $tests = @('test_script_parse') }
if ($Mode -eq 'supplemental') { $tests = @('test_rivalry_player_profile','test_app') }
if ($Mode -eq 'headless') { $tests += @('test_rivalry_custom_cars','test_weekly_rivalry','test_rivalry_track_detail','test_rivalry_player_profile','test_app') }
if ($Mode -eq 'gl_compatibility') { $tests += @('test_rivalry_custom_cars','test_weekly_rivalry') }
$results = @()
foreach ($test in $tests) {
    $arguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $repo 'scripts/dev.ps1'),'-Action','TestScript','-ScriptPath',"res://tests/$test.gd")
    if ($Mode -notin @('headless','parser','supplemental')) {
        $arguments += @('-Graphical','-RenderingMethod',$(if ($Mode -eq 'before') { 'gl_compatibility' } else { $Mode }))
    }
    if ($Mode -eq 'before') { $arguments += @('-TestArgument','--before') }
    $log = Join-Path $PSScriptRoot "$test-$Mode.log"
    $started = [DateTime]::UtcNow
    $timer = [Diagnostics.Stopwatch]::StartNew()
    & powershell.exe @arguments 2>&1 | Tee-Object -FilePath $log
    $code = $LASTEXITCODE
    $timer.Stop()
    $results += [ordered]@{test=$test; mode=$Mode; arguments=$arguments; started_utc=$started.ToString('o'); seconds=$timer.Elapsed.TotalSeconds; exit_code=$code; log=$log}
    $results | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $PSScriptRoot "results-$Mode.json") -Encoding UTF8
    if ($code -ne 0) { exit $code }
}
