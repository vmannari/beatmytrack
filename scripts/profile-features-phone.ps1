param([int]$Seconds = 20, [switch]$StormOnly, [switch]$SkipInstall, [switch]$SurfaceProfile, [switch]$GrassProfile, [switch]$DesertProfile, [switch]$DesertCostProfile,
    [switch]$WinterStress, [switch]$WinterProfile, [switch]$HeadlightsProfile, [switch]$Baseline, [ValidatePattern('^[a-zA-Z0-9-]*$')][string]$ReportName = '')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$adb = Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools/adb.exe'
$package = 'org.circuit01.handlinglab'
$evidence = Join-Path $root 'docs/evidence/performance-2026-09-22'
if ($SurfaceProfile) { $evidence = Join-Path $root 'docs/evidence/surface-performance-2026-09-22' }
if ($ReportName) { $evidence = Join-Path $root "docs/evidence/$ReportName" }
New-Item -ItemType Directory -Force -Path $evidence | Out-Null
function Adb([string[]]$Arguments) {
    $result = & $adb @Arguments
    if ($LASTEXITCODE -ne 0) { throw "adb failed: $Arguments" }
    return $result
}
Adb @('devices','-l')
Adb @('shell','getprop','ro.product.model') | Set-Content "$evidence/device.txt"
Adb @('shell','dumpsys','battery') | Set-Content "$evidence/battery-before.txt"
if (-not $SkipInstall) { Adb @('install','-r',"$root/build/android/circuit01-debug.apk") }
Get-FileHash "$root/build/android/circuit01-debug.apk" | Format-List | Out-File "$evidence/apk-hash.txt"
try {
    $profileTracks = @(@('ajorata','track_acf29166cceaaa42'),@('storm','track_f7dc946b49ce9ea8'))
    if ($DesertProfile -or $DesertCostProfile) { $profileTracks = ,@('desert','track_3e26605a8a90165e') }
    if ($HeadlightsProfile) { $profileTracks = ,@('night','track_c7ad183a78f7a033') }
    if ($WinterProfile) { $profileTracks = ,@('winter','track_b5d3f29314a7ae53') }
    foreach ($track in $profileTracks) {
        if ($StormOnly -and $track[0] -ne 'storm') { continue }
        $config = @{track_id=$track[1]; seconds=$Seconds; sustained=$true; use_game_scale=$true; feature_profile=$true; touch_stress=$true; features=@('baseline','telemetry','shadows','particles','trails','hud','weather','half_scale','baseline')}
        if ($SurfaceProfile) { $config.features = @('baseline','asphalt_previous','baseline','directional_off','baseline','road_flat','baseline','terrain_flat','baseline') }
        if ($GrassProfile) { $config.features = @('grass_original','baseline','grass_original','grass_material','baseline','grass_original') }
        if ($DesertProfile) { $config.features = @('desert_original','baseline','desert_original','baseline','desert_original') }
        if ($DesertCostProfile) { $config.features = @('baseline','particles','baseline') }
        if ($HeadlightsProfile) { $config.features = @('headlights','baseline','headlights','baseline') }
        if ($WinterProfile) { $config.features = @('baseline','particles','baseline') }
        if ($WinterStress) { $config.winter_stress = $true; $config.touch_stress = $false }
        if ($Baseline) { $config.features = @('baseline') }
        $stageCount = $config.features.Count
        $config | ConvertTo-Json -Depth 4 | Set-Content "$evidence/$($track[0])-config.json" -Encoding ASCII
        Adb @('shell','am','force-stop',$package)
        Adb @('push',"$evidence/$($track[0])-config.json",'/data/local/tmp/feature-profile.json')
        Adb @('shell','run-as',$package,'cp','/data/local/tmp/feature-profile.json','files/mobile_probe.json')
        Adb @('shell','run-as',$package,'rm','-f','files/mobile_probe_results.json')
        Adb @('shell','input','keyevent','KEYCODE_WAKEUP')
        Adb @('shell','am','start','-W','-a','android.intent.action.MAIN','-c','android.intent.category.LAUNCHER','-p',$package)
        $deadline = (Get-Date).AddSeconds(($Seconds+5)*$stageCount+120)
        $done = 0
        while ((Get-Date) -lt $deadline) {
            Start-Sleep -Seconds 5
            $exists = Adb @('shell','run-as',$package,'ls','files')
            if ($exists -notcontains 'mobile_probe_results.json') { continue }
            $raw = Adb @('shell','run-as',$package,'cat','files/mobile_probe_results.json')
            try { $reports = $raw -join "`n" | ConvertFrom-Json } catch { continue }
            if ($reports.Count -gt $done) {
                $raw | Set-Content "$evidence/$($track[0]).json" -Encoding UTF8
                foreach ($r in $reports | Select-Object -Skip $done) { Write-Host "$($track[0]) $($r.disabled_feature): median=$($r.frame_median_ms) p95=$($r.frame_p95_ms) telemetry=$($r.telemetry_mean_ms)" }
                $done = $reports.Count
            }
            if ($done -eq $stageCount) { break }
        }
        if ($done -ne $stageCount) { throw "Incomplete $($track[0]) profile: $done/$stageCount stages" }
        if ($WinterProfile -or $HeadlightsProfile -or $GrassProfile -or $DesertProfile -or $DesertCostProfile) {
            # All timing windows have ended and the probe restored production materials.
            Adb @('shell','screencap','-p','/data/local/tmp/grass-review.png')
            Adb @('pull','/data/local/tmp/grass-review.png',"$evidence/$($track[0])-phone.png")
            Adb @('shell','rm','-f','/data/local/tmp/grass-review.png')
        }
        Adb @('shell','dumpsys','battery') | Set-Content "$evidence/battery-$($track[0]).txt"
    }
} finally {
    Adb @('shell','am','force-stop',$package)
    Adb @('shell','run-as',$package,'rm','-f','files/mobile_probe.json','files/mobile_probe_results.json')
    Adb @('shell','rm','-f','/data/local/tmp/feature-profile.json')
    Adb @('shell','am','start','-W','-a','android.intent.action.MAIN','-c','android.intent.category.LAUNCHER','-p',$package)
    Write-Host 'Normal play restored; diagnostic marker removed.'
}
