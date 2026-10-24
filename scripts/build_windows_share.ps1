param()
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$bindings = Join-Path $repoRoot '.tools/godot-cpp-music'
if ((& git -C $bindings rev-parse HEAD) -ne 'e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77') { throw 'Unexpected existing Godot bindings revision.' }
$buildRoot = Join-Path $repoRoot 'build/track-direct-share/native'
$outputRoot = Join-Path $repoRoot 'game/platform/windows'
New-Item -ItemType Directory -Path $buildRoot -Force | Out-Null
$vswhere = 'C:/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe'
$installation = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $installation) { throw 'Existing Visual C++ tools are required for the Windows SDK share API.' }
$toolchain = Get-ChildItem -LiteralPath (Join-Path $installation 'VC/Tools/MSVC') -Directory | Sort-Object Name -Descending | Select-Object -First 1
$sdkRoot = 'C:/Program Files (x86)/Windows Kits/10'
$sdk = Get-ChildItem -LiteralPath (Join-Path $sdkRoot 'Include') -Directory | Sort-Object Name -Descending | Select-Object -First 1
$env:INCLUDE = (Join-Path $toolchain.FullName 'include') + ';' + ((@('ucrt','shared','um','winrt','cppwinrt') | ForEach-Object { Join-Path $sdk.FullName $_ }) -join ';')
$env:LIB = (Join-Path $toolchain.FullName 'lib/x64') + ';' + (Join-Path $sdkRoot ('Lib/'+$sdk.Name+'/um/x64')) + ';' + (Join-Path $sdkRoot ('Lib/'+$sdk.Name+'/ucrt/x64'))
$runtime = Join-Path $buildRoot 'bmt_share_runtime.dll'
& (Join-Path $toolchain.FullName 'bin/Hostx64/x64/cl.exe') /nologo /std:c++17 /EHsc /O2 /MT /LD /DWINVER=0x0A00 /D_WIN32_WINNT=0x0A00 (Join-Path $repoRoot 'native/windows_share/share_runtime.cpp') "/Fo$buildRoot/" /link /Brepro windowsapp.lib user32.lib "/OUT:$runtime" "/IMPLIB:$buildRoot/bmt_share_runtime.lib"
if ($LASTEXITCODE) { throw 'Windows share runtime build failed.' }
$runtimeName = 'bmt_share_runtime.'+(Get-FileHash -LiteralPath $runtime -Algorithm SHA256).Hash.ToLowerInvariant().Substring(0,12)+'.dll'
$runtimeOutput = Join-Path $outputRoot $runtimeName
if (-not (Test-Path -LiteralPath $runtimeOutput)) { Copy-Item -LiteralPath $runtime -Destination $runtimeOutput }
$compiled = Join-Path $buildRoot 'bmt_windows_share.dll'
[System.IO.File]::WriteAllText((Join-Path $buildRoot 'runtime_name.hpp'),('#define BMT_SHARE_RUNTIME L"'+$runtimeName+'"'),[System.Text.UTF8Encoding]::new($false))
$arguments = @('-std=c++17','-O2','-shared','-static','-s','-Wl,--no-insert-timestamp','-DGDEXTENSION','-DNDEBUG','-DWINDOWS_ENABLED',('-I'+$buildRoot),('-I'+(Join-Path $bindings 'include')),('-I'+(Join-Path $bindings 'gen/include')),('-I'+(Join-Path $bindings 'gdextension')),(Join-Path $repoRoot 'native/windows_share/share_extension.cpp'),(Join-Path $bindings 'bin/libgodot-cpp.windows.template_release.x86_64.a'),'-o',$compiled)
& 'C:/msys64/mingw64/bin/g++.exe' @arguments
if ($LASTEXITCODE) { throw 'Windows share Godot adapter build failed.' }
$binaryName = 'bmt_windows_share.'+(Get-FileHash -LiteralPath $compiled -Algorithm SHA256).Hash.ToLowerInvariant().Substring(0,12)+'.dll'
$destination = Join-Path $outputRoot $binaryName
if (-not (Test-Path -LiteralPath $destination)) { Copy-Item -LiteralPath $compiled -Destination $destination }
$descriptor = @"
[configuration]
entry_symbol = "bmt_windows_share_init"
compatibility_minimum = "4.5"
reloadable = false

[libraries]
windows.x86_64 = "res://platform/windows/$binaryName"

[dependencies]
windows.x86_64 = { "res://platform/windows/$runtimeName": "" }
"@
[System.IO.File]::WriteAllText((Join-Path $outputRoot 'share.gdextension'),$descriptor,[System.Text.UTF8Encoding]::new($false))
Get-FileHash -LiteralPath $destination,$runtimeOutput -Algorithm SHA256

# Keep loaded generations; quarantine other rollback bytes outside the resource root.
& (Join-Path $PSScriptRoot 'archive_native_libraries.ps1') -Archive
