# Automatic waypoints and retired track collection

2026-09-17 owner request. Requirements: R01 / T01-T04 / V03 / V05. Supersedes manual waypoint authoring and the earlier imported 194-track playable collection.

## Behavior

Waypoints offers **Auto waypoints**, which traces one closed chain of placed road pieces. Manual node movement, insertion, deletion, width/corner inspectors, manual lap-start selection and road-from-route action are removed. The generated route is shown as small passive gold markers; dragging pans instead of editing nodes. Auto generation preserves road geometry, is undoable/redoable, and saves to the existing WIP flow. Incomplete/disconnected roads report an actionable error without altering the previous route. Practice-start positioning remains a separate untimed spawn control. Auto generation requires connected road sections; it does not infer a lap from arbitrary painted asphalt. Existing saved creator routes remain readable.

All 194 Slicks JSON circuits were moved out of runtime resources to `game/tests/fixtures/legacy_tracks/`. The playable catalog contains only an original **Starter Circuit**, generated from the existing project-owned default creator layout. Saved original creator circuits remain available. Retired native bases fail validation and do not appear as playable saved remixes. The application never deletes their player files. A retired last-played preference safely falls back to the starter circuit. Old favorites/records are not destructively rewritten. The starter can be edited but has no user-track deletion action.

The historical native fixtures remain solely to preserve existing handling/collision/replay diagnostics. The existing Android `exclude_filter="tests/*"` excludes them; no shipping code references their paths. SHA-256 verification against their original manifest found **194 matches, zero mismatches**. Original source archives/import tools outside the export root remain historical development material. No legacy binary importer is added or exposed.

## Changed files

- Runtime: `game/core/app.gd`, `game/core/game.gd`, `game/editor/editor_canvas.gd`, `game/ui/track_catalog.gd`, `game/ui/track_browser.gd`.
- Content: `game/resources/builtin_tracks.json`, new `game/resources/tracks/starter_circuit.json`, 194 relocated `slicks_*.json` files and the provenance manifest/README under `game/tests/fixtures/legacy_tracks/`.
- Contract/tooling: `docs/schemas/builtin-track-catalog-v1.schema.json` accepts original native IDs/attribution without requiring a third-party source archive; `scripts/dev.ps1` adds GenerateStarter, TestEditorRetirement, CaptureEditorRetirement and the new test to Validate.
- New tests/generator: `game/tests/test_editor_retirement.gd`, `game/tests/generate_starter.gd`.
- Tests updated to current UI or starter: `test_app.gd`, `test_editor_v2.gd`, `test_editor_workflow.gd`, `test_editor_practice.gd`, `test_free_editor.gd`, `test_catalog.gd`, `test_menu_presentation.gd`, `test_road_pieces.gd`, `test_kerbs.gd`.
- Historical regression paths updated in `capture_handling.gd`, `test_bridge_hud.gd`, `test_bulk_tracks.gd`, `test_cars.gd`, `test_extra_tracks.gd`, `test_handling.gd`, `test_tracks.gd`.
- Documentation: AGENTS.md override, DEVELOPMENT_STATUS.md, docs/PHASE_0_PLAN.md, licenses/ASSETS.md, this document and evidence.

Existing unrelated worktree changes were preserved. Canonical simulation and creator schema/compiler identity are unchanged. No player files were removed.

## Actual verification

All commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 <Action>` and pinned Godot 4.7.2:

| Action | Actual result |
|---|---|
| GenerateStarter | Original native JSON generated successfully |
| CaptureEditorRetirement | 26 checks, zero failures; real editor/library captures |
| TestApp | 86 checks, zero failures; input, undo, persistence and startup |
| TestEditor | 35 checks, zero failures; passive waypoint UI and object editing |
| TestWorkflow | 168 checks, zero failures; road controls, automatic route and practice |
| TestFreeEditor | 43 checks, zero failures; five-lap crossing race, saved creator geometry, starter editing |
| TestPieces | 172 checks, zero failures; five-lap section race |
| TestPractice | 33 checks, zero failures; six-lap starter witness, zero contacts |
| TestCatalog | 18 checks, zero failures; search/filter behavior including 5,000 metadata entries |
| TestMenus | 11 checks, zero failures |
| TestKerbs | 31 checks, zero failures |
| TestTracks | 167 historical physics checks, zero failures |
| TestCorpus | 793 historical fixture checks, zero failures |

Manual-node UI assertions were replaced with the new required passive/automatic behavior. Mouse/touch/undo/autosave tests now exercise road dimension handles rather than retired waypoint handles; none of those interaction guarantees were dropped. The generator initially rejected a newly assigned StringName creator key; using the contract's string key corrected it. One capture reported a Windows WASAPI output-device invalidation despite all assertions passing; rerunning it passed cleanly. Practice reported the existing two ObjectDB exit leaks. A new autosave assertion was corrected to compare JSON-round-tripped coordinates, matching persistence precision.

[Editor screenshot](evidence/automatic-waypoints/editor.png) and [playable library screenshot](evidence/automatic-waypoints/library.png) are inspected engine output. The first visual pass exposed large overlapping waypoint rings; these were replaced with passive small markers. The library capture now contains no unsupported saved remix or legacy native card.

## Acceptance limits

No phone/device test or Android export was performed. Export exclusion was inspected in configuration, not verified by building an APK. Full Validate was not run. Remaining acceptance: owner review of the automatic-only flow, road-chain requirements, phone touch reach and legibility. Unsupported old remixes remain on disk but are not loadable/playable. Existing independent creator tracks are supported.
