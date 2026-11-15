param([string]$Receipt = 'identity')
$ErrorActionPreference = 'Stop'
$speakerRepository = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $speakerRepository 'scripts/build_identity.ps1')
Write-ClientBuildIdentity $speakerRepository (Join-Path $PSScriptRoot $Receipt)
