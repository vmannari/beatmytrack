param()
$ErrorActionPreference='Stop'
$repoRoot=Split-Path -Parent $PSScriptRoot
$bindings=Join-Path $repoRoot '.tools/godot-cpp-music'
# Reuse the existing cleared engine binding ABI; no package or SDK download.
if ((& git -C $bindings rev-parse HEAD) -ne 'e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77') { throw 'Unexpected existing Godot bindings revision.' }
$compiler='C:/msys64/mingw64/bin/g++.exe'
if (-not (Test-Path -LiteralPath $compiler)) { throw 'Existing MinGW compiler unavailable.' }
$output=Join-Path $repoRoot 'game/platform/windows/bmt_windows_audio_v2.dll'
$objectPath=Join-Path $repoRoot 'build/windows_audio'
New-Item -ItemType Directory -Path $objectPath -Force | Out-Null
$compiled=Join-Path $objectPath 'bmt_windows_audio_v2.dll'
$arguments=@('-std=c++17','-O2','-shared','-static','-Wl,--no-insert-timestamp','-DGDEXTENSION','-DNDEBUG','-DWINDOWS_ENABLED',('-I'+(Join-Path $bindings 'include')),('-I'+(Join-Path $bindings 'gen/include')),('-I'+(Join-Path $bindings 'gdextension')),(Join-Path $repoRoot 'native/windows_audio/impact.cpp'),(Join-Path $bindings 'bin/libgodot-cpp.windows.template_release.x86_64.a'),'-lole32','-luuid','-lavrt','-o',$compiled)
& $compiler @arguments
if ($LASTEXITCODE) { throw 'Windows audio adapter build failed.' }
if (-not (Test-Path -LiteralPath $output) -or (Get-FileHash -LiteralPath $compiled).Hash -ne (Get-FileHash -LiteralPath $output).Hash) { Copy-Item -LiteralPath $compiled -Destination $output -Force }
Get-FileHash -LiteralPath $output -Algorithm SHA256
