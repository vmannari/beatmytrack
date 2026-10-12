[CmdletBinding()]
param(
    [ValidateSet('BackendDriversFill', 'BackendDriversFleet', 'BackendDriversTick', 'BackendDriversWatch', 'TestCameraModes', 'CaptureCameraModes', 'TestScript', 'CaptureReview', 'CaptureSettings', 'TestReview', 'TestHandbrake', 'CaptureHandbrake', 'BakeStormGlass', 'CapturePause', 'ProfileStormReflections', 'TestRewind', 'CaptureRewind', 'TestRoadCache', 'TestRoadBuild', 'TestShoulders', 'CapturePCAccount', 'BackendTestLifecycle', 'BackendStart', 'BackendStop', 'BackendTest', 'BackendRun', 'BackendWorker', 'BackendMigrate', 'TestMusicExit', 'BuildMusic', 'TestMusic', 'CaptureMusicDrive', 'MusicLab', 'CaptureMusic', 'TestContactShading', 'CaptureContactShading', 'TestTyreEquivalence', 'TestCompilerRaster', 'ProfileTrackLoad', 'ProfileMenus', 'TestMenuLoading', 'ProfileRaceStart', 'CaptureWinter', 'TestHeadlights', 'CaptureHeadlights', 'CaptureWinterBridge', 'CaptureDesertBridge', 'TestControlLayout', 'CaptureControlLayout', 'TestGrass', 'CaptureGrass', 'TestDesert', 'CaptureDesert', 'CaptureCompactDetail', 'CaptureCheckpoints', 'TestSurfaceProfile', 'TestBridgeContacts', 'TestPerformance', 'TestResults', 'CaptureResults', 'TestVehicleBatch', 'TestMobileControls', 'CaptureControls', 'TestStorm', 'CaptureStorm', 'CaptureStormVideo', 'TestIce', 'CaptureObjectModels', 'TestBiomes', 'CaptureBiomes', 'ProfileRoadApproval', 'TestRoadApproval', 'TestSurfaces', 'CaptureSurfaces', 'TestPlacement', 'ProfilePlacementBaseline', 'ProfilePlacement', 'TestStartLine', 'CaptureStartLine', 'ReconcileBackendTracks', 'GenerateBackendStarter', 'GenerateStarter', 'TestEditorRetirement', 'CaptureEditorRetirement', 'TestKart', 'CaptureKart', 'TestSilmukka', 'CaptureShortcutFeedback', 'ReviewRouteValidation', 'TestRouteValidation', 'TestCarBalance', 'TestCars', 'CaptureCars', 'TestSoil', 'CaptureSoil', 'ProfileMinimap', 'TestBridgeHUD', 'CaptureBridgeHUD', 'TestSuspension', 'CaptureSuspension', 'CaptureKerbs', 'TestKerbs', 'TestHandling', 'TestDriving', 'CaptureHandling', 'TestObjects', 'CaptureObjects', 'TestDeleteTracks', 'CaptureDeleteTracks', 'TestHazards', 'CaptureHazards', 'CaptureStyle', 'Doctor', 'Validate', 'TestTracks', 'TestCorpus', 'TestCreator', 'TestApp', 'TestRecords', 'TestCatalog', 'TestMenus', 'TestEditor', 'TestFreeEditor', 'TestPractice', 'CapturePractice', 'TestPieces', 'TestWorkflow', 'ReviewCreator', 'Import', 'CheckScript', 'TestConstruction', 'CaptureConstruction', 'TestRefinement', 'CaptureRefinement', 'TestTyresLoad', 'CaptureTyresLoad', 'CaptureWorkflow', 'CaptureFreeEditor', 'CaptureEditor', 'CaptureApp', 'CaptureMenus', 'Run', 'Editor', 'Capture', 'Snapshot', 'ExportAndroid', 'InstallAndroid', 'LaunchAndroid', 'DeployAndroid', 'DeployAndroidWithTracks')]
    [string]$Action = 'Validate',
    [string]$GodotPath = $env:GODOT_BIN,
    [string]$DeviceSerial = '',
    [string]$AdbPath = $env:ADB_BIN,
    [string]$TracksPath = (Join-Path $env:APPDATA 'Circuit01Lab/tracks'),
    [string]$Track = '',
    [string]$Screen = '',
    [string]$ScriptPath = '',
    [ValidateSet('', 'write-golden', 'local-corpus')]
    [string]$CompilerAudit = '',
    [string]$StyleDocument = '',
    [switch]$Overview,
    [switch]$QuickValidation,
    [switch]$Graphical,
    [switch]$AI,
    [switch]$TestDrivers,
    [switch]$InstantDrivers,
    [string]$DriverPlan = '',
    [int]$DriverCount = 0,
    [int]$DriverSeed = 27,
    [int]$CaptureTick = 0,
    [ValidateRange(1, 7200)]
    [int]$CommandTimeoutSeconds = 300
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$projectRoot = Join-Path $repoRoot 'game'
$buildRoot = Join-Path $repoRoot 'build'
$expectedVersion = (Get-Content -LiteralPath (Join-Path $repoRoot 'godot-version.txt') -Raw).Trim()
$apkPath = Join-Path $buildRoot 'android/circuit01-debug.apk'
$packageId = 'org.circuit01.handlinglab'
$trackArguments = @()
if ($Track) { $trackArguments += "--track=$Track" }
if ($Screen) { $trackArguments += "--screen=$Screen" }
if ($Overview) { $trackArguments += '--overview' }
if ($AI) { $trackArguments += '--ai' }
if ($CaptureTick -gt 0) { $trackArguments += "--capture-tick=$CaptureTick" }
New-Item -ItemType Directory -Path $buildRoot -Force | Out-Null
$commandLogRoot = Join-Path $buildRoot "logs/$Action-$PID"
New-Item -ItemType Directory -Path $commandLogRoot -Force | Out-Null

function Find-Godot {
    if ($GodotPath) {
        if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) { throw "GODOT_BIN / -GodotPath does not exist: $GodotPath" }
        return $GodotPath
    }
    $candidates = @('C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe')
    $found = Get-Command 'Godot_v4.7.2-stable_win64_console.exe', 'godot.exe', 'godot.cmd' -ErrorAction SilentlyContinue
    foreach ($item in $found) { $candidates += $item.Source }
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    throw 'Godot not found. Set GODOT_BIN to the pinned standard console executable, or pass -GodotPath.'
}

