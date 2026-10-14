param(
    [Parameter(Mandatory = $true)][ValidateRange(1, 2147483647)][int]$GameProcessId,
    [ValidateRange(5, 120)][int]$Seconds = 60,
    [ValidateRange(100, 10000)][int]$ThresholdMs = 500
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$gameProcess = Get-Process -Id $GameProcessId -ErrorAction Stop
if ($gameProcess.ProcessName -notlike 'Godot*') { throw 'Expected a Godot game process.' }
$processStart = $gameProcess.StartTime.ToUniversalTime().Ticks
$output = Join-Path $taskRoot ('build/race-hitch-threads/' + $GameProcessId + '-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $output -Force | Out-Null
$hitchDirectory = Join-Path $env:APPDATA 'Circuit01Lab/diagnostics/race_hitches'
$baseline = @{}
function Read-GameHitches {
    $result = @{}
    if (-not (Test-Path -LiteralPath $hitchDirectory)) { return $result }
    foreach ($file in Get-ChildItem -LiteralPath $hitchDirectory -Filter ('race-*-' + $GameProcessId + '-*.json') -File) {
        try { $result[$file.Name] = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json }
        catch { continue }
    }
    return $result
}
foreach ($entry in (Read-GameHitches).GetEnumerator()) { $baseline[$entry.Key] = [double](($entry.Value.events | ForEach-Object { $_.frame.wall_ms } | Measure-Object -Maximum).Maximum) }
$samples = New-Object 'System.Collections.Generic.List[object]'
$timer = [diagnostics.stopwatch]::StartNew()
$metadata = [ordered]@{ process_id = $GameProcessId; process_start_utc_ticks = $processStart; started_utc = [datetime]::UtcNow.ToString('o'); seconds_limit = $Seconds; threshold_ms = $ThresholdMs; captured_new_hitch = $false; stop_reason = 'time_limit'; samples = $samples }
Write-Host ('RACE_HITCH_THREADS observing PID=' + $GameProcessId + ' for at most ' + $Seconds + ' seconds; output=' + $output)
try {
    while ($timer.Elapsed.TotalSeconds -lt $Seconds) {
        $current = Get-Process -Id $GameProcessId -ErrorAction SilentlyContinue
        if ($null -eq $current -or $current.StartTime.ToUniversalTime().Ticks -ne $processStart) { $metadata.stop_reason = 'process_exited'; break }
        $threads = New-Object 'System.Collections.Generic.List[object]'
        foreach ($thread in $current.Threads) {
            if ($threads.Count -ge 256) { break }
            try {
                $state = $thread.ThreadState.ToString()
                $wait = if ($state -eq 'Wait') { $thread.WaitReason.ToString() } else { '' }
                $threads.Add([ordered]@{ id = $thread.Id; cpu_ms = $thread.TotalProcessorTime.TotalMilliseconds; kernel_ms = $thread.PrivilegedProcessorTime.TotalMilliseconds; state = $state; wait = $wait })
            } catch { continue } # A worker may exit between enumeration/query.
        }
        $samples.Add([ordered]@{ elapsed_ms = $timer.Elapsed.TotalMilliseconds; utc = [datetime]::UtcNow.ToString('o'); process_cpu_ms = $current.TotalProcessorTime.TotalMilliseconds; threads = $threads })
        foreach ($entry in (Read-GameHitches).GetEnumerator()) {
            $events = @($entry.Value.events)
            $previous = if ($baseline.ContainsKey($entry.Key)) { [double]$baseline[$entry.Key] } else { -1 }
            for ($index = 0; $index -lt $events.Count; $index++) {
                if ([double]$events[$index].frame.wall_ms -le $previous) { continue }
                if ([double]$events[$index].frame.frame_ms -lt $ThresholdMs) { continue }
                $metadata.captured_new_hitch = $true
                $metadata.stop_reason = 'new_hitch'
                $metadata.frame_ms = [double]$events[$index].frame.frame_ms
                $metadata.race_tick = [int]$events[$index].frame.tick
                Copy-Item -LiteralPath (Join-Path $hitchDirectory $entry.Key) -Destination $output
                break
            }
            $baseline[$entry.Key] = [double](($events | ForEach-Object { $_.frame.wall_ms } | Measure-Object -Maximum).Maximum)
            if ($metadata.captured_new_hitch) { break }
        }
        if ($metadata.captured_new_hitch) { break }
        Start-Sleep -Milliseconds 250
    }
} finally {
    $metadata.finished_utc = [datetime]::UtcNow.ToString('o')
    $metadata | ConvertTo-Json -Depth 8 -Compress | Set-Content -LiteralPath (Join-Path $output 'threads.json') -Encoding UTF8
    Write-Host ('RACE_HITCH_THREADS complete captured_new_hitch=' + $metadata.captured_new_hitch + ' reason=' + $metadata.stop_reason + ' samples=' + $samples.Count)
}
