param(
    [ValidateSet('windows','android','all')][string]$Platform = 'all',
    [string]$NdkPath = '',
    [int]$Jobs = 8
)
$ErrorActionPreference = 'Stop'
$musicRoot = Split-Path -Parent $PSScriptRoot
$bindings = Join-Path $musicRoot '.tools/godot-cpp-music'
$scons = Join-Path $musicRoot '.tools/scons-music'
if (-not (Test-Path -LiteralPath $bindings)) {
    & git -c http.sslBackend=schannel clone --depth 1 --branch godot-4.5-stable https://github.com/godotengine/godot-cpp.git $bindings
    if ($LASTEXITCODE) { throw 'Could not fetch Godot engine bindings.' }
}
if ((& git -C $bindings rev-parse HEAD) -ne 'e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77') { throw 'Unexpected godot-cpp revision; do not silently rebuild a different ABI.' }
if (-not (Test-Path -LiteralPath $scons)) {
    & git -c http.sslBackend=schannel clone --depth 1 --branch 4.9.1 https://github.com/SCons/scons.git $scons
    if ($LASTEXITCODE) { throw 'Could not fetch the build tool.' }
}
if ((& git -C $scons rev-parse HEAD) -ne 'dfd6b7e45985eb73462d2efa878651c92745099c') { throw 'Unexpected SCons revision.' }
if (-not $NdkPath) { $NdkPath = Join-Path $musicRoot '.tools/android-ndk-r28b' }
Push-Location (Join-Path $musicRoot 'native/music')
$previousNdk = $env:ANDROID_NDK_ROOT
try {
    foreach ($platformName in @('windows','android')) {
        if ($Platform -ne 'all' -and $Platform -ne $platformName) { continue }
        if ($platformName -eq 'android') {
            if (-not (Test-Path -LiteralPath (Join-Path $NdkPath 'source.properties'))) { throw 'Install Android NDK r28b (28.1.13356709) and pass -NdkPath. See docs/PROCEDURAL_MUSIC.md.' }
            $env:ANDROID_NDK_ROOT = $NdkPath
        }
        foreach ($target in @('template_debug','template_release')) {
            $arguments = @((Join-Path $scons 'scripts/scons.py'),"platform=$platformName","target=$target",'build_profile=profile.json',"-j$Jobs")
            if ($platformName -eq 'windows') { $arguments += 'use_mingw=yes' }
            else { $arguments += @('arch=arm64','ANDROID_HOME=') }
            & python @arguments
            if ($LASTEXITCODE) { throw "Native music build failed: $platformName / $target" }
        }
    }
} finally {
    $env:ANDROID_NDK_ROOT = $previousNdk
    Pop-Location
}
