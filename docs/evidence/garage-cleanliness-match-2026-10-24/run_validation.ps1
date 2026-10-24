param(
    [string]$Test = 'test_garage_cleanliness_match',
    [ValidateSet('headless','gl_compatibility','mobile')][string]$Mode = 'headless',
    [switch]$Before
)
$ErrorActionPreference = 'Stop'
$cleanRepo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$cleanOutput = Join-Path $PSScriptRoot ("$Test-$Mode" + $(if ($Before) {'-before'} else {''}))
New-Item -ItemType Directory -Force -Path $cleanOutput | Out-Null
$env:APPDATA = Join-Path $cleanRepo 'build/garage-cleanliness-match-2026-10-24/user'
$env:BMT_API_URL = ''
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
$cleanArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $cleanRepo 'scripts/dev.ps1'),'-Action','TestScript','-ScriptPath',"res://tests/$Test.gd",'-CommandTimeoutSeconds','240','-TestArgument',"--evidence-root=$cleanOutput")
if ($Before) { $cleanArgs[-1] += ',--before' }
if ($Mode -ne 'headless') { $cleanArgs += @('-Graphical','-RenderingMethod',$Mode,'-RenderingDriver',$(if ($Mode -eq 'mobile') {'vulkan'} else {'opengl3'})) }
$cleanStarted = [DateTime]::UtcNow
& powershell @cleanArgs *> (Join-Path $cleanOutput 'console.log')
$cleanCode = $LASTEXITCODE
@{command='powershell'; arguments=$cleanArgs; exit_code=$cleanCode; started_utc=$cleanStarted.ToString('o'); duration_seconds=([DateTime]::UtcNow-$cleanStarted).TotalSeconds} | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 (Join-Path $cleanOutput 'command.json')
Get-Content (Join-Path $cleanOutput 'console.log') -Tail 24
exit $cleanCode