function Invoke-Checked([string]$Executable, [string[]]$Arguments, [string]$LogName) {
    # Stream both pipes while bounding noninteractive child execution.
    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = $Executable
    $quoted = foreach ($argument in $Arguments) {
        # Windows CommandLineToArgvW escaping, including trailing backslashes.
        '"' + ([regex]::Replace([regex]::Replace($argument, '(\\*)"', '$1$1\"'), '(\\+)$', '$1$1')) + '"'
    }
    $info.Arguments = $quoted -join ' '
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $info
    $lines = New-Object 'System.Collections.Generic.List[string]'
    $log = New-Object System.IO.StreamWriter((Join-Path $commandLogRoot $LogName), $false, (New-Object System.Text.UTF8Encoding($false)))
    $clock = [System.Diagnostics.Stopwatch]::StartNew()
    $interactive = $Action -in @('Run', 'Editor', 'MusicLab', 'BackendRun', 'BackendWorker')
    try {
        if (-not $process.Start()) { throw 'Child command could not start.' }
        $reads = @($process.StandardOutput.ReadLineAsync(), $process.StandardError.ReadLineAsync())
        $streams = @($process.StandardOutput, $process.StandardError)
        while ($null -ne $reads[0] -or $null -ne $reads[1]) {
            if (-not $interactive -and $clock.Elapsed.TotalSeconds -gt $CommandTimeoutSeconds) {
                # Kill only this spawned tree; never enumerate unrelated engine processes.
                & taskkill.exe /PID $process.Id /T /F 2>&1 | Out-Null
                throw "Command timed out after $CommandTimeoutSeconds seconds; see $commandLogRoot/$LogName."
            }
            for ($index = 0; $index -lt 2; $index++) {
                if ($null -eq $reads[$index] -or -not $reads[$index].IsCompleted) { continue }
                $line = $reads[$index].GetAwaiter().GetResult()
                if ($null -eq $line) { $reads[$index] = $null; continue }
                $lines.Add($line)
                $log.WriteLine($line)
                $log.Flush()
                Write-Host $line
                if (-not $process.HasExited -and $line -match '(?i)SCRIPT ERROR:|(^|\s)ERROR:|Parse Error:') {
                    & taskkill.exe /PID $process.Id /T /F 2>&1 | Out-Null
                }
                $reads[$index] = $streams[$index].ReadLineAsync()
            }
            Start-Sleep -Milliseconds 20
        }
        if ($interactive) { $process.WaitForExit() }
        else {
            $remainingMilliseconds = [Math]::Max(1, [int](($CommandTimeoutSeconds - $clock.Elapsed.TotalSeconds) * 1000))
            if (-not $process.WaitForExit($remainingMilliseconds)) {
                & taskkill.exe /PID $process.Id /T /F 2>&1 | Out-Null
                throw "Command timed out after $CommandTimeoutSeconds seconds; see $commandLogRoot/$LogName."
            }
        }
        $nativeExit = $process.ExitCode
    } finally {
        $log.Dispose()
        $process.Dispose()
    }
    if ($nativeExit -ne 0 -or ($lines -match '(?i)SCRIPT ERROR:|(^|\s)ERROR:|Parse Error:')) {
        throw "Command failed (exit $nativeExit); see $commandLogRoot/$LogName."
    }
}

function Invoke-Validation {
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--editor', '--import') 'import.log'
    if ($QuickValidation) {
        Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_startup_smoke.gd') 'startup.log'
        if (-not (Select-String -LiteralPath (Join-Path $commandLogRoot 'startup.log') -SimpleMatch 'APP_READY' -Quiet)) {
            throw 'Main scene did not emit APP_READY.'
        }
        Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_driving.gd') 'driving-tests.log'
        Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_catalog.gd') 'catalog-tests.log'
        Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_menu_presentation.gd') 'menu-presentation-tests.log'
        Write-Host 'PASS: focused deployment checks (import, startup, driving, catalog, menus). Full regression suite not run by this mode.'
        return
    }
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_script_parse.gd') 'parse-all.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_startup_smoke.gd') 'startup.log'
    if (-not (Select-String -LiteralPath (Join-Path $commandLogRoot 'startup.log') -SimpleMatch 'APP_READY' -Quiet)) {
        throw 'Main scene did not emit APP_READY.'
    }
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_driving.gd') 'driving-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_handling.gd') 'handling-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_launch_start.gd') 'launch-start-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_checkpoint_rules.gd') 'route-validation-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_star_spline_laps.gd') 'star-spline-lap-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_checkpoint_bridge_layers.gd') 'bridge-checkpoint-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_bridge_entry_checkpoints.gd') 'bridge-entry-checkpoint-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_bridge_exit_checkpoints.gd') 'bridge-exit-checkpoint-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_checkpoint_notices.gd') 'checkpoint-notice-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_tracks.gd') 'track-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_extra_tracks.gd') 'extra-track-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_editor_retirement.gd') 'editor-retirement.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/profile_placement.gd') 'placement-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/profile_road_approval.gd') 'road-approval-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_start_line.gd') 'start-line-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_creator.gd') 'creator-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_editor_v2.gd') 'editor-v2-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_free_editor.gd') 'free-editor-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_road_pieces.gd') 'road-pieces-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_spline_road.gd') 'spline-road-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_spline_borders.gd') 'spline-border-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_spline_composition.gd') 'spline-composition-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_spline_joins.gd') 'spline-join-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_editor_practice.gd') 'editor-practice-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_editor_workflow.gd') 'editor-workflow-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/profile_editor_performance.gd') 'editor-performance-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_editor_review_fixes.gd') 'editor-review-fixes.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_construction.gd') 'construction-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_bridge_contacts.gd') 'bridge-contacts-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_bridge_hud.gd') 'bridge-hud-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_creator_refinement.gd') 'refinement-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_tyres_and_load.gd') 'tyres-load-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_tyre_equivalence.gd') 'tyre-equivalence-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_grid_contact_equivalence.gd') 'grid-contact-equivalence-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_pile_contact_equivalence.gd') 'pile-contact-equivalence-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_hazards.gd') 'hazards-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_kerbs.gd') 'kerbs-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_ice.gd') 'ice-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_desert.gd') 'desert-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_storm.gd') 'storm-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_soil.gd') 'soil-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_suspension.gd') 'suspension-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_object_browser.gd') 'object-browser-tests.log'
    if (Test-Path -LiteralPath (Join-Path $projectRoot 'tests/test_app.gd')) {
        Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_app.gd') 'app-tests.log'
    }
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_review_reliability.gd') 'review-reliability-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_records.gd') 'records-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_personal_ghosts.gd') 'personal-ghost-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_camera_modes.gd') 'camera-mode-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_catalog.gd') 'catalog-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_menu_loading.gd') 'menu-loading-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_compiler_raster.gd') 'compiler-raster-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_night_lighting.gd') 'night-lighting-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_track_deletion.gd') 'delete-track-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_menu_presentation.gd') 'menu-presentation-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_kart.gd') 'kart-handling-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_cars.gd') 'car-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_car_balance.gd') 'car-balance.log'
    Write-Host 'PASS: import, all project scripts parsed, main-scene startup and all domain/UI regression tests.'
}

