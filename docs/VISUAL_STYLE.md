# Reference-led visual revision ? 2026-09-14

Requirements: V02/V04 (matte graphic-novel materials and selective contours), V03/R01 (readable race controls), V05 (shared creator scenery). Owner requested a closer match to the attached woodland racing example. Presentation kit is now `track-kit-5`.

## Changes

- `game/track/track_theme.gd`: olive pine terrain, charcoal asphalt, warm stone and curb palette.
- `game/track/surface_detail.gdshaderinc`, `terrain.gdshader`, `creator_road.gdshader`, `ground.gdshader`: original world-space ground pigment and restrained asphalt grain, shared by road pieces and terrain. Derivative fade reduces distant high-frequency detail. Outer ground shares the terrain treatment.
- `game/track/native_track_visual.gd`: five irregular pine tiers, selective scenery contour pass, bounded 480-site scenery budget (previously 180), shared by race and creator views. Existing road-clearance checks remain.
- `game/track/ink.gdshader`, `game/vehicle/visual_geometry.gd`, `car_visual.gd`: thin inverted-hull contour pass and ivory matte car paint.
- `game/ui/playground_hud.gd`, `touch_controls.gd`: dark translucent bordered controls, drawn steering/brake/pedal icons, larger speed text and olive speed-panel accent. Existing touch zones, simultaneous inputs, handedness and scaling remain.

No physics, track collision data, camera pose, physical car dimensions, lap rules or saved-document format changed. All new visuals are original shader/mesh/drawing code; the reference image is not a runtime asset.

## Actual validation

Commands use the pinned engine through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- `Snapshot -Track slicks_freeway_test`: passed before and after; actual Compatibility renderer captures inspected.
- `CapturePractice`: passed, 32 checks / 0 failures, six practice laps with zero contacts; graphical creator practice inspected.
- `Validate`: passed import, 70 script parses, startup and all 16 domain/UI suites (947 checks, zero failures), including same-engine replay. The final shader seam adjustment was additionally verified by fresh native and creator graphical captures.
- `git diff --check`: passed (line-ending normalization notices only).

Evidence: [before](evidence/style-before.png), [after](evidence/style-after.png), [creator practice](evidence/style-practice.png).

## Acceptance limits

This moves the existing procedural kit toward the example, rather than reproducing its hand-painted asset quality. Native raster-derived curb silhouettes remain visibly stepped; scenery is simpler and sparser than the reference. Fixed world-unit contours need further review at different zoom levels. No added collision is implied by decorative scenery.

Desktop captures are 1280?720 on the NVIDIA Compatibility renderer. No physical-phone test, Android export, thermal test or Mobile renderer comparison was performed; device attachment was not enumerated. Import still reports missing Android build-tools. Phone readability, contour stability in motion, GPU cost of the additional pass/scenery, and owner visual acceptance remain open. Camera calibration remains its separate existing gate.
