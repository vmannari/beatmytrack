param([string]$ScriptPath, [switch]$Graphical)
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$source = Join-Path $PSScriptRoot 'source'
$env:GIT_DIR = Join-Path $repoRoot '.git'
$env:GIT_WORK_TREE = $source
& (Join-Path $source 'scripts/dev.ps1') -Action TestScript -ScriptPath $ScriptPath -Graphical:$Graphical -CommandTimeoutSeconds 600
exit $LASTEXITCODE
