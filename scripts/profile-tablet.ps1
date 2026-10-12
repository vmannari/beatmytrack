[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$DeviceSerial,
    [string]$DocumentPath = '',
    [ValidateRange(10, 180)][int]$Seconds = 12,
    [string[]]$Features = @('baseline', 'half_scale', 'render_40', 'shadows', 'contact_lighting', 'audio', 'baseline'),
    [string]$Output = 'build/tablet-performance-2026-10-08/profile',
    [switch]$BridgeReview,
    [switch]$DustParityReview,
    [ValidateSet('Ground','Deck')][string]$BridgeLayer = 'Ground',
    [ValidateRange(-1,512)][double]$BridgeAlong = -1,
    [string]$RequiredRenderer = '',
    [string]$RequiredDriver = '',
    [switch]$CaptureDriving,
    [ValidateRange(1,60)][double]$CaptureDelaySeconds = 8,
    [switch]$Install
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$adb = Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools/adb.exe'
$package = 'org.circuit01.handlinglab'
$outputRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $Output))
New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
$runId = 'tablet-perf-' + [guid]::NewGuid().ToString('N')
$stageRoot = '/data/local/tmp/' + $runId
$privateRoot = 'files/diagnostics/' + $runId
$markerCreated = $false
$resultsExisted = $false
$Features = @($Features | ForEach-Object { $_ -split ',' })

function Invoke-Tablet([string[]]$Arguments) {
    $result = @(& $adb -s $DeviceSerial @Arguments)
    if ($LASTEXITCODE -ne 0) { throw "ADB command failed: $($Arguments -join ' ')" }
    return $result
}

if ((Invoke-Tablet @('get-state') -join '').Trim() -ne 'device') { throw 'The selected tablet is not authorized.' }
Invoke-Tablet @('shell','getprop','ro.product.model') | Set-Content -LiteralPath (Join-Path $outputRoot 'device.txt') -Encoding utf8
Invoke-Tablet @('shell','input','keyevent','KEYCODE_WAKEUP') | Out-Null
Invoke-Tablet @('shell','wm','dismiss-keyguard') | Out-Null
$keyguard = Invoke-Tablet @('shell','dumpsys','window','policy')
if ($keyguard -match '^\s*mIsShowing=true\s*$') { throw 'Unlock the tablet before profiling. No diagnostic marker or player data was changed.' }