function Get-AndroidPaths {
    $settingsFile = Join-Path $env:APPDATA 'Godot/editor_settings-4.7.tres'
    $settingsText = if (Test-Path -LiteralPath $settingsFile) { Get-Content -LiteralPath $settingsFile -Raw } else { '' }
    $sdk = ''; $jdk = ''
    if ($settingsText -match 'export/android/android_sdk_path\s*=\s*"([^"]*)"') { $sdk = $Matches[1].Replace('\\', '\') }
    if ($settingsText -match 'export/android/java_sdk_path\s*=\s*"([^"]*)"') { $jdk = $Matches[1].Replace('\\', '\') }
    return @{
        Sdk = $sdk
        Jdk = $jdk
        Templates = (Join-Path $env:APPDATA 'Godot/export_templates/4.7.2.stable')
    }
}

function Get-Adb {
    if ($AdbPath) {
        if (-not (Test-Path -LiteralPath $AdbPath -PathType Leaf)) { throw "ADB_BIN / -AdbPath does not exist: $AdbPath" }
        return $AdbPath
    }
    $android = Get-AndroidPaths
    if ($android.Sdk) {
        $configured = Join-Path $android.Sdk 'platform-tools/adb.exe'
        if (Test-Path -LiteralPath $configured -PathType Leaf) { return $configured }
    }
    $command = Get-Command adb.exe -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    throw 'ADB not found. Configure Android SDK Path in Godot 4.7.2 Editor Settings, or pass -AdbPath.'
}

function Test-AndroidTools {
    $android = Get-AndroidPaths
    $missing = @()
    if (-not (Test-Path -LiteralPath (Join-Path $android.Templates 'android_debug.apk'))) { $missing += '4.7.2.stable Android debug export template' }
    if (-not $android.Sdk -or -not (Test-Path -LiteralPath (Join-Path $android.Sdk 'platform-tools/adb.exe'))) { $missing += 'Android SDK with platform-tools/adb.exe in Godot Editor Settings' }
    if (-not $android.Sdk -or -not (Test-Path -LiteralPath (Join-Path $android.Sdk 'build-tools'))) { $missing += 'Android SDK build-tools' }
    if (-not $android.Jdk -or -not (Test-Path -LiteralPath (Join-Path $android.Jdk 'bin/jarsigner.exe'))) { $missing += 'JDK (17 recommended) in Godot Editor Settings' }
    Write-Host "Android template directory: $($android.Templates)"
    if ($missing.Count) { throw "Android prerequisites missing: $($missing -join '; '). See docs/ANDROID.md. No APK or device test produced." }
}

function Get-SelectedDevice([string]$AdbExecutable) {
    $savedPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& $AdbExecutable devices 2>&1 | ForEach-Object { "$_" })
        $nativeExit = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $savedPreference
    }
    if ($nativeExit -ne 0) { throw "adb devices failed: $($output -join ' ')" }
    $available = @($output | Where-Object { $_ -match '^\S+\s+device$' } | ForEach-Object { ($_ -split '\s+')[0] })
    if ($DeviceSerial) {
        if ($available -notcontains $DeviceSerial) { throw "Device '$DeviceSerial' is not authorized/online. Unlock the phone and accept its USB debugging prompt." }
        return $DeviceSerial
    }
    if ($available.Count -ne 1) { throw "Expected one authorized device; found $($available.Count). Connect a phone, or specify -DeviceSerial. adb output: $($output -join ' ')" }
    return $available[0]
}

function Prepare-AndroidGradle {
    # Reproduce the pinned engine's Project > Install Android Build Template,
    # then attach the project's original development-only Java bridge.
    $android = Get-AndroidPaths
    $source = Join-Path $android.Templates 'android_source.zip'
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        $source = Join-Path $repoRoot '.tools/admob/android_source.zip'
    }
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw 'Matching Godot 4.7.2 android_source.zip is required for AdMob. See docs/ADMOB_DEVELOPMENT.md.'
    }
    $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
    if ($sourceHash -ne 'A15416B528EFB0A19A7D187E4D9F4E5336D0689144B111329FB4BD12C4447AD3') {
        throw 'Android Gradle source does not match the pinned official Godot 4.7.2 template.'
    }
    $androidRoot = Join-Path $projectRoot 'android'
    $gradleRoot = Join-Path $androidRoot 'build'
    $versionFile = Join-Path $androidRoot '.build_version'
    $templateVersion = $expectedVersion -replace '\.official\..+$', ''
    if (Test-Path -LiteralPath (Join-Path $gradleRoot 'gradlew.bat')) {
        if (-not (Test-Path -LiteralPath $versionFile) -or (Get-Content -LiteralPath $versionFile -Raw).Trim() -ne $templateVersion) {
            throw 'Existing Android Gradle directory has a different/missing version. Preserve it and install the matching template before exporting.'
        }
    } else {
        if ((Test-Path -LiteralPath $gradleRoot) -and @(Get-ChildItem -LiteralPath $gradleRoot -Force).Count -gt 0) {
            throw 'Android Gradle directory is incomplete; preserve/review its contents before reinstalling the template.'
        }
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        New-Item -ItemType Directory -Path $gradleRoot -Force | Out-Null
        [System.IO.Compression.ZipFile]::ExtractToDirectory($source, $gradleRoot)
        [System.IO.File]::WriteAllText($versionFile, $templateVersion + "`n", (New-Object System.Text.UTF8Encoding($false)))
        [System.IO.File]::WriteAllText((Join-Path $gradleRoot '.gdignore'), "`n")
    }
    $gradleFile = Join-Path $gradleRoot 'build.gradle'
    $hook = "apply from: '../../../native/admob/android.gradle'"
    $gradleText = Get-Content -LiteralPath $gradleFile -Raw
    if (-not $gradleText.Contains($hook)) {
        [System.IO.File]::AppendAllText($gradleFile, "`n" + $hook + "`n", (New-Object System.Text.UTF8Encoding($false)))
    }
    # A persistent Gradle daemon inherits the Godot console wrapper's pipe.
    # Finish this build's own Gradle process so command completion is reliable.
    $propertiesFile = Join-Path $gradleRoot 'gradle.properties'
    $propertiesText = Get-Content -LiteralPath $propertiesFile -Raw
    if ($propertiesText -notmatch '(?m)^org\.gradle\.daemon=false\s*$') {
        [System.IO.File]::AppendAllText($propertiesFile, "`norg.gradle.daemon=false`n", (New-Object System.Text.UTF8Encoding($false)))
    }
    Write-Host "Android Gradle template: $templateVersion; AdMob debug bridge attached."
}

