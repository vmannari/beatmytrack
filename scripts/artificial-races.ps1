param(
    [string]$BatchId = "",
    [string]$RivalryId = "",
    [switch]$ListRivalries,
    [ValidateRange(1,20)][int]$MaxJobs = 1,
    [ValidateRange(0.5,8)][double]$Cpus = 1,
    [switch]$Inspect
)
$ErrorActionPreference = "Stop"
$workspaceRoot = Split-Path -Parent $PSScriptRoot
$interpreter = Join-Path $workspaceRoot ".tools/backend-venv/Scripts/python.exe"
if (-not (Test-Path -LiteralPath $interpreter)) { throw "The existing backend Python environment is required." }
$arguments = @((Join-Path $workspaceRoot "backend/deploy/local_artificial.py"), "--max-jobs", "$MaxJobs", "--cpus", $Cpus.ToString([Globalization.CultureInfo]::InvariantCulture))
if ($BatchId) { $arguments += @("--batch", $BatchId) }
if ($RivalryId) { $arguments += @("--rivalry", $RivalryId) }
if ($ListRivalries) { $arguments += "--list-rivalries" }
if ($Inspect) { $arguments += "--inspect" }
& $interpreter @arguments
if ($LASTEXITCODE -ne 0) { throw "Local artificial-race command failed. Its journal is preserved for retry." }
