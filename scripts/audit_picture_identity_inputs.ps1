$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'build_identity.ps1')
$paths = @(
    'game/editor/view_state.gd',
    'game/editor/object_properties.gd',
    'game/localization/en.po',
    'game/ui/header_car_appearance_cache.gd',
    'game/core/app.gd',
    'game/vehicle/super_rally_model.gd',
    'game/vehicle/electric_reference_body.gd',
    'game/ui/header_icon_renderer.gd'
)
$result = @($paths | ForEach-Object {
    [pscustomobject]@{ path = $_; invalidates_all_header_pictures = (Test-HeaderPreviewSource $_) }
})
$output = Join-Path (Split-Path -Parent $PSScriptRoot) 'docs/evidence/car-picture-loading-audit-2026-11-17'
[void][IO.Directory]::CreateDirectory($output)
$result | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $output 'identity-inputs.json') -Encoding UTF8
$result | ConvertTo-Json