function Export-Android {
    Test-AndroidTools
    Prepare-AndroidGradle
    Invoke-Validation
    New-Item -ItemType Directory -Path (Split-Path -Parent $apkPath) -Force | Out-Null
    # Export to a fresh name so a failed build can never deploy a stale APK.
    $freshApk = Join-Path (Split-Path -Parent $apkPath) ('circuit01-' + [guid]::NewGuid().ToString('N') + '.apk')
    $savedJavaOptions = $env:JAVA_TOOL_OPTIONS
    try {
        # Java's bundled CA list can differ from Windows. Keep verified HTTPS
        # downloads and respect a caller's explicit custom trust-store setting.
        if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT -and [string]$savedJavaOptions -notmatch 'javax\.net\.ssl\.trustStore') {
            $env:JAVA_TOOL_OPTIONS = ([string]$savedJavaOptions + ' -Djavax.net.ssl.trustStoreType=Windows-ROOT -Djavax.net.ssl.trustStore=NONE').Trim()
        }
        Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--export-debug', 'Android Debug', $freshApk) 'android-export.log'
    } finally {
        $env:JAVA_TOOL_OPTIONS = $savedJavaOptions
    }
    if (-not (Test-Path -LiteralPath $freshApk -PathType Leaf)) { throw 'Export returned without an APK.' }
    Move-Item -LiteralPath $freshApk -Destination $apkPath -Force
    Write-Host "APK: $apkPath"
}

function Install-Android {
    if (-not (Test-Path -LiteralPath $apkPath -PathType Leaf)) { throw 'No debug APK. Run ExportAndroid first.' }
    $adb = Get-Adb
    $serial = Get-SelectedDevice $adb
    Invoke-Checked $adb @('-s', $serial, 'install', '-r', $apkPath) 'adb-install.log'
}

function Launch-Android {
    $adb = Get-Adb
    $serial = Get-SelectedDevice $adb
    Invoke-Checked $adb @('-s', $serial, 'shell', 'am', 'start', '-W', '-a', 'android.intent.action.MAIN', '-c', 'android.intent.category.LAUNCHER', '-p', $packageId) 'adb-launch.log'
}

