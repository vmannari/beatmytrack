param(
    [string]$ScriptPath = 'res://tests/review_night_brightness.gd',
    [string]$Renderer = 'gl_compatibility',
    [switch]$Graphical
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$identityPath = Join-Path $repo 'game/core/build_identity.gd'
$projectPath = Join-Path $repo 'game/project.godot'
$identityBefore = [IO.File]::ReadAllBytes($identityPath)
$versionBefore = [regex]::Match([IO.File]::ReadAllText($projectPath), '(?m)^config/version="[^"]*"').Value
$env:APPDATA = Join-Path $repo 'tmp/night-brightness-user'
$env:LOCALAPPDATA = Join-Path $env:APPDATA 'local'
$env:BMT_API_URL = ''
$env:BMT_DEV_AUTH_KEY = ''
New-Item -ItemType Directory -Path $env:APPDATA,$env:LOCALAPPDATA -Force | Out-Null
$logs = Join-Path $repo "build/logs/TestScript-$PID"
$name = [IO.Path]::GetFileNameWithoutExtension($ScriptPath) + '-' + $Renderer + '-' + $PID
$exitCode = 1
try {
    & (Join-Path $repo 'scripts/dev.ps1') -Action TestScript -ScriptPath $ScriptPath -RenderingMethod $Renderer -Graphical:$Graphical -CommandTimeoutSeconds 180
    $exitCode = $LASTEXITCODE
} finally {
    New-Item -ItemType Directory -Path (Join-Path $PSScriptRoot 'logs') -Force | Out-Null
    foreach ($leaf in @('test-script.log','client-build-identity.json')) {
        $source = Join-Path $logs $leaf
        if (Test-Path -LiteralPath $source) { Copy-Item -LiteralPath $source -Destination (Join-Path $PSScriptRoot "logs/$name-$leaf") }
    }
    $receiptPath = Join-Path $logs 'client-build-identity.json'
    if (Test-Path -LiteralPath $receiptPath) {
        $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
        if ([IO.File]::ReadAllText($identityPath).Contains('const ID: String = "' + $receipt.build_id + '"')) {
            [IO.File]::WriteAllBytes($identityPath,$identityBefore)
        }
        $projectNow = [IO.File]::ReadAllText($projectPath)
        if ([regex]::Match($projectNow, '(?m)^config/version="[^"]*"').Value -ceq ('config/version="' + $receipt.build_id + '"')) {
            [IO.File]::WriteAllText($projectPath,[regex]::Replace($projectNow,'(?m)^config/version="[^"]*"',$versionBefore),(New-Object Text.UTF8Encoding($false)))
        }
    }
    @{script=$ScriptPath;renderer=$Renderer;graphical=[bool]$Graphical;exit_code=$exitCode} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot "logs/$name-result.json") -Encoding UTF8
}
exit $exitCode
