# Source boundaries for saved Garage pictures. Unknown dependencies stay shared.
# The rest-template provenance currently includes every model builder, so none
# of those scripts is classified as vehicle-local here.
function Get-GaragePreviewVehicleIds {
    return @('compact', 'pickup', 'classic', 'formula', 'kart', 'forklift', 'electric', 'hovercraft', 'super_rally')
}

function Get-GaragePreviewVehicles([string]$Relative) {
    # New visual files are shared by default, rather than silently omitted.
    # These narrowly excluded files cannot affect the captured showroom.
    if ($Relative -match '^game/(backend/|diagnostics/|music/|localization/|core/features/|assets/menu/header_car_templates_v1/)' -or
        ($Relative -match '^game/soundtrack/' -and $Relative -ne 'game/soundtrack/record_library.gd') -or
        $Relative -in @('game/core/app.gd', 'game/ui/garage_page.gd', 'game/ui/garage_preloader.gd',
            'game/ui/own_profile_page.gd', 'game/ui/achievements_menu.gd', 'game/ui/achievement_badge.gd',
            'game/ui/profile_car.gd', 'game/ui/header_car_picker.gd', 'game/ui/header_car_motion.gd',
            'game/ui/track_of_day_page.gd', 'game/ui/menu_page_swipe.gd', 'game/persistence/local_records.gd')) { return @() }
    if ($Relative -notmatch '^(game/|native/)' -and $Relative -ne 'godot-version.txt') { return @() }
    $vehicles = @(Get-GaragePreviewVehicleIds)
    # Only resources consumed by one named car are separated. Source files,
    # shader and unknown paths retain the shared fallback, including all model
    # builders used by the Garage rest-template provenance check.
    if ($Relative -match '^game/assets/garage/(cars_v1|previews_v1)/(compact|pickup|classic|formula|kart|forklift|electric|hovercraft|super_rally)\.(scn|png)(\.import)?$') {
        if ($Matches[2] -eq 'compact') { return @('compact', 'super_rally') }
        return @($Matches[2])
    }
    if ($Relative -match '^game/resources/cars/(compact|pickup|classic|formula|kart|forklift|electric|hovercraft|super_rally)\.tres$') {
        return @($Matches[1])
    }
    return $vehicles
}
