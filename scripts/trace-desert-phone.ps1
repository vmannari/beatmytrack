param(
    [string]$DeviceSerial = 'PRQKU4U4PREQNRWG',
    [ValidateSet('Warm','ColdPair')][string]$Mode = 'Warm',
    [ValidatePattern('^[a-z0-9-]+$')][string]$RunName = 'warm-01',
    [ValidateRange(30,90)][int]$Seconds = 60,
    [string[]]$Features = @('baseline'),
    [string]$DocumentFile = '',
    [switch]$NoCpuStacks
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$evidence = Join-Path $root "docs/evidence/desert-hitch-2026-10-13/$RunName"
$rawRoot = Join-Path $root "build/desert-hitch-2026-10-13/$RunName"
$adb = Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools/adb.exe'
$package = 'org.circuit01.handlinglab'
$cacheBackup = "files/diagnostics/desert-hitch-cache-before-$RunName"
$cacheGenerated = "files/diagnostics/desert-hitch-cache-generated-$RunName"
$documentRemote = "files/diagnostics/desert-hitch-document-$RunName.json"
if ($Features.Count -ne 1) { throw 'Use one feature stage per bounded system trace.' }
$traceDurationMs = ($Seconds + 15) * 1000
if ($DocumentFile) {
    $documentSource = (Resolve-Path -LiteralPath $DocumentFile).Path
    if (-not (Test-Path -LiteralPath $documentSource -PathType Leaf)) { throw 'Diagnostic document must be an existing file.' }
}
New-Item -ItemType Directory -Force -Path $evidence,$rawRoot | Out-Null
function Adb([string[]]$Arguments) {
    $result = & $adb -s $DeviceSerial @Arguments
    if ($LASTEXITCODE -ne 0) { throw "adb failed: $Arguments" }
    return $result
}
$lockState = (Adb @('shell','dumpsys','window','policy')) -join "`n"
if ($lockState -match 'mIsShowing=true') { throw 'Phone is locked; physical owner unlock is required before starting a trace.' }
$files = @(Adb @('shell','run-as',$package,'ls','files'))
foreach ($marker in @('mobile_probe.json','mobile_probe_results.json','hitch_ready.json')) {
    if ($files -contains $marker) { throw "Preserve the existing diagnostic $marker before tracing." }
}
$diagnosticFiles = @()
if ($files -contains 'diagnostics') { $diagnosticFiles = @(Adb @('shell','run-as',$package,'ls','files/diagnostics')) }
foreach ($owned in @("desert-hitch-cache-before-$RunName","desert-hitch-cache-generated-$RunName","desert-hitch-record-before-$RunName.json","desert-hitch-record-before-$RunName.bak","desert-hitch-document-$RunName.json")) {
    if ($diagnosticFiles -contains $owned) { throw "Preserve existing task backup $owned before tracing." }
}
$cacheMoved = $false
$savedRecords = @()
$recordNames = @('local_records.json','local_records.json.bak')
$originalRecordNames = @($recordNames | Where-Object { $files -contains $_ })
$documentCopied = $false
try {
    Adb @('shell','am','force-stop',$package) | Out-Null
    Adb @('shell','run-as',$package,'mkdir','-p','files/diagnostics') | Out-Null
    @{existing_record_files=$originalRecordNames;document_supplied=[bool]$DocumentFile} | ConvertTo-Json | Set-Content "$evidence/original-state.json"
    foreach ($recordName in $originalRecordNames) {
        $suffix = if ($recordName -eq 'local_records.json') {'json'} else {'bak'}
        Adb @('shell','run-as',$package,'cp',"files/$recordName","files/diagnostics/desert-hitch-record-before-$RunName.$suffix") | Out-Null
        $savedRecords += @{name=$recordName;backup="files/diagnostics/desert-hitch-record-before-$RunName.$suffix"}
    }
    if ($originalRecordNames.Count -gt 0) {
        Adb (@('shell','run-as',$package,'sha256sum') + @($originalRecordNames | ForEach-Object {"files/$_"})) | Set-Content "$evidence/records-before.txt"
    }
    if ($DocumentFile) {
        Adb @('push',$documentSource,'/data/local/tmp/bmt-hitch-document.json') | Out-Null
        Adb @('shell','run-as',$package,'cp','/data/local/tmp/bmt-hitch-document.json',$documentRemote) | Out-Null
        $documentCopied = $true
        Get-FileHash -LiteralPath $documentSource | Select-Object Hash | ConvertTo-Json | Set-Content "$evidence/document-hash.json"
    }
    $apkPath = ((Adb @('shell','pm','path',$package)) -replace '^package:','').Trim()
    Adb @('shell','sha256sum',$apkPath) | Set-Content "$evidence/installed-apk.txt"
    if ($Mode -eq 'ColdPair') {
        # Exact known app-private paths; original cache is moved, never deleted.
        Adb @('shell','run-as',$package,'du','-s','files/shader_cache') | Set-Content "$evidence/cache-before.txt"
        $cacheHashes = @(Adb @('shell','run-as',$package,'find','files/shader_cache','-type','f','-exec','sha256sum','{}','+') | Sort-Object)
        $cacheHashes | Set-Content "$evidence/cache-hashes-before.txt"
        Adb @('shell','run-as',$package,'mv','files/shader_cache',$cacheBackup) | Out-Null
        $cacheMoved = $true
    }
    $stages = @('warm')
    if ($Mode -eq 'ColdPair') { $stages = @('cold','primed') }
    foreach ($stage in $stages) {
        $traceRemote = "/data/misc/perfetto-traces/bmt-hitch-$RunName-$stage.pftrace"
        $traceFile = "$rawRoot/$stage.pftrace"
        $cpuSource = ''
        if (-not $NoCpuStacks) {
            $cpuSource = @'
data_sources { config {
  name: "linux.perf"
  target_buffer: 0
  perf_event_config {
    timebase { frequency: 99 }
    callstack_sampling {
      scope { target_cmdline: "org.circuit01.handlinglab" }
      kernel_frames: false
    }
  }
} }
'@
        }
        $traceConfig = @"
# Keep metadata/stack intern tables apart from the high-rate kernel stream.
# DISCARD preserves the early race; health checks must confirm neither fills.
buffers { size_kb: 65536 fill_policy: DISCARD }
buffers { size_kb: 262144 fill_policy: DISCARD }
duration_ms: $traceDurationMs
incremental_state_config { clear_period_ms: 5000 }
data_sources { config {
  name: "linux.ftrace"
  target_buffer: 1
  ftrace_config {
    ftrace_events: "sched/sched_switch"
    ftrace_events: "sched/sched_waking"
    ftrace_events: "power/cpu_frequency"
    ftrace_events: "power/cpu_idle"
    ftrace_events: "task/task_newtask"
    ftrace_events: "task/task_rename"
    ftrace_events: "block/block_rq_issue"
    ftrace_events: "block/block_rq_complete"
    atrace_categories: "gfx"
    atrace_categories: "view"
    atrace_categories: "sync"
    atrace_apps: "org.circuit01.handlinglab"
    buffer_size_kb: 4096
    drain_period_ms: 250
  }
} }
data_sources { config {
  name: "linux.process_stats"
  target_buffer: 0
  process_stats_config { scan_all_processes_on_start: true record_thread_names: true }
} }
data_sources { config {
  name: "android.log"
  target_buffer: 0
  android_log_config { min_prio: PRIO_INFO filter_tags: "godot" log_ids: LID_DEFAULT }
} }
data_sources { config { name: "android.surfaceflinger.frametimeline" target_buffer: 0 } }
$cpuSource
"@
        $traceConfig.TrimEnd() | Set-Content "$evidence/$stage-trace.pbtxt" -Encoding ASCII
        $config = @{track_id='track_3e26605a8a90165e';seconds=$Seconds;sustained=$true;use_game_scale=$true;feature_profile=$true;touch_stress=$false;features=$Features;state_path='user://hitch_ready.json'}
        if ($DocumentFile) { $config.document_path = "user://diagnostics/desert-hitch-document-$RunName.json" }
        $config | ConvertTo-Json -Depth 4 | Set-Content "$evidence/$stage-probe-config.json" -Encoding ASCII
        Adb @('shell','am','force-stop',$package) | Out-Null
        Adb @('push',"$evidence/$stage-probe-config.json",'/data/local/tmp/bmt-hitch-probe.json') | Out-Null
        Adb @('push',"$evidence/$stage-trace.pbtxt",'/data/local/tmp/bmt-hitch-trace.pbtxt') | Out-Null
        Adb @('shell','run-as',$package,'cp','/data/local/tmp/bmt-hitch-probe.json','files/mobile_probe.json') | Out-Null
        Adb @('shell','run-as',$package,'rm','-f','files/mobile_probe_results.json','files/hitch_ready.json') | Out-Null
        Adb @('shell','dumpsys','thermalservice') | Set-Content "$evidence/$stage-thermal-before.txt"
        # Perfetto drops privileges; stdin avoids SELinux denying the pushed file.
        Adb @('shell','input','keyevent','KEYCODE_WAKEUP') | Out-Null
        Adb @('shell','wm','dismiss-keyguard') | Out-Null
        Adb @('shell','am','start','-W','-a','android.intent.action.MAIN','-c','android.intent.category.LAUNCHER','-p',$package) | Set-Content "$evidence/$stage-launch.txt"
        $readyDeadline = (Get-Date).AddSeconds(180)
        $readyTimer = [System.Diagnostics.Stopwatch]::StartNew()
        $lastWake = -15.0
        do {
            $files = @(Adb @('shell','run-as',$package,'ls','files'))
            if ($files -contains 'hitch_ready.json') { break }
            if ($readyTimer.Elapsed.TotalSeconds - $lastWake -ge 15) {
                # Normal wake/dismiss only while startup has not set its keep-on flag.
                Adb @('shell','input','keyevent','KEYCODE_WAKEUP') | Out-Null
                Adb @('shell','wm','dismiss-keyguard') | Out-Null
                $lastWake = $readyTimer.Elapsed.TotalSeconds
                Write-Host "$RunName/$stage waiting for race readiness ($([int]$lastWake)s)."
            }
            Start-Sleep -Seconds 1
        } while ((Get-Date) -lt $readyDeadline)
        if ($files -notcontains 'hitch_ready.json') { throw 'Race never reached readiness; system trace not started.' }
        $appPid = (Adb @('shell','pidof',$package)) -join ''
        @{pid=$appPid;phase=$stage;native_stack_scope=$package} | ConvertTo-Json | Set-Content "$evidence/$stage-process.json"
        Adb @('shell',"cat /data/local/tmp/bmt-hitch-trace.pbtxt | perfetto --txt -c - -o $traceRemote --background-wait") | Set-Content "$evidence/$stage-trace-start.txt"
        $traceTimer = [System.Diagnostics.Stopwatch]::StartNew()
        $deadline = (Get-Date).AddSeconds(120)
        $lastProgress = -1
        do {
            $files = @(Adb @('shell','run-as',$package,'ls','files'))
            if ($files -contains 'mobile_probe_results.json') { break }
            $progress = [int][math]::Floor($traceTimer.Elapsed.TotalSeconds/15)
            if ($progress -gt $lastProgress) {
                Write-Host "$RunName/$stage elapsed=$([int]$traceTimer.Elapsed.TotalSeconds)s ready=$($files -contains 'hitch_ready.json')"
                $lastProgress = $progress
            }
            Start-Sleep -Seconds 2
        } while ((Get-Date) -lt $deadline)
        if ($files -notcontains 'mobile_probe_results.json') { throw 'Trace workload did not complete; preserve the trace and check foreground/readiness.' }
        $raw = Adb @('shell','run-as',$package,'cat','files/mobile_probe_results.json')
        $raw | Set-Content "$evidence/$stage-probe.json" -Encoding UTF8
        $reports = @(($raw -join "`n") | ConvertFrom-Json)
        foreach ($report in $reports) { Write-Host "$RunName/$stage $($report.disabled_feature) max=$($report.frame_max_ms)ms p99=$($report.frame_p99_ms)ms paused=$($report.paused_frames) distance=$($report.driven_metres)m" }
        $log = @(Adb @('logcat','-d',"--pid=$appPid",'-v','threadtime'))
        $log | Set-Content "$rawRoot/$stage-logcat.txt" -Encoding UTF8
        $godot = @($log | Where-Object { $_ -match ' [IEW] godot ' })
        $godot | ForEach-Object { $_.TrimEnd() } | Set-Content "$evidence/$stage-godot-log.txt" -Encoding UTF8
        $hitchPaths = @($godot | Select-String 'local_log=user://diagnostics/race_hitches/([^\s]+)' | ForEach-Object { $_.Matches[0].Groups[1].Value } | Select-Object -Unique)
        foreach ($hitchName in $hitchPaths) {
            Adb @('shell','run-as',$package,'cat',"files/diagnostics/race_hitches/$hitchName") | Set-Content "$evidence/$stage-$hitchName" -Encoding UTF8
        }
        Adb @('shell','dumpsys','thermalservice') | Set-Content "$evidence/$stage-thermal-after.txt"
        while ($traceTimer.Elapsed.TotalSeconds -lt ($traceDurationMs/1000 + 3)) { Start-Sleep -Seconds 2 }
        Adb @('pull',$traceRemote,$traceFile) | Out-Null
        Adb @('shell','rm','-f',$traceRemote) | Out-Null
        Get-FileHash $traceFile | Select-Object Hash,Path | ConvertTo-Json | Set-Content "$evidence/$stage-trace-hash.json"
        Write-Host "$RunName/$stage trace saved locally ($((Get-Item $traceFile).Length) bytes)."
    }
} finally {
    Adb @('shell','am','force-stop',$package) | Out-Null
    Adb @('shell','run-as',$package,'rm','-f','files/mobile_probe.json','files/mobile_probe_results.json','files/hitch_ready.json') | Out-Null
    if ($cacheMoved) {
        $currentFiles = @(Adb @('shell','run-as',$package,'ls','files'))
        if ($currentFiles -contains 'shader_cache') {
            Adb @('shell','run-as',$package,'mv','files/shader_cache',$cacheGenerated) | Out-Null
        }
        Adb @('shell','run-as',$package,'mv',$cacheBackup,'files/shader_cache') | Out-Null
        Adb @('shell','run-as',$package,'du','-s','files/shader_cache') | Set-Content "$evidence/cache-restored.txt"
        $restoredCacheHashes = @(Adb @('shell','run-as',$package,'find','files/shader_cache','-type','f','-exec','sha256sum','{}','+') | Sort-Object)
        $restoredCacheHashes | Set-Content "$evidence/cache-hashes-restored.txt"
        if (($cacheHashes -join "`n") -ne ($restoredCacheHashes -join "`n")) { Write-Error 'Restored shader cache hashes differ; preserve all evidence and backups.' -ErrorAction Continue }
    }
    foreach ($record in $savedRecords) {
        Adb @('shell','run-as',$package,'cp',$record.backup,"files/$($record.name)") | Out-Null
        Adb @('shell','run-as',$package,'rm','-f',$record.backup) | Out-Null
    }
    foreach ($recordName in $recordNames) {
        if ($recordName -notin $originalRecordNames) {
            Adb @('shell','run-as',$package,'rm','-f',"files/$recordName") | Out-Null
        }
    }
    if ($originalRecordNames.Count -gt 0) {
        Adb (@('shell','run-as',$package,'sha256sum') + @($originalRecordNames | ForEach-Object {"files/$_"})) | Set-Content "$evidence/records-restored.txt"
    }
    $restoredFiles = @(Adb @('shell','run-as',$package,'ls','files'))
    @{existing_record_files=@($recordNames | Where-Object {$restoredFiles -contains $_})} | ConvertTo-Json | Set-Content "$evidence/restored-state.json"
    if ($documentCopied) { Adb @('shell','run-as',$package,'rm','-f',$documentRemote) | Out-Null }
    Adb @('shell','rm','-f','/data/local/tmp/bmt-hitch-probe.json','/data/local/tmp/bmt-hitch-trace.pbtxt','/data/local/tmp/bmt-hitch-document.json') | Out-Null
    Adb @('shell','am','start','-W','-a','android.intent.action.MAIN','-c','android.intent.category.LAUNCHER','-p',$package) | Set-Content "$evidence/normal-launch.txt"
    Write-Host 'Original records/cache and normal launch restored; private trace files remain local.'
}
