param(
    [string]$ScriptPath = 'res://tests/bake_boot_logo.gd',
    [string]$Phase = 'after',
    [string]$Renderer = 'gl_compatibility',
    [ValidateSet('TestScript','Import')][string]$Action = 'TestScript',
    [switch]$Headless
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$identityPath = Join-Path $repo 'game/core/build_identity.gd'
$projectPath = Join-Path $repo 'game/project.godot'
$identityBytes = [IO.File]::ReadAllBytes($identityPath)
$projectBefore = [IO.File]::ReadAllText($projectPath)
$previousVersion = [regex]::Match($projectBefore, '(?m)^config/version="[^"]*"').Value
$taskRoot = Join-Path $repo 'build/logo-tire-width-review'
New-Item -ItemType Directory -Path $taskRoot -Force | Out-Null
$env:APPDATA = Join-Path $taskRoot 'profile'
$env:LOCALAPPDATA = Join-Path $taskRoot 'local-profile'
$env:BMT_API_URL = ''
$env:BMT_MENU_LOGO_OUTPUT = Join-Path $PSScriptRoot "$Phase/$Renderer"
$receiptPath = Join-Path $repo "build/logs/$Action-$PID/client-build-identity.json"
try {
    & (Join-Path $repo 'scripts/dev.ps1') -Action $Action -ScriptPath $ScriptPath -Graphical:(-not $Headless) -RenderingMethod $Renderer -CommandTimeoutSeconds 180
    if ($LASTEXITCODE) { throw "Review command failed: $LASTEXITCODE" }
} finally {
    $logName = if ($Action -eq 'Import') { 'import.log' } else { 'test-script.log' }
    $logPath = Join-Path $repo "build/logs/$Action-$PID/$logName"
    if (Test-Path -LiteralPath $logPath) {
        $logDirectory = Join-Path $PSScriptRoot 'logs'
        New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
        Copy-Item -LiteralPath $logPath -Destination (Join-Path $logDirectory "run-$PID.log")
    }
    # Restore only this run's generated metadata; preserve concurrent source edits.
    if (Test-Path -LiteralPath $receiptPath) {
        $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
        Copy-Item -LiteralPath $receiptPath -Destination (Join-Path $PSScriptRoot "logs/run-$PID-identity.json")
        $identityNow = [IO.File]::ReadAllText($identityPath)
        if ($identityNow.Contains('const ID: String = "' + $receipt.build_id + '"')) {
            [IO.File]::WriteAllBytes($identityPath, $identityBytes)
        }
        $projectNow = [IO.File]::ReadAllText($projectPath)
        $generatedVersion = 'config/version="' + $receipt.build_id + '"'
        if ([regex]::Match($projectNow, '(?m)^config/version="[^"]*"').Value -ceq $generatedVersion) {
            $restored = [regex]::Replace($projectNow, '(?m)^config/version="[^"]*"', $previousVersion)
            if ($restored -cne $projectNow) {
                [IO.File]::WriteAllText($projectPath, $restored, (New-Object Text.UTF8Encoding($false)))
            }
        }
    }
}
