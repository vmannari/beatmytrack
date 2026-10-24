param([ValidateSet('headless','gl_compatibility','mobile','before','regression','parser')][string]$Mode = 'headless')
$ErrorActionPreference = 'Continue'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$env:APPDATA = Join-Path $repo "build/rivalry-name-userdata-$Mode"
$env:LOCALAPPDATA = Join-Path $repo "build/rivalry-name-local-$Mode"
$env:BMT_RIVALRY_POLISH_EVIDENCE_DIR = 'res://../docs/evidence/rivalry-name-integration-2026-10-24'
$env:BMT_RIVALRY_POLISH_BEFORE_SOURCE = 'res://../docs/evidence/rivalry-name-integration-2026-10-24/before/weekly_rivalry_page.gd'
$env:BMT_RIVALRY_CARS_EVIDENCE_DIR = 'res://../docs/evidence/rivalry-name-integration-2026-10-24/cars'
$env:BMT_RIVALRY_EVIDENCE_DIR = 'res://../docs/evidence/rivalry-name-integration-2026-10-24/app'
$tests = @('test_rivalry_view_polish')
if ($Mode -eq 'regression') { $tests = @('test_weekly_rivalry','test_rivalry_custom_cars') }
if ($Mode -eq 'parser') { $tests = @('test_script_parse') }
$results = @()
foreach ($test in $tests) {
    $arguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $repo 'scripts/dev.ps1'),'-Action','TestScript','-ScriptPath',"res://tests/$test.gd")
    if ($Mode -notin @('headless','parser')) {
        $arguments += @('-Graphical','-RenderingMethod',$(if ($Mode -in @('before','regression')) { 'gl_compatibility' } else { $Mode }))
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


