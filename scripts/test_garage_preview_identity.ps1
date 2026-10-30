[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'build_identity.ps1')
$fixtureRoot = Join-Path (Split-Path -Parent $PSScriptRoot) ('build/garage-identity-fixture-' + [guid]::NewGuid().ToString('N'))
$encoding = New-Object System.Text.UTF8Encoding($false)
function Set-FixtureFile([string]$Path, [string]$Value) {
    $full = Join-Path $fixtureRoot $Path
    [System.IO.Directory]::CreateDirectory((Split-Path -Parent $full)) | Out-Null
    [System.IO.File]::WriteAllText($full, $Value, $encoding)
}
Set-FixtureFile 'game/project.godot' "[application]`nconfig/base_version=`"fixture`"`nconfig/version=`"old`"`n"
Set-FixtureFile 'game/export_presets.cfg' "exclude_filter=`"tests/*`"`nversion/name=`"`"`n"
foreach ($vehicle in @(Get-GaragePreviewVehicleIds)) {
    Set-FixtureFile "game/assets/garage/cars_v1/$vehicle.scn" "model $vehicle"
    Set-FixtureFile "game/assets/garage/previews_v1/$vehicle.png" "picture $vehicle"
    Set-FixtureFile "game/resources/cars/$vehicle.tres" "configuration $vehicle"
}
Set-FixtureFile 'game/vehicle/electric_reference_body.gd' '# electric body'
Set-FixtureFile 'game/vehicle/compact_glazing.gd' '# shared windows'
Set-FixtureFile 'game/ui/garage_reflections.gd' '# room lighting'
Set-FixtureFile 'game/assets/vehicles/electric_reference_mesh.bin' 'mesh bytes'
& git -C $fixtureRoot init -q
if ($LASTEXITCODE) { throw 'Fixture Git initialization failed.' }
function Get-Hashes {
    Write-ClientBuildIdentity $fixtureRoot $fixtureRoot | Out-Null
    return (Get-Content -Raw (Join-Path $fixtureRoot 'client-build-identity.json') | ConvertFrom-Json).garage_preview_vehicle_sha256
}
function Assert-Changed($Before, $After, [string[]]$Expected, [string]$Label) {
    foreach ($vehicle in @(Get-GaragePreviewVehicleIds)) {
        $changed = $Before.$vehicle -cne $After.$vehicle
        if ($changed -ne ($vehicle -in $Expected)) { throw "$Label produced an unexpected change for $vehicle" }
    }
}
$all = @(Get-GaragePreviewVehicleIds)
$before = Get-Hashes
$stable = Get-Hashes
Assert-Changed $before $stable @() 'identical inputs'
Set-FixtureFile 'game/assets/garage/cars_v1/electric.scn' 'revised electric model'
$after = Get-Hashes
Assert-Changed $stable $after @('electric') 'one baked model'
$stable = $after
Set-FixtureFile 'game/resources/cars/kart.tres' 'revised kart config'
$after = Get-Hashes
Assert-Changed $stable $after @('kart') 'one car config'
$stable = $after
Set-FixtureFile 'game/assets/garage/previews_v1/hovercraft.png' 'revised hovercraft stock image'
$after = Get-Hashes
Assert-Changed $stable $after @('hovercraft') 'one stock picture'
$stable = $after
Set-FixtureFile 'game/vehicle/electric_reference_body.gd' '# revised electric body'
$after = Get-Hashes
Assert-Changed $stable $after $all 'model-source provenance affects all template guards'
$stable = $after
Set-FixtureFile 'game/vehicle/new_uncategorized.gd' '# unknown vehicle dependency'
$after = Get-Hashes
Assert-Changed $stable $after $all 'unknown vehicle dependencies stay shared'
$stable = $after
Set-FixtureFile 'game/assets/vehicles/electric_reference_mesh.bin' 'revised mesh bytes'
$after = Get-Hashes
Assert-Changed $stable $after $all 'mesh assets stay shared'
$stable = $after
Set-FixtureFile 'game/ui/garage_reflections.gd' '# revised room lighting'
$after = Get-Hashes
Assert-Changed $stable $after $all 'shared room change'
$stable = $after
Set-FixtureFile 'game/ui/new_unknown_visual.gd' '# newly introduced visual dependency'
$after = Get-Hashes
Assert-Changed $stable $after $all 'unknown visual dependencies stay shared'
$stable = $after
Set-FixtureFile 'game/ui/garage_page.gd' '# changed menu label'
$after = Get-Hashes
Assert-Changed $stable $after @() 'nonvisual Garage page'
Write-Host 'GARAGE_PREVIEW_IDENTITY: 80 vehicle/hash checks passed; isolated fixture retained in build/.'
