param([ValidateSet('Focus','Export','Verify')][string]$Step = 'Export')
$ErrorActionPreference = 'Stop'
$work = Split-Path -Parent $PSCommandPath
$root = (Resolve-Path (Join-Path $work '../..')).Path
$source = Join-Path $work 'source'
$env:GIT_DIR = Join-Path $root '.git'
$env:GIT_WORK_TREE = $source
$env:APPDATA = Join-Path $work 'appdata'
$env:BMT_API_URL = ''
$env:BMT_DEV_AUTH_KEY = ''
$dev = Join-Path $source 'scripts/dev.ps1'
switch ($Step) {
    'Focus' {
        & $dev -Action TestScript -ScriptPath res://tests/test_touch_slide_activation.gd -CommandTimeoutSeconds 300
        if (-not $? -or $LASTEXITCODE -ne 0) { exit 1 }
        & $dev -Action TestScript -ScriptPath res://tests/test_touch_target_padding.gd -CommandTimeoutSeconds 300
    }
    'Export' { & $dev -Action ExportAndroid -QuickValidation -CommandTimeoutSeconds 900 }
    'Verify' {
        . (Join-Path $source 'scripts/build_identity.ps1')
        $exportRoot = Get-ChildItem -LiteralPath (Join-Path $source 'build/logs') -Directory -Filter 'ExportAndroid-*' | Select-Object -Last 1
        if (-not $exportRoot) { throw 'Export receipt is missing' }
        $expected = Get-Content -LiteralPath (Join-Path $exportRoot.FullName 'client-build-identity.json') -Raw | ConvertFrom-Json
        $identity = Write-ClientBuildIdentity $source (Join-Path $work 'verified-identity')
        if ($identity -cne $expected.build_id) { throw 'Frozen source changed during export' }
        $apk = Join-Path $source 'build/android/circuit01-debug.apk'
        $aapt = Join-Path $env:LOCALAPPDATA 'Android/Sdk/build-tools/36.1.0/aapt.exe'
        $package = @(& $aapt dump badging $apk) | Where-Object { $_ -like 'package:*' } | Select-Object -First 1
        if ($LASTEXITCODE -ne 0 -or $package -notlike "*name='org.circuit01.handlinglab'*" -or $package -notlike "*versionName='$identity'*") { throw 'APK identity differs from frozen source' }
        $result = @{
            build_id = $identity; source_sha256 = $expected.source_sha256; source_files = $expected.source_files
            apk_path = $apk; apk_sha256 = (Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash
            apk_bytes = (Get-Item -LiteralPath $apk).Length; source_check = 'match'; apk_version_check = 'match'
        }
        [System.IO.File]::WriteAllText((Join-Path $work 'verified-build.json'), ($result | ConvertTo-Json) + "`n", (New-Object System.Text.UTF8Encoding($false)))
        Write-Output ($result | ConvertTo-Json)
    }
}
if (-not $? -or ($LASTEXITCODE -and $LASTEXITCODE -ne 0)) { exit 1 }
