param([int]$Seconds = 120, [string]$Output = 'build/ajorata-performance/present-final')
$ErrorActionPreference = 'Stop'
$adb = Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools/adb.exe'
$layer = @(& $adb shell dumpsys SurfaceFlinger --list | Where-Object { $_ -like 'SurfaceView[[]org.circuit01.handlinglab/*(BLAST)*' }) | Select-Object -Last 1
if (-not $layer) { throw 'Game SurfaceView is not visible.' }
$frames = [System.Collections.Generic.HashSet[long]]::new()
$raw = [System.Collections.Generic.List[string]]::new()
$timer = [System.Diagnostics.Stopwatch]::StartNew()
while ($timer.Elapsed.TotalSeconds -lt $Seconds) {
    $lines = @(& $adb shell "dumpsys SurfaceFlinger --latency '$layer'")
    foreach ($line in $lines) {
        $raw.Add($line)
        if ($line -match '^\d+\s+(\d+)\s+\d+$') {
            $stamp = [long]$Matches[1]
            if ($stamp -gt 0 -and $stamp -lt 9000000000000000000) { [void]$frames.Add($stamp) }
        }
    }
    Start-Sleep -Milliseconds 900
}
$times = @($frames | Sort-Object)
$deltas = @(for ($i=1; $i -lt $times.Count; $i++) { ($times[$i]-$times[$i-1])/1000000.0 }) | Sort-Object
if ($deltas.Count -eq 0) { throw 'No presentation timestamps available.' }
$report = [ordered]@{
    source = 'SurfaceFlinger actual-present timestamps, deduplicated across overlapping polls'
    layer = $layer
    frames = $deltas.Count
    seconds = ($times[-1]-$times[0])/1000000000.0
    median_ms = $deltas[[int][math]::Floor($deltas.Count*0.5)]
    p95_ms = $deltas[[int][math]::Floor($deltas.Count*0.95)]
    p99_ms = $deltas[[int][math]::Floor($deltas.Count*0.99)]
    max_ms = $deltas[-1]
    over_25_ms = @($deltas | Where-Object { $_ -gt 25 }).Count
    over_33_34_ms = @($deltas | Where-Object { $_ -gt 33.34 }).Count
}
$raw | Set-Content "$Output.txt" -Encoding UTF8
$report | ConvertTo-Json | Set-Content "$Output.json" -Encoding UTF8
$report | ConvertTo-Json
