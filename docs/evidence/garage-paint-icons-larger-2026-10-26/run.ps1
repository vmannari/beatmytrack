param([string]$Test='test_garage_paint_list',[ValidateSet('headless','gl_compatibility','mobile')][string]$Mode='headless',[switch]$Before,[switch]$Import)
$ErrorActionPreference='Stop'
if ($Import) {$Test='import';$Mode='headless'}
$kitRepo=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$kitOutput=Join-Path $PSScriptRoot $(if ($Before) {"before/$Mode"} else {"$Test-$Mode"})
New-Item -ItemType Directory -Force -Path $kitOutput | Out-Null
$env:APPDATA=Join-Path $kitRepo "build/garage-paint-icons-larger-2026-10-26/$(if ($Before) {'before'} else {"$Test-$Mode"})/user"
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
$kitArgs=@('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $kitRepo 'scripts/dev.ps1'),'-Action','TestScript','-ScriptPath',"res://tests/$Test.gd",'-CommandTimeoutSeconds','240','-TestArgument',"--evidence-root=$kitOutput")
if ($Import) {$kitArgs=@('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $kitRepo 'scripts/dev.ps1'),'-Action','Import','-CommandTimeoutSeconds','180')}
if ($Mode -ne 'headless') {$kitArgs+=@('-Graphical','-RenderingMethod',$Mode,'-RenderingDriver',$(if ($Mode -eq 'mobile') {'vulkan'} else {'opengl3'}))}
$kitStarted=[DateTime]::UtcNow
& powershell @kitArgs *> (Join-Path $kitOutput 'console.log')
$kitCode=$LASTEXITCODE
@{arguments=$kitArgs;exit_code=$kitCode;started_utc=$kitStarted.ToString('o');duration_seconds=([DateTime]::UtcNow-$kitStarted).TotalSeconds}|ConvertTo-Json -Depth 5|Set-Content -Encoding UTF8 (Join-Path $kitOutput 'command.json')
Get-Content (Join-Path $kitOutput 'console.log') -Tail 16
exit $kitCode
