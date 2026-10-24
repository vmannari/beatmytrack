param([switch]$Graphical,[ValidateSet('gl_compatibility','mobile')][string]$Renderer='gl_compatibility',[string[]]$TestName=@('test_creator_capacity'),[switch]$Isolated)
$ErrorActionPreference='Stop'
$capacityRoot=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$capacityEngine='C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe'
if ((& $capacityEngine --version | Out-String).Trim() -ne [IO.File]::ReadAllText((Join-Path $capacityRoot 'godot-version.txt')).Trim()) { throw 'Pinned engine mismatch' }
$env:APPDATA=Join-Path $capacityRoot 'build/creator-capacity/appdata'
$env:BMT_API_URL='audit-disabled'
New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
$capacityProject=if ($Isolated) { Join-Path $capacityRoot 'build/creator-object-limit/probe-project' } else { Join-Path $capacityRoot 'game' }
$capacityMode=if ($Graphical) { $Renderer } else { 'headless' }
$capacityFailures=0
foreach ($capacityTest in $TestName) {
    $capacityEditorOutput=Join-Path $PSScriptRoot ($capacityTest+'-'+$capacityMode)
    New-Item -ItemType Directory -Path $capacityEditorOutput -Force | Out-Null
    $capacityArgs=@('--path',$capacityProject,'--audio-driver','Dummy','--script',('res://tests/'+$capacityTest+'.gd'))
    if ($Graphical) { $capacityArgs+=@('--rendering-method',$Renderer) } else { $capacityArgs=@('--headless')+$capacityArgs }
    $capacityArgs+=@('--',('--capacity-evidence='+$PSScriptRoot),('--editor-evidence='+$capacityEditorOutput))
    $capacityLog=Join-Path $PSScriptRoot ($capacityTest+'-'+$capacityMode+'.log')
    $ErrorActionPreference='Continue'
    & $capacityEngine @capacityArgs *> $capacityLog
    $capacityExit=$LASTEXITCODE
    $ErrorActionPreference='Stop'
    $capacityErrors=@(Get-Content -LiteralPath $capacityLog | Where-Object { $_ -match '(^| : )(SCRIPT ERROR:|ERROR:|Parse Error:)|^FAIL[: ]' -and $_ -notmatch 'Failed to read the root certificate store|^ERROR: Access denied$' })
    if ($capacityExit -ne 0 -or $capacityErrors.Count -gt 0) { $capacityFailures++; Write-Output ($capacityTest+' FAILED exit='+$capacityExit+' diagnostics='+$capacityErrors.Count) }
    else { Write-Output ($capacityTest+' '+$capacityMode+' PASS') }
}
exit $capacityFailures
