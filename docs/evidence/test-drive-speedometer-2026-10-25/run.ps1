param(
    [string]$Script = 'capture_test_drive_speedometer',
    [ValidateSet('headless','gl_compatibility','mobile')][string]$Mode = 'gl_compatibility',
    [string]$Stage = 'after'
)
$ErrorActionPreference = 'Stop'
$speedRepo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$speedOutput = Join-Path $PSScriptRoot "$Stage-$Script-$Mode"
New-Item -ItemType Directory -Path $speedOutput -Force | Out-Null
$env:APPDATA = Join-Path $speedRepo "build/test-drive-speedometer/$Stage-$Script-$Mode/user"
New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
$speedArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $speedRepo 'scripts/dev.ps1'),'-Action','TestScript','-ScriptPath',"res://tests/$Script.gd",'-CommandTimeoutSeconds','180','-TestArgument',"--evidence-root=$speedOutput")
if ($Mode -ne 'headless') {
    $speedArgs += @('-Graphical','-RenderingMethod',$Mode,'-RenderingDriver',$(if ($Mode -eq 'mobile') {'vulkan'} else {'opengl3'}))
}
$speedStarted = [DateTime]::UtcNow
& powershell @speedArgs *> (Join-Path $speedOutput 'console.log')
$speedCode = $LASTEXITCODE
@{arguments=$speedArgs;exit_code=$speedCode;started_utc=$speedStarted.ToString('o');duration_seconds=([DateTime]::UtcNow-$speedStarted).TotalSeconds} | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 (Join-Path $speedOutput 'command.json')
Get-Content (Join-Path $speedOutput 'console.log') -Tail 18
exit $speedCode