function Deploy-AndroidWithTracks {
    # Freeze validated saved documents before building. Never upload editor autosaves.
    if (-not (Test-Path -LiteralPath $TracksPath -PathType Container)) { throw "PC track directory not found: $TracksPath" }
    $sources = @(Get-ChildItem -LiteralPath $TracksPath -File -Filter '*.json' | Sort-Object Name)
    if ($sources.Count -eq 0) { throw "No saved tracks found in $TracksPath. Nothing deployed." }
    foreach ($source in $sources) {
        $doc = Get-Content -LiteralPath $source.FullName -Raw | ConvertFrom-Json
        if ($source.BaseName -cnotmatch '^track_[0-9a-f]{16}$' -or $doc.id -cne $source.BaseName) {
            throw "Track filename/id mismatch: $($source.FullName)"
        }
    }
    $adb = Get-Adb
    $script:DeviceSerial = Get-SelectedDevice $adb
    $runId = [guid]::NewGuid().ToString('N')
    $snapshot = Join-Path $buildRoot "track-sync/$runId"
    New-Item -ItemType Directory -Path $snapshot -Force | Out-Null
    foreach ($source in $sources) { Copy-Item -LiteralPath $source.FullName -Destination $snapshot }
    Export-Android
    Install-Android
    $remote = "/data/local/tmp/circuit-tracks-$runId"
    $backup = "files/track_sync_backups/$runId"
    function Invoke-TrackAdb([string[]]$Arguments) {
        $savedPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            $result = @(& $adb -s $script:DeviceSerial @Arguments 2>&1 | ForEach-Object { "$_" })
            $nativeExit = $LASTEXITCODE
        } finally { $ErrorActionPreference = $savedPreference }
        if ($nativeExit -ne 0) { throw "Track sync ADB command failed: $($result -join ' ')" }
        return $result
    }
    $manifest = @()
    try {
        Invoke-TrackAdb @('shell','am','force-stop',$packageId) | Out-Null
        Invoke-TrackAdb @('shell','mkdir','-p',$remote) | Out-Null
        Invoke-TrackAdb @('shell','run-as',$packageId,'mkdir','-p','files/tracks',$backup) | Out-Null
        $existing = @(Invoke-TrackAdb @('shell','run-as',$packageId,'ls','files/tracks'))
        foreach ($source in $sources) {
            $local = Join-Path $snapshot $source.Name
            $hash = (Get-FileHash -LiteralPath $local -Algorithm SHA256).Hash.ToLowerInvariant()
            $destination = "files/tracks/$($source.Name)"
            $staging = "$remote/$($source.Name)"
            Invoke-TrackAdb @('push',$local,$staging) | Out-Null
            Invoke-TrackAdb @('shell','run-as',$packageId,'cp',$staging,"$destination.sync-$runId") | Out-Null
            $sum = (Invoke-TrackAdb @('shell','run-as',$packageId,'sha256sum',"$destination.sync-$runId")) -join ''
            if (($sum -split '\s+')[0] -cne $hash) { throw "Upload verification failed: $($source.Name)" }
            $replaced = $existing -contains $source.Name
            if ($replaced) { Invoke-TrackAdb @('shell','run-as',$packageId,'cp',$destination,"$backup/$($source.Name)") | Out-Null }
            Invoke-TrackAdb @('shell','run-as',$packageId,'mv',"$destination.sync-$runId",$destination) | Out-Null
            $sum = (Invoke-TrackAdb @('shell','run-as',$packageId,'sha256sum',$destination)) -join ''
            if (($sum -split '\s+')[0] -cne $hash) { throw "Installed track verification failed: $($source.Name)" }
            $manifest += [pscustomobject]@{ file=$source.Name; sha256=$hash; replaced=$replaced; phone_backup=if ($replaced) { "$backup/$($source.Name)" } else { $null } }
            $manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $snapshot 'manifest.json') -Encoding UTF8
            Write-Host "Verified track: $($source.Name)"
        }
    } finally {
        # Exact generated staging paths only; no recursive removal or player-data deletion.
        foreach ($source in $sources) {
            & $adb -s $script:DeviceSerial shell rm -f "$remote/$($source.Name)" | Out-Null
            & $adb -s $script:DeviceSerial shell run-as $packageId rm -f "files/tracks/$($source.Name).sync-$runId" | Out-Null
        }
        & $adb -s $script:DeviceSerial shell rmdir $remote | Out-Null
    }
    Launch-Android
    Write-Host "PASS: deployed game and verified $($manifest.Count) saved tracks. Phone-only tracks preserved."
    Write-Host "Snapshot/manifest: $snapshot"
    Write-Host "Replaced phone tracks backed up under: $backup"
}

