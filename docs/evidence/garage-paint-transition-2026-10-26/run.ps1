param([string]$Test='test_garage_paint_transition',[ValidateSet('headless','gl_compatibility','mobile')][string]$Mode='headless',[switch]$Import)
$ErrorActionPreference='Stop'
if ($Import) {$Test='import';$Mode='headless'}
$paintRepo=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$paintOutput=Join-Path $PSScriptRoot "$Test-$Mode"
New-Item -ItemType Directory -Force -Path $paintOutput | Out-Null
$env:APPDATA=Join-Path $paintRepo "build/garage-paint-transition-2026-10-26/$Test-$Mode/user"
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
$paintArgs=@('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $paintRepo 'scripts/dev.ps1'),'-Action','TestScript','-ScriptPath',"res://tests/$Test.gd",'-CommandTimeoutSeconds','240','-TestArgument',"--evidence-root=$paintOutput")
if ($Import) {$paintArgs=@('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $paintRepo 'scripts/dev.ps1'),'-Action','Import','-CommandTimeoutSeconds','180')}
if ($Mode -ne 'headless') {$paintArgs+=@('-Graphical','-RenderingMethod',$Mode,'-RenderingDriver',$(if ($Mode -eq 'mobile') {'vulkan'} else {'opengl3'}))}
$paintStarted=[DateTime]::UtcNow
& powershell @paintArgs *> (Join-Path $paintOutput 'console.log')
$paintCode=$LASTEXITCODE
@{arguments=$paintArgs;exit_code=$paintCode;started_utc=$paintStarted.ToString('o');duration_seconds=([DateTime]::UtcNow-$paintStarted).TotalSeconds}|ConvertTo-Json -Depth 5|Set-Content -Encoding UTF8 (Join-Path $paintOutput 'command.json')
Get-Content (Join-Path $paintOutput 'console.log') -Tail 24
exit $paintCode
