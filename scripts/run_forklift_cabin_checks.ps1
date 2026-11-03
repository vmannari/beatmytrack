param([string]$Stage = 'geometry')
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repo
$env:APPDATA = Join-Path $repo 'tmp/forklift-cabin-user'
$env:BMT_API_URL = ''
New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
$evidence = Join-Path $repo 'docs/evidence/forklift-cabin-kits-2026-11-02'
function Run-ForkliftCheck([string]$Name, [string]$Script, [string[]]$Extra = @()) {
    $argsForCheck = @('-NoProfile','-ExecutionPolicy','Bypass','-File','scripts/dev.ps1','-Action','TestScript','-ScriptPath',$Script,'-CommandTimeoutSeconds','480') + $Extra
    & python scripts/run_no_crash_dialog.py -- powershell @argsForCheck *> (Join-Path $evidence "$Name.log")
    $code = $LASTEXITCODE
    Get-Content -LiteralPath (Join-Path $evidence "$Name.log") -Tail 12
    if ($code -ne 0) { throw "Forklift step $Name exited $code" }
}
switch ($Stage) {
    'geometry' {
        Run-ForkliftCheck 'kits-final' 'res://tests/test_forklift_kits.gd'
        Run-ForkliftCheck 'original' 'res://tests/test_forklift_original_cabin.gd'
        Run-ForkliftCheck 'retained-model' 'res://tests/test_forklift_model_finish.gd' @('-TestArgument','--evidence-dir=res://../docs/evidence/forklift-cabin-kits-2026-11-02/retained-model')
    }
    'bake' {
        Run-ForkliftCheck 'bake-bases' 'res://tests/bake_modular_car_bases.gd' @('-TestArgument','--vehicle=forklift')
        Run-ForkliftCheck 'bake-kits' 'res://tests/bake_modular_car_kits.gd' @('-TestArgument','--vehicle=forklift')
        Run-ForkliftCheck 'bake-garage' 'res://tests/bake_garage_cars.gd' @('-TestArgument','--vehicle=forklift')
        Run-ForkliftCheck 'prepared' 'res://tests/test_forklift_prepared_kits.gd'
    }
    'gl' { Run-ForkliftCheck 'garage-gl-final' 'res://tests/test_forklift_garage.gd' @('-Graphical','-RenderingMethod','gl_compatibility','-TestArgument','--output=res://../docs/evidence/forklift-cabin-kits-2026-11-02/garage-gl-final') }
    'original' { Run-ForkliftCheck 'original-corrected' 'res://tests/test_forklift_original_cabin.gd' }
    'mobile' {
        Run-ForkliftCheck 'garage-mobile-final' 'res://tests/test_forklift_garage.gd' @('-Graphical','-RenderingMethod','mobile','-TestArgument','--output=res://../docs/evidence/forklift-cabin-kits-2026-11-02/garage-mobile-final')
        Run-ForkliftCheck 'retained-model' 'res://tests/test_forklift_model_finish.gd' @('-TestArgument','--evidence-dir=res://../docs/evidence/forklift-cabin-kits-2026-11-02/retained-model')
    }
    default { throw "Unknown stage: $Stage" }
}
