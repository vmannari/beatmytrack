param([string]$Script='res://tests/test_graphics_settings.gd', [string]$Renderer='')
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$env:APPDATA = Join-Path $repoRoot ('build/graphics-settings-2026-10-22/'+[System.IO.Path]::GetFileNameWithoutExtension($Script)+'-'+$Renderer+'/appdata')
New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
$env:BMT_API_URL = ''
$options = @{ Action='TestScript'; ScriptPath=$Script; CommandTimeoutSeconds=240 }
if ($Renderer) { $options.Graphical=$true; $options.RenderingMethod=$Renderer }
& (Join-Path $PSScriptRoot 'dev.ps1') @options
