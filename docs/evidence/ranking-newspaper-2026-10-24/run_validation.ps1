param(
    [string]$Test = 'test_ranking_newspaper',
    [ValidateSet('headless','gl_compatibility','mobile')][string]$Mode = 'headless',
    [string[]]$TestArgument = @()
)
$ErrorActionPreference = 'Stop'
$rankingRepo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$env:APPDATA = Join-Path $rankingRepo "build/ranking-newspaper-validation/$Test-$Mode/user"
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
$rankingEngine = 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe'
if ((& $rankingEngine --version).Trim() -ne (Get-Content -LiteralPath (Join-Path $rankingRepo 'godot-version.txt') -Raw).Trim()) { throw 'Pinned Godot version mismatch.' }
$rankingArguments = @('--path', (Join-Path $rankingRepo 'game'), '--log-file', (Join-Path $PSScriptRoot "$Test-$Mode.log"), '--script', "res://tests/$Test.gd", '--audio-driver', 'Dummy')
if ($Mode -eq 'headless') { $rankingArguments += '--headless' }
else { $rankingArguments += @('--rendering-method',$Mode,'--max-fps','60') }
if ($Mode -eq 'mobile') { $rankingArguments += @('--rendering-driver','vulkan') }
if ($TestArgument.Count -gt 0) { $rankingArguments += @('--') + $TestArgument }
$rankingStarted = [DateTime]::UtcNow
& $rankingEngine @rankingArguments
$rankingCode = $LASTEXITCODE
@{command = $rankingEngine; arguments = $rankingArguments; exit_code = $rankingCode; started_utc = $rankingStarted.ToString('o'); duration_seconds = ([DateTime]::UtcNow-$rankingStarted).TotalSeconds} | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 (Join-Path $PSScriptRoot "$Test-$Mode-command.json")
exit $rankingCode
