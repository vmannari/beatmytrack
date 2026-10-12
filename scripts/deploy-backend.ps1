<#
.SYNOPSIS
Review or update the existing retained Google Cloud backend.
.EXAMPLE
.\scripts\deploy-backend.ps1
.EXAMPLE
.\scripts\deploy-backend.ps1 -Apply
#>
[CmdletBinding()]
param(
    [switch]$Apply,
    [string]$Config = '.tools/gcp-staging/config.json',
    [string]$Python = '.tools/backend-venv/Scripts/python.exe'
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
if (-not [IO.Path]::IsPathRooted($Config)) { $Config = Join-Path $repoRoot $Config }
if (-not [IO.Path]::IsPathRooted($Python)) { $Python = Join-Path $repoRoot $Python }
if (-not (Test-Path -LiteralPath $Python -PathType Leaf)) { throw "Backend Python environment missing: $Python" }
if (-not (Test-Path -LiteralPath $Config -PathType Leaf)) { throw "Private Google Cloud configuration missing: $Config" }
$arguments = @((Join-Path $repoRoot 'backend/deploy/gcp/update.py'), '--config', $Config)
if ($Apply) { $arguments += '--apply' }
Push-Location $repoRoot
try {
    & $Python @arguments
    if ($LASTEXITCODE -ne 0) { throw "Backend deployment failed (exit $LASTEXITCODE). Inspect the reported stage before retrying." }
} finally { Pop-Location }
