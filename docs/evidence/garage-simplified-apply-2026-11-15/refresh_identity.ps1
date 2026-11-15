$ErrorActionPreference = 'Stop'
$simplifiedRepository = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $simplifiedRepository 'scripts/build_identity.ps1')
Write-ClientBuildIdentity $simplifiedRepository (Join-Path $PSScriptRoot 'identity')
