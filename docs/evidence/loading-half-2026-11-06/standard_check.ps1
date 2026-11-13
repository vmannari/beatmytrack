param([string]$ReceiptName = 'standard-feature-parse-checked.log')
$ErrorActionPreference = 'Stop'
if ([IO.Path]::GetFileName($ReceiptName) -ne $ReceiptName) { throw 'Receipt must be a local filename.' }
$receiptPath = Join-Path $PSScriptRoot $ReceiptName
if (Test-Path -LiteralPath $receiptPath) { throw 'Choose a fresh receipt filename.' }
$taskRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
Set-Location -LiteralPath $taskRoot
$env:GIT_OPTIONAL_LOCKS = '0'
$env:APPDATA = Join-Path $taskRoot 'build/loading-half-20261106/standard-checked-profile/appdata'
$env:LOCALAPPDATA = Join-Path $taskRoot 'build/loading-half-20261106/standard-checked-profile/localappdata'
$env:BMT_API_URL = ''
Remove-Item Env:BMT_DEV_AUTH_KEY -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force (Join-Path $env:APPDATA 'Circuit01Lab'), $env:LOCALAPPDATA | Out-Null
Set-Content -LiteralPath (Join-Path $env:APPDATA 'Circuit01Lab/backend.cfg') -Value "[backend]`nurl=`"`"" -Encoding UTF8
& powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_startup_feature_parse.gd -CommandTimeoutSeconds 150 *> $receiptPath
exit $LASTEXITCODE
