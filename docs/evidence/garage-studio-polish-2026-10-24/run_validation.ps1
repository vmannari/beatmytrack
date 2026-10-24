param([string]$Test='test_garage_studio_polish',[ValidateSet('headless','gl_compatibility','mobile')][string]$Mode='headless',[switch]$Baseline)
$ErrorActionPreference='Stop'
$studioRepo=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$studioOutput=Join-Path $PSScriptRoot "$Test-$Mode$(if ($Baseline) {'-baseline'})"
New-Item -ItemType Directory -Force -Path $studioOutput | Out-Null
$env:APPDATA=Join-Path $studioRepo "build/garage-studio-polish-2026-10-24/$Test-$Mode/user"
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
$studioArguments=@('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $studioRepo 'scripts/dev.ps1'),'-Action','TestScript','-ScriptPath',"res://tests/$Test.gd",'-CommandTimeoutSeconds','240','-TestArgument',"--evidence-root=$studioOutput$(if ($Baseline) {',--baseline'})")
if ($Mode -ne 'headless') {$studioArguments+=@('-Graphical','-RenderingMethod',$Mode,'-RenderingDriver',$(if ($Mode -eq 'mobile') {'vulkan'} else {'opengl3'}))}
$studioStarted=[DateTime]::UtcNow
& powershell @studioArguments *> (Join-Path $studioOutput 'console.log')
$studioCode=$LASTEXITCODE
@{arguments=$studioArguments;exit_code=$studioCode;started_utc=$studioStarted.ToString('o');duration_seconds=([DateTime]::UtcNow-$studioStarted).TotalSeconds}|ConvertTo-Json -Depth 5|Set-Content -Encoding UTF8 (Join-Path $studioOutput 'command.json')
Get-Content (Join-Path $studioOutput 'console.log') -Tail 22
exit $studioCode
