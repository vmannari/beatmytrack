[CmdletBinding()]
param(
    [ValidateSet('TestBridgeHUD', 'CaptureBridgeHUD', 'CaptureKerbs', 'TestKerbs', 'TestHandling', 'TestDriving', 'CaptureHandling', 'TestObjects', 'CaptureObjects', 'TestDeleteTracks', 'CaptureDeleteTracks', 'TestHazards', 'CaptureHazards', 'CaptureStyle', 'Doctor', 'Validate', 'TestTracks', 'TestCorpus', 'TestCreator', 'TestApp', 'TestRecords', 'TestCatalog', 'TestMenus', 'TestEditor', 'TestFreeEditor', 'TestPractice', 'CapturePractice', 'TestPieces', 'TestWorkflow', 'ReviewCreator', 'Import', 'CheckScript', 'TestConstruction', 'CaptureConstruction', 'TestRefinement', 'CaptureRefinement', 'TestTyresLoad', 'CaptureTyresLoad', 'CaptureWorkflow', 'CaptureFreeEditor', 'CaptureEditor', 'CaptureApp', 'Run', 'Editor', 'Capture', 'Snapshot', 'ExportAndroid', 'InstallAndroid', 'LaunchAndroid', 'DeployAndroid')]
    [string]$Action = 'Validate',
    [string]$GodotPath = $env:GODOT_BIN,
    [string]$DeviceSerial = '',
    [string]$AdbPath = $env:ADB_BIN,
    [string]$Track = '',
    [string]$Screen = '',
    [string]$ScriptPath = '',
    [string]$StyleDocument = '',
    [switch]$Overview,
    [switch]$AI,
    [int]$CaptureTick = 0
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
    # Native Godot may report script errors while exiting 0; inspect output as well.
    # Windows PowerShell 5 wraps stderr as NativeCommandError, even for benign
    # editor diagnostics. Capture it, then classify the exit code and text.
    $savedPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $lines = @(& $Executable @Arguments 2>&1 | ForEach-Object { "$_" })
        $nativeExit = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $savedPreference
    }
    $lines | Set-Content -LiteralPath (Join-Path $buildRoot $LogName) -Encoding UTF8
    $lines | ForEach-Object { Write-Host $_ }
    if ($nativeExit -ne 0 -or ($lines -match '(?i)SCRIPT ERROR:|(^|\s)ERROR:|Parse Error:')) {
        throw "Command failed (exit $nativeExit); see build/$LogName."
    }
}

function Invoke-Validation {
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--editor', '--import') 'import.log'
    $scripts = @(Get-ChildItem -LiteralPath $projectRoot -Filter '*.gd' -Recurse | Where-Object { $_.FullName -notmatch '[\\/]\.godot[\\/]' })
    foreach ($source in $scripts) {
        Write-Host "Checking $($source.FullName)"
        Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--check-only', '--script', $source.FullName) 'parse.log'
    }
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--quit-after', '8') 'startup.log'
    if (-not (Select-String -LiteralPath (Join-Path $buildRoot 'startup.log') -SimpleMatch 'APP_READY' -Quiet)) {
        throw 'Main scene did not emit APP_READY.'
    }
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_driving.gd') 'driving-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_handling.gd') 'handling-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_tracks.gd') 'track-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_extra_tracks.gd') 'extra-track-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_creator.gd') 'creator-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_editor_v2.gd') 'editor-v2-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_free_editor.gd') 'free-editor-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_road_pieces.gd') 'road-pieces-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_editor_practice.gd') 'editor-practice-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_editor_workflow.gd') 'editor-workflow-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_construction.gd') 'construction-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_bridge_hud.gd') 'bridge-hud-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_creator_refinement.gd') 'refinement-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_tyres_and_load.gd') 'tyres-load-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_hazards.gd') 'hazards-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_kerbs.gd') 'kerbs-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_object_browser.gd') 'object-browser-tests.log'
    if (Test-Path -LiteralPath (Join-Path $projectRoot 'tests/test_app.gd')) {
        Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_app.gd') 'app-tests.log'
    }
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_records.gd') 'records-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_catalog.gd') 'catalog-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_track_deletion.gd') 'delete-track-tests.log'
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_menu_presentation.gd') 'menu-presentation-tests.log'
    Write-Host "PASS: import, $($scripts.Count) script parse(s), main-scene startup and all domain/UI regression tests."
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
    $output = @(& $AdbExecutable devices 2>&1 | ForEach-Object { "$_" })
    if ($LASTEXITCODE -ne 0) { throw "adb devices failed: $($output -join ' ')" }
    $available = @($output | Where-Object { $_ -match '^\S+\s+device$' } | ForEach-Object { ($_ -split '\s+')[0] })
    if ($DeviceSerial) {
        if ($available -notcontains $DeviceSerial) { throw "Device '$DeviceSerial' is not authorized/online. Unlock the phone and accept its USB debugging prompt." }
        return $DeviceSerial
    }
    if ($available.Count -ne 1) { throw "Expected one authorized device; found $($available.Count). Connect a phone, or specify -DeviceSerial. adb output: $($output -join ' ')" }
    return $available[0]
}

