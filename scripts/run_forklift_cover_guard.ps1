param([string]$Stage='quality')
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repo
$env:APPDATA=Join-Path $repo 'tmp/forklift-cover-guard-user'
$env:BMT_API_URL=''
New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
$evidence=Join-Path $repo 'docs/evidence/forklift-cover-guard-variation-2026-11-03'
function Run-Check([string]$Name,[string]$Script,[string[]]$Extra=@()) {
    $arguments=@('-NoProfile','-ExecutionPolicy','Bypass','-File','scripts/dev.ps1','-Action','TestScript','-ScriptPath',$Script,'-CommandTimeoutSeconds','600')+$Extra
    & python scripts/run_no_crash_dialog.py -- powershell @arguments *> (Join-Path $evidence "$Name.log")
    $result=$LASTEXITCODE
    Get-Content -LiteralPath (Join-Path $evidence "$Name.log") -Tail 12
    if($result -ne 0) { throw "Cover/guard step $Name exited $result" }
}
switch($Stage) {
    'before' { Run-Check 'before-capture' 'res://tests/capture_forklift_kit_refinement.gd' @('-Graphical','-RenderingMethod','gl_compatibility','-TestArgument','--output=res://../docs/evidence/forklift-cover-guard-variation-2026-11-03/before-native') }
    'quality' {
        Run-Check 'construction' 'res://tests/test_forklift_kit_construction.gd' @('-TestArgument','--output=res://../docs/evidence/forklift-cover-guard-variation-2026-11-03/construction.json')
        Run-Check 'options' 'res://tests/test_forklift_kits.gd'
        Run-Check 'original' 'res://tests/test_forklift_original_cabin.gd'
        Run-Check 'retained-decks' 'res://tests/test_forklift_cover_decks.gd'
    }
    'capture' { Run-Check 'capture' 'res://tests/capture_forklift_kit_refinement.gd' @('-Graphical','-RenderingMethod','gl_compatibility','-TestArgument','--output=res://../docs/evidence/forklift-cover-guard-variation-2026-11-03/native') }
    'detail' { Run-Check 'detail' 'res://tests/capture_forklift_kit_refinement.gd' @('-Graphical','-RenderingMethod','gl_compatibility','-TestArgument','--cover-guard-detail') }
    'polish' {
        Run-Check 'construction' 'res://tests/test_forklift_kit_construction.gd' @('-TestArgument','--output=res://../docs/evidence/forklift-cover-guard-variation-2026-11-03/construction.json')
        Run-Check 'options' 'res://tests/test_forklift_kits.gd'
        Run-Check 'capture' 'res://tests/capture_forklift_kit_refinement.gd' @('-Graphical','-RenderingMethod','gl_compatibility','-TestArgument','--output=res://../docs/evidence/forklift-cover-guard-variation-2026-11-03/native')
    }
    'bake' {
        Run-Check 'bake-bases' 'res://tests/bake_modular_car_bases.gd' @('-TestArgument','--vehicle=forklift')
        Run-Check 'bake-kits' 'res://tests/bake_modular_car_kits.gd' @('-TestArgument','--vehicle=forklift')
        Run-Check 'bake-garage' 'res://tests/bake_garage_cars.gd' @('-TestArgument','--vehicle=forklift')
        Run-Check 'prepared' 'res://tests/test_forklift_prepared_kits.gd'
    }
    'gl' { Run-Check 'garage-gl' 'res://tests/test_forklift_garage.gd' @('-Graphical','-RenderingMethod','gl_compatibility','-TestArgument','--output=res://../docs/evidence/forklift-cover-guard-variation-2026-11-03/garage-gl') }
    'mobile' { Run-Check 'garage-mobile' 'res://tests/test_forklift_garage.gd' @('-Graphical','-RenderingMethod','mobile','-TestArgument','--output=res://../docs/evidence/forklift-cover-guard-variation-2026-11-03/garage-mobile') }
    default { throw "Unknown stage $Stage" }
}
