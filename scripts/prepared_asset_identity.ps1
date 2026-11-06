# Match game/vehicle/prepared_asset_sources.gd; keep one source of routing rules.
$script:PreparedAssetDependencies = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot '../game/vehicle/prepared_asset_dependencies.json') | ConvertFrom-Json
if ($script:PreparedAssetDependencies.schema -cne 'prepared-asset-dependencies-1') { throw 'Invalid prepared asset dependency manifest.' }
function Get-PreparedAssetVehicles([string]$Relative) {
    foreach ($pattern in $script:PreparedAssetDependencies.excluded) { if ($Relative -clike $pattern) { return @() } }
    foreach ($rule in $script:PreparedAssetDependencies.rules) { if ($Relative -clike $rule.pattern) { return @($rule.vehicles) } }
    if ($Relative -cmatch '^game/resources/cars/([^/]+)\.tres$' -and $Matches[1] -in $script:PreparedAssetDependencies.vehicles) { return @($Matches[1]) }
    if ($Relative -cmatch '^game/(vehicle/|assets/(vehicles/|liveries/|fonts/)|resources/)' -or
        $Relative -cmatch '^game/track/[^/]+\.gdshader(inc)?$' -or
        $Relative -in @('godot-version.txt','scripts/prepared_asset_identity.ps1')) { return @($script:PreparedAssetDependencies.vehicles) }
    return @()
}
