# Shared object model refinement â€” 2026-09-18

Owner request: improve creator object icons and in-game 3D objects to fit the existing illustrated/cel-shaded game. Requirements V02/V03/V04/V05, R01, T01â€“T04; Q01 remains device-dependent. Presentation version: track-kit-28.

The creator still renders the actual shipping models into one-shot transparent thumbnails. Front-facing three-quarter framing, warm key light and cooler restrained ambient light reveal signs and building fronts. Thumbnail foliage and stone now use the selected biome, matching placed objects.

Original code-authored refinements include layered pine and broadleaf crowns, tapered trunks, blade-shaped grass, stratified stone silhouettes, round logs, shaped concrete barriers with closed ends, formed guardrails, actual chevrons, planked crates, pallet supports, sloped parked-vehicle cabins and round wheels, ribbed containers, closed building gables and garage shutters, and supported grandstand benches. Existing cones, tyres, flags, lights, gantries and hazards retain their shared models and receive the revised thumbnail presentation. Matte toon materials remain shared; no external models, textures, dependencies or runtime services were introduced.

Changed runtime files: `game/track/creator_prop_visual.gd`, `game/track/native_track_visual.gd`, `game/editor/object_thumbnail.gd`, `game/editor/object_browser.gd`. Capture tooling: `game/tests/capture_object_models.gd`, `scripts/dev.ps1`. Documentation: this file, DEVELOPMENT_STATUS, PHASE_0_PLAN and licenses/ASSETS. Existing unrelated working-tree edits were retained.

## Actual verification

