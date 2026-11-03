param([string]$Stage = 'geometry')
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repo
$env:APPDATA = Join-Path $repo 'tmp/forklift-refinement-user'
$env:BMT_API_URL = ''
New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
$evidence = Join-Path $repo 'docs/evidence/forklift-kit-refinement-2026-11-02'
function Run-Refinement([string]$Name, [string]$Script, [string[]]$Extra = @()) {
    $arguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File','scripts/dev.ps1','-Action','TestScript','-ScriptPath',$Script,'-CommandTimeoutSeconds','600') + $Extra
    & python scripts/run_no_crash_dialog.py -- powershell @arguments *> (Join-Path $evidence "$Name.log")
    $result = $LASTEXITCODE
    Get-Content -LiteralPath (Join-Path $evidence "$Name.log") -Tail 16
    if ($result -ne 0) { throw "Refinement step $Name exited $result" }
}
switch ($Stage) {
    'geometry' {
        Run-Refinement 'options' 'res://tests/test_forklift_kits.gd'
        Run-Refinement 'original' 'res://tests/test_forklift_original_cabin.gd'
    }
    'quality' { Run-Refinement 'construction' 'res://tests/test_forklift_kit_construction.gd' }
    'quality-final' { Run-Refinement 'construction-final' 'res://tests/test_forklift_kit_construction.gd' }
    'edge-review' {
        Run-Refinement 'construction-edge-final' 'res://tests/test_forklift_kit_construction.gd'
        Run-Refinement 'review-edge-final' 'res://tests/capture_forklift_kit_refinement.gd' @('-Graphical','-RenderingMethod','gl_compatibility','-TestArgument','--output=res://../docs/evidence/forklift-kit-refinement-2026-11-02/review-edge-final')
    }
    'wheel-fit' {
        Run-Refinement 'options-wheel-fit' 'res://tests/test_forklift_kits.gd'
        Run-Refinement 'original-wheel-fit' 'res://tests/test_forklift_original_cabin.gd'
        Run-Refinement 'construction-wheel-fit' 'res://tests/test_forklift_kit_construction.gd'
    }
    'seams' { Run-Refinement 'seams' 'res://tests/probe_forklift_kit_seams.gd' }
    'capture' { Run-Refinement 'review-gl' 'res://tests/capture_forklift_kit_refinement.gd' @('-Graphical','-RenderingMethod','gl_compatibility') }
    'capture-before' { Run-Refinement 'review-before' 'res://tests/capture_forklift_kit_refinement.gd' @('-Graphical','-RenderingMethod','gl_compatibility','-TestArgument','--before') }
    'review' {
        Run-Refinement 'review-final' 'res://tests/capture_forklift_kit_refinement.gd' @('-Graphical','-RenderingMethod','gl_compatibility','-TestArgument','--output=res://../docs/evidence/forklift-kit-refinement-2026-11-02/review-final')
        Run-Refinement 'review-before' 'res://tests/capture_forklift_kit_refinement.gd' @('-Graphical','-RenderingMethod','gl_compatibility','-TestArgument','--before')
    }
    'bake' {
        Run-Refinement 'options-final' 'res://tests/test_forklift_kits.gd'
        Run-Refinement 'original-final' 'res://tests/test_forklift_original_cabin.gd'
        Run-Refinement 'bake-bases' 'res://tests/bake_modular_car_bases.gd' @('-TestArgument','--vehicle=forklift')
        Run-Refinement 'bake-kits' 'res://tests/bake_modular_car_kits.gd' @('-TestArgument','--vehicle=forklift')
        Run-Refinement 'bake-garage' 'res://tests/bake_garage_cars.gd' @('-TestArgument','--vehicle=forklift')
        Run-Refinement 'prepared' 'res://tests/test_forklift_prepared_kits.gd'
    }
    'gl' { Run-Refinement 'garage-gl' 'res://tests/test_forklift_garage.gd' @('-Graphical','-RenderingMethod','gl_compatibility','-TestArgument','--output=res://../docs/evidence/forklift-kit-refinement-2026-11-02/garage-gl') }
    'mobile' {
        Run-Refinement 'garage-mobile' 'res://tests/test_forklift_garage.gd' @('-Graphical','-RenderingMethod','mobile','-TestArgument','--output=res://../docs/evidence/forklift-kit-refinement-2026-11-02/garage-mobile')
        Run-Refinement 'retained-model' 'res://tests/test_forklift_model_finish.gd' @('-TestArgument','--evidence-dir=res://../docs/evidence/forklift-kit-refinement-2026-11-02/retained-model')
    }
    default { throw "Unknown refinement stage: $Stage" }
}
