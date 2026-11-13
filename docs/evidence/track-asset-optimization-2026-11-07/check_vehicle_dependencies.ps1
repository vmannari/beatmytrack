$ErrorActionPreference = 'Stop'
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
. (Join-Path $repoRoot 'scripts/prepared_asset_identity.ps1')
$paths = @('game/track/creator_prop_visual.gd','game/track/prop_geometry.gd','game/track/native_track_visual.gd','game/track/spatial_mesh_chunks.gd','game/track/spatial_mesh_preparation.gd','game/track/prepared_world_cache.gd','game/editor/cache_bytes.gd','game/track/scenery_mesh_lods.gd','game/assets/scenery_lods_v1/ice_compact.res','game/assets/scenery_lods_v1/snow_castle.res','game/assets/scenery_lods_v1/container.res')
foreach ($path in $paths) {
    $vehicles = @(Get-PreparedAssetVehicles $path)
    if ($vehicles.Count -gt 0) { throw "Unexpected prepared-car identity dependency: $path" }
}
$paths | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'vehicle-identity-independent-paths.json') -Encoding UTF8
Write-Output 'All 11 production task paths are outside prepared-car identity inputs.'
