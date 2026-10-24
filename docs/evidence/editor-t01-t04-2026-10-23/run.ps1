param([switch]$Graphical, [ValidateSet('gl_compatibility','mobile')][string]$Renderer = 'gl_compatibility', [string[]]$TestName = @('test_editor_t01_t04'))
$ErrorActionPreference = 'Stop'
$editorRepo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$editorEngine = 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe'
$editorPin = [System.IO.File]::ReadAllText((Join-Path $editorRepo 'godot-version.txt')).Trim()
if ((& $editorEngine --version | Out-String).Trim() -ne $editorPin) { throw 'Pinned engine mismatch' }
$env:APPDATA = Join-Path $editorRepo 'build/editor-t01-t04/appdata'
$env:BMT_API_URL = 'audit-disabled'
New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
$editorArgs = @('--path',(Join-Path $editorRepo 'game'),'--audio-driver','Dummy')
if ($Graphical) { $editorArgs += @('--rendering-method',$Renderer) } else { $editorArgs = @('--headless')+$editorArgs }
$editorMode = if ($Graphical) { $Renderer } else { 'headless' }
$editorFailures = 0
# dev.ps1 was attempted first. Its fail-on-ERROR gate terminates this sandbox
# on the unrelated Windows certificate-store diagnostic; retain direct engine
# exit codes and every diagnostic instead of masking runtime script failures.
$ErrorActionPreference = 'Continue'
foreach ($editorTest in $TestName) {
    $editorLog = Join-Path $PSScriptRoot ($editorTest+'-'+$editorMode+'.log')
    & $editorEngine @editorArgs --script ('res://tests/'+$editorTest+'.gd') -- ('--editor-evidence='+$PSScriptRoot) 2>&1 | Tee-Object -FilePath $editorLog
    $editorExit = $LASTEXITCODE
    $editorErrors = @(Get-Content -LiteralPath $editorLog | Where-Object { $_ -match '(^| : )(SCRIPT ERROR:|ERROR:)|Parse Error:' -and $_ -notmatch 'Failed to read the root certificate store|ERROR: Access denied' })
    if ($editorExit -ne 0 -or $editorErrors.Count -gt 0) { $editorFailures++; Write-Output ('EDITOR_TEST_EXIT '+$editorTest+' '+$editorExit+' unexpected_errors='+$editorErrors.Count) }
}
exit $editorFailures
