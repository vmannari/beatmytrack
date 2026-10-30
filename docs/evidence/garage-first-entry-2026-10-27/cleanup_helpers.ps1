$ErrorActionPreference='Stop'
$receipts=@()
foreach ($candidate in Get-CimInstance Win32_Process) {
    if ($candidate.Name -notlike 'Godot_v4.7.2-stable_win64*' -or !$candidate.CommandLine) { continue }
    $arguments=$candidate.CommandLine.Replace('/','\')
    $taskScript=$arguments -like '*\docs\evidence\garage-first-entry-2026-10-27\*'
    $failedProbe=$taskScript -and (($arguments -like '*inspect_keys.gd*') -or ($arguments -like '*driver-cache-control*'))
    $oldEmptyCheck=$candidate.ProcessId -eq 9876 -and $arguments.Contains('--check-only') -and $candidate.CreationDate -ge [datetime]'2026-10-27T21:28:13' -and $candidate.CreationDate -le [datetime]'2026-10-27T21:28:17'
    if (!$failedProbe -and !$oldEmptyCheck) { continue }
    $receipts+=@{pid=$candidate.ProcessId;created=$candidate.CreationDate.ToString('o');reason='Failed isolated profiling helper from this task'}
    ConvertTo-Json -InputObject $receipts -Depth 3 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'helper-cleanup.json')
    try {
        $helperProcess=[Diagnostics.Process]::GetProcessById($candidate.ProcessId)
        $helperProcess.Kill()
        $helperProcess.WaitForExit(2000) | Out-Null
    } catch [ArgumentException] {
        # A wrapper or child may already have exited after the exact-path match.
    } catch [InvalidOperationException] {
    }
}
ConvertTo-Json -InputObject $receipts -Depth 3 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'helper-cleanup.json')
Write-Output "Closed $($receipts.Count) failed task helpers"