function Export-Android {
    Invoke-Validation
    Test-AndroidTools
    New-Item -ItemType Directory -Path (Split-Path -Parent $apkPath) -Force | Out-Null
    # Export to a fresh name so a failed build can never deploy a stale APK.
    $freshApk = Join-Path (Split-Path -Parent $apkPath) ('circuit01-' + [guid]::NewGuid().ToString('N') + '.apk')
    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--export-debug', 'Android Debug', $freshApk) 'android-export.log'
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
    Invoke-Checked $adb @('-s', $serial, 'shell', 'am', 'start', '-W', '-n', "$packageId/com.godot.game.GodotApp") 'adb-launch.log'
}

try {
    $script:godot = Find-Godot
    $version = (@(& $script:godot --version 2>&1 | ForEach-Object { "$_" }) -join "`n").Trim()
    if ($LASTEXITCODE -ne 0 -or $version -ne $expectedVersion) { throw "Engine mismatch: expected $expectedVersion; got '$version' from $script:godot." }
    Write-Host "Godot: $version ($script:godot)"
    switch ($Action) {
        'TestHandling' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_handling.gd') 'handling-tests.log' }
        'CaptureKerbs' {
            $evidencePath = Join-Path $buildRoot 'kerbs'
            New-Item -ItemType Directory -Path $evidencePath -Force | Out-Null
            Invoke-Checked $script:godot @('--fixed-fps', '60', '--path', $projectRoot, '--script', 'res://tests/test_kerbs.gd', '--', "--capture-kerbs=$evidencePath") 'kerbs-capture.log'
        }
        'TestKerbs' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_kerbs.gd') 'kerbs-tests.log' }
        'TestDriving' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_driving.gd') 'driving-tests.log' }
        'CaptureHandling' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/capture_handling.gd') 'handling-capture.log' }
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
        'CheckScript' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--check-only', '--script', $ScriptPath, '--verbose') 'parse.log' }
        'Import' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--editor', '--import') 'import.log' }
        'TestConstruction' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_construction.gd') 'construction-tests.log' }
        'CaptureConstruction' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/test_construction.gd', '--', '--capture-construction') 'construction-capture.log' }
        'ReviewCreator' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/review_creator_usability.gd') 'creator-usability-review.log' }
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
        'TestBridgeHUD' { Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_bridge_hud.gd') 'bridge-hud-tests.log' }
        'CaptureBridgeHUD' { Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/test_bridge_hud.gd', '--', '--capture-bridge-hud') 'bridge-hud-capture.log' }
        'CaptureStyle' {
            Invoke-Checked $script:godot @('--path', $projectRoot, '--script', 'res://tests/capture_style.gd', '--', "--style-document=$StyleDocument", "--style-output=$(Join-Path $buildRoot 'style-roadside.png')") 'style-capture.log'
        }
        'Snapshot' {
            $captureName = if ($Track) { $Track } elseif ($Screen) { "menu-$Screen" } else { 'menu-play' }
            Invoke-Checked $script:godot (@('--path', $projectRoot, '--', "--capture=$(Join-Path $buildRoot "$captureName.png")") + $trackArguments) 'capture.log'
            if (-not (Select-String -LiteralPath (Join-Path $buildRoot 'capture.log') -SimpleMatch 'CAPTURE_SAVED:' -Quiet)) { throw 'Window closed before capture completed; do not use an older PNG. Keep delayed captures focused.' }
        }
        'Run' { Invoke-Checked $script:godot (@('--path', $projectRoot, '--') + $trackArguments) 'run.log' }
        'Editor' { Invoke-Checked $script:godot @('--path', $projectRoot, '--editor') 'editor.log' }
        'Capture' {
            Invoke-Validation
            $captureName = if ($Track) { $Track } elseif ($Screen) { "menu-$Screen" } else { 'menu-play' }
            Invoke-Checked $script:godot (@('--path', $projectRoot, '--', "--capture=$(Join-Path $buildRoot "$captureName.png")") + $trackArguments) 'capture.log'
            if (-not (Select-String -LiteralPath (Join-Path $buildRoot 'capture.log') -SimpleMatch 'CAPTURE_SAVED:' -Quiet)) { throw 'Window closed before capture completed; do not use an older PNG. Keep delayed captures focused.' }
        }
        'ExportAndroid' { Export-Android }
        'InstallAndroid' { Install-Android }
        'LaunchAndroid' { Launch-Android }
        'DeployAndroid' { Export-Android; Install-Android; Launch-Android }
    }
    exit 0
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
