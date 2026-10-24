param(
    [string]$Test = 'test_challenge_tab',
    [ValidateSet('headless', 'gl_compatibility', 'mobile')][string]$Mode = 'headless'
)
$ErrorActionPreference = 'Stop'
$taskRepo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$taskOutput = Join-Path $PSScriptRoot "$Test-$Mode"
New-Item -ItemType Directory -Path $taskOutput -Force | Out-Null
$env:APPDATA = Join-Path $taskRepo "build/find-play-created-2026-10-24/$Test-$Mode/user"
New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
$env:BMT_CHALLENGE_ENTRY_OUTPUT = Join-Path $taskOutput 'ui'
$env:BMT_CHALLENGE_DISCOVERY_OUTPUT = Join-Path $taskOutput 'ui'
$env:BMT_CHALLENGE_BROWSER_STATES_OUTPUT = Join-Path $taskOutput 'ui'
$taskArguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $taskRepo 'scripts/dev.ps1'), '-Action', 'TestScript', '-ScriptPath', "res://tests/$Test.gd", '-CommandTimeoutSeconds', '240')
if ($Mode -ne 'headless') {
    $taskArguments += @('-Graphical', '-RenderingMethod', $Mode, '-RenderingDriver', $(if ($Mode -eq 'mobile') {'vulkan'} else {'opengl3'}))
}
$taskStarted = [DateTime]::UtcNow
& powershell @taskArguments *> (Join-Path $taskOutput 'console.log')
$taskCode = $LASTEXITCODE
@{arguments = $taskArguments; exit_code = $taskCode; started_utc = $taskStarted.ToString('o'); duration_seconds = ([DateTime]::UtcNow - $taskStarted).TotalSeconds} | ConvertTo-Json -Depth 4 | Set-Content -Encoding UTF8 (Join-Path $taskOutput 'command.json')
Get-Content (Join-Path $taskOutput 'console.log') -Tail 25
exit $taskCode
