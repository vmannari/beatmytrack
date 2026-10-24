param(
    [ValidateSet('smoke','gameplay','garage','editor','challenge')]
    [string]$Mode = 'smoke',
    [string]$Output = 'build/trailer-2026-10-24'
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$destination = [IO.Path]::GetFullPath((Join-Path $repo $Output))
if (-not $destination.StartsWith($repo + [IO.Path]::DirectorySeparatorChar)) { throw 'Output must be inside this workspace.' }
New-Item -ItemType Directory -Force -Path $destination | Out-Null
$env:APPDATA = Join-Path $destination 'userdata'
$env:LOCALAPPDATA = $env:APPDATA
$env:BMT_API_URL = ''
$godotTrailer = 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe'
$actualVersion = & $godotTrailer --version
if ($actualVersion.Trim() -ne (Get-Content -LiteralPath (Join-Path $repo 'godot-version.txt') -Raw).Trim()) { throw 'Pinned Godot version mismatch.' }
& $godotTrailer --path (Join-Path $repo 'game') --rendering-method gl_compatibility --rendering-driver opengl3 --audio-driver Dummy --fixed-fps 30 --resolution 1920x1080 --script (Join-Path $PSScriptRoot 'capture.gd') --log-file (Join-Path $destination "$Mode.log") -- "--output=$(Join-Path $destination 'raw')" "--mode=$Mode"
if ($LASTEXITCODE -ne 0) { throw "Godot capture failed: $LASTEXITCODE" }
$logText = Get-Content -LiteralPath (Join-Path $destination "$Mode.log") -Raw
if ($logText -match 'SCRIPT ERROR|Assertion failed|Parse Error|Failed loading resource|Unable to open file' -or $logText -notmatch "TRAILER_CAPTURE_COMPLETE $Mode") { throw "Incomplete capture; inspect $Mode.log" }
