param(
    [string]$DeviceSerial = 'PRQKU4U4PREQNRWG',
    [ValidateSet('Baselines','WinterVisual')][string]$Phase = 'Baselines',
    [ValidateSet('winter','desert')][string[]]$Biomes = @('winter','desert'),
    [ValidateRange(30,180)][int]$Seconds = 120,
    [string]$OutputDirectory = 'docs/evidence/biome-phone-test-2026-10-13'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$evidence = Join-Path $root $OutputDirectory
$adb = Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools/adb.exe'
$package = 'org.circuit01.handlinglab'
$readyPath = 'files/biome_phone_ready.json'
New-Item -ItemType Directory -Force -Path $evidence | Out-Null
function Adb([string[]]$Arguments) {
    $result = & $adb -s $DeviceSerial @Arguments
    if ($LASTEXITCODE -ne 0) { throw "adb failed: $Arguments" }
    return $result
}
function PresentStamps([string]$Layer) {
    $lines = @(Adb @('shell',"dumpsys SurfaceFlinger --latency '$Layer'"))
    foreach ($line in $lines) {
        if ($line -match '^\d+\s+(\d+)\s+\d+$') {
            $stamp = [long]$Matches[1]
            if ($stamp -gt 0 -and $stamp -lt 9000000000000000000) { $stamp }
        }
    }
}
function Capture([string]$Name) {
    Adb @('shell','screencap','-p','/data/local/tmp/biome-phone-test.png') | Out-Null
    Adb @('pull','/data/local/tmp/biome-phone-test.png',"$evidence/$Name.png") | Out-Null
    Adb @('shell','rm','-f','/data/local/tmp/biome-phone-test.png') | Out-Null
}
$existingFiles = @(Adb @('shell','run-as',$package,'ls','files'))
foreach ($name in @('mobile_probe.json','mobile_probe_results.json','biome_phone_ready.json')) {
    if ($existingFiles -contains $name) { throw "Existing diagnostic $name must be preserved; stop before replacing it." }
}
$recordFiles = @('local_records.json','local_records.json.bak') | Where-Object { $existingFiles -contains $_ }
foreach ($name in $recordFiles) {
    $diagnosticFiles = @(Adb @('shell','run-as',$package,'ls','files/diagnostics'))
    if ($diagnosticFiles -contains "biome-phone-before-$name") { throw 'An earlier record backup exists; preserve it before running another test.' }
}
Adb @('shell','am','force-stop',$package) | Out-Null
foreach ($name in $recordFiles) {
    Adb @('shell','run-as',$package,'cp',"files/$name","files/diagnostics/biome-phone-before-$name") | Out-Null
}
Adb @('shell','run-as',$package,'sha256sum','files/local_records.json','files/local_records.json.bak') | Set-Content "$evidence/$Phase-record-hashes-before.txt"
try {
    $recordingSupported = $false
    if ($Phase -eq 'WinterVisual') {
        $recordingPath = & $adb -s $DeviceSerial shell which screenrecord
        $recordingSupported = $LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace(($recordingPath -join ''))
        @{screenrecord_available=$recordingSupported;mode=$(if ($recordingSupported) {'video'} else {'timestamped_screenshots'})} | ConvertTo-Json | Set-Content "$evidence/visual-capture-mode.json"
        if (-not $recordingSupported) {
            New-Item -ItemType Directory -Force -Path "$evidence/motion-frames" | Out-Null
            Write-Host 'Android screenrecord is absent; capture bounded, timestamped gameplay frames instead.'
        }
    }
    $runs = @(@('winter','track_b5d3f29314a7ae53'),@('desert','track_3e26605a8a90165e'))
    $runs = @($runs | Where-Object { $_[0] -in $Biomes })
    if ($Phase -eq 'WinterVisual') { $runs = ,@('winter-bank-visual','track_b5d3f29314a7ae53') }
    foreach ($run in $runs) {
        $name = $run[0]
        $config = [ordered]@{track_id=$run[1]; seconds=$Seconds; sustained=$true; use_game_scale=$true; feature_profile=$true; touch_stress=$false; features=@('baseline'); state_path='user://biome_phone_ready.json'}
        if ($Phase -eq 'WinterVisual') { $config.winter_stress = $true }
        $config | ConvertTo-Json -Depth 4 | Set-Content "$evidence/$name-config.json" -Encoding ASCII
        Adb @('shell','dumpsys','battery') | Set-Content "$evidence/$name-battery-before.txt"
        Adb @('shell','dumpsys','thermalservice') | Set-Content "$evidence/$name-thermal-before.txt"
        Adb @('shell','am','force-stop',$package) | Out-Null
        Adb @('push',"$evidence/$name-config.json",'/data/local/tmp/biome-phone-config.json') | Out-Null
        Adb @('shell','run-as',$package,'cp','/data/local/tmp/biome-phone-config.json','files/mobile_probe.json') | Out-Null
        Adb @('shell','run-as',$package,'rm','-f','files/mobile_probe_results.json',$readyPath) | Out-Null
        Adb @('shell','input','keyevent','KEYCODE_WAKEUP') | Out-Null
        Adb @('shell','wm','dismiss-keyguard') | Out-Null
        Adb @('shell','am','start','-W','-a','android.intent.action.MAIN','-c','android.intent.category.LAUNCHER','-p',$package) | Set-Content "$evidence/$name-launch.txt"
        $deadline = (Get-Date).AddSeconds(120)
        do {
            Start-Sleep -Seconds 1
            $files = @(Adb @('shell','run-as',$package,'ls','files'))
        } until ($files -contains 'biome_phone_ready.json' -or (Get-Date) -gt $deadline)
        if ($files -notcontains 'biome_phone_ready.json') { throw "$name did not start its local practice probe." }
        $appPid = (Adb @('shell','pidof',$package)) -join ''
        $timer = [System.Diagnostics.Stopwatch]::StartNew()
        Write-Host "$name ready: actual game settings, $Seconds seconds after five-second warmup."
        $stamps = [System.Collections.Generic.HashSet[long]]::new()
        $floorStamp = 0L
        $lastSeenStamp = 0L
        $polls = [System.Collections.Generic.List[object]]::new()
        $bufferGaps = 0
        $layer = ''
        $samplingSeconds = $Seconds - 20
        $lastProgress = -1
        $recording = $null
        $visualFrames = [System.Collections.Generic.List[object]]::new()
        $lastVisualFrame = -1.0
        $captureIndex = 0
        $captureTimes = @(7.0,13.0,19.0,25.0)
        while ($timer.Elapsed.TotalSeconds -lt ($Seconds + 6)) {
            $elapsed = $timer.Elapsed.TotalSeconds
            $progress = [int][math]::Floor($elapsed/20)
            if ($progress -gt $lastProgress) {
                Write-Host "$name elapsed=$([int]$elapsed)s present timestamps=$($stamps.Count)"
                $lastProgress = $progress
            }
            if ($Phase -eq 'Baselines' -and $elapsed -ge 8 -and $elapsed -lt (8+$samplingSeconds)) {
                if (-not $layer) {
                    $layer = @(Adb @('shell','dumpsys','SurfaceFlinger','--list') | Where-Object { $_ -like 'SurfaceView[[]org.circuit01.handlinglab/*(BLAST)*' }) | Select-Object -Last 1
                    if (-not $layer) { throw 'Game SurfaceView is not visible.' }
                    $previous = @(PresentStamps $layer)
                    if ($previous.Count -gt 0) { $floorStamp = ($previous | Measure-Object -Maximum).Maximum }
                    $lastSeenStamp = $floorStamp
                } else {
                    $pollStart = $timer.Elapsed.TotalSeconds
                    $observed = @(PresentStamps $layer | Sort-Object)
                    $gap = $observed.Count -gt 0 -and $observed[0] -gt $lastSeenStamp
                    if ($gap) { $bufferGaps++ }
                    $polls.Add([ordered]@{start_seconds=$pollStart;end_seconds=$timer.Elapsed.TotalSeconds;rows=$observed.Count;buffer_gap=$gap})
                    foreach ($stamp in $observed) {
                        if ($stamp -gt $floorStamp) { [void]$stamps.Add($stamp) }
                    }
                    if ($observed.Count -gt 0) { $lastSeenStamp = $observed[-1] }
                }
            }
            if ($Phase -eq 'WinterVisual') {
                # Screen recording/readback deliberately occur only in this visual run.
                if ($recordingSupported -and -not $recording -and $elapsed -ge 5) {
                    $recording = Start-Process -FilePath $adb -ArgumentList @('-s',$DeviceSerial,'shell','screenrecord','--size','1600x720','--time-limit','24','--bit-rate','4000000','/data/local/tmp/biome-phone-winter.mp4') -WindowStyle Hidden -PassThru -RedirectStandardOutput "$evidence/winter-recording-stdout.txt" -RedirectStandardError "$evidence/winter-recording-stderr.txt"
                    $recordingHandle = $recording.Handle
                }
                if (-not $recordingSupported -and $elapsed -ge 6 -and $elapsed -lt 15 -and $visualFrames.Count -lt 20 -and ($elapsed-$lastVisualFrame) -ge 0.35) {
                    $frameName = 'motion-frames/winter-{0:D3}' -f $visualFrames.Count
                    Capture $frameName
                    $visualFrames.Add([ordered]@{file="$frameName.png";start_seconds=$elapsed;end_seconds=$timer.Elapsed.TotalSeconds})
                    $lastVisualFrame = $elapsed
                }
                if ($captureIndex -lt $captureTimes.Count -and $elapsed -ge $captureTimes[$captureIndex]) {
                    Capture "$name-$captureIndex"
                    $captureIndex++
                }
            }
            Start-Sleep -Milliseconds $(if ($Phase -eq 'WinterVisual' -and -not $recordingSupported) {100} else {900})
        }
        if ($Phase -eq 'Baselines') {
            $times = @($stamps | Sort-Object)
            if ($times.Count -lt 2) { throw 'No actual-present frame interval data.' }
            $deltas = @(for ($i=1; $i -lt $times.Count; $i++) { ($times[$i]-$times[$i-1])/1000000.0 }) | Sort-Object
            $span = ($times[-1]-$times[0])/1000000000.0
            $present = [ordered]@{source='SurfaceFlinger actual-present timestamps, deduplicated; startup/warmup and screenshots excluded';layer=$layer;frames=$deltas.Count;seconds=$span;fps=$deltas.Count/$span;median_ms=$deltas[[int][math]::Floor($deltas.Count*0.5)];p95_ms=$deltas[[int][math]::Floor($deltas.Count*0.95)];p99_ms=$deltas[[int][math]::Floor($deltas.Count*0.99)];max_ms=$deltas[-1];over_25_ms=@($deltas | Where-Object { $_ -gt 25 }).Count;over_33_34_ms=@($deltas | Where-Object { $_ -gt 33.34 }).Count}
            $times | Set-Content "$evidence/$name-present-nanoseconds.txt" -Encoding ASCII
            $present.capture_buffer_gaps = $bufferGaps
            $present.valid_contiguous_capture = $bufferGaps -eq 0
            $present | ConvertTo-Json | Set-Content "$evidence/$name-present.json"
            ConvertTo-Json -InputObject @($polls) -Depth 4 | Set-Content "$evidence/$name-present-polls.json"
            Write-Host ($present | ConvertTo-Json -Compress)
        }
        $deadline = (Get-Date).AddSeconds(30)
        do {
            $files = @(Adb @('shell','run-as',$package,'ls','files'))
            if ($files -contains 'mobile_probe_results.json') { break }
            Start-Sleep -Seconds 1
        } while ((Get-Date) -lt $deadline)
        if ($files -notcontains 'mobile_probe_results.json') { throw "$name did not finish." }
        $raw = Adb @('shell','run-as',$package,'cat','files/mobile_probe_results.json')
        $raw | Set-Content "$evidence/$name-probe.json" -Encoding UTF8
        $report = @(($raw -join "`n") | ConvertFrom-Json)[0]
        Write-Host "$name completed: frames=$($report.frames) paused=$($report.paused_frames) driven=$($report.driven_metres)m powder_frames=$($report.snow_powder_frames) bursts=$($report.snow_bank_bursts)"
        Adb @('logcat','-d',"--pid=$appPid",'-v','threadtime') | Set-Content "$evidence/$name-logcat.txt"
        Adb @('shell','dumpsys','battery') | Set-Content "$evidence/$name-battery-after.txt"
        Adb @('shell','dumpsys','thermalservice') | Set-Content "$evidence/$name-thermal-after.txt"
        if ($Phase -eq 'Baselines') {
            # The probe has ended and paused; resume only after timing is complete.
            Adb @('shell','input','keyevent','KEYCODE_ESCAPE') | Out-Null
            Start-Sleep -Seconds 2
            Capture "$name-phone"
        } else {
            if ($recordingSupported) {
                $recording.WaitForExit()
                $recording.Refresh()
                if ($recording.ExitCode -ne 0) { throw "Phone screen recording failed (exit=$($recording.ExitCode)); see winter-recording-stderr.txt." }
                Adb @('pull','/data/local/tmp/biome-phone-winter.mp4',"$evidence/winter-bank-phone.mp4") | Out-Null
                Adb @('shell','rm','-f','/data/local/tmp/biome-phone-winter.mp4') | Out-Null
            } else {
                ConvertTo-Json -InputObject @($visualFrames) -Depth 4 | Set-Content "$evidence/winter-bank-frames.json" -Encoding UTF8
                Write-Host "Recorded $($visualFrames.Count) actual phone frames; capture timestamps retained."
            }
        }
        Adb @('shell','run-as',$package,'rm','-f','files/mobile_probe.json','files/mobile_probe_results.json',$readyPath) | Out-Null
    }
} finally {
    Adb @('shell','am','force-stop',$package) | Out-Null
    Adb @('shell','run-as',$package,'rm','-f','files/mobile_probe.json','files/mobile_probe_results.json',$readyPath) | Out-Null
    foreach ($name in $recordFiles) {
        Adb @('shell','run-as',$package,'cp',"files/diagnostics/biome-phone-before-$name","files/$name") | Out-Null
        Adb @('shell','run-as',$package,'rm','-f',"files/diagnostics/biome-phone-before-$name") | Out-Null
    }
    Adb @('shell','run-as',$package,'sha256sum','files/local_records.json','files/local_records.json.bak') | Set-Content "$evidence/$Phase-record-hashes-restored.txt"
    Adb @('shell','rm','-f','/data/local/tmp/biome-phone-config.json','/data/local/tmp/biome-phone-test.png') | Out-Null
    Adb @('shell','am','start','-W','-a','android.intent.action.MAIN','-c','android.intent.category.LAUNCHER','-p',$package) | Set-Content "$evidence/$Phase-normal-launch.txt"
    Write-Host 'Normal play restored; diagnostic markers removed; original local records/cosmetics restored.'
}
