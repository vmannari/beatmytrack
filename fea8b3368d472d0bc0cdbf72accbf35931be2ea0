param([ValidateSet('before','final','fi','ja','mobile')][string]$Mode = 'final')
$ErrorActionPreference = 'Stop'
$repoRoot = $PSScriptRoot
while (-not (Test-Path -LiteralPath (Join-Path $repoRoot 'scripts/dev.ps1'))) {
    $repoParent = Split-Path -Parent $repoRoot
    if ($repoParent -eq $repoRoot -or -not $repoParent) { throw 'Repository root not found' }
    $repoRoot = $repoParent
}
$env:APPDATA = Join-Path $repoRoot ('build/create-biome-height-2026-10-25/appdata-' + $Mode)
New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
$captureArguments = @('--out=res://../docs/evidence/create-biome-height-2026-10-25/' + $Mode)
if ($Mode -eq 'before') { $captureArguments += '--source=res://../docs/evidence/create-biome-height-2026-10-25/before/app.gd.txt' }
if ($Mode -in @('fi','ja')) { $captureArguments += '--locale=' + $Mode }
$renderMethod = if ($Mode -eq 'mobile') { 'mobile' } else { 'gl_compatibility' }
& (Join-Path $repoRoot 'scripts/dev.ps1') -Action TestScript -ScriptPath res://tests/capture_create_biome_height.gd -Graphical -RenderingMethod $renderMethod -TestArgument $captureArguments
