$ErrorActionPreference = 'Stop'
$modelRefinementRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'build_identity.ps1')
Write-ClientBuildIdentity $modelRefinementRoot (Join-Path $modelRefinementRoot 'build/car-model-refinement-2026-11-12/identity')
