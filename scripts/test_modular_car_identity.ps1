[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'build_identity.ps1')

# The fixture owns its own Git repository and build files; no workspace index,
# generated shipping identities or player files are touched.
$fixture = Join-Path (Split-Path -Parent $PSScriptRoot) ('build/modular-identity-fixture-' + [guid]::NewGuid().ToString('N'))
$encoding = New-Object System.Text.UTF8Encoding($false)
$script:ModularIdentityChecks = 0
function Set-FixtureFile([string]$Relative, [string]$Value) {
    $path = Join-Path $fixture $Relative
    [System.IO.Directory]::CreateDirectory((Split-Path -Parent $path)) | Out-Null
    [System.IO.File]::WriteAllText($path, $Value, $encoding)
}
function Get-FixtureIdentity {
    Write-ClientBuildIdentity $fixture $fixture | Out-Null
    return Get-Content -Raw -LiteralPath (Join-Path $fixture 'client-build-identity.json') | ConvertFrom-Json
}
function Assert-Changed($Before, $After, [string[]]$Expected, [string]$Label) {
    foreach ($vehicle in @(Get-GaragePreviewVehicleIds)) {
        $script:ModularIdentityChecks++
        $changed = $Before.modular_car_sha256.$vehicle -cne $After.modular_car_sha256.$vehicle
        if ($changed -ne ($vehicle -in $Expected)) { throw "$Label produced an unexpected modular revision for $vehicle" }
    }
}

Set-FixtureFile 'game/project.godot' "[application]`nconfig/base_version=`"fixture`"`nconfig/version=`"old`"`n"
Set-FixtureFile 'game/export_presets.cfg' "exclude_filter=`"tests/*`"`nversion/name=`"`"`n"
Set-FixtureFile 'game/vehicle/electric_reference_mesh.gd' '# electric source'
Set-FixtureFile 'game/vehicle/racing_car_models.gd' '# shared racer source'
Set-FixtureFile 'game/assets/vehicles/electric_subtle_fenders_v1/mesh.res' 'mesh initial'
Set-FixtureFile 'game/assets/vehicles/racing_simple_v1/electric_shadow_0.res' 'electric shadow initial'
Set-FixtureFile 'game/assets/vehicles/racing_simple_v1/forklift_shadow_0.res' 'forklift shadow initial'
Set-FixtureFile 'game/assets/vehicles/racing_simple_v1/manifest.json' 'manifest initial'
Set-FixtureFile 'game/assets/vehicles/electric_unknown_shared/mesh.res' 'unknown initial'
Set-FixtureFile 'game/assets/vehicles/modular_car_bases_v1/compact.scn' 'generated base initial'
Set-FixtureFile 'game/assets/vehicles/modular_kits_v1/kart/module.scn' 'generated kit initial'
Set-FixtureFile 'game/resources/cars/kart.tres' 'kart initial'
& git -C $fixture init -q
if ($LASTEXITCODE -ne 0) { throw 'Could not initialize isolated fixture repository.' }

$all = @(Get-GaragePreviewVehicleIds)
$before = Get-FixtureIdentity
$after = Get-FixtureIdentity
Assert-Changed $before $after @() 'identical inputs'

$before = $after
Set-FixtureFile 'game/assets/vehicles/electric_subtle_fenders_v1/mesh.res' 'mesh changed'
$after = Get-FixtureIdentity
Assert-Changed $before $after @('electric') 'Electric prepared mesh'

$before = $after
Set-FixtureFile 'game/assets/vehicles/racing_simple_v1/electric_shadow_0.res' 'electric shadow changed'
$after = Get-FixtureIdentity
Assert-Changed $before $after @('electric') 'Electric shadow proxy'

$before = $after
Set-FixtureFile 'game/assets/vehicles/racing_simple_v1/forklift_shadow_0.res' 'forklift shadow changed'
$after = Get-FixtureIdentity
Assert-Changed $before $after @('forklift') 'Forklift shadow input'

$before = $after
Set-FixtureFile 'game/assets/vehicles/racing_simple_v1/manifest.json' 'manifest changed'
$after = Get-FixtureIdentity
Assert-Changed $before $after @() 'offline provenance manifest'
if ($before.source_sha256 -ceq $after.source_sha256) { throw 'The complete build identity must still include the manifest.' }

$before = $after
Set-FixtureFile 'game/assets/vehicles/electric_unknown_shared/mesh.res' 'unknown changed'
$after = Get-FixtureIdentity
Assert-Changed $before $after $all 'unknown similarly named directory'

$before = $after
Set-FixtureFile 'game/vehicle/electric_reference_mesh.gd' '# electric source changed'
$after = Get-FixtureIdentity
Assert-Changed $before $after @('electric') 'Electric builder is vehicle-local'

$before = $after
Set-FixtureFile 'game/vehicle/compact_detail.gd' '# shared tyre helper changed'
$after = Get-FixtureIdentity
Assert-Changed $before $after @('compact','electric','forklift') 'shared tyre helper retains actual consumers'

$before = $after
Set-FixtureFile 'game/vehicle/compact_finish.gd' '# shared finish changed'
$after = Get-FixtureIdentity
Assert-Changed $before $after @('compact','kart','electric','forklift','hovercraft') 'shared finish retains all actual consumers'

$before = $after
Set-FixtureFile 'game/vehicle/electric_glass.gdshader' '# shared glass changed'
$after = Get-FixtureIdentity
Assert-Changed $before $after @('electric','hovercraft') 'Hover keeps its Electric glass dependency'

$before = $after
Set-FixtureFile 'game/assets/vehicles/modular_car_bases_v1/compact.scn' 'generated base changed'
Set-FixtureFile 'game/assets/vehicles/modular_kits_v1/kart/module.scn' 'generated kit changed'
$after = Get-FixtureIdentity
Assert-Changed $before $after @() 'generated scenes excluded from modular identity'
if ($before.source_sha256 -ceq $after.source_sha256) { throw 'The complete build identity must still include generated scenes.' }

$before = $after
Set-FixtureFile 'game/resources/cars/kart.tres' 'kart changed'
$after = Get-FixtureIdentity
Assert-Changed $before $after @('kart') 'per-car handling resource'

$before = $after
Set-FixtureFile 'game/assets/garage/cars_v1/compact.scn' 'generated Garage template changed'
$after = Get-FixtureIdentity
Assert-Changed $before $after @() 'Garage output cannot change geometry or header-template revisions'

$before = $after
Set-FixtureFile 'game/ui/header_simple_cache.gd' '# header rest schema changed'
$after = Get-FixtureIdentity
Assert-Changed $before $after @('compact') 'header template helper'

$before = $after
Set-FixtureFile 'game/ui/garage_car_cache.gd' '# shared Garage rest schema changed'
$after = Get-FixtureIdentity
Assert-Changed $before $after $all 'Garage template helper'

$before = $after
Set-FixtureFile 'game/vehicle/new_geometry_helper.gd' '# unknown geometry stays shared'
$after = Get-FixtureIdentity
Assert-Changed $before $after $all 'unknown helper remains conservative'

Write-Host "MODULAR_CAR_IDENTITY: $script:ModularIdentityChecks vehicle/hash checks and 2 complete-identity checks passed; isolated fixture retained in build."
