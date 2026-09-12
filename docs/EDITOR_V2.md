# Track editor revision 2

2026-09-12 owner-requested sharp corners, independent road widths and mobile object editing. Requirements: T01 bounded plain-data authoring; T02 route validation; T03 content identity foundations; T04 free local drafts/exchange; V05 shared editor/race geometry; R01 touch interaction. No simulation algorithm changes.

Select a numbered road node to set its width (6–20 m) and choose Smooth or Sharp. Add bend inserts a sharp node on the closest road section and selects it for dragging. Selecting near a node preserves its position; dragging preserves the finger offset. Set start keeps width and corner properties together. Undo/redo includes these properties.

Objects offers trees, rocks, barriers, dirt and water. Tap to repeat-stamp; select to move, rotate in 45-degree steps, copy or delete. Drag empty space to pan; pinch to zoom. Starting a pinch or canceling a pending touch places nothing. Controls fit the captured 1280×720 landscape layout; physical-phone usability remains untested.

Native cells remain authoritative. Barriers/water block; trees/rocks slow the car. Terrain stamps sit below the road, physical objects above it. All themes reuse the original matte procedural kit. No downloaded editor graphics or binaries are shipped. The 2D view shows footprints; 3D preview shows the compiled track and placed kit. Road stamping uses 0.5 m cells, so edges remain rasterized, with rounded outer corners even when the centreline is sharp.

## Slicks ideas adapted

Read SSEDIT255.TXT from the SSEdit archive linked by the [official Slicks site](https://slicksnslide.com/) ([archive](https://slicksnslide.com/webapi/download.php?p=dos-slix&v=ssedit+for+1.41.zip)). Downloaded into ignored build/ for reference; no executable was run or redistributed.

| Original editor idea | Mobile adaptation |
|---|---|
| Object pieces and repeated placement | Small built-in palette and repeat tap stamping |
| Rotation and selected-object removal | Visible Rotate, Copy and Delete buttons |
| Above/below placement | Automatic terrain/road/prop order |
| Separate route/checkpoint/start modes | Generated routing/checkpoints and Set start |
| Computer-driver testing | Test drive and automated diagnostic race checks |

## Format and geometry

Only `creator-track-v2` is supported, per the owner's explicit compatibility waiver. There is no v1 migration. Existing files remain untouched; old-format imports are rejected and drafts excluded from the usable library. Historical schemas/docs are not a runtime compatibility promise.

See [schema](schemas/creator-track-v2.schema.json). Each point has matching `widths` and `corners` (`smooth` or `sharp`) entries. Up to 96 allowlisted objects contain only kind, position and rotation. The global width field remains baseline metadata; per-node widths determine the road. Minimum node spacing is 2 m; route length is 40–750 m. Actual centreline crossings fail. The former minimum bend-radius and broad shoulder-separation rules were deliberately removed to satisfy the owner's sharp-turn request. Touching shoulders are allowed; route enjoyment and shortcut fairness are not guaranteed.

Smooth segments retain the default spline. Sharp vertices survive resampling exactly, with interpolated widths. A sharp start node places the start/finish along its outgoing road so apex cutting does not evade the finish plane. Compiler `creator-compiler-2` hashes normalized sorted JSON, preserving identity across integer/decimal save conversions. Default grid, route sample count and road area remain unchanged.

## Verification

Commands ran on Windows using the pinned Godot 4.7.2 console through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- `TestEditor`: geometry, hostile payloads, physical props, sharp-circuit replay and touch checks passed.
- `CaptureEditor`: final expanded suite plus real Windows screenshots passed 42 checks, zero failures.
- `Validate`: import, 46 script parses, startup and all domain/UI regressions passed, including 86 creator, 39 editor, 76 app and 49 records checks. Original driving/track replay suites also passed.
- `git diff --check`: passed.

The sharp four-node circuit with 8–16 m widths completed three diagnostic laps in 28.817 / 28.411 / 28.384 seconds, zero contacts, and exact JSON replay. These are explicit three-lap diagnostics independent of production settings. Tests cover add/set-start/undo/redo, stamp cancellation/pinch, object move/rotate/copy/delete and save/export/import identity. Testing exposed and fixed finish-plane placement, numeric hash normalization and unsupported `%g` UI formatting. An earlier full validation encountered incomplete concurrent menu code; the subsequent full run passed.

Evidence: [validation log](evidence/editor-v2-validation.txt), [graphical checks](evidence/editor-v2-capture.txt), [node inspector](evidence/editor-v2-node.png), [objects](evidence/editor-v2-objects.png), [3D preview](evidence/editor-v2-preview.png). Screenshots use an isolated draft and synthetic touch events.

Changed files: `game/editor/{track_document,track_compiler,editor_canvas,creator_objects}.gd`, editor sections of `game/core/app.gd`, placed-kit sections of `game/track/native_track_visual.gd`, creator fixture/tests, `game/tests/test_editor_v2.gd`, v2 schema, wrapper actions and docs. `TrackSession` accepts an explicit diagnostic lap count, preserving its existing three-lap default in this checkpoint. Concurrent menu/library/race-rule work is separate; its working-tree catalog schema guard excludes v1.

The v2 JSON schema was checked with the existing development-only `jsonschema.Draft202012Validator`: starter fixture accepted; legacy version, unsupported object, narrow width and invalid corner rejected. No runtime dependency added. To isolate the checkpoint from concurrent edits, `git checkout-index --all --prefix=build/editor-v2-checkpoint/` created an ignored index snapshot. The same wrapper's Validate and CaptureEditor actions were then run from that snapshot; final isolated results are recorded below. Main workspace files were not reverted.

Final isolated checkpoint: **41 script parses and 489 checks passed** (56 driving, 163 original tracks, 27 extra tracks, 86 creator, 39 editor, 70 app, 48 records). CaptureEditor passed 42 checks and its screenshots are the retained images above. [Isolated validation log](evidence/editor-v2-checkpoint-validation.txt). The first snapshot run exposed the new tests' explicit lap-count dependency; the small TrackSession constructor extension was included and the full rerun passed. Validation evidence has terminal color codes removed and line endings normalized for review.

Remaining acceptance: real-phone reach/touch targets/safe areas, pan/pinch, file picker/performance, novice creation/testing/sharing, and human evaluation of tight tracks. No physical-phone test or APK export was performed; Android tooling/device enumeration was unavailable. No online publication or competition-grade shortcut verification is included. Placed barriers can intentionally make a course undrivable; use Test drive to assess it.
