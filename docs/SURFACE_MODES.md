# Surface placement modes - 2026-09-17

Owner request: line, bounded area and free painting, movable construction points, explicit confirmation, smooth contours and gradual material edges. Requirements: R01, T01-T04, V03, V05; local editor slice.

Surfaces exposes Line / Bounded area / Free painting directly in the palette and in Mode / width. Line/area: tap to add up to 64 control points, drag the gold dots, confirm with the check button or Enter. The inspector also offers Remove last point and Cancel surface; Backspace/Delete removes the last draft point and Escape cancels. Lines need two points, areas three. Crossing or degenerate areas are rejected. Release only commits in free painting. Road protection and undo/redo apply to all modes. Save, load, share and practice reject pending surface drafts. Tool/category changes discard the unconfirmed draft like road previews. Pinch and desktop pan preserve point drafts.

Shared three-pass Chaikin smoothing rounds line/area contours without overshooting the authored hull. Areas fill the rounded enclosed region, not a wide boundary stroke. Preview, compiler and road-overlay exclusion share the same geometry. Area rasterization is bounded to its footprint. Terrain material weights now blend rather than select a hard winning material; a small spatial filter softens cell edges. Canonical driving surfaces remain discrete 0.5 m cells, not blended grip. Placed road meshes/kerbs retain their existing mesh geometry and overlay clipping. Oil/puddle object stamps retain their existing object placement workflow.

Contracts: optional paint `mode` is `free`, `line`, or `area`; missing mode preserves prior free strokes. JSON schema and runtime validation updated. Compiler identity becomes creator-compiler-13; visual kit track-kit-23. Existing player files are not deleted.

Changed files: `game/editor/surface_paint.gd` (+ Godot UID), `editor_canvas.gd`, `track_document.gd`, `track_compiler.gd`; `game/core/app.gd`; `game/track/road_kerbs.gd`, `terrain.gdshader`, `native_track_visual.gd`; `docs/schemas/creator-track-v5.schema.json`; `game/tests/test_surface_modes.gd` (+ UID), `game/tests/test_creator.gd`; `scripts/dev.ps1`; status/plan and this evidence. These files overlap earlier uncommitted owner work; no combined commit was created.

Actual commands used the pinned engine via `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 <Action>`:

- `CheckScript -ScriptPath res://core/app.gd`: initially failed because the new global class had not been imported.
- `Import`: passed; registered SurfacePaint. Android build-tools warning remains.
- `TestSurfaces`: 19 checks passed before the final gesture/malformed-input additions.
- `CaptureSurfaces`: final 25 checks passed, including point drag, confirmation, filled interior/exterior, road protection, overlay exclusion, undo/redo, free painting, JSON roundtrip, incomplete/crossing/malformed areas and pinch preserving the draft. Graphical run compiled shaders successfully.
- `TestFreeEditor`: final 43 checks passed, including five-lap drive.
- `TestCreator`: initial 85/86 passed; the intentional compiler-13 identity change required refreshing the exact golden hash. The unchanged dimensions, road area and JSON roundtrip assertions remain. Final 86 checks passed.
- `git diff --check`: passed.
- `TestWorkflow`: 166 checks passed.
- `TestKerbs`: 31 checks passed.
- `Doctor`: failed Android prerequisites (matching debug template, configured SDK/platform-tools/build-tools and JDK missing). No APK or phone/device test performed; phone attachment could not be established through configured ADB.

Desktop screenshots inspected: [line draft](evidence/surface-modes/surfaces-line-preview.png), [area draft](evidence/surface-modes/surfaces-area-preview.png), [confirmed blended surfaces](evidence/surface-modes/surfaces-confirmed.png). Logs are in the same directory. No generated/external artwork added.

Remaining acceptance: owner review of smoothing/blend strength, touch ergonomics and shader/large-area performance on a phone. The material boundary is visual; this does not introduce gradual physical grip or edit handles for already committed strokes (undo and repaint remain available).


## Roadside verge follow-up - 2026-09-17

Owner screenshot exposed a grass strip between protected road and painted sand. The same road-preservation mask was keeping the decorative 1.8 m grass skirt and gravel fringe over painted terrain. The overlay texture now has separate road and natural-grass channels: asphalt/markings still respect Keep road, while grass/gravel decoration only covers native grass cells. Ground paint is visible up to the road. No canonical cell, collision, grip or compiler identity changed; visual kit is track-kit-24.

Owner also requested the same border as the existing road shoulder. Terrain grass blending now shares `grass_fringe` with the shoulder shader, with matching world-space pigment scale and irregularity; the broad blur was reduced. The terrain colors and smooth authored contour remain, with a short broken fringe against grass.

