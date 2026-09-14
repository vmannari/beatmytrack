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


## Triangle artifacts and sand shimmer ? 2026-09-14, track-kit-8

V02/V04/V05 owner reports black road triangles and flickering sand. Inspection found mixed inferred normals in flat meshes: the Silmukka audit initially counted 5,425/5,448 asphalt vertices and 24,282/25,128 shoulder vertices outside the upward-normal tolerance. These are mesh diagnostics, not a claim that every such vertex was visibly black. `native_track_visual.gd` now normalizes triangle winding and assigns explicit UP normals to all flat creator-road materials. Final audit reports zero bad normals across all five material batches.

The six-view review additionally reproduced large sawtooth sand spikes on a rotated straight. Microscopic offset segments had unstable extrusion tangents. Removing successive points less than 1 cm apart fixes the visible spikes in the same bend capture. Miter orientation now follows polygon winding rather than a tiny boundary containment probe. This cleanup affects only cosmetic edge meshes.

Creator raster terrain/grass skirt/sand are now at -0.06/-0.04/-0.02 m, providing explicit layer separation beneath the unchanged asphalt, markings, finish and car presentation. `creator_road.gdshader` derivative-filters subpixel gravel grain to address texture shimmer. Canonical collision/surface cells, camera framing, physics and saved documents remain unchanged.

Changed runtime: `native_track_visual.gd`, `creator_road.gdshader`. Verification: `tests/test_road_pieces.gd`, `tests/capture_style.gd` (adds normal audit and six read-only route-position captures). Status and this document updated. No external asset or dependency added.

Actual commands via `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:
- `TestPieces`: final 132 checks, zero failures. Includes upward normals, rotated microscopic-edge cleanup, finite miters, existing UV metre-spacing/seam checks, canonical golden cells and five-lap witness with zero contacts. Initial new UP-normal assertion was too strict for packed mesh normals; the final 0.0001-vector-distance tolerance accounts for mesh normal quantization, rather than accepting downward normals.
- `CaptureStyle -StyleDocument <local Silmukka JSON>`: passed, zero bad normals, unchanged-cell assertion and six route-position captures. Reviewed all six intermediate views, then recaptured and inspected the corrected sawtooth bend: [final capture](evidence/style-glitch-fix.png). [Audit](evidence/style-glitch-capture.txt), [tests](evidence/style-glitch-tests.txt).
- `TestWorkflow`: final 96 checks, zero failures.
- `git diff --check`: passed.

Desktop Compatibility captures establish the corrected static geometry. Continuous-motion flicker on the owner's display still needs owner confirmation; these six views are not a video or phone test. No physical-phone test or Android export was performed; attachment was not enumerated. A newly attached close-up was not present in this user turn, so no claim of matching an exact supplied black-triangle pixel is made.


## Painted texture reference ? 2026-09-14, track-kit-9

V02/V04/V05: owner supplied a painted grass/albedo/variation/detail/transition board. Implemented one original generated grass bitmap, shared by native terrain, outer ground and creator grass skirts. The source board is not embedded in runtime. The exact built-in image_gen prompt, generated source dimensions and import policy are in [PAINTED_GRASS_PROMPT.md](PAINTED_GRASS_PROMPT.md).

`surface_detail.gdshaderinc` now samples the grass asset at 20 m and 47 m scales, with broad procedural colour modulation and theme tint. The second sample softens recognizable repetition. This uses one bitmap plus procedural variation rather than claiming the board's two separate grayscale masks were authored. Asphalt and non-grass native materials retain their existing treatment. `ground.gdshader`, `terrain.gdshader`, `creator_road.gdshader` and `native_track_visual.gd` share the texture binding. Shoulder UVs now encode distance across the strip, blending irregular grass into the outer gravel edge; kerbs retain the owner's no-sand rule.

`game/assets/textures/painted_grass_v1.png` is retained at generated resolution, with a committed import configuration limiting runtime size to 1024 and enabling mipmaps. Shader uses anisotropic mip filtering and positive mip bias to soften fine brush detail. Initial graphical review found the raw texture too busy/bright; final shader increases the brush scale and restrains brightness/contrast. [Final in-game bend](evidence/painted-grass.png).

Actual commands through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:
- `Import`: passed, including reimport after setting mipmap generation and size limit. Existing missing Android build-tools diagnostic remains.
- `CaptureStyle -StyleDocument <local Silmukka JSON>`: passed, unchanged cells, zero bad flat normals, six route-position captures. Final bend inspected after material adjustment.
- `TestPieces`: 132 checks passed, zero failures; includes edge cleanup, normals, kerb spacing/seams, five laps and golden cells.
- `TestWorkflow`: 96 checks passed, zero failures.
- `git diff --check`: passed.

No camera/physics/collision/document-format changes. No physical-phone test, motion-video capture, Mobile renderer comparison or Android export performed; attachment was not enumerated. Repetition visibility, in-motion stability and GPU/thermal cost still need owner/device acceptance. The generated texture is a new prototype asset, not a claim of production art acceptance.


## Kerb starts and ends ? 2026-09-14, track-kit-10

V02/V04/V05: owner requests attention to red/white stripe beginnings and endings. `native_track_visual.gd` now groups exposed kerb segments into continuous runs, restarts physical UV distance at each run, and supplies the full run length to `creator_road.gdshader`. Paint fits an odd count of complete equal blocks into each run, starting and ending white rather than cutting arbitrary red slivers. Nominal 1.5 m spacing now adjusts slightly per run to fit whole blocks; equality within a run remains. Very short fragments use one white block. Geometry, road lines, no-sand kerb backing, collisions and source documents remain unchanged.

Changed runtime files: `game/track/native_track_visual.gd`, `game/track/creator_road.gdshader`. Regression coverage in `game/tests/test_road_pieces.gd` additionally checks run coordinates stay within their declared length.

Actual commands through the pinned `scripts/dev.ps1` PowerShell entry point:
- `TestPieces`: 138 checks, zero failures; normal/spacing/seam/cleanup checks, golden native cells and five-lap witness with zero contacts remain passing.
- `CaptureStyle -StyleDocument <local Silmukka JSON>`: passed; zero bad flat normals, unchanged-cell assertion and six route captures. Reviewed [bend endings](evidence/kerb-endings.png).
- `git diff --check`: passed.

Run grouping stops at road-piece boundaries or hidden junction edges. Paint masks may still clip a run where the owner explicitly paints over the road; this does not remove those edits. No physical-phone or continuous-motion test performed, no APK exported, and device attachment was not enumerated. Owner visual acceptance remains open.
