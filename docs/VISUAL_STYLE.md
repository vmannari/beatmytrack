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


## Owner correction ? 2026-09-14, track-kit-6

V02/V04/V05: owner rejected mottled grass, sharp repeated tree shapes, large automatically scattered stones and broad cream road shoulders.

Changed `native_track_visual.gd`, `surface_detail.gdshaderinc` and `creator_road.gdshader`: sparse jittered grass strokes replace cloud noise; layered blunt branch masses replace star-cone foliage; automatically scattered stones are now low pebbles (placed solid rock objects retain their footprint). Creator shoulders now use a separate sandy gravel material. White road lines remain and inside bends receive alternating 1.5 m red/off-white kerb segments. Existing exposed-edge and junction checks also govern kerb placement. Scenery collision footprints now display grass beneath their meshes instead of concrete-grey ground. Canonical cells remain unchanged.

Added read-only `game/tests/capture_style.gd` and `scripts/dev.ps1 CaptureStyle -StyleDocument <absolute creator JSON>` for review of saved tracks, without saving the track or records. Reviewed the owner's local Silmukka document at 1494?1009: [actual updated capture](evidence/style-roadside.png). Its document is not copied into the repository.

Actual commands (all via PowerShell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1):
- `CapturePractice`: passed 32 checks, six laps and zero contacts; intermediate foliage review.
- `TestPieces`: passed 106 checks, golden geometry and five laps with zero contacts.
- `TestRefinement`: passed 29 checks, including solid objects and movable tyres.
- `CaptureStyle -StyleDocument <local Silmukka JSON>`: final capture passed; assertion confirms native cells preserved. First version of the preservation assertion used the wrong packed-array type and failed parsing; corrected to PackedInt32Array, then reran successfully.
- `git diff --check`: passed.

This is still procedural artwork, with further owner visual acceptance required. Native raster-derived road contours remain an existing limitation; new inside-curve kerbs apply to creator road pieces. Decorative rocks were reduced, not owner-placed solid obstacles. No new guardrails, tyre barriers or collision geometry are inferred from the reference. Phone readability, motion shimmer and GPU performance remain untested. No physical phone test or Android export was performed; device attachment was not enumerated.


## Equal kerbs and eroded shoulders ? 2026-09-14, track-kit-7

Owner correction, V02/V04/V05: equal red/white lengths on curves, procedurally rough sand contours, and no sand behind kerbs.

`game/track/native_track_visual.gd` now measures texture U along the actual kerb midline. Shared mitered endpoint offsets close gaps between successive quads. `creator_road.gdshader` paints alternating 1.5 m red/white blocks independently of road sampling and radius, with derivative antialiasing. Terminal blocks can be clipped where a kerb begins/ends or a junction hides it; complete blocks retain equal length. This is a world-space length, not equal screen-space length under oblique projection.

Sand is now an exposed-edge strip rather than a full road-sized backing polygon. It is omitted on kerbed segments. A grass skirt covers the old raster shoulder underneath so grass meets the kerb directly. Sand's outer edge varies continuously with deterministic world-position functions (roughly +/-0.225 m), sampled at no more than 0.20 m intervals. The road boundary and white line remain fixed. Road, surface and collision authority remain the existing native cells.

Changed files: `native_track_visual.gd`, `creator_road.gdshader`, `game/tests/test_road_pieces.gd`, this document and project status entries. Original procedural code; no new external assets.

Actual commands, through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:
- `TestPieces`: passed 124 checks, including 18 new checks over radii 8/16/30 m in both directions. Inspect actual generated mesh UVs against physical kerb-midline distance; verify shared inner/outer corners and unchanged canonical cells. Golden geometry and five-lap witness pass with zero contacts.
- First test harness attempt assumed indexed geometry and failed on the unindexed mesh; fixed the harness to support both representations, then reran successfully. No invariant was removed.
- `CaptureStyle -StyleDocument <local Silmukka JSON>`: passed and verified unchanged cells. [Final actual screenshot](evidence/style-kerbs.png) inspected on Compatibility/NVIDIA at 1494x1009. Saved owner document and records are untouched.
- `TestWorkflow`: passed 96 checks, zero failures.
- `git diff --check`: passed (line-ending normalization notices only).

Existing native raster-only kerbs are outside this creator-piece correction. Phone motion/aliasing and GPU performance remain untested; no physical-phone test or Android export was performed, and device attachment was not enumerated. Further owner acceptance remains open.
