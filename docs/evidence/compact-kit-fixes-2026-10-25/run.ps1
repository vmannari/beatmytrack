param(
    [ValidateSet('attachments','baseline','source','construction','geometry','geometrysource','catalog','aero','incremental','focus','speed','bake','photos','capture','parser','import')][string]$Job='attachments',
    [ValidateSet('gl_compatibility','mobile')][string]$Renderer='gl_compatibility',
    [ValidateSet('hood','aero','body')][string]$Category='hood',
    [string]$Attempt=''
)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
Set-Location -LiteralPath $repo
$env:APPDATA=Join-Path $repo 'build/compact-kit-fixes/appdata'
$env:LOCALAPPDATA=Join-Path $repo 'build/compact-kit-fixes/localappdata'
New-Item -ItemType Directory -Force $env:APPDATA,$env:LOCALAPPDATA | Out-Null
$scripts=@{attachments='test_compact_kit_attachments.gd';baseline='test_compact_kit_attachments.gd';source='test_compact_kit_attachments.gd';construction='test_compact_kit_construction.gd';geometry='test_compact_kit_geometry.gd';geometrysource='test_compact_kit_geometry.gd';catalog='test_expanded_compact_catalog.gd';aero='test_compact_aero_variety.gd';incremental='test_incremental_compact_kits.gd';focus='test_customisation_carousel.gd';speed='test_garage_customisation_speed.gd';bake='bake_compact_kit_previews.gd';photos='bake_compact_kit_previews.gd';capture='capture_compact_kit_review.gd';parser='test_script_parse.gd'}
$folder="$Job-$Renderer$Attempt"
if ($Job -in @('bake','photos')) {$folder+="-$Category"}
$arguments=@("--evidence-root=res://../docs/evidence/compact-kit-fixes-2026-10-25/$folder")
if ($Job -in @('source','geometrysource')) {$arguments+='--source'}
if ($Job -in @('geometry','geometrysource')) {$arguments+='--parts-only'}
if ($Job -in @('bake','photos')) {
    $ids=@{hood='dome,vented';aero='lip';body='rally,club,heritage,wide,endurance,gravel'}
    $arguments+=@("--category=$Category","--ids=$($ids[$Category])")
}
if ($Job -eq 'photos') {$arguments+='--photos-only'}
$parameters=@{ScriptPath="res://tests/$($scripts[$Job])";Graphical=($Job -in @('attachments','baseline','focus','speed','bake','photos','capture'));RenderingMethod=$Renderer;TestArgument=$arguments;CommandTimeoutSeconds=600}
if ($Renderer -eq 'mobile') {$parameters.RenderingDriver='vulkan'}
$result=0
try {
    if ($Job -eq 'import') {& ./scripts/dev.ps1 Import}
    else {& ./scripts/dev.ps1 TestScript @parameters}
    $result=$LASTEXITCODE
} catch {Write-Host $_; $result=1}
$action=if ($Job -eq 'import') {'Import'} else {'TestScript'}
$name=if ($Job -eq 'import') {'import.log'} else {'test-script.log'}
$log="$repo/build/logs/$action-$PID/$name"
if (Test-Path -LiteralPath $log) {Copy-Item -LiteralPath $log -Destination "$PSScriptRoot/$folder.log"}
@{job=$Job;renderer=$Renderer;category=$Category;script=$scripts[$Job];arguments=$arguments;exit_code=$result;log="build/logs/$action-$PID/$name"}|ConvertTo-Json|Set-Content "$PSScriptRoot/$folder-command.json"
exit $result
