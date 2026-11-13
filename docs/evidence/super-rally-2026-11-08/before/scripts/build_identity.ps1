# Deterministic client identity, including uncommitted shipping sources.
# Dot-source from dev.ps1; no network, credentials or player files are read.
. (Join-Path $PSScriptRoot 'garage_preview_identity.ps1')
. (Join-Path $PSScriptRoot 'prepared_asset_identity.ps1')
function Test-GaragePreviewSource([string]$Relative) {
    # Match the native preview baker's conservative model/room dependencies.
    # Menu layout, translations, backend and build metadata do not repaint a car.
    if ($Relative -match '^game/(vehicle/|assets/(garage/|liveries/)|resources/(cars/|[^/]+\.tres$))' -or
        $Relative -in @('godot-version.txt', 'game/project.godot', 'game/soundtrack/record_library.gd')) { return $true }
    if ($Relative -match '^game/ui/(showroom_|studio_|garage_thumbnail_)' -or $Relative -match '^game/ui/garage_.*\.gdshader(inc)?$') { return $true }
    return $Relative -in @(
        'game/ui/car_showroom.gd', 'game/ui/garage_preview_renderer.gd', 'game/ui/garage_thumbnail_studio.gd', 'game/ui/garage_car_cache.gd',
        'game/ui/garage_preloaded_studio.gd', 'game/ui/handling_selection.gd',
        'game/ui/garage_environment.gd', 'game/ui/garage_reflections.gd', 'game/ui/garage_details.gd',
        'game/ui/garage_drain.gd', 'game/ui/garage_furnishings.gd', 'game/ui/garage_materials.gd',
        'game/ui/garage_workshop.gd', 'game/ui/garage_record_station.gd',
        'game/ui/garage_plant.gd', 'game/ui/garage_car_reveal.gd', 'game/ui/garage_wash_effect.gd',
        'game/ui/garage_wash_geometry.gd', 'game/ui/garage_wash_tool.gd', 'game/ui/garage_hose_geometry.gd',
        'game/ui/garage_hose_rig.gd'
    )
}

function Test-HeaderPreviewSource([string]$Relative) {
    # Known non-rendering consumers must not discard every saved photograph.
    # Keep models, shaders, render factories, assets, unknown UI/helpers, native
    # code and project settings conservative. profile_car.gd also delegates the
    # capture factory/presentation, so its source remains a visual dependency.
    if ($Relative -match '^game/(backend/|soundtrack/|diagnostics/|localization/|core/features/)' -or
        $Relative -in @(
            'game/core/app.gd', 'game/ui/own_profile_page.gd', 'game/ui/achievements_menu.gd',
            'game/ui/achievement_badge.gd', 'game/ui/header_car_picker.gd',
            'game/ui/header_car_motion.gd', 'game/ui/garage_page.gd', 'game/ui/garage_preloader.gd',
            'game/ui/track_of_day_page.gd', 'game/ui/menu_page_swipe.gd', 'game/persistence/local_records.gd'
        )) { return $false }
    return $true
}

function Get-ModularCarVehicles([string]$Relative) {
    return @(Get-PreparedAssetVehicles $Relative)
}

function Get-CheckpointLayoutSources([string]$RepositoryRoot, [string[]]$Paths) {
    # Reviewed numerical dependency manifest. TrackSession's complete resource
    # graph also reaches cars/scenery through unrelated helper methods; hashing
    # that graph would invalidate layouts for cosmetic changes. Actual compiled
    # grid/route/kerb/metadata values are independently included in each cache key.
    $selected = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($relative in @(
        'godot-version.txt',
        'game/race/track_session.gd', 'game/race/race_rules.gd',
        'game/race/checkpoint_layout_cache.gd', 'game/race/checkpoint_layout_disk_cache.gd',
        'game/race/checkpoint_layout_artifact.gd', 'game/race/spline_gate_corridor.gd',
        'game/race/road_gate_coverage.gd', 'game/track/native_track.gd',
        'game/track/playground_data.gd', 'game/track/road_kerbs.gd',
        'game/track/creator_bridges.gd', 'game/track/road_edges.gd',
        'game/track/visual_road_join.gd', 'game/editor/track_compiler.gd',
        'game/editor/track_document.gd', 'game/editor/start_line.gd',
        'game/editor/road_pieces.gd', 'game/editor/road_piece_catalog.gd',
        'game/editor/road_sections.gd', 'game/editor/road_update.gd',
        'game/editor/spline_road.gd', 'game/editor/spline_borders.gd',
        'game/editor/surface_paint.gd', 'game/track/geometry_acceleration.gd'
    )) {
        if (-not [System.IO.File]::Exists((Join-Path $RepositoryRoot $relative))) { throw "Missing checkpoint layout dependency: $relative" }
        [void]$selected.Add($relative)
    }
    foreach ($relative in $Paths) {
        if ($relative.StartsWith('native/track_geometry/') -or $relative.StartsWith('game/platform/track_geometry/')) { [void]$selected.Add($relative) }
    }
    return ,$selected
}

