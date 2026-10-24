param([ValidateSet('windows','android','all')][string]$Platform = 'all')
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$bindings = Join-Path $repoRoot '.tools/godot-cpp-music'
if ((& git -C $bindings rev-parse HEAD) -ne 'e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77') { throw 'Unexpected existing Godot bindings revision.' }
$source = Join-Path $repoRoot 'native/track_geometry/track_geometry.cpp'
$outputRoot = Join-Path $repoRoot 'game/platform/track_geometry'
$buildRoot = Join-Path $repoRoot 'build/device-track-loading/native'
New-Item -ItemType Directory -Path $buildRoot -Force | Out-Null
$common = @('-std=c++17','-O2','-ffp-contract=off','-shared','-s','-DGDEXTENSION','-DNDEBUG',('-I'+(Join-Path $bindings 'include')),('-I'+(Join-Path $bindings 'gen/include')),('-I'+(Join-Path $bindings 'gdextension')),$source)
if ($Platform -in @('windows','all')) {
    $compiler = 'C:/msys64/mingw64/bin/g++.exe'
    $compiled = Join-Path $buildRoot 'bmt_track_geometry.windows.x86_64.roads.dll'
    & $compiler @common '-static' '-Wl,--no-insert-timestamp' '-DWINDOWS_ENABLED' (Join-Path $bindings 'bin/libgodot-cpp.windows.template_release.x86_64.a') '-o' $compiled
    if ($LASTEXITCODE) { throw 'Windows track geometry build failed.' }
    # A running editor may retain the previous DLL. Content-address the new
    # library so rebuilding never replaces a loaded native image.
    $binaryTag = (Get-FileHash -LiteralPath $compiled -Algorithm SHA256).Hash.ToLowerInvariant().Substring(0,12)
    $binaryName = "bmt_track_geometry.windows.x86_64.$binaryTag.dll"
    $destination = Join-Path $outputRoot $binaryName
    if (-not (Test-Path -LiteralPath $destination)) { Copy-Item -LiteralPath $compiled -Destination $destination }
    $descriptor = Join-Path $outputRoot 'track_geometry.gdextension'
    $descriptorText = [System.IO.File]::ReadAllText($descriptor)
    $descriptorText = [regex]::Replace($descriptorText,'(?m)^windows\.x86_64\s*=.*$',('windows.x86_64 = "res://platform/track_geometry/'+$binaryName+'"'))
    [System.IO.File]::WriteAllText($descriptor,$descriptorText,[System.Text.UTF8Encoding]::new($false))
}
if ($Platform -in @('android','all')) {
    $toolchain = Join-Path $repoRoot '.tools/android-ndk-r28b/toolchains/llvm/prebuilt/windows-x86_64'
    foreach ($architecture in @('arm64','x86_64')) {
        $target = if ($architecture -eq 'arm64') { 'aarch64-linux-android24' } else { 'x86_64-linux-android24' }
        $compiler = Join-Path $toolchain 'bin/clang++.exe'
        $compiled = Join-Path $buildRoot "libbmt_track_geometry.android.$architecture.so"
        & $compiler @common ("--target="+$target) ("--sysroot="+(Join-Path $toolchain 'sysroot')) '-fPIC' '-DANDROID_ENABLED' '-DUNIX_ENABLED' '-Wl,-z,max-page-size=16384' '-static-libstdc++' (Join-Path $bindings "bin/libgodot-cpp.android.template_release.$architecture.a") '-llog' '-ldl' '-o' $compiled
        if ($LASTEXITCODE) { throw "Android $architecture track geometry build failed." }
        Copy-Item -LiteralPath $compiled -Destination (Join-Path $outputRoot (Split-Path -Leaf $compiled)) -Force
    }
}
Get-ChildItem -LiteralPath $outputRoot -File | Where-Object { $_.Extension -in @('.dll','.so') } | Get-FileHash -Algorithm SHA256

# Keep loaded generations; quarantine other rollback bytes outside the resource root.
& (Join-Path $PSScriptRoot 'archive_native_libraries.ps1') -Archive
