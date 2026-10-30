$ErrorActionPreference = 'Stop'
$taskRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$cases = @(
    @('test_rivalry_ready_entry', 'rivalry-ready-entry'),
    @('test_rivalry_entry', 'rivalry-ready-entry'),
    @('test_rivalry_car_switch', 'rivalry-car-switch'),
    @('test_rivalry_join_failure', 'rivalry-join-feedback'),
    @('test_automatic_rivalry_flow', 'rivalry-ready-entry'),
    @('test_menu_loading_speed', 'rivalry-ready-entry'),
    @('test_rivalry_week_completion', 'rivalry-ready-entry'),
    @('test_race_mode_input', 'rivalry-ready-entry'),
    @('test_app', 'rivalry-ready-entry'),
    @('test_script_parse', 'rivalry-ready-entry')
)
$failedCases = @()
foreach ($case in $cases) {
    $testName = $case[0]
    $env:APPDATA = Join-Path $taskRoot "build/$($case[1])/ready-entry-regressions/$testName/appdata"
    $env:LOCALAPPDATA = Join-Path $taskRoot "build/$($case[1])/ready-entry-regressions/$testName/localappdata"
    New-Item -ItemType Directory -Force -Path (Join-Path $env:APPDATA 'Circuit01Lab'),$env:LOCALAPPDATA | Out-Null
    Set-Content -LiteralPath (Join-Path $env:APPDATA 'Circuit01Lab/backend.cfg') -Value "[backend]`nurl=`"`"" -Encoding UTF8
    $env:BMT_API_URL = ''
    $env:BMT_RIVALRY_READY_CAPTURE_DIR = ''
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $taskRoot 'scripts/dev.ps1') -Action TestScript -ScriptPath "res://tests/$testName.gd" -CommandTimeoutSeconds 180 *> (Join-Path $PSScriptRoot "$testName.log")
    if ($LASTEXITCODE -ne 0) { $failedCases += $testName }
    Get-Content -LiteralPath (Join-Path $PSScriptRoot "$testName.log") -Tail 6
}
Write-Output "Failed cases: $($failedCases -join ', ')"
if ($failedCases.Count -gt 0) { exit 1 }
