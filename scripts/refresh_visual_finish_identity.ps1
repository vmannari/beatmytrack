$ErrorActionPreference = 'Stop'
$visualFinishRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'build_identity.ps1')
Write-ClientBuildIdentity $visualFinishRoot (Join-Path $visualFinishRoot 'build/visual-fixes-2026-11-13/identity')
