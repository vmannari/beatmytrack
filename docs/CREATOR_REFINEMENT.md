# Creator collision, painting and save follow-up - 2026-09-14

Owner request covers placed tree/rock collision, road-safe terrain painting, freely placed moving tyre walls, nearby endpoint connections, variable curve angle/radius, and accessible saving/local racing. Requirement coverage: R01, T01-T04, V05 and G01; ordinary five-lap racing and untimed creator practice remain separate.

## Using the changes

- Placed trees and rocks are solid obstacles. Their authored footprints now stop the car; the automatic low-cover scenery remains decorative.
- Surface > **Keep road** is on by default. Sand/dirt, grass and other terrain strokes avoid existing roads. Off-road sand can still be erased with grass while preserving the road. **Paint all** deliberately permits resurfacing/erasing a road. Road brush strokes remain unrestricted. Native remix asphalt/dirt cells are protected as road; source maps do not distinguish off-road dirt from dirt roadway.
- Tyre wall opens in **Single** placement. Tap anywhere to place a section; Select moves it, Rotate turns it, Copy duplicates it. **Free line** uses two arbitrary points; **Road edge** follows the nearest road as before. The same line options are available for barriers/fences.
- A tyre section contains six movable two-tyre stacks. Car impacts transfer momentum, stacks slide/spin, slow down and bounce against solid ground obstacles. They are no longer baked into an immovable wall. Restart restores their authored positions; collisions never rewrite the saved map.
- Select a road section and choose **Connect** to close the closest eligible endpoint gap within 8 m, leaving the opposite end fixed. Each connection is one undo action. End-dot dragging still snaps directly; this connects road-piece ends, not arbitrary nonadjacent lap checkpoints.
- For a Curve, **Shape > Angle** provides a drag handle and 5-degree buttons, from 5 to 270 degrees. Radius remains independently adjustable from 3 to 60 m. Lead-in and width controls remain. Curves without an angle field retain the 90-degree default.
- **Save** is visible beside Test. It commits a valid pending piece before saving and reports the result. Structurally valid drafts can be saved even when their lap route needs repair. **Map settings > My circuits** saves, clears search/theme filters and opens Saved tracks with the current circuit selected. Saved tracks expose Race/Edit; a draft with an invalid route exposes Edit draft and explains the route issue. Road-piece thumbnails show the authored roads instead of the hidden default lap outline. A completed racing lap still needs Race > Use roads or manual route setup.

## Contracts and implementation

The bounded creator-track-v5 schema adds optional piece `angle` and stroke `protect_road`; defaults preserve existing field meanings. Compiler identity is **creator-compiler-6**, with golden default hash `fe5a3a3775d4acf8fc518ff82356dd60804771bb8c514145918cd46d8ab16eb0`. Local saving relaxes lap spacing/length readiness only; unsupported fields, nonfinite values, unsafe identifiers and all structural bounds remain rejected. Export/racing still require the full route validator. Existing files are preserved.

Canonical simulation is versioned **arcade-planar-0.13**. The fixed-step ground adapter advances prop state; tyre positions, velocities and spin live in each VehicleState and its replay snapshot. No new randomness, wall clock, I/O, network or display-rate behavior enters simulation. Native tracks without loose tyres retain their existing motion. Handling parameters and racing camera framing are unchanged. The tyre mesh is original procedural geometry rendered as a shared MultiMesh.

Changed files:

- `game/core/app.gd`, `game/editor/editor_canvas.gd`, `road_pieces.gd`: Save, safe painting, free object lines, Connect and curve controls.
- `game/editor/creator_objects.gd`, `track_document.gd`, `track_compiler.gd`, `game/persistence/track_library.gd`, v5 schema: collision categories, separate road-protection mask, optional fields and draft persistence.
- `game/vehicle/loose_tyres.gd`, `vehicle_simulation.gd`, `vehicle_state.gd`, `game/track/playground_data.gd`, `native_track.gd`: deterministic movable stacks and replay state.
- `game/track/native_track_visual.gd`, `game/core/game.gd`: instanced moving tyres and protected road overlays.
- `game/ui/track_browser.gd`, `track_catalog.gd`, `track_tile.gd`: local selection, draft recovery and actual road thumbnails.
- `game/tests/test_creator_refinement.gd`, creator/editor/piece/free-paint expectations, `scripts/dev.ps1`: new regression/capture actions and pinned-engine script diagnosis. Status/phase documents and captured evidence are updated.

## Actual verification

All commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action <Action>` and pinned Godot 4.7.2.

- `TestRefinement`: 29 checks pass. Covers car impacts with trees/rocks, variable sweep endpoints, road-safe sand and erasure, explicit resurfacing, loose stack movement/reset, exact JSON-input replay, incomplete draft round trip, Connect/undo, preview-inclusive Save, saved-only navigation and local race startup.
- `CaptureRefinement`: 33 checks pass, including actual GPU tyre transforms. Four stacks move in the 360-tick impact witness, with four car contacts. Capture uses Windows OpenGL/NVIDIA; headless dummy rendering returns zero MultiMesh transforms, so that visual assertion is retained in the graphical run. Simulation/replay assertions run headlessly too.
- `TestWorkflow`: 96 checks pass, including existing blocked-start recovery. `TestPieces`: 106 checks pass, including five piece-road laps with no contacts and exact replay.
- Initial checks exposed a protected-stroke overlay omission, static-tyre/soft-tree expectations and a script dependency leak. The overlay was corrected, intentionally changed collision/golden expectations updated, and the simulation-to-native-track dependency replaced with the ground adapter. `CheckScript -ScriptPath res://vehicle/vehicle_simulation.gd` passes without the leak.
- `Validate` passed import, all 69 script parses, startup, driving 56, native tracks 163, extra tracks 27, creator 86 and editor 39 checks. It then stopped at the old unrestricted touch-paint test because road protection is now enabled by default. That scenario now explicitly selects Paint all, retaining the continuous-stroke assertion; the new protected-paint cases remain separate.
- After that test-only correction, all remaining actions passed: `TestFreeEditor` 55, `TestPieces` 106, `TestPractice` 31, `TestWorkflow` 96, `TestConstruction` 73, `TestRefinement` 29, `TestApp` 84, `TestRecords` 53, `TestCatalog` 18 and `TestMenus` 11. Together with the completed Validate stages, all 927 regression checks pass. No physics checks were weakened or bypassed. The separate final `CaptureRefinement` run passes 33 checks.
- `Doctor` confirms missing matching Android templates, SDK/platform-tools/build-tools and JDK; device attachment could not be enumerated through ADB. No APK or phone test was produced.
- Python parsed the updated JSON schema and checked the angle/protection definitions. `git diff --check` passed.

Engine captures: [curve angle and protected sand](evidence/refinement-curve.png), [saved local roads](evidence/refinement-library.png), [displaced tyre stacks](evidence/refinement-tyres.png).

## Limits and remaining acceptance

Tyres use simple planar stack bodies, not a 3D tumbling solver. They do not collide with other loose stacks, so pushed stacks may overlap. They are ground-layer objects and are not placeable on bridge decks. There is no inter-car collision or online verification added here. Individual stacked tyres do not separate vertically.

Physical-phone touch reach, toolbar scrolling, frame pacing and tyre feel still need owner/device acceptance. No phone test or APK export was performed; configured Android SDK/ADB/build-tools, JDK and matching templates are missing. Earlier race-readiness/shortcut-validation findings remain outside this follow-up; saving a partial map does not certify it as a completed competitive course.
