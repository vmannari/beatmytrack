$ErrorActionPreference = 'Stop'
$failedTests = @()
foreach ($test in @('test_sticker_collection','test_sticker_appearance_sync','test_rivalry_custom_cars','test_garage_customisation_speed','test_records')) {
    try {
        & (Join-Path $PSScriptRoot 'run.ps1') -Phase regressions -Headless -ScriptPath ('res://tests/' + $test + '.gd')
    } catch {
        $failedTests += $test
        Write-Output $_
    }
}
Write-Output ('STICKER_REGRESSION_FAILURES: ' + ($failedTests -join ', '))
if ($failedTests.Count) { exit 1 }
