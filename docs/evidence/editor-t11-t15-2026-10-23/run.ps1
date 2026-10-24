param([switch]$Graphical, [ValidateSet('gl_compatibility','mobile')][string]$Renderer = 'gl_compatibility', [string[]]$TestName = @('test_editor_t11_t15'), [switch]$EngineVerbose, [string[]]$ExtraArgument = @())
$ErrorActionPreference = 'Stop'
$editorRepo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$editorEngine = 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe'
$editorPin = [System.IO.File]::ReadAllText((Join-Path $editorRepo 'godot-version.txt')).Trim()
if ((& $editorEngine --version | Out-String).Trim() -ne $editorPin) { throw 'Pinned engine mismatch' }
$env:APPDATA = Join-Path $editorRepo 'build/editor-t11-t15/appdata'
$env:BMT_API_URL = 'audit-disabled'
New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
$editorArgs = @('--path',(Join-Path $editorRepo 'game'),'--audio-driver','Dummy')
if ($Graphical) { $editorArgs += @('--rendering-method',$Renderer) } else { $editorArgs = @('--headless')+$editorArgs }
if ($EngineVerbose) { $editorArgs += '--verbose' }
$editorMode = if ($Graphical) { $Renderer } else { 'headless' }
$editorFailures = 0
# The ordinary dev.ps1 parser gate passes with isolated APPDATA. Direct test
# runs retain the pinned engine, Dummy audio and exact bootstrap certificate
# exemption; all other runtime errors and engine exit codes fail the receipt.
$ErrorActionPreference = 'Continue'
foreach ($editorTest in $TestName) {
    $editorLog = Join-Path $PSScriptRoot ($editorTest+'-'+$editorMode+'.log')
    $editorOutput = Join-Path $PSScriptRoot $editorTest
    New-Item -ItemType Directory -Path $editorOutput -Force | Out-Null
    & $editorEngine @editorArgs --script ('res://tests/'+$editorTest+'.gd') -- ('--editor-evidence='+$editorOutput) @ExtraArgument 2>&1 | Tee-Object -FilePath $editorLog
    $editorExit = $LASTEXITCODE
    $editorErrors = @(Get-Content -LiteralPath $editorLog | Where-Object { $_ -match '(^| : )(SCRIPT ERROR:|ERROR:)|Parse Error:' -and $_ -notmatch 'Failed to read the root certificate store' -and $_.Trim() -ne 'ERROR: Access denied' })
    if ($editorExit -ne 0 -or $editorErrors.Count -gt 0) { $editorFailures++; Write-Output ('EDITOR_TEST_EXIT '+$editorTest+' '+$editorExit+' unexpected_errors='+$editorErrors.Count) }
}
exit $editorFailures
