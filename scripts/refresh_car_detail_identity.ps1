$ErrorActionPreference = 'Stop'
$detailRepository = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'build_identity.ps1')
Write-ClientBuildIdentity $detailRepository (Join-Path $detailRepository 'build/car-detail-reduction-2026-11-14/identity')