& $adb -s $DeviceSerial shell run-as $package test -f files/mobile_probe.json
if ($LASTEXITCODE -eq 0) { throw 'An existing mobile probe is present. Preserve it; no profiling started.' }
& $adb -s $DeviceSerial shell run-as $package test -f files/mobile_probe_results.json
$resultsExisted = ($LASTEXITCODE -eq 0)
if ($Install) {
    & (Join-Path $PSScriptRoot 'dev.ps1') InstallAndroid -DeviceSerial $DeviceSerial
    if ($LASTEXITCODE -ne 0) { throw 'Debug APK installation failed.' }
}
$config = @{state_path=('user://diagnostics/' + $runId + '/state.json'); bridge_review=[bool]$BridgeReview; dust_parity_review=[bool]$DustParityReview; bridge_upper=($BridgeLayer -eq 'Deck'); bridge_along=$BridgeAlong; seconds=$Seconds; sustained=$true; use_game_scale=$true; feature_profile=$true; touch_stress=$true; features=$Features}
if ($DocumentPath) {
    $documentFile = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $DocumentPath))
    $document = Get-Content -LiteralPath $documentFile -Raw | ConvertFrom-Json
    $config.track_id = $document.id
    $config.document_path = 'user://diagnostics/' + $runId + '/track.json'
}
$config | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $outputRoot 'config.json') -Encoding ASCII
Invoke-Tablet @('shell','dumpsys','battery') | Set-Content -LiteralPath (Join-Path $outputRoot 'battery-before.txt') -Encoding utf8
Invoke-Tablet @('shell','dumpsys','thermalservice') | Set-Content -LiteralPath (Join-Path $outputRoot 'thermal-before.txt') -Encoding utf8
Get-FileHash -LiteralPath (Join-Path $repoRoot 'build/android/circuit01-debug.apk') | Format-List | Out-File -LiteralPath (Join-Path $outputRoot 'apk-hash.txt') -Encoding utf8
try {
    Invoke-Tablet @('shell','am','force-stop',$package) | Out-Null
    Invoke-Tablet @('shell','mkdir','-p',$stageRoot) | Out-Null
    Invoke-Tablet @('shell','run-as',$package,'mkdir','-p',$privateRoot) | Out-Null
    if ($resultsExisted) {
        Invoke-Tablet @('shell','run-as',$package,'cp','files/mobile_probe_results.json',"$privateRoot/results-before.json") | Out-Null
    }
    if ($DocumentPath) {
        Invoke-Tablet @('push',$documentFile,"$stageRoot/track.json") | Out-Null
        Invoke-Tablet @('shell','run-as',$package,'cp',"$stageRoot/track.json","$privateRoot/track.json") | Out-Null
    }
    Invoke-Tablet @('push',(Join-Path $outputRoot 'config.json'),"$stageRoot/probe.json") | Out-Null
    Invoke-Tablet @('shell','run-as',$package,'cp',"$stageRoot/probe.json",'files/mobile_probe.json') | Out-Null
    $markerCreated = $true
    Invoke-Tablet @('shell','run-as',$package,'rm','-f','files/mobile_probe_results.json') | Out-Null
    Invoke-Tablet @('shell','input','keyevent','KEYCODE_WAKEUP') | Out-Null
    Invoke-Tablet @('shell','wm','dismiss-keyguard') | Out-Null
    Invoke-Tablet @('shell','cmd','statusbar','collapse') | Out-Null
    Invoke-Tablet @('shell','am','start','-W','-a','android.intent.action.MAIN','-c','android.intent.category.LAUNCHER','-p',$package) | Out-Null
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    $deadline = ($Seconds + 5) * $Features.Count + 120
    $done = 0
    $lastStageTime = 0.0
    $capturedStages = @{}
    $readyStages = @{}
    while ($timer.Elapsed.TotalSeconds -lt $deadline) {
        Start-Sleep -Seconds 3
        if ($CaptureDriving -and -not $readyStages.ContainsKey($done)) {
            try {
                $stateLines = @(& $adb -s $DeviceSerial shell run-as $package cat "$privateRoot/state.json" 2>$null)
                $state = ConvertFrom-Json -InputObject ($stateLines -join "`n")
                if ($state.ready -and $state.stage -eq $done) { $readyStages[$done] = $timer.Elapsed.TotalSeconds }
            } catch { }
        }
        if ($CaptureDriving -and $readyStages.ContainsKey($done) -and -not $capturedStages.ContainsKey($done) -and $timer.Elapsed.TotalSeconds - $readyStages[$done] -gt $CaptureDelaySeconds) {
            Invoke-Tablet @('shell','screencap','-p',"$stageRoot/driving.png") | Out-Null
            Invoke-Tablet @('pull',"$stageRoot/driving.png",(Join-Path $outputRoot "driving-$done.png")) | Out-Null
            Invoke-Tablet @('shell','rm','-f',"$stageRoot/driving.png") | Out-Null
            $capturedStages[$done] = $true
        }
        $files = Invoke-Tablet @('shell','run-as',$package,'ls','files')
        if ($files -notcontains 'mobile_probe_results.json') { continue }
        $raw = Invoke-Tablet @('shell','run-as',$package,'cat','files/mobile_probe_results.json')
        try { $reports = ConvertFrom-Json -InputObject ($raw -join "`n") } catch { continue }
        $raw | Set-Content -LiteralPath (Join-Path $outputRoot 'results.json') -Encoding utf8
        foreach ($report in $reports | Select-Object -Skip $done) {
            if ($RequiredRenderer -and $report.renderer -ne $RequiredRenderer) { throw "Unexpected renderer: $($report.renderer)." }
            if ($RequiredDriver -and $report.rendering_driver -ne $RequiredDriver) { throw "Unexpected rendering driver: $($report.rendering_driver)." }
            if ($report.PSObject.Properties.Name -contains 'paused_frames' -and $report.paused_frames -gt 0) {
                throw 'The profile was interrupted by pause/background. Retain the report but do not use it as driving performance evidence.'
            }
            if ($report.PSObject.Properties.Name -contains 'scale_actual' -and [math]::Abs($report.scale_actual-$report.scale) -gt 0.00001) {
                throw 'The requested resolution comparison was overridden. Do not use this result as controlled evidence.'
            }
            Write-Host "$($report.disabled_feature): median=$($report.frame_median_ms)ms p95=$($report.frame_p95_ms)ms process=$($report.process_median_ms)ms physics=$($report.physics_median_ms)ms"
        }
        if ($done -ne $reports.Count) { $lastStageTime = $timer.Elapsed.TotalSeconds }
        $done = $reports.Count
        if ($done -eq $Features.Count) { break }
    }
    if ($done -ne $Features.Count) { throw "Incomplete profile: $done/$($Features.Count) stages." }
    Invoke-Tablet @('shell','screencap','-p',"$stageRoot/final.png") | Out-Null
    Invoke-Tablet @('pull',"$stageRoot/final.png",(Join-Path $outputRoot 'final.png')) | Out-Null
    Invoke-Tablet @('shell','dumpsys','battery') | Set-Content -LiteralPath (Join-Path $outputRoot 'battery-after.txt') -Encoding utf8
    Invoke-Tablet @('shell','dumpsys','thermalservice') | Set-Content -LiteralPath (Join-Path $outputRoot 'thermal-after.txt') -Encoding utf8
} finally {
    if ($markerCreated) {
        Invoke-Tablet @('shell','am','force-stop',$package) | Out-Null
        Invoke-Tablet @('shell','run-as',$package,'rm','-f','files/mobile_probe.json','files/mobile_probe_results.json') | Out-Null
        if ($resultsExisted) {
            Invoke-Tablet @('shell','run-as',$package,'mv',"$privateRoot/results-before.json",'files/mobile_probe_results.json') | Out-Null
        }
        Invoke-Tablet @('shell','run-as',$package,'rm','-f',"$privateRoot/track.json","$privateRoot/state.json") | Out-Null
        Invoke-Tablet @('shell','run-as',$package,'rmdir',$privateRoot) | Out-Null
        Invoke-Tablet @('shell','rm','-f',"$stageRoot/track.json","$stageRoot/probe.json","$stageRoot/final.png") | Out-Null
        Invoke-Tablet @('shell','rmdir',$stageRoot) | Out-Null
        Invoke-Tablet @('shell','am','start','-W','-a','android.intent.action.MAIN','-c','android.intent.category.LAUNCHER','-p',$package) | Out-Null
        Write-Host 'Diagnostic files removed; ordinary play restored. Records, sessions and authored tracks preserved.'
    }
}
