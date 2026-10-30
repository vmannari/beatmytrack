param([string]$Test='test_garage_sidebar',[ValidateSet('headless','gl_compatibility','mobile')][string]$Mode='headless')
$ErrorActionPreference='Stop'
$customRepo=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$customOutput=Join-Path $PSScriptRoot "$Test-$Mode"
New-Item -ItemType Directory -Force -Path $customOutput | Out-Null
$env:APPDATA=Join-Path $customRepo "build/garage-workshop-overlay-2026-10-25/$Test-$Mode/user"
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
$customArgs=@('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $customRepo 'scripts/dev.ps1'),'-Action','TestScript','-ScriptPath',"res://tests/$Test.gd",'-CommandTimeoutSeconds','240','-TestArgument',"--evidence-root=$customOutput")
if ($Mode -ne 'headless') {$customArgs+=@('-Graphical','-RenderingMethod',$Mode,'-RenderingDriver',$(if ($Mode -eq 'mobile') {'vulkan'} else {'opengl3'}))}
$customStarted=[DateTime]::UtcNow
& powershell @customArgs *> (Join-Path $customOutput 'console.log')
$customCode=$LASTEXITCODE
@{arguments=$customArgs;exit_code=$customCode;started_utc=$customStarted.ToString('o');duration_seconds=([DateTime]::UtcNow-$customStarted).TotalSeconds}|ConvertTo-Json -Depth 5|Set-Content -Encoding UTF8 (Join-Path $customOutput 'command.json')
Get-Content (Join-Path $customOutput 'console.log') -Tail 28
exit $customCode



