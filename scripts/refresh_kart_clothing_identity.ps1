$ErrorActionPreference = 'Stop'
$kartClothingRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'build_identity.ps1')
Write-ClientBuildIdentity $kartClothingRoot (Join-Path $kartClothingRoot 'build/kart-clothing-2026-11-14/identity')
