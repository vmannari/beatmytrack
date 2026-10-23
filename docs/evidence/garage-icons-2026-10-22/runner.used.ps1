param([string]$Script='res://tests/test_garage_sidebar.gd', [string]$Renderer='', [string]$Evidence='', [switch]$Before)
$ErrorActionPreference = 'Stop'
$env:APPDATA = Join-Path $PSScriptRoot ('garage-sidebar/'+[System.IO.Path]::GetFileNameWithoutExtension($Script)+'-'+$Renderer+'/appdata')
New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
$options = @{ Action='TestScript'; ScriptPath=$Script; CommandTimeoutSeconds=240 }
if ($Renderer) { $options.Graphical=$true; $options.RenderingMethod=$Renderer }
$arguments = @()
if ($Evidence) { $arguments += "--evidence-root=$Evidence" }
if ($Before) { $arguments += '--before' }
if ($arguments.Count) { $options.TestArgument=$arguments }
& (Join-Path $PSScriptRoot '../scripts/dev.ps1') @options
