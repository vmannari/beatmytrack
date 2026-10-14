param(
    [Parameter(Mandatory = $true)][ValidateRange(1, 2147483647)][int]$GameProcessId,
    [ValidateRange(10, 120)][int]$Seconds = 60,
    [ValidateRange(100, 10000)][int]$ThresholdMs = 500
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$process = Get-Process -Id $GameProcessId -ErrorAction Stop
if ($process.ProcessName -notlike 'Godot*') { throw 'Expected a Godot game process.' }
$startedProcess = $process.StartTime.ToUniversalTime().Ticks
$wpr = (Get-Command wpr.exe -ErrorAction Stop).Source
$session = 'BMT-RaceHitch-' + $GameProcessId + '-' + [guid]::NewGuid().ToString('N')
$output = Join-Path $taskRoot ('build/race-hitch-traces/' + $session)
New-Item -ItemType Directory -Path $output -Force | Out-Null
$hitchDirectory = Join-Path $env:APPDATA 'Circuit01Lab/diagnostics/race_hitches'
$baseline = @{}
function Read-Hitches {
    $result = @{}
    if (-not (Test-Path -LiteralPath $hitchDirectory)) { return $result }
    foreach ($file in Get-ChildItem -LiteralPath $hitchDirectory -Filter ('race-*-' + $GameProcessId + '-*.json') -File) {
        try { $result[$file.Name] = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json }
        catch { continue } # Atomic replacement or a concurrently retiring capture.
    }
    return $result
}
foreach ($entry in (Read-Hitches).GetEnumerator()) { $baseline[$entry.Key] = [double](($entry.Value.events | ForEach-Object { $_.frame.wall_ms } | Measure-Object -Maximum).Maximum) }
$metadata = [ordered]@{ process_id = $GameProcessId; process_start_utc_ticks = $startedProcess; trace_session = $session; started_utc = [datetime]::UtcNow.ToString('o'); profiles = @('CPU', 'GPU'); seconds_limit = $Seconds; threshold_ms = $ThresholdMs; captured_new_hitch = $false; stop_reason = 'time_limit' }
$owned = $false
try {
    # Unique controller: never cancel/stop another user's recording. Memory mode
    # uses bounded circular buffers; no heap/file/network recording or upload.
    $ErrorActionPreference = 'Continue'
    $startOutput = & $wpr -start CPU -start GPU -instancename $session 2>&1
    $startExit = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    $startOutput | ForEach-Object { $_.ToString() } | Tee-Object -FilePath (Join-Path $output 'start.log')
    $metadata.start_exit_code = $startExit
    if ($startExit -ne 0) { $metadata.stop_reason = 'start_failed'; throw 'WPR could not start the owned recording; see start.log.' }
    $owned = $true
    Write-Host ('RACE_HITCH_TRACE recording PID=' + $GameProcessId + ' for at most ' + $Seconds + ' seconds; output=' + $output)
    $timer = [diagnostics.stopwatch]::StartNew()
    while ($timer.Elapsed.TotalSeconds -lt $Seconds) {
        $current = Get-Process -Id $GameProcessId -ErrorAction SilentlyContinue
        if ($null -eq $current -or $current.StartTime.ToUniversalTime().Ticks -ne $startedProcess) { $metadata.stop_reason = 'process_exited'; break }
        foreach ($entry in (Read-Hitches).GetEnumerator()) {
            $events = @($entry.Value.events)
            $previous = if ($baseline.ContainsKey($entry.Key)) { [double]$baseline[$entry.Key] } else { -1 }
            for ($index = 0; $index -lt $events.Count; $index++) {
                if ([double]$events[$index].frame.wall_ms -le $previous) { continue }
                if ([double]$events[$index].frame.frame_ms -lt $ThresholdMs) { continue }
                $metadata.captured_new_hitch = $true
                $metadata.stop_reason = 'new_hitch'
                $metadata.capture_file = $entry.Key
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
    if ($owned) {
        $ErrorActionPreference = 'Continue'
        $stopOutput = & $wpr -stop (Join-Path $output 'cpu-gpu.etl') 'Beat my track recovered render stall' -skipPdbGen -compress -instancename $session 2>&1
        $metadata.stop_exit_code = $LASTEXITCODE
        if ($metadata.stop_exit_code -ne 0) {
            & $wpr -cancel -instancename $session 2>&1 | Out-File -LiteralPath (Join-Path $output 'cancel.log')
            $metadata.cancel_exit_code = $LASTEXITCODE
        }
        $ErrorActionPreference = 'Stop'
        $stopOutput | ForEach-Object { $_.ToString() } | Tee-Object -FilePath (Join-Path $output 'stop.log')
    }
    $metadata.finished_utc = [datetime]::UtcNow.ToString('o')
    $metadata | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $output 'capture.json') -Encoding UTF8
    Write-Host ('RACE_HITCH_TRACE complete captured_new_hitch=' + $metadata.captured_new_hitch + ' reason=' + $metadata.stop_reason + ' output=' + $output)
}
