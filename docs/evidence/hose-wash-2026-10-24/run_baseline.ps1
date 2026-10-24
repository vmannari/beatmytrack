$ErrorActionPreference = 'Stop'
$hoseRepo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$hoseProject = Join-Path $hoseRepo 'build/hose-wash-2026-10-24/baseline-game'
New-Item -ItemType Directory -Force -Path $hoseProject | Out-Null
foreach ($hoseItem in Get-ChildItem (Join-Path $hoseRepo 'game') -Force) {
    $hoseTarget = Join-Path $hoseProject $hoseItem.Name
    if ($hoseItem.Name -in @('ui','vehicle','.godot')) { continue }
    if (Test-Path -LiteralPath $hoseTarget) { continue }
    if ($hoseItem.PSIsContainer) { New-Item -ItemType Junction -Path $hoseTarget -Target $hoseItem.FullName | Out-Null }
    else { Copy-Item -LiteralPath $hoseItem.FullName -Destination $hoseTarget }
}
foreach ($hoseFolder in @('ui','vehicle')) {
    Copy-Item -LiteralPath (Join-Path $hoseRepo "game/$hoseFolder") -Destination $hoseProject -Recurse -Force
}
$hoseCache = Join-Path $hoseProject '.godot'
New-Item -ItemType Directory -Force -Path $hoseCache | Out-Null
Get-ChildItem (Join-Path $hoseRepo 'game/.godot') -File | Copy-Item -Destination $hoseCache -Force
foreach ($hoseFolder in @('imported','shader_cache')) {
    $hoseTarget = Join-Path $hoseCache $hoseFolder
    if (-not (Test-Path -LiteralPath $hoseTarget)) { New-Item -ItemType Junction -Path $hoseTarget -Target (Join-Path $hoseRepo "game/.godot/$hoseFolder") | Out-Null }
}
foreach ($hoseFile in @('ui/car_showroom.gd','ui/garage_page.gd','ui/garage_wash_effect.gd','ui/garage_wash_geometry.gd','vehicle/vehicle_weathering.gd')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('before/game/'+$hoseFile)) -Destination (Join-Path $hoseProject $hoseFile) -Force
}
$env:APPDATA = Join-Path $hoseRepo 'build/hose-wash-2026-10-24/baseline-user'
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
$hoseEngine = 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe'
if ((& $hoseEngine --version).Trim() -ne (Get-Content (Join-Path $hoseRepo 'godot-version.txt') -Raw).Trim()) { throw 'Wrong engine.' }
$hoseArguments = @('--path',$hoseProject,'--rendering-method','gl_compatibility','--rendering-driver','opengl3','--script','res://tests/test_garage_wash_animation.gd','--','--evidence-root='+(Join-Path $PSScriptRoot 'baseline-animation'))
& $hoseEngine @hoseArguments *> (Join-Path $PSScriptRoot 'baseline-animation.log')
$hoseCode = $LASTEXITCODE
@{command = $hoseEngine; arguments = $hoseArguments; exit_code = $hoseCode; source = 'Exact task-start copies of all five changed runtime scripts; other dependencies shared with current workspace.'} | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 (Join-Path $PSScriptRoot 'baseline-animation-command.json')
Get-Content (Join-Path $PSScriptRoot 'baseline-animation.log') -Tail 12
exit $hoseCode