Changed: `game/track/native_track_visual.gd`, `creator_road.gdshader`, `terrain.gdshader`, `surface_detail.gdshaderinc`, `game/tests/test_surface_modes.gd`, status/plan and this note. Requirements R01/T01-T04/V03/V05.

Actual commands, through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:
- `CaptureSurfaces`: 30 checks, zero failures. Includes a constructed hairpin, protected sand area, mask coverage for painted terrain, retained asphalt and untouched grass, plus the prior mode checks. Shader compilation and PNG capture succeeded.
- `TestKerbs`: 31 checks, zero failures.

[Inspected desktop hairpin screenshot](evidence/surface-verge/surfaces-painted-verge.png). This deliberately isolated open hairpin fixture has two route issues; it tests roadside visuals, not race completion. Logs are beside the screenshot. No phone/device test or Android export performed; the missing Android prerequisites recorded above remain. Owner visual acceptance and on-phone rendering/performance remain outstanding.


## Unpainted road regression correction - 2026-09-17

Owner rejected the bright road fringe introduced above. The previous decorative mask incorrectly suppressed the grass skirt over all native asphalt/kerb cells, exposing underlying raster edges on untouched roads. It now derives replacement coverage from actual authored paint footprints, with last-stroke ordering and grass erasure respected. No paint means no additional decorative clipping. Keep road still preserves asphalt and markings; painted terrain still reaches the road. Visual kit track-kit-25; no canonical simulation or compiler changes.

Changed: `game/track/native_track_visual.gd`, `game/tests/test_surface_modes.gd`, status/plan and evidence. Requirements R01/T01-T04/V03/V05.

Actual commands via `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:
- `TestSurfaces` before the correction: 27 checks, 1 failure, specifically untouched road decoration incorrectly clipped. Saved `unpainted-regression-before.log`.
- `CaptureSurfaces` after correction: 32 checks, zero failures. Uses a closed four-piece circuit and captures both painted and entirely unpainted roads. This replaces the isolated open-hairpin fixture used above.
- `TestKerbs`: 31 checks, zero failures.

Inspected [restored unpainted road](evidence/surface-verge/surfaces-unpainted-road.png) and [painted roadside](evidence/surface-verge/surfaces-painted-verge.png). Both show the normal road edge without the bright exposed fringe; paint retains the irregular grass transition. No phone test or Android export performed. Owner review and phone visual/performance acceptance remain pending.


## Matched sand color and grain - 2026-09-17

Owner requested painted sand use the roadside shoulder color and a better sand texture. Terrain surface 2 now uses the same theme color darkened by 20% as the shoulder. Both shaders call shared `sand_detail`: fine mineral grain, sparse darker grit, restrained broad tonal variation and derivative-based detail filtering. The former grass-like diagonal strokes no longer shade sand. Existing grass fringe and authored paint mask remain. Visual kit track-kit-26; no geometry, simulation, grip or compiler changes. Original procedural shader artwork, no external assets.

Requirements V02/V04/V05/R01/T01-T04. Changed `game/track/native_track_visual.gd`, `surface_detail.gdshaderinc`, `terrain.gdshader`, `creator_road.gdshader`, `game/tests/test_surface_modes.gd` (close-up capture), status/plan and this note.

Actual command: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureSurfaces`: final 33 checks, zero failures, successful graphical shader compilation. Inspected [overview](evidence/sand-texture/surfaces-painted-verge.png), [close-up](evidence/sand-texture/surfaces-sand-detail.png) and [unpainted road](evidence/sand-texture/surfaces-unpainted-road.png). Capture log is in the same directory. No phone test or Android export performed. Remaining acceptance: owner texture/color review and phone detail stability/performance.


## Continuous shoulder / painted sand join - 2026-09-17

Owner close-up showed a cell-sized hard step where the decorative shoulder ended at painted sand. Replaced the decorative sand cutout with a dedicated sand-coverage channel, linearly sampled and spatially filtered only for the verge. Shoulder grass fringe fades into sand coverage; the underlying grass skirt blends to the same sand color and grain. Uses the terrain grass-fringe pattern. Asphalt/marking exclusion still uses the exact nearest mask; other surface types retain their existing clipping. Unpainted roads receive no sand blend. Track-kit-27; canonical geometry/physics unchanged.

Requirements V02/V04/V05/R01/T01-T04. Changed `game/track/native_track_visual.gd`, `creator_road.gdshader`, `game/tests/test_surface_modes.gd`, status/plan and evidence.

Actual command: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureSurfaces`: final 34 checks, zero failures, shaders compiled. Regression checks cover sand blend coverage and no decorative clipping/blend on unpainted roads. Inspected [continuous join close-up](evidence/sand-join/surfaces-sand-detail.png); [unpainted capture](evidence/sand-join/surfaces-unpainted-road.png) and log are saved alongside it. No phone/device test or Android export performed. Remaining acceptance: owner review and mobile rendering/performance.
