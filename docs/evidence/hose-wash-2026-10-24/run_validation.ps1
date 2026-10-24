param(
    [string]$Test = 'test_garage_hose',
    [ValidateSet('headless','gl_compatibility','mobile')][string]$Mode = 'headless'
)
$ErrorActionPreference = 'Stop'
$hoseRepo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$hoseOutput = Join-Path $PSScriptRoot "$Test-$Mode"
New-Item -ItemType Directory -Force -Path $hoseOutput | Out-Null
$env:APPDATA = Join-Path $hoseRepo "build/hose-wash-2026-10-24/$Test-$Mode/user"
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
$hoseArguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $hoseRepo 'scripts/dev.ps1'),'-Action','TestScript','-ScriptPath',"res://tests/$Test.gd",'-CommandTimeoutSeconds','240','-TestArgument',"--evidence-root=$hoseOutput")
if ($Mode -ne 'headless') { $hoseArguments += @('-Graphical','-RenderingMethod',$Mode,'-RenderingDriver',$(if ($Mode -eq 'mobile') {'vulkan'} else {'opengl3'})) }
$hoseStarted = [DateTime]::UtcNow
& powershell @hoseArguments *> (Join-Path $hoseOutput 'console.log')
$hoseCode = $LASTEXITCODE
@{command = 'powershell'; arguments = $hoseArguments; exit_code = $hoseCode; started_utc = $hoseStarted.ToString('o'); duration_seconds = ([DateTime]::UtcNow-$hoseStarted).TotalSeconds} | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 (Join-Path $hoseOutput 'command.json')
Get-Content (Join-Path $hoseOutput 'console.log') -Tail 18
exit $hoseCode