try {
    $script:godot = Find-Godot
    $version = (@(& $script:godot --version 2>&1 | ForEach-Object { "$_" }) -join "`n").Trim()
    if ($LASTEXITCODE -ne 0 -or $version -ne $expectedVersion) { throw "Engine mismatch: expected $expectedVersion; got '$version' from $script:godot." }
    Write-Host "Godot: $version ($script:godot)"
    if ($Action.StartsWith('Backend')) {
        $backendPython = Join-Path $repoRoot '.tools/backend-venv/Scripts/python.exe'
        if (-not (Test-Path -LiteralPath $backendPython)) {
            throw 'Set up .tools/backend-venv using backend/README.md first.'
        }
        $env:BMT_GODOT_BIN = $script:godot
        $env:BMT_GAME_PROJECT = $projectRoot
        if ($Action.StartsWith('BackendDrivers')) {
            if (-not $DriverPlan) { throw 'Pass -DriverPlan with a persistent JSON state path.' }
            # Read the existing private operator configuration without printing it.
            $driverEnvPath = Join-Path $repoRoot '.tools/bmt-pc.env'
            if (-not $env:BMT_DEV_AUTH_KEY -and (Test-Path -LiteralPath $driverEnvPath)) {
                foreach ($driverLine in Get-Content -LiteralPath $driverEnvPath) {
                    if ($driverLine.StartsWith('BMT_DEV_AUTH_KEY=')) { $env:BMT_DEV_AUTH_KEY = $driverLine.Substring(17) }
                }
            }
            $driverCommand = $Action.Substring('BackendDrivers'.Length).ToLowerInvariant()
            $driverArguments = @('-m','bmt_backend.test_population_tool',$driverCommand,'--state',$DriverPlan,'--seed',[string]$DriverSeed)
            if ($DriverCount -gt 0) { $driverArguments += @('--count',[string]$DriverCount) }
            if ($InstantDrivers) { $driverArguments += '--instant' }
            & $backendPython @driverArguments
            if ($LASTEXITCODE -ne 0) { throw 'Test-driver tool failed. The saved plan can be resumed.' }
            return
        }
        switch ($Action) {
            'BackendStart' {
                $startArguments = @((Join-Path $repoRoot 'backend/deploy/pc_development.py'), 'start')
                if ($TestDrivers) { $startArguments += '--test-drivers' }
                & $backendPython @startArguments
            }
            'BackendStop' { & $backendPython (Join-Path $repoRoot 'backend/deploy/pc_development.py') stop }
            'BackendTestLifecycle' { & $backendPython -m pytest (Join-Path $repoRoot 'backend/tests/test_cloud_client.py') -q }
            'BackendTest' {
                & $backendPython -m pytest (Join-Path $repoRoot 'backend/tests') -q
            }
            'BackendRun' {
                & $backendPython -m uvicorn bmt_backend.app:create_app --factory --host 127.0.0.1 --port 8080 --no-access-log --no-proxy-headers
            }
            'BackendWorker' { & $backendPython -m bmt_backend.worker }
            'BackendMigrate' { & $backendPython -m bmt_backend.migrate }
        }
        if ($LASTEXITCODE -ne 0) { throw "Backend action failed: $Action (exit $LASTEXITCODE)" }
        return
    }
    switch ($Action) {
        'ReconcileBackendTracks' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/reconcile_backend_tracks.gd') 'backend-track-reconciliation.log' }
        'GenerateBackendStarter' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/export_backend_starter.gd') 'backend-starter-export.log' }
        'CaptureReview' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/capture_review_reliability.gd') 'review-capture.log' }
        'CapturePCAccount' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/test_pc_account.gd') 'pc-account-tests.log' }
        'CaptureCompactDetail' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/capture_compact_detail.gd') 'compact-detail-capture.log' }
        'TestVehicleBatch' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/test_vehicle_batch.gd') 'vehicle-batch-tests.log' }
        'TestControlLayout' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_control_layout.gd') 'control-layout-tests.log' }
        'CaptureControlLayout' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/test_control_layout.gd') 'control-layout-capture.log' }
        'TestMobileControls' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_mobile_controls.gd') 'mobile-controls-tests.log' }
        'TestBridgeContacts' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_bridge_contacts.gd') 'bridge-contacts-tests.log' }
        'TestSuspension' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_suspension.gd') 'suspension-tests.log' }
        'TestPerformance' {
            Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_impact_cracks.gd') 'impact-cracks-tests.log'
            Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/test_performance.gd') 'performance-tests.log'
        }
        'TestSoil' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_soil.gd') 'soil-tests.log' }
        'CaptureSoil' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/test_soil.gd', '--', '--capture') 'soil-capture.log' }
        'CaptureSuspension' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/test_suspension.gd', '--', '--capture') 'suspension-capture.log' }
        'TestHandling' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_handling.gd') 'handling-tests.log' }
        'CaptureKerbs' {
            $evidencePath = Join-Path $buildRoot 'kerbs'
            New-Item -ItemType Directory -Path $evidencePath -Force | Out-Null
            Invoke-Checked $script:godot @('--fixed-fps', '60', '--path', $projectRoot, '--script', 'res://tests/test_kerbs.gd', '--', "--capture-kerbs=$evidencePath") 'kerbs-capture.log'
        }
        'TestKerbs' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_kerbs.gd') 'kerbs-tests.log' }
        'TestCarBalance' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_car_balance.gd') 'car-balance.log' }
        'TestKart' {
            Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_kart.gd') 'kart-handling-tests.log'
            Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_cars.gd', '--', '--car=kart') 'kart-replay-tests.log'
        }
        'CaptureKart' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/capture_cars.gd', '--', '--car=kart') 'kart-captures.log' }
        'TestCars' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_cars.gd') 'car-tests.log' }
        'CaptureCars' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/capture_cars.gd') 'car-captures.log' }
        'TestDriving' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_driving.gd') 'driving-tests.log' }
        'CaptureHandling' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/capture_handling.gd') 'handling-capture.log' }
        'TestTyreEquivalence' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_tyre_equivalence.gd') 'tyre-equivalence-tests.log' }
        'TestTyresLoad' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_tyres_and_load.gd') 'tyres-load-tests.log' }
        'CaptureTyresLoad' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/test_tyres_and_load.gd', '--', '--capture') 'tyres-load-capture.log' }
        'TestDeleteTracks' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_track_deletion.gd') 'delete-track-tests.log' }
        'CaptureDeleteTracks' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/test_track_deletion.gd', '--', '--capture-delete') 'delete-track-capture.log' }
        'TestObjects' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_object_browser.gd') 'object-browser-tests.log' }
        'CaptureObjects' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/test_object_browser.gd', '--', '--capture-objects') 'object-browser-capture.log' }
        'TestHazards' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_hazards.gd') 'hazards-tests.log' }
        'CaptureHazards' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/test_hazards.gd', '--', '--capture-hazards') 'hazards-capture.log' }
        'TestRefinement' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_creator_refinement.gd') 'refinement-tests.log' }
        'CaptureRefinement' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/test_creator_refinement.gd', '--', '--capture-refinement') 'refinement-capture.log' }
        'GenerateStarter' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/generate_starter.gd') 'starter-generation.log' }
        'TestEditorRetirement' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_editor_retirement.gd') 'editor-retirement.log' }
        'CaptureEditorRetirement' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/test_editor_retirement.gd', '--', '--capture') 'editor-retirement-capture.log' }
        'ProfilePlacementBaseline' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/profile_placement.gd', '--', '--baseline') 'placement-baseline.log' }
        'TestPlacement' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/profile_placement.gd') 'placement-tests.log' }
        'ProfileRoadApproval' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/profile_road_approval.gd') 'road-approval-profile.log' }
        'TestRoadApproval' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/profile_road_approval.gd') 'road-approval-tests.log' }
        'ProfilePlacement' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/profile_placement.gd') 'placement-profile.log' }
        'TestSurfaces' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_surface_modes.gd') 'surface-modes-tests.log' }
        'CaptureSurfaces' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/test_surface_modes.gd', '--', '--capture') 'surface-modes-capture.log' }
        'TestStartLine' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_start_line.gd') 'start-line-tests.log' }
        'CaptureStartLine' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/test_start_line.gd', '--', '--capture') 'start-line-capture.log' }
        'CaptureObjectModels' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/capture_object_models.gd') 'object-models-capture.log' }
        'TestStorm' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_storm.gd') 'storm-tests.log' }
        'CaptureStormVideo' { Invoke-Checked $script:godot @('--path', $projectRoot, '--fixed-fps', '30', '--write-movie', (Join-Path $buildRoot 'storm-weather.avi'), '--script', 'res://tests/test_storm.gd', '--', '--video') 'storm-video.log' }
        'CaptureStorm' { Invoke-Checked $script:godot (@('--path', $projectRoot, '--script', 'res://tests/test_storm.gd', '--', '--capture') + $trackArguments) 'storm-capture.log' }
        'TestContactShading' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_contact_shading.gd') 'contact-shading-tests.log' }
        'CaptureContactShading' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/test_contact_shading.gd') 'contact-shading-capture.log' }
        'CaptureWinter' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/capture_winter.gd') 'winter-capture.log' }
        'TestIce' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_ice.gd') 'ice-tests.log' }
        'TestGrass' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_grass.gd') 'grass-tests.log' }
        'CaptureGrass' { Invoke-Checked $script:godot (@('--path', $projectRoot, '--script', 'res://tests/test_grass.gd', '--', '--capture') + $trackArguments) 'grass-capture.log' }
        'TestDesert' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_desert.gd') 'desert-tests.log' }
        'CaptureDesertBridge' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/capture_desert_bridge.gd') 'desert-bridge-capture.log' }
        'CaptureWinterBridge' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/capture_winter_bridge.gd') 'winter-bridge-capture.log' }
        'CaptureDesert' { Invoke-Checked $script:godot (@('--path', $projectRoot, '--script', 'res://tests/test_desert.gd', '--', '--capture') + $trackArguments) 'desert-capture.log' }
        'TestBiomes' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_biomes.gd') 'biomes-test.log' }
        'CaptureBiomes' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/test_biomes.gd', '--', '--capture') 'biomes-capture.log' }
        'TestHandbrake' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_handbrake.gd') 'handbrake-tests.log' }
        'CaptureHandbrake' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/capture_handbrake.gd') 'handbrake-capture.log' }
        'TestCameraModes' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_camera_modes.gd') 'camera-mode-tests.log' }
        'CaptureCameraModes' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/capture_camera_modes.gd') 'camera-mode-capture.log' }
        'CaptureControls' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/capture_controls.gd') 'controls-capture.log' }
        'TestResults' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_race_results.gd') 'results-tests.log' }
        'CaptureResults' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/test_race_results.gd', '--', '--capture') 'results-capture.log' }
        'BakeStormGlass' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/bake_storm_glass.gd') 'storm-glass-bake.log' }
        'ProfileStormReflections' { Invoke-Checked $script:godot (@('--path', $projectRoot, '--script', 'res://tests/profile_storm_reflections.gd', '--') + $trackArguments) 'storm-reflection-profile.log' }
        'TestSurfaceProfile' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/test_surface_profile.gd', '--', "--fixture-directory=$TracksPath") 'surface-profile-tests.log' }
        'CaptureCheckpoints' { Invoke-Checked $script:godot (@('--path', $projectRoot, '--script', 'res://tests/capture_checkpoints.gd', '--') + $trackArguments) 'checkpoint-capture.log' }
        'TestHeadlights' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_headlights.gd') 'headlights-tests.log' }
        'CaptureHeadlights' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/test_headlights.gd', '--', '--capture') 'headlights-capture.log' }
        { $_ -in @('CaptureMusicDrive','BuildMusic','TestMusicExit','TestMusic','MusicLab','CaptureMusic') } {
            throw 'The owner retired this soundtrack. Source is in archive/retired-soundtrack-2026-10-06; use TestScript -ScriptPath res://tests/test_vehicle_audio.gd for the replacement.'
        }
        'TestRoadCache' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_road_cache.gd') 'road-cache-tests.log' }
        'TestRoadBuild' { Invoke-Checked $script:godot (@('--headless', '--path', $projectRoot, '--script', 'res://tests/test_road_build.gd', '--') + $trackArguments) 'road-build-tests.log' }
        'TestShoulders' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_shoulders.gd') 'shoulder-tests.log' }
        'CheckScript' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--check-only', '--script', $ScriptPath, '--verbose') 'parse.log' }
        'TestScript' {
            if (-not $ScriptPath.StartsWith('res://tests/')) { throw 'TestScript requires a res://tests/ GDScript path.' }
            $testRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot 'tests')) + [System.IO.Path]::DirectorySeparatorChar
            $testPath = [System.IO.Path]::GetFullPath((Join-Path $projectRoot $ScriptPath.Substring(6)))
            if (-not $testPath.StartsWith($testRoot, [System.StringComparison]::OrdinalIgnoreCase) -or [System.IO.Path]::GetExtension($testPath) -ne '.gd' -or -not (Test-Path -LiteralPath $testPath -PathType Leaf)) {
                throw 'TestScript must resolve to an existing GDScript inside game/tests.'
            }
            $testArguments = @('--path', $projectRoot, '--script', $testPath)
            if (-not $Graphical) { $testArguments = @('--headless') + $testArguments }
            Invoke-Checked $script:godot $testArguments 'test-script.log'
        }
        'Import' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--editor', '--import') 'import.log' }
        'TestConstruction' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_construction.gd') 'construction-tests.log' }
        'CaptureConstruction' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/test_construction.gd', '--', '--capture-construction') 'construction-capture.log' }
        'ReviewCreator' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/review_creator_usability.gd') 'creator-usability-review.log' }
        'CapturePause' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/test_pause_menu.gd') 'pause-menu-tests.log' }
        'TestRewind' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_rewind.gd') 'rewind-tests.log' }
        'CaptureRewind' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/test_rewind.gd', '--', "--capture-rewind=$buildRoot/rewind.png") 'rewind-capture.log' }
        'TestPractice' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_editor_practice.gd') 'editor-practice-tests.log' }
        'CapturePractice' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/test_editor_practice.gd', '--', "--capture-practice=$buildRoot/editor-practice.png") 'editor-practice-capture.log' }
        'TestPieces' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_road_pieces.gd') 'road-pieces-tests.log' }
        'TestWorkflow' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_editor_workflow.gd') 'editor-workflow-tests.log' }
        'CaptureWorkflow' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/test_editor_workflow.gd', '--', '--capture-workflow') 'editor-workflow-capture.log' }
        'Doctor' {
            Test-AndroidTools
            $adb = Get-Adb
            Invoke-Checked $adb @('devices', '-l') 'adb-devices.log'
            Write-Host 'Tool prerequisites found. Device list is not proof of physical-phone acceptance.'
        }
        'Validate' { Invoke-Validation }
        'CaptureShortcutFeedback' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/capture_shortcut_feedback.gd') 'shortcut-hud-tests.log' }
        'ReviewRouteValidation' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/review_route_validation.gd') 'route-owner-review.log' }
        'TestSilmukka' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_silmukka.gd') 'silmukka-tests.log' }
        'TestRouteValidation' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_checkpoint_rules.gd') 'route-validation-tests.log' }
        'TestTracks' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_tracks.gd') 'track-tests.log' }
        'TestCreator' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_creator.gd') 'creator-tests.log' }
        'TestEditor' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_editor_v2.gd') 'editor-v2-tests.log' }
        'TestFreeEditor' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_free_editor.gd') 'free-editor-tests.log' }
        'CaptureFreeEditor' {
            $evidencePath = Join-Path $buildRoot 'free-editor-evidence'
            New-Item -ItemType Directory -Path $evidencePath -Force | Out-Null
            Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/test_free_editor.gd', '--', "--capture-free-editor=$evidencePath") 'free-editor-capture.log'
        }
        'CaptureEditor' {
            $evidencePath = Join-Path $buildRoot 'editor-v2-evidence'
            New-Item -ItemType Directory -Path $evidencePath -Force | Out-Null
            Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/test_editor_v2.gd', '--', "--capture-editor=$evidencePath") 'editor-v2-capture.log'
        }
        'TestReview' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_review_reliability.gd') 'review-reliability-tests.log' }
        'TestApp' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_app.gd') 'app-tests.log' }
        'TestRecords' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_records.gd') 'records-tests.log' }
        'TestMenus' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_menu_presentation.gd') 'menu-presentation-tests.log' }
        'TestCatalog' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_catalog.gd') 'catalog-tests.log' }
        'TestCorpus' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_bulk_tracks.gd') 'bulk-track-tests.log' }
        'CaptureApp' {
            $evidencePath = Join-Path $buildRoot 'app-evidence'
            New-Item -ItemType Directory -Path $evidencePath -Force | Out-Null
            Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/test_app.gd', '--', "--capture-app-flow=$evidencePath") 'app-capture.log'
        }
        'CaptureSettings' {
            $evidencePath = Join-Path $buildRoot 'settings'
            New-Item -ItemType Directory -Path $evidencePath -Force | Out-Null
            Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/capture_settings.gd', '--', "--capture-settings=$evidencePath") 'settings-capture.log'
        }
        'CaptureMenus' {
            $evidencePath = Join-Path $buildRoot 'premium-menus'
            New-Item -ItemType Directory -Path $evidencePath -Force | Out-Null
            Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/capture_premium_menus.gd', '--', "--capture-menus=$evidencePath") 'premium-menus-capture.log'
        }
        'ProfileMinimap' {
            $baseline = @(& git -C $repoRoot show 'c647398:game/ui/hud_road_map.gd')
            if ($LASTEXITCODE -ne 0) { throw 'Cannot read minimap baseline c647398.' }
            [System.IO.File]::WriteAllText((Join-Path $buildRoot 'minimap-before.gd'), (($baseline -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding($false)))
            Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/profile_minimap.gd', '--', "--document=$StyleDocument") 'minimap-profile.log'
        }
        'TestBridgeHUD' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_bridge_hud.gd') 'bridge-hud-tests.log' }
        'CaptureBridgeHUD' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/test_bridge_hud.gd', '--', '--capture-bridge-hud') 'bridge-hud-capture.log' }
        'CaptureStyle' {
            Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/capture_style.gd', '--', "--style-document=$StyleDocument", "--style-output=$(Join-Path $buildRoot 'style-roadside.png')") 'style-capture.log'
        }
        'Snapshot' {
            $captureName = if ($Track) { $Track } elseif ($Screen) { "menu-$Screen" } else { 'menu-play' }
            Invoke-Checked $script:godot (@('--path', $projectRoot, '--', "--capture=$(Join-Path $buildRoot "$captureName.png")") + $trackArguments) 'capture.log'
            if (-not (Select-String -LiteralPath (Join-Path $commandLogRoot 'capture.log') -SimpleMatch 'CAPTURE_SAVED:' -Quiet)) { throw 'Window closed before capture completed; do not use an older PNG. Keep delayed captures focused.' }
        }
        'TestCompilerRaster' {
            $rasterArgs = @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_compiler_raster.gd')
            if ($CompilerAudit) { $rasterArgs += @('--', "--$CompilerAudit") }
            Invoke-Checked $script:godot $rasterArgs 'compiler-raster-tests.log'
        }
        'ProfileTrackLoad' { Invoke-Checked $script:godot (@('--path', $projectRoot, '--script', 'res://tests/profile_track_load.gd', '--') + $trackArguments) 'track-load-profile.log' }
        'ProfileMenus' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/profile_menu_selection.gd') 'menu-selection-profile.log' }
        'TestMenuLoading' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_menu_loading.gd') 'menu-loading-tests.log' }
        'ProfileRaceStart' { Invoke-Checked $script:godot (@('--path', $projectRoot, '--script', 'res://tests/profile_race_start.gd', '--') + $trackArguments) 'race-start-profile.log' }
        'Run' { Invoke-Checked $script:godot (@('--path', $projectRoot, '--') + $trackArguments) 'run.log' }
        'Editor' { Invoke-Checked $script:godot @('--path', $projectRoot, '--editor') 'editor.log' }
        'Capture' {
            Invoke-Validation
            $captureName = if ($Track) { $Track } elseif ($Screen) { "menu-$Screen" } else { 'menu-play' }
            Invoke-Checked $script:godot (@('--path', $projectRoot, '--', "--capture=$(Join-Path $buildRoot "$captureName.png")") + $trackArguments) 'capture.log'
            if (-not (Select-String -LiteralPath (Join-Path $commandLogRoot 'capture.log') -SimpleMatch 'CAPTURE_SAVED:' -Quiet)) { throw 'Window closed before capture completed; do not use an older PNG. Keep delayed captures focused.' }
        }
        'ExportAndroid' { Export-Android }
        'InstallAndroid' { Install-Android }
        'LaunchAndroid' { Launch-Android }
        'DeployAndroid' { Export-Android; Install-Android; Launch-Android }
        'DeployAndroidWithTracks' { Deploy-AndroidWithTracks }
    }
    exit 0
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
