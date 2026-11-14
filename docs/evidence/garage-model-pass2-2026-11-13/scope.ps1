$ErrorActionPreference = 'Stop'
. ./scripts/build_identity.ps1
$previewInputs = @('game/ui/garage_mesh_cleanup.gd','game/rendering/mesh_vertex_packing.gd')
foreach ($path in $previewInputs) {
    if (-not (Test-GaragePreviewSource $path)) { throw "Missing Garage preview dependency: $path" }
    if (@(Get-ModularCarVehicles $path).Count -ne 0) { throw "Garage helper unexpectedly changes vehicle identities: $path" }
}
'GARAGE_IDENTITY_SCOPE: 4 checks, 0 failures'
