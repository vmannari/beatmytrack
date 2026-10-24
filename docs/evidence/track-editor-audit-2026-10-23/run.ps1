param([switch]$Graphical, [string]$Renderer = 'gl_compatibility', [switch]$Regression, [switch]$Detail, [string[]]$TestName = @(), [ValidateSet('','winter-parity.gd','interactions.gd','road-materials.gd')][string]$ProbeName = '')
$ErrorActionPreference = 'Stop'
$auditRepo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$auditEngine = 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe'
$auditPin = [System.IO.File]::ReadAllText((Join-Path $auditRepo 'godot-version.txt')).Trim()
$auditVersion = (& $auditEngine --version | Out-String).Trim()
if ($auditVersion -ne $auditPin) { throw 'Pinned engine mismatch' }
$ErrorActionPreference = 'Continue'
$env:APPDATA = Join-Path $auditRepo 'build/track-editor-audit-2026-10-23/appdata'
$env:BMT_API_URL = 'audit-disabled'
New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
$auditArgs = @('--path', (Join-Path $auditRepo 'game'), '--audio-driver', 'Dummy')
if (-not $Graphical) { $auditArgs = @('--headless') + $auditArgs }
else { $auditArgs += @('--rendering-method', $Renderer) }
if ($Regression) {
    if ($TestName.Count -eq 0) { $TestName = @('test_editor_workflow','test_editor_preparation','test_editor_practice','test_editor_review_fixes','test_editor_incremental_objects','test_editor_remaining','test_road_pieces','test_start_line','test_local_draft_publication') }
    $auditFailed = 0
    foreach ($auditTest in $TestName) {
        & $auditEngine @auditArgs --script ('res://tests/'+$auditTest+'.gd') 2>&1 | Tee-Object -FilePath (Join-Path $PSScriptRoot ($auditTest+'.log'))
        if ($LASTEXITCODE -ne 0) { Write-Output ('AUDIT_TEST_EXIT '+$auditTest+' '+$LASTEXITCODE); $auditFailed++ }
    }
    exit $auditFailed
} else {
    $auditRun = if ($Graphical) { $Renderer } else { 'headless' }
    if ($Detail) { $auditRun += '-detail' }
    $auditScript = if ($Detail) { 'detail.gd' } else { 'audit.gd' }
    if ($ProbeName) { $auditScript = $ProbeName; $auditRun = $ProbeName.Replace('.gd','') }
    & $auditEngine @auditArgs --script (Join-Path $PSScriptRoot $auditScript) 2>&1 | Tee-Object -FilePath (Join-Path $PSScriptRoot ($auditRun+'.log'))
    exit $LASTEXITCODE
}
