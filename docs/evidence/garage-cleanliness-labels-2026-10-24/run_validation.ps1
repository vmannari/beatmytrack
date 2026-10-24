param(
    [string]$Test = 'test_garage_clean_customisation',
    [ValidateSet('headless','gl_compatibility','mobile')][string]$Mode = 'headless'
)
$ErrorActionPreference = 'Stop'
$labelRepo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$labelOutput = Join-Path $PSScriptRoot "$Test-$Mode"
New-Item -ItemType Directory -Force -Path $labelOutput | Out-Null
$env:APPDATA = Join-Path $labelRepo 'build/garage-cleanliness-labels-2026-10-24/user'
$env:BMT_API_URL = ''
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
$labelArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $labelRepo 'scripts/dev.ps1'),'-Action','TestScript','-ScriptPath',"res://tests/$Test.gd",'-CommandTimeoutSeconds','240','-TestArgument',"--evidence-root=$labelOutput")
if ($Mode -ne 'headless') { $labelArgs += @('-Graphical','-RenderingMethod',$Mode,'-RenderingDriver',$(if ($Mode -eq 'mobile') {'vulkan'} else {'opengl3'})) }
$labelStarted = [DateTime]::UtcNow
& powershell @labelArgs *> (Join-Path $labelOutput 'console.log')
$labelCode = $LASTEXITCODE
@{command='powershell'; arguments=$labelArgs; exit_code=$labelCode; started_utc=$labelStarted.ToString('o'); duration_seconds=([DateTime]::UtcNow-$labelStarted).TotalSeconds} | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 (Join-Path $labelOutput 'command.json')
Get-Content (Join-Path $labelOutput 'console.log') -Tail 16
exit $labelCode
