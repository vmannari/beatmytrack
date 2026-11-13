param([string]$Only = '')
$ErrorActionPreference = 'Stop'
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$runs = @(
    @('focused-headless','test_scenery_mesh_lods.gd',''),
    @('focused-gl','test_scenery_mesh_lods.gd','gl_compatibility'),
    @('focused-mobile','test_scenery_mesh_lods.gd','mobile'),
    @('spatial-worker','test_spatial_worker_object_ranges.gd',''),
    @('spatial-chunks','test_spatial_mesh_chunks.gd',''),
    @('editor-objects','test_scenery_lods_editor_retention.gd','gl_compatibility'),
    @('prop-refinement','test_prop_refinement.gd',''),
    @('race-loading','test_race_loading_optimisation.gd',''),
    @('scenery-budget','test_selective_scenery_budget.gd',''),
    @('driving','test_driving.gd',''),
    @('prepared-assets','check_prepared_assets.gd','')
)
Push-Location -LiteralPath $repoRoot
try {
    foreach ($run in $runs) {
        $name = $run[0]
        if ($Only -and $name -notin $Only.Split(',')) { continue }
        $env:APPDATA = Join-Path $repoRoot "build/track-asset-optimization-20261107/$name-appdata"
        $env:LOCALAPPDATA = Join-Path $repoRoot "build/track-asset-optimization-20261107/$name-localappdata"
        $env:BMT_API_URL = 'http://127.0.0.1:1'
        $arguments = @('scripts/run_no_crash_dialog.py','--','powershell','-NoProfile','-ExecutionPolicy','Bypass','-File','scripts/dev.ps1','-Action','TestScript','-ScriptPath',"res://tests/$($run[1])",'-CommandTimeoutSeconds','600')
        if ($run[2]) {
            $driver = if ($run[2] -eq 'mobile') { 'vulkan' } else { 'opengl3' }
            $arguments += @('-Graphical','-RenderingMethod',$run[2],'-RenderingDriver',$driver)
        }
        Write-Output "SCENERY_VALIDATION_RUN $name"
        & python @arguments
        if ($LASTEXITCODE -ne 0) { throw "Scenery validation failed in $name (exit $LASTEXITCODE)" }
    }
} finally { Pop-Location }
