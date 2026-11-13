$ErrorActionPreference = 'Stop'
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
Push-Location -LiteralPath $repoRoot
try {
    foreach ($mode in @('inventory','gl_compatibility','mobile')) {
        $env:APPDATA = Join-Path $repoRoot "build/track-asset-review-20261107/final-$mode-appdata"
        $env:LOCALAPPDATA = Join-Path $repoRoot "build/track-asset-review-20261107/final-$mode-localappdata"
        $env:BMT_BACKEND_URL = 'http://127.0.0.1:1'
        $arguments = @('scripts/run_no_crash_dialog.py','--','powershell','-NoProfile','-ExecutionPolicy','Bypass','-File','scripts/dev.ps1','-Action','TestScript','-ScriptPath','res://tests/review_track_asset_simplification_2026_11_07.gd','-CommandTimeoutSeconds','600')
        if ($mode -ne 'inventory') {
            $driver = if ($mode -eq 'mobile') { 'vulkan' } else { 'opengl3' }
            $arguments += @('-Graphical','-RenderingMethod',$mode,'-RenderingDriver',$driver)
        }
        & python @arguments
        if ($LASTEXITCODE -ne 0) { throw "Track asset review failed in $mode (exit $LASTEXITCODE)" }
    }
} finally {
    Pop-Location
}