Commands run through the pinned Godot 4.7.2 entry point:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CheckScript -ScriptPath res://track/creator_prop_visual.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureObjects
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestHazards
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestPlacement
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureObjectModels
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Doctor
```

- Parse check passed. Final creator capture: 69 checks, zero failures.
- Hazard regression: 150 checks, zero failures; engine reported two ObjectDB instances leaked at exit. This warning was not investigated as part of the art pass.
- Placement regression: 24 checks, zero failures. Headless click callbacks measured 64â€“70 ms in this run; this is not a device performance result or a comparable graphical before/after benchmark.
- Final model capture: all 35 catalog variants rendered, plus actual gameplay with the normal follow camera. Native collision cells remained identical before/after rendering. Screenshots inspected on desktop Compatibility/NVIDIA RTX 3090.
- Capture development initially exposed a clipped review sheet and an invalid fixture start-line key; both were corrected before the final successful capture. These were capture-tool issues, not relaxed runtime invariants.
- Targeted `git diff --check` passed (line-ending normalization warnings only).
- Doctor failed: matching Android debug template, SDK/build-tools and configured JDK missing. No APK export or phone test performed. Device attachment was not verified because Doctor stopped before adb discovery.

## Evidence and remaining acceptance

- [All 35 object variants](evidence/object-models/object-models.png)
- [Actual gameplay view](evidence/object-models/object-models-gameplay.png)
- [Creator nature palette](evidence/object-models/object-nature.png)
- [Creator barrier palette](evidence/object-models/object-browser.png)
- [Wide creator layout](evidence/object-models/object-wide.png)
- Actual logs are beside the screenshots.

Owner visual acceptance remains pending. Natural forms remain economical faceted meshes; this is not hand-painted texture artwork. Foliage geometry is denser than the previous kit and requires dense-scene phone profiling. Check readability in motion, shadows near corners, small-screen icon legibility, biome colour matching and thermal frame pacing on the intended Android device. No canonical handling, collision dimensions, route data, gameplay camera, save schema or record identity was changed by this pass. Full physics replay/Android acceptance is not claimed.

## Owner-directed barrier and tree correction — 2026-09-18

The owner preferred the original block barriers and rejected rounded tree foliage next to the inked car. This supersedes the Jersey barrier and rounded canopy choices above. Requirements V02/V03/V04/V05/R01/T01–T04; presentation version track-kit-29.

Restored the original rectangular concrete silhouette and three broad red bands, adding a shaded foot, light crown bevel and selective contour. Pine foliage now uses swept pointed boughs with dark undersides; broadleaf and bush crowns use flattened irregular leaf masses with stronger value separation. Trees and barriers share the car's existing toon/ink materials through a separate batched mesh. No collision, placement dimensions, camera or handling edits.

Runtime changes: game/track/creator_prop_visual.gd and game/track/native_track_visual.gd. game/tests/capture_object_models.gd now also checks outward canopy top normals. The first outlined capture exposed inward-facing foliage surfaces; corrected winding removes the resulting speckling. Original code-authored geometry, no external assets.

Actual commands (all via `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`):

- `-Action CaptureObjects`: 69 checks, zero failures.
- `-Action TestHazards`: 150 checks, zero failures. The same two ObjectDB leak warnings remain at exit.
- `-Action CaptureObjectModels`: all 35 variants rendered, canopy normal check passed and gameplay collision cells preserved; final desktop screenshots inspected.
- `git diff --check -- game/track/creator_prop_visual.gd game/track/native_track_visual.gd game/tests/capture_object_models.gd`: passed, line-ending notices only.
- `git apply --reverse --check docs/evidence/object-models/followup/revision.patch`: passed. This review patch isolates the three code-file changes from the pre-existing dirty working tree.

[Updated models](evidence/object-models/followup/object-models.png) · [Gameplay with car](evidence/object-models/followup/object-models-gameplay.png) · [Creator trees](evidence/object-models/followup/object-nature.png) · [Creator barriers](evidence/object-models/followup/object-browser.png). Logs and the scoped revision patch are alongside the captures.

Owner acceptance of the revised tree shapes and contrast remains pending. The extra selective contour batch/pass requires phone profiling, particularly in dense scenery and in motion. No phone test, Android export or fresh device discovery was performed; the previously reported Android tooling blockage remains unresolved.

## Rocks and larger cliffs — 2026-09-18

Owner accepted the trees and requested improved rocks and larger cliffs. Requirements V02/V03/V04/V05/R01/T01–T04. Presentation track-kit-31; existing physics/compiler/schema contracts remain unchanged.

Rock, boulder and slate now have asymmetric broken caps, broad light/shadow faces, short fissures and the accepted shared ink outline. Cliffs are continuous stratified walls with inset shelves, broken upper ledges and fracture marks. Their base matches the established rectangular footprint. Theme colours remain shared. All geometry is original code-authored work.

Cliff is a separate Nature tile. New cliff placements default to scale 2 (16 × 6 m footprint, approximately 8 m high). Its size menu exposes 8 m, 16 m and 24 m widths (scale 1/2/3, depth 3/6/9 m). Large therefore uses the existing supported scale 3 contract, rather than changing collision rules or schemas. Existing placed cliff footprints are preserved; their revised visual height follows the new 4 m nominal model at their saved scale. No player files are rewritten.

Changed files: game/track/creator_prop_visual.gd, game/track/native_track_visual.gd, game/editor/creator_catalog.gd, game/editor/object_browser.gd, game/core/app.gd, game/tests/test_object_browser.gd, game/tests/capture_object_models.gd; this document and status/phase notes.

Actual commands through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- `-Action CaptureObjects`: 76 checks, zero failures, including cliff default/presets, actual placement scale, undo, enlarged collision bounds and save/reload.
- `-Action TestHazards`: 150 checks, zero failures; final run had no engine errors or leak warnings.
- `-Action CaptureObjectModels`: 35 variants rendered, gameplay collision cells preserved, full cliff/car model comparison saved. Desktop Compatibility/RTX 3090 captures inspected.
- Targeted `git diff --check`: passed with line-ending notices only.
- Scoped review patch: `git apply --reverse --check --ignore-space-change docs/evidence/object-models/rocks/revision.patch` passed. Without the whitespace flag the mixed-line-ending capture script rejected the reverse check.

Initial validation caught an Array/Array[float] mismatch in the preset helper; fixed with explicit typed assignment before the successful runs above. No invariant was weakened.

[Cliff with reference car](evidence/object-models/rocks/object-models-cliff.png) · [Icons](evidence/object-models/rocks/object-models.png) · [Gameplay](evidence/object-models/rocks/object-models-gameplay.png). Logs and the scoped code patch are alongside the images. The full cliff comparison uses a separate review camera; gameplay camera settings are unchanged.

Remaining acceptance: owner review of the deliberately faceted stone/cliff shapes; large-cliff visibility near roads; close-up shadow aliasing and dense scenery performance on phone. Taller cliffs can occlude the road if placed too close. No Android export or phone test was performed; device connection was not checked. The earlier Android tooling blockage remains unresolved. This is a freestanding solid prop, not editable/elevated drivable terrain.
