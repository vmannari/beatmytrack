$ErrorActionPreference = 'Stop'
$detailRepository = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'build_identity.ps1')
$detailWork = if ($env:BMT_CAR_BUDGET_WORK_DIR) { $env:BMT_CAR_BUDGET_WORK_DIR } else { 'build/car-10k-models-2026-11-14' }
Write-ClientBuildIdentity $detailRepository (Join-Path $detailRepository ($detailWork + '/identity'))