function Write-ClientBuildIdentity([string]$RepositoryRoot, [string]$OutputDirectory) {
    $projectPath = Join-Path $RepositoryRoot 'game/project.godot'
    $projectText = [System.IO.File]::ReadAllText($projectPath)
    $baseMatch = [regex]::Match($projectText, '(?m)^config/base_version="([A-Za-z0-9._-]{1,40})"\r?$')
    if (-not $baseMatch.Success) { throw 'Client base version is missing or invalid.' }
    $baseVersion = $baseMatch.Groups[1].Value
    $presetPath = Join-Path $RepositoryRoot 'game/export_presets.cfg'
    $presetText = [System.IO.File]::ReadAllText($presetPath)
    $excludeMatch = [regex]::Match($presetText, '(?m)^exclude_filter="([^"]*)"\r?$')
    $excluded = @($excludeMatch.Groups[1].Value.Split(',') | Where-Object { $_ })
    $paths = @(& git -C $RepositoryRoot -c core.quotepath=false ls-files --cached --others --exclude-standard -- game native godot-version.txt scripts/build_identity.ps1 scripts/garage_preview_identity.ps1 scripts/prepared_asset_identity.ps1)
    if ($LASTEXITCODE -ne 0) { throw 'Cannot enumerate client build sources.' }
    $paths = @($paths | Where-Object {
        $relative = $_
        $include = $relative -notmatch '^game/(\.godot/|android/|tests/|music/)' -and $relative -notmatch '\.uid$' -and $relative -ne 'game/core/build_identity.gd'
        if ($relative.StartsWith('game/')) {
            foreach ($pattern in $excluded) { if ($relative.Substring(5) -like $pattern) { $include = $false; break } }
        }
        $include
    } | Sort-Object -Unique)
    $encoding = New-Object System.Text.UTF8Encoding($false)
    $checkpointSources = Get-CheckpointLayoutSources $RepositoryRoot $paths
    $digest = [System.Security.Cryptography.SHA256]::Create()
    $checkpointDigest = [System.Security.Cryptography.SHA256]::Create()
    $previewDigest = [System.Security.Cryptography.SHA256]::Create()
    $headerDigest = [System.Security.Cryptography.SHA256]::Create()
    $vehicleDigests = [ordered]@{}
    foreach ($vehicle in @(Get-GaragePreviewVehicleIds)) { $vehicleDigests[$vehicle] = [System.Security.Cryptography.SHA256]::Create() }
    $modularDigests = [ordered]@{}
    foreach ($vehicle in @(Get-GaragePreviewVehicleIds)) { $modularDigests[$vehicle] = [System.Security.Cryptography.SHA256]::Create() }
    $fileCount = 0
    $previewFileCount = 0
    $headerFileCount = 0
    try {
        foreach ($relative in $paths) {
            $absolute = Join-Path $RepositoryRoot $relative
            if (-not [System.IO.File]::Exists($absolute)) { continue }
            [byte[]]$bytes = $null
            if ($relative -eq 'game/project.godot') {
                $normalized = [regex]::Replace($projectText, '(?m)^config/version="[^"]*"\r?$', 'config/version="GENERATED"')
                $bytes = $encoding.GetBytes($normalized.Replace("`r`n", "`n"))
            } else { $bytes = [System.IO.File]::ReadAllBytes($absolute) }
            $fileDigest = [System.Security.Cryptography.SHA256]::Create()
            try { $fileHash = ([BitConverter]::ToString($fileDigest.ComputeHash([byte[]]$bytes, 0, $bytes.Length))).Replace('-', '').ToLowerInvariant() }
            finally { $fileDigest.Dispose() }
            $record = $encoding.GetBytes($relative + "`n" + $fileHash + "`n")
            [void]$digest.TransformBlock($record, 0, $record.Length, $record, 0)
            if ($checkpointSources.Contains($relative)) { [void]$checkpointDigest.TransformBlock($record, 0, $record.Length, $record, 0) }
            if (Test-GaragePreviewSource $relative) {
                [void]$previewDigest.TransformBlock($record, 0, $record.Length, $record, 0)
                $previewFileCount++
            }
            if (Test-HeaderPreviewSource $relative) {
                [void]$headerDigest.TransformBlock($record, 0, $record.Length, $record, 0)
                $headerFileCount++
            }
            foreach ($vehicle in @(Get-GaragePreviewVehicles $relative)) {
                [void]$vehicleDigests[$vehicle].TransformBlock($record, 0, $record.Length, $record, 0)
            }
            foreach ($vehicle in @(Get-ModularCarVehicles $relative)) {
                [void]$modularDigests[$vehicle].TransformBlock($record, 0, $record.Length, $record, 0)
            }
            $fileCount++
        }
        [void]$digest.TransformFinalBlock([byte[]]@(), 0, 0)
        $sourceHash = ([BitConverter]::ToString($digest.Hash)).Replace('-', '').ToLowerInvariant()
        [void]$checkpointDigest.TransformFinalBlock([byte[]]@(), 0, 0)
        $checkpointHash = ([BitConverter]::ToString($checkpointDigest.Hash)).Replace('-', '').ToLowerInvariant()
        [void]$previewDigest.TransformFinalBlock([byte[]]@(), 0, 0)
        $previewHash = ([BitConverter]::ToString($previewDigest.Hash)).Replace('-', '').ToLowerInvariant()
        [void]$headerDigest.TransformFinalBlock([byte[]]@(), 0, 0)
        $headerHash = ([BitConverter]::ToString($headerDigest.Hash)).Replace('-', '').ToLowerInvariant()
        $vehicleHashes = [ordered]@{}
        foreach ($vehicle in $vehicleDigests.Keys) {
            $vehicleDigest = $vehicleDigests[$vehicle]
            [void]$vehicleDigest.TransformFinalBlock([byte[]]@(), 0, 0)
            $vehicleHashes[$vehicle] = ([BitConverter]::ToString($vehicleDigest.Hash)).Replace('-', '').ToLowerInvariant()
        }
        $modularHashes = [ordered]@{}
        foreach ($vehicle in $modularDigests.Keys) {
            $modularDigest = $modularDigests[$vehicle]
            [void]$modularDigest.TransformFinalBlock([byte[]]@(), 0, 0)
            $modularHashes[$vehicle] = ([BitConverter]::ToString($modularDigest.Hash)).Replace('-', '').ToLowerInvariant()
        }
    } finally {
        $digest.Dispose(); $previewDigest.Dispose(); $headerDigest.Dispose(); $checkpointDigest.Dispose()
        foreach ($vehicleDigest in $vehicleDigests.Values) { $vehicleDigest.Dispose() }
        foreach ($modularDigest in $modularDigests.Values) { $modularDigest.Dispose() }
    }
    $identifier = $baseVersion + '.' + $sourceHash.Substring(0, 32)
    $vehicleHashText = ConvertTo-Json -InputObject $vehicleHashes -Compress
    $modularHashText = ConvertTo-Json -InputObject $modularHashes -Compress
    $identityText = "extends RefCounted`n# Generated by scripts/dev.ps1. Never recompute during gameplay.`nconst ID: String = `"$identifier`"`nconst SOURCE_SHA256: String = `"$sourceHash`"`nconst CHECKPOINT_LAYOUT_SHA256: String = `"$checkpointHash`"`nconst GARAGE_PREVIEW_SHA256: String = `"$previewHash`"`nconst GARAGE_PREVIEW_VEHICLE_SHA256: Dictionary = $vehicleHashText`nconst MODULAR_CAR_SHA256: Dictionary = $modularHashText`nconst HEADER_PREVIEW_SHA256: String = `"$headerHash`"`n"
    $identityPath = Join-Path $RepositoryRoot 'game/core/build_identity.gd'
    [System.IO.Directory]::CreateDirectory((Split-Path -Parent $identityPath)) | Out-Null
    $nextProject = [regex]::Replace($projectText, '(?m)^config/version="[^"]*"\r?$', ('config/version="' + $identifier + '"'))
    # Android's empty version/name uses application/config/version.
    if ($presetText -notmatch '(?m)^version/name=""\r?$') { throw 'Android version/name must inherit the generated project version.' }
    foreach ($entry in @(@($identityPath, $identityText), @($projectPath, $nextProject))) {
        if (-not [System.IO.File]::Exists($entry[0]) -or [System.IO.File]::ReadAllText($entry[0]) -cne $entry[1]) {
            [System.IO.File]::WriteAllText($entry[0], $entry[1], $encoding)
        }
    }
    if ($OutputDirectory) {
        [System.IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
        $receipt = @{ build_id = $identifier; source_sha256 = $sourceHash; source_files = $fileCount; checkpoint_layout_sha256 = $checkpointHash; checkpoint_layout_sources = @($checkpointSources | Sort-Object); garage_preview_sha256 = $previewHash; garage_preview_files = $previewFileCount; garage_preview_vehicle_sha256 = $vehicleHashes; modular_car_sha256 = $modularHashes; header_preview_sha256 = $headerHash; header_preview_files = $headerFileCount }
        [System.IO.File]::WriteAllText((Join-Path $OutputDirectory 'client-build-identity.json'), ($receipt | ConvertTo-Json) + "`n", $encoding)
    }
    return $identifier
}
