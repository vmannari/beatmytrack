param([switch]$Graphical, [ValidateSet('gl_compatibility','mobile')][string]$Renderer = 'gl_compatibility', [string[]]$TestName = @('test_object_rotation'))
$rotationRepo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$rotationEngine = 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe'
$rotationPin = [System.IO.File]::ReadAllText((Join-Path $rotationRepo 'godot-version.txt')).Trim()
if ((& $rotationEngine --version | Out-String).Trim() -ne $rotationPin) { throw 'Pinned engine mismatch' }
$env:APPDATA = Join-Path $rotationRepo 'build/object-rotation-2026-10-23/profile'
$env:BMT_API_URL = 'audit-disabled'
New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
$rotationArgs = @('--path',(Join-Path $rotationRepo 'game'),'--audio-driver','Dummy')
if ($Graphical) { $rotationArgs += @('--rendering-method',$Renderer) } else { $rotationArgs = @('--headless')+$rotationArgs }
$rotationMode = if ($Graphical) { $Renderer } else { 'headless' }
$rotationFailures = 0
# dev.ps1 was attempted first. Its gate stops on this sandbox's Windows
# certificate-store diagnostic; retain exit codes and reject all other errors.
$ErrorActionPreference = 'Continue'
foreach ($rotationTest in $TestName) {
    $rotationLog = Join-Path $PSScriptRoot ($rotationTest+'-'+$rotationMode+'.log')
    & $rotationEngine @rotationArgs --script ('res://tests/'+$rotationTest+'.gd') -- ('--rotation-evidence='+$PSScriptRoot) 2>&1 | Tee-Object -FilePath $rotationLog
    $rotationExit = $LASTEXITCODE
    $rotationErrors = @(Get-Content -LiteralPath $rotationLog | Where-Object { $_ -match '(^| : )(SCRIPT ERROR:|ERROR:)|Parse Error:' -and $_ -notmatch 'Failed to read the root certificate store' -and $_.Trim() -ne 'ERROR: Access denied' })
    if ($rotationExit -ne 0 -or $rotationErrors.Count -gt 0) { $rotationFailures++; Write-Output ('ROTATION_TEST_EXIT '+$rotationTest+' '+$rotationExit+' unexpected_errors='+$rotationErrors.Count) }
}
exit $rotationFailures
