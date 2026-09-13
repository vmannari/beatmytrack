# Direct construction and overpasses ? 2026-09-13

Owner request: drag inside a piece to move it, drag its endpoint dots to reshape it, support desktop navigation, and author bridges. Covers R01, T01?T04 and V05. Bridge authoring supersedes the earlier ground-only scope restriction.

## Controls and behavior

- Drag within a section to translate it. Drag either large end dot to resize and turn it while the opposite end stays fixed. Curved pieces preserve their shape family and proportions; Shape still adjusts radius/lead-in independently. Width stays independent. Endpoint connections permit sharp angles and different widths; they do not add an automatic smooth width taper.
- Wheel zooms around the cursor. Middle/right drag and Space + left drag pan in every tool without painting. F fits the map; +/? zoom; 1?4 choose categories; Q/E rotate; Enter confirms; Esc cancels; Delete removes; Ctrl+Z and Ctrl+Shift+Z/Ctrl+Y undo/redo; Ctrl+S saves. Text fields retain text editing. Tab or the Layer button cycles sections at the last selected crossing.
- Bridge is in Road. Its automatic ramps meet ground at both ends, with a raised deck and collidable side rails. Ground roads and painted surfaces continue underneath. Both editor and racing use the same procedural bridge mesh. Place the crossing beneath the flat middle, then use Race to set the intended ordered lap (or Use roads for a closed piece chain).
- Body/endpoint drags reject invalid geometry and remain at the last valid shape. Snapping also validates its result. Testing a pending preview is disabled until it is confirmed or cancelled. A pinch no longer relocates a ghost merely because the first finger touched empty terrain.

## Contract and implementation

Creator-track-v5 / creator-compiler-5 includes straight bridges: length 24?120 m, width 6?20 m, fixed 3.5 m deck and two 8 m ramps, up to 16 nonoverlapping spans. Two road levels are supported; curved bridges and stacked elevated spans are outside this revision. Existing native remix bridges are retained; new spans cannot overlap their deck. Ground paint/props remain ground-only, so keep tall props clear of ramps/decks. Old user-track formats are unsupported and their files are preserved.

Creator bridge layer transitions use the car's current layer and ramp entrances, independently of the nearby lap tangent. Native tracks without creator spans retain the existing collision path. Visual car pitch/height and skid trails use the actual driving layer. No handling parameters or racing camera framing changed. New meshes and icons are original procedural code, with no added external assets or dependencies.

Changed files:

- `game/core/app.gd`, `game/editor/editor_canvas.gd`, `editor_button.gd`, `road_pieces.gd`: body/end-dot gestures, snapping, PC navigation, overlap selection and preview protection.
- `game/editor/track_document.gd`, `track_compiler.gd`, `game/track/creator_bridges.gd`, v5 schema and default fixture: bounded bridge documents and separate native deck compilation.
- `game/track/creator_bridge_visual.gd`, `bridge_presentation.gd`, `native_track_visual.gd`, `native_track.gd`, `game/core/game.gd`, `game/vehicle/skid_trails.gd`: shared ramps/deck, collision layers and vehicle presentation.
- `game/tests/test_construction.gd`, creator/piece golden expectations and `scripts/dev.ps1`: regression, replay and capture tooling. Generated Godot UIDs are tracked.

## Validation and evidence

All actions use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action <Action>` with pinned Godot 4.7.2.

- `CaptureConstruction`: 75 checks passed, including independent end-dot edits for all five piece families, mouse navigation, real keyboard dispatch, native touch selection, one-step undo, selected bridge retention at crossings, upper rail impact and lower pass-through. Five completed overpass laps took 23,850 simulation ticks with zero contacts, 801 upper-crossing ticks and 807 lower-crossing ticks, followed by exact JSON-input replay.
- `TestWorkflow`: final focused rerun passed all 96 checks. The first full run exposed seven failures because a Test-button refresh cleared the focused issue marker; separating button state from issue selection restored the complete blocked-start recovery workflow.
- `TestPieces`: 106 and `TestCreator`: 86 checks passed in the full run. Earlier stale v4 golden/width expectations were updated to the intentional v5 contract. Default identity is `937933293b3304a5240810da867dc1878e2e41393c9da7d1f3509f4d1171ecfe`.
- `Doctor`: failed due to missing 4.7.2 Android debug templates, configured SDK/platform-tools/build-tools and JDK. No APK or device test was produced; attachment could not be checked through ADB.
- Python parsed the schema and default JSON and checked matching v5 identifiers. This is not a standalone JSON Schema validator run.
- Final `Validate`: import, all 67 script parses, startup and all 898 domain/UI checks passed: driving 56, original tracks 163, extra tracks 27, creator 86, editor 39, free editor 55, pieces 106, practice 31, workflow 96, construction 73, app 84, records 53, catalog 18 and menu presentation 11. Original bridge ramp/rail fixtures and same-engine replay checks remain passing. `git diff --check` also passed.

Screenshots: [editor with selected bridge](evidence/construction-editor.png), [driving on the raised deck](evidence/construction-practice.png). These are engine captures on Windows with synthetic interaction. Visual inspection confirmed endpoint controls, full-screen world, ramps, deck and the lower crossing.

Physical-phone touch reach, safe areas, frame time, multi-touch feel and ramp/camera readability still require device acceptance. No phone test or APK export was performed; this environment lacks the configured Android tools/templates. The earlier usability review's separate race-readiness, object-run route selection and issue-navigation findings remain open; this change does not claim a complete usability sign-off.
