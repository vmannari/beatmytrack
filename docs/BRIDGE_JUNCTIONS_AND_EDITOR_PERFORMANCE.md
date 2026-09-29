# Bridge junctions and creator performance — 2026-09-29

Owner request: allow bridges to overlap, make their intersection drivable, and investigate creator stalls, particularly undo. Requirements: R01, T01–T04, V04/V05 and Q01. This supersedes the nonoverlapping creator-span restriction in CREATOR_CONSTRUCTION.md.

## Behavior and implementation

Creator bridges with matching elevations can intersect, including diagonal flat-deck crossings. Upper road interiors take priority over every span's rail cells, independent of placement order. Cars can continue straight or turn onto the other bridge. Collision queries consider every supporting span's outer rails while retaining isolation from nearby disconnected spans. Ground roads/water beneath the high deck remain separate. Ramps still meet the ground at their original ends.

Steel and desert masonry rail openings use intersected road polygons; their exposed intervals are calculated once per span/side and reused by mesh strips and posts. Oblique openings conservatively remove the full rail-band interval touched by the other road. Matching-height validation prevents joining a low ramp to a high deck; the placement error explains how to move the crossing onto the flat decks. This is a shared elevated junction, not another stacked road level. Legacy native-deck merging remains excluded.

Undo previously joined an outstanding compiler thread, compiled/rebuilt a preview, then recreated the entire editor and built another preview. Undo/redo now retain the controls, camera and viewport, restore the document immediately, autosave, and queue the existing worker. The worker discards superseded results and compiles the newest document. Practice waits for current collision/issue validation. Title, selections and pending gestures reset appropriately. Shape buttons, deletions and ordinary completed gestures use the same asynchronous path.

The app retains at most three compiled previews; the editor world retains at most two detached scenery trees in addition to the displayed tree. Recent undo can reuse both collision data and scenery. Cached object batches are refreshed on restoration, and detached trees are freed when the editor exits. The 3D editor no longer creates a hidden per-cell CPU map texture on every preview update; the 2D fallback still creates it.

Compiler version is now `creator-compiler-20`; authoring schema remains `creator-track-v5`. The new compiler identity separates changed collision content from existing records/verifier manifests. No handling constants changed. An already running backend worker/container must use the matching compiler before accepting new-version runs; no backend deployment or restart was performed here.

## Measured evidence

Pinned Godot 4.7.2, Windows, RTX 3090, 1280×720 graphical editor. `ProfileRoadApproval` uses an oval with successively added sections, an in-flight approval, undo/redo, and the reconstructed old synchronous undo sequence on the same fixture.

| Operation | Desktop handler time |
| --- | ---: |
| New undo with preview work pending | 45.109 ms |
| New redo | 13.280 ms |
| Old synchronous save/recreate sequence | 1368.643 ms |
| Road approval, three samples | 11.549 / 13.558 / 14.123 ms |
| Approval through first frame | 17.530 / 20.602 / 20.800 ms |

This compares handler return times, not total time to a newly built uncached scene. The reconstructed old path runs against current cache/raster code, rather than a separate historical binary. An earlier graphical run measured 40.864/12.399/1364.285 ms respectively. The tests also prove scenery-node reuse, bounded caches, title restoration, no unused map raster, and final compiled identity after rapid undo/redo supersession.

[Raw graphical profile](evidence/bridge-junctions/editor-profile.txt). Inspected engine captures: [grass junction](evidence/bridge-junctions/pine.png), [desert junction](evidence/bridge-junctions/desert.png). The isolated four-arm screenshot fixture intentionally lacks a closed automatic lap; its issue indicator is expected.

## Actual validation

Commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action <Action>`:

- `ProfileRoadApproval`: 28 checks passed, including in-flight and rapid history supersession, independent compiled output and cache reuse.
- `TestConstruction`: 100 checks passed, including both crossing axes/directions, turns in either span order, rail openings, exterior barriers, unequal ramp rejection, both visual styles, and five full overpass laps with exact JSON replay (24,570 ticks, zero contacts). `CaptureConstruction`: 102 checks passed before the two additional turning assertions; its engine screenshots were inspected.
- `TestBridgeContacts`: 16 passed, including the Knit regression in both directions at three lateral offsets, low-underside blocking and upper/lower rail separation.
- `TestCreator`: 112 passed across five themes, including diagnostic races and deterministic identities. Its initial run correctly failed the old compiler-v19 hash; the v20 expected hash was updated after inspecting unchanged grid dimensions, cell counts and race behavior.
- `TestCompilerRaster -CompilerAudit write-golden`: regenerated eight version-dependent fingerprints with the retained pre-optimization compiler, changing only its version to 20. `TestCompilerRaster`: all eight independent raster comparisons passed.
- `TestWorkflow`: 207 passed. Initial run failed two immediate-readiness assertions after edits moved to the worker; tests now await actual completion with a deadline and retain the same obstacle/start/practice-access assertions.
- `TestPlacement`: 24 passed, including autosave and completed compiled-preview equality.
- `TestDriving`: 74 passed; `TestTracks`: 167 passed; `TestHandling`: 88 passed, including historical fixtures and exact replay at multiple display schedules. Headless driving/construction emitted ObjectDB cleanup warnings on some runs; graphical profile/capture completed without script errors.
- The real backend verifier replayed `backend/tests/fixtures/verified_oval.json`: unchanged 12,757 total ticks and lap ticks `[2634, 2532, 2531, 2530, 2530]`. Only compiler version/content hash changed in its pinned manifest; every other manifest field was asserted unchanged.
- `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_verifier.py -q -x`: 31 passed. `BackendTest` was stopped after repeated PostgreSQL setup errors; a direct TCP probe of the configured disposable test database timed out. This is not a full backend-suite pass. `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests -q -k "not postgres"`: 122 passed, 33 deselected; the configured PostgreSQL variants remain unverified.
- `CheckScript -ScriptPath res://track/creator_bridge_visual.gd`: passed. `git diff --check`: passed.
- Android SDK `adb.exe devices`: empty device list. No Android export, installation or physical-device test performed.

## Changed files and remaining acceptance

Implementation: `game/core/app.gd`; `game/editor/editor_canvas.gd`, `editor_world.gd`, `track_compiler.gd`; `game/track/creator_bridges.gd`, `creator_bridge_visual.gd`, `desert_bridge_visual.gd`, `native_track.gd`.

Regression/evidence: `game/tests/profile_road_approval.gd`, `test_construction.gd`, `test_creator.gd`, `test_editor_workflow.gd`, `fixtures/compiler_raster.json`; `backend/tests/fixtures/verified_oval.json`; this document and evidence directory; AGENTS.md, DEVELOPMENT_STATUS.md and PHASE_0_PLAN.md.

Uncached scenery construction still happens on the main thread when its worker result arrives and may cause a hitch on large maps. Autosave and route validation also remain synchronous. The bounded scenery cache trades memory for speed; phone memory/frame-time measurements, long editing sessions, touch responsiveness and human acceptance of junction appearance remain outstanding. No claim is made that all creator performance issues are resolved. Existing player files and unrelated working-tree edits were preserved.
