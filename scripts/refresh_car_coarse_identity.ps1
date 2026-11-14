$ErrorActionPreference = 'Stop'
$coarseRepository = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'build_identity.ps1')
Write-ClientBuildIdentity $coarseRepository (Join-Path $coarseRepository 'build/car-coarse-models-2026-11-14/identity')
