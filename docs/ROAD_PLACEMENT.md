# Road dimensions and placement ? 2026-09-16

Requirements: R01 / T01?T04 / V03 / V05; owner request for S-curve height, equal hairpin sides and on-element acceptance with dragging preserved.

S-bend Shape now offers Height (2?60 m), with metre buttons and a direct geometry handle. Height is lateral map span, independent of the existing lead-in length. Optional `height` is persisted in creator-track-v5 and validated; omitted values preserve the previous radius-derived height. Endpoint resizing scales authored height with the whole piece. Hairpins now have matching straight entry and exit arms, each using `length`; endpoint poses, outlines and compiled roads use that same geometry.

The selected/preview road displays a 56 px yellow checkmark on its centerline. Tap accepts placement or finishes selection. Movement beyond 8 px turns that same press into ordinary whole-piece dragging without accepting. Canceled touches and pinch gestures cannot accept. Endpoint/geometry handles take priority where touch regions overlap. The corner confirmation remains available for other editor tools. At extreme zoom-out, small roads can have overlapping controls; zoom in for precise editing.

Compiler identity advances to creator-compiler-11 because hairpin geometry changed. The canonical creator golden hash is now `62a46b0e0e31115b22e25a55eaa0665f7f3dfa97d24556192937268311f65269`. Existing files are not deleted; existing hairpins gain the matching exit arm when recompiled and may need their neighbours reconnected.

Changed files: `game/editor/road_pieces.gd`, `game/editor/editor_canvas.gd`, `game/editor/track_compiler.gd`, road controls in `game/core/app.gd`, `game/tests/test_road_pieces.gd`, `game/tests/test_editor_workflow.gd`, `game/tests/test_construction.gd`, `game/tests/test_creator.gd`, `docs/schemas/creator-track-v5.schema.json`, this document, status/phase notes and evidence below. The workspace already contained unrelated edits; those were retained.

Actual commands (Windows PowerShell, pinned Godot 4.7.2):

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestPieces`: 172 checks, 0 failures, including a five-lap creator race.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestCreator`: 86 checks, 0 failures; compiler identity and three historical diagnostic races.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestWorkflow`: initial existing suite, 94 checks, 0 failures; two ObjectDB leak warnings at exit.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureWorkflow`: final graphical suite, 107 checks, 0 failures. New assertions cover height, tap acceptance, drag from checkmark, cancellation and hiding the corner road action.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestConstruction`: 74 checks, 0 failures, including five-lap bridge driving and exact replay.

During development, the first added workflow test polluted a later test's undo history; isolating its document and moving it after the original workflow corrected the fixture. The construction fixture previously tapped the bridge's center checkmark before testing its endpoint; it now explicitly verifies that this accepts selection, then reselects the bridge before checking endpoint input. No endpoint assertion was removed.

[Inspected engine screenshot](evidence/road-placement/s-height-accept.png). The initial capture exposed overlapping dimension/hint text; the hint was moved above the road bounds and the final capture inspected. Test logs are in `docs/evidence/road-placement/`.

No physical-phone/device test or Android export was performed. Remaining acceptance: owner review of the new placement gesture and hairpin shape, phone reach/zoom and touch feel. No full physics regression was run; canonical vehicle handling is unchanged.

## Hairpin straight-length follow-up

Owner follow-up (2026-09-16), R01/T01-T04/V03/V05: added a directly visible **Straight length** action for hairpins, renamed the former Lead-in caption, and clarified that both arms change equally independently of radius. New hairpins default to 0 m straight length; existing pieces keep their authored value and can reduce it to zero. No document/schema/compiler contract changes were needed for this follow-up.

Changed files: `game/core/app.gd`, `game/editor/editor_canvas.gd`, `game/editor/road_pieces.gd`, `game/tests/test_editor_workflow.gd`, this document, status/phase notes and the hairpin evidence files.

Actual commands: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestPieces` passed 172 checks; `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureWorkflow` passed 113 checks. Tests exercise direct access, zero default, independent radius and reduction back to zero. Inspected engine captures: [12 m arms](evidence/road-placement/hairpin-straights.png) and [0 m plain U-turn](evidence/road-placement/hairpin-zero-straights.png). Logs: `hairpin-pieces.txt` and `hairpin-workflow.txt` in the same evidence directory. No physical-phone test or Android export performed. Owner/device feel acceptance remains open.

## Direct preview controls follow-up

Owner request (2026-09-16), R01/T01-T04/V03/V05: every selected road/placement preview exposes its applicable dimensions simultaneously, without a toolbar mode switch. Straight and bridge offer Length, Width and Rotate. Curves add independent straight lead-in, Radius and Angle; S-bends add Height; hairpins expose Straight length and Radius with equal arms. Existing toolbar controls remain as numeric alternatives.

All controls share cyan directional arrows, value captions, leader lines to the geometry, and 48 px hit targets. Layout separates their captions and hit targets from each other, endpoint dots and the yellow accept control. The redundant floating instruction badge was removed after captures showed overlap. Endpoint resizing and body/accept dragging remain available. Direct dimensions use the original gesture geometry to avoid cumulative drift, clamp to valid dimension limits, and preserve the existing validation/undo/cancellation flow. S-bend radius dragging preserves lateral height. Rotation follows a tangential drag around the anchored start.

Changed files for this follow-up: `game/editor/editor_canvas.gd`, `game/tests/test_editor_workflow.gd`, this document, status/phase notes and `docs/evidence/road-placement/direct-*` evidence. No schema, compiler identity, or canonical simulation change.

Actual commands: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureWorkflow` passed 183 checks, including native touch selection and dimension changes for every handle on all five types without choosing a toolbar mode, plus matching controls on committed roads. An initial new assertion expected unrounded S height; it was corrected to the editor's existing half-metre snapping contract. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestConstruction` passed 74 checks (including exact bridge replay); the existing two ObjectDB exit leaks were reported. `git diff --check -- game/editor/editor_canvas.gd game/tests/test_editor_workflow.gd` passed.

Engine screenshots: [Straight](evidence/road-placement/direct-straight.png), [Curve](evidence/road-placement/direct-curve.png), [S-bend](evidence/road-placement/direct-s_bend.png), [Hairpin](evidence/road-placement/direct-hairpin.png), [Bridge](evidence/road-placement/direct-bridge.png). Logs: `direct-workflow.txt` and `direct-construction.txt` beside them.

No physical-phone/device test or Android export performed. Owner acceptance of control placement, gesture feel, small-screen legibility and extreme zoom/pan remains open; handles on a piece near the viewport boundary may require panning to reach. Bridge elevation remains fixed by the existing bridge contract.


## Straight and curve dot controls (2026-09-17)

Owner request, R01/T01-T04/V03/V05: straight and curve sections use their two endpoint dots for size and rotation. Their separate Shape/Rotate/Width toolbar buttons and floating length/rotation controls are removed. Width is an arrow-in-dot directly on the road edge with no leader line or caption. Curves have an angle dot inside the bend; dragging around the arc center adjusts the angle. Endpoint drags resize the curve radius and rotate it while retaining the opposite endpoint. The accept button moves to the quarter point to leave the middle clear for width and angle controls. Other road types retain their controls.

Curves are now pure arcs. New curves store zero length, and any old stored curve lead-in is ignored by sampling/end poses. Resizing a curve resets that unused length to zero. This intentionally changes existing curves with a straight portion; no player files are deleted. Compiler 14 versions that content change. Starter regenerated, schema field description updated, and creator golden becomes `5cba5f896d825ef2ddfbe5a345992eb9a43a146db019dde92e7a6be49d73e0b0`.

Changed files: `game/editor/editor_canvas.gd`, `road_pieces.gd`, `track_compiler.gd`; `game/core/app.gd`; `game/tests/test_editor_workflow.gd`, `test_road_pieces.gd`, `test_creator.gd`; `game/resources/tracks/starter_circuit.json`; `docs/schemas/creator-track-v5.schema.json`; this document, DEVELOPMENT_STATUS.md and docs/PHASE_0_PLAN.md.

Actual commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 ACTION`:

- TestPieces: 184 checks passed, including pure-circle samples for both directions despite an old lead-in, both endpoint edits, and a five-lap race with zero contacts.
- TestCreator: 86 checks passed with compiler-14 golden and driven race checks.
- TestConstruction: 74 checks passed, including five-lap bridge driving and exact replay. The existing two ObjectDB exit leaks were reported.
- GenerateStarter: completed.

Initial workflow checks expected removed radius/width captions and a four-degree movement smaller than the inner angle dot's effective drag threshold. The checks now verify endpoint motion, absence of separate buttons, width-dot alignment, and a 30-degree angular gesture. Endpoint position is checked within 0.001 m rather than asserting an exact floating-point radius delta.

Desktop captures: [straight](evidence/road-dots/straight.png), [curve](evidence/road-dots/curve.png). No phone/device test or Android export performed. Owner acceptance of gesture feel, narrow bends, and small-screen touch spacing remains pending. Full Validate was not run for this slice.

Final CaptureWorkflow: 170 checks passed, including touch drags on previews and committed roads, endpoint undo, width-dot placement and inner angle adjustment. Total: 514 passing checks across the four suites. Final targeted git diff --check passed.


## Fixed S-curve ends (2026-09-17)

Owner request, R01/T01-T04/V03/V05: every S-curve has a short straight on both ends, with no length adjustment. Each straight is fixed at 2 metres, an implementation choice for "very short". The length handle and Lead-in toolbar option are removed; stored length values no longer affect S geometry. Radius and height remain adjustable. Endpoint resizing solves for the curved span while keeping both end straights at 2 m and placing the dragged endpoint exactly at the pointer. Mirroring and rotation preserve matching entry/exit tangents.

Compiler 15 versions the changed S geometry; existing S-curves adopt the fixed ends without deleting player files. Updated the schema field description, regenerated the starter and changed the default golden to `9f033bdfcab6f0ce4473f46283af2eff18b84633999e76b2a876b55ee388582d`.

Changed files: game/editor/road_pieces.gd, editor_canvas.gd, track_compiler.gd; game/core/app.gd; game/tests/test_road_pieces.gd, test_editor_workflow.gd, test_creator.gd; game/resources/tracks/starter_circuit.json; docs/schemas/creator-track-v5.schema.json; this document, DEVELOPMENT_STATUS.md and docs/PHASE_0_PLAN.md.

Actual commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 ACTION`. TestPieces passed 201 checks, including fixed 2 m ends and aligned tangents after resizing either endpoint in both mirrored directions, ignored stored lengths, and a five-lap race without contacts. GenerateStarter completed. Further results and the capture are recorded below.

No phone/device test or Android export was performed. Full Validate was not run. Owner acceptance of the chosen 2 m fixed length and phone gesture feel remains pending.

Final CaptureWorkflow passed 168 checks; TestCreator passed 86 checks with unchanged default geometry and compiler-15 identity. Total: 455 passing checks. The initial graphical run caught a typed-array conditional error; an explicitly typed control list fixed it and the rerun passed. Targeted git diff --check passed. [Inspected S-curve capture](evidence/s-fixed-ends/s-bend.png); logs are alongside it.


## Adjustable curve curvature (2026-09-17)

Owner request, R01/T01-T04/V03/V05: normal curves have an additional draggable inner dot for reshaping curvature, with a perfect circular arc by default. The central inner dot moves radially to tighten or expand the middle; the angle dot sits farther along the inner arc and retains angular adjustment. Width remains separate. No extra toolbar selection is required.

Optional curve-only `curvature` defaults to zero and is clamped to [-0.3, 0.3]. It applies a smooth radial bulge weighted by sin(pi * fraction)^2, keeping both endpoints and their analytic tangents unchanged. Its scale is radius * min(1, angle/90)^2, limiting shallow-arc deformation. Additional samples maintain smooth deformed geometry. Mirroring, endpoint resizing, JSON persistence and undo retain the setting. New compiler-16 identity versions the content contract; the schema, starter and creator golden were updated. Default golden: `819930a1ffa5d5d8aedcaa7b13a0a3f39b11f96e8bfea0ee34fd74aa4e64da2b`.

Changed files: game/editor/road_pieces.gd, editor_canvas.gd, track_compiler.gd; game/tests/test_road_pieces.gd, test_editor_workflow.gd, test_creator.gd; game/resources/tracks/starter_circuit.json; docs/schemas/creator-track-v5.schema.json; this document, DEVELOPMENT_STATUS.md and docs/PHASE_0_PLAN.md.

Actual commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 ACTION`:

- TestPieces: 278 checks passed. Covers exact circular default, both curvature bounds, mirrored curves at 15/90/180/270 degrees, endpoint preservation, malformed values, JSON/compiled-cell identity, and a loop of alternating inward/outward reshaped curves. That circuit completes five laps with zero contacts and replays exactly.
- TestCreator: 86 checks passed with the compiler-16 golden and unchanged default geometry/racing outcomes.
- GenerateStarter: completed.

No phone/device test or Android export was performed; full Validate was not run. Owner acceptance of drag feel and handle spacing on very small/tight bends remains pending. Desktop capture and final workflow result follow below.

CaptureWorkflow passed 176 checks, including direct curvature dragging, upper clamping, joined endpoint preservation, undo and redo. Total: 540 passing checks. Inspected [circular default](evidence/curve-curvature/circular.png) and [reshaped curve](evidence/curve-curvature/reshaped.png). Logs are alongside the captures. Targeted git diff --check passed.


## Consistent S-curve and hairpin dots (2026-09-17)

Owner request, R01/T01-T04/V03/V05: S-curves and hairpins now follow the straight/curve direct-dot convention. Endpoint dots resize and rotate. The width dot sits on the road edge. S-curve inner dots independently adjust longitudinal span (radius) and height; its 2 m end straights remain fixed. Hairpin inner dots adjust radius and the equal straight-arm length, including zero. Both types omit separate Shape/Width/Rotate/Straight length buttons, floating captions and leader lines. The accept control sits at the quarter point to leave space for the local controls. Bridges retain their existing controls.

This changes controls/presentation only; no content schema, compiler version or canonical simulation change. Changed files: game/editor/editor_canvas.gd, game/core/app.gd, game/tests/test_editor_workflow.gd, this document, DEVELOPMENT_STATUS.md and docs/PHASE_0_PLAN.md.

Actual commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 ACTION`. TestConstruction passed 74 checks including five-lap bridge driving and exact replay; the existing two ObjectDB exit leaks were reported. The initial workflow radius-drag test allowed implicit S height to change while deriving its expected drag direction. It now holds height fixed, matching the existing independent-height contract. Final graphical results and evidence follow below.

No phone/device test, Android export or full Validate was performed. Owner acceptance of dot spacing and gesture feel, particularly at small scales or tight bends, remains pending.

Final CaptureWorkflow passed 174 checks, including actual touch selection and independent dimension changes on every preview and matching width controls after placement. Total: 248 passing checks. Targeted git diff --check passed. Inspected [S-curve](evidence/consistent-bend-dots/s_bend.png) and [hairpin](evidence/consistent-bend-dots/hairpin.png) captures; logs are alongside them.


## Handle affordances without labels (2026-09-17)

Owner request, R01/T01-T04/V03/V05: make each handle's purpose clearer without adding labels. Endpoint handles now use white four-way movement symbols. Width is a blue rounded square containing parallel road-edge bars and a widening arrow. Amber circular shape handles use action-specific pictograms: curved-edge/radial arrows for curvature or radius, an angle/circular arrow for sweep, an S with horizontal arrows for span, an S with vertical arrows for height, and parallel arms with extension arrows for hairpin straight length. Shape and symbols distinguish actions independently of colour. No new text labels or persistent leader lines were added.

Pressing a handle adds a halo and a short directional cue. Width highlights the two road edges; shape controls highlight the centerline, making the affected geometry visible before moving. Nearby inner controls are offset by the smallest tested screen-space displacement to separate their 48 px touch targets, endpoints and acceptance button. Width stays attached to its road edge. Drag calculations remain anchored to the original geometry, so spacing offsets do not alter the value under the finger.

Changed files: game/editor/editor_canvas.gd; game/tests/test_editor_workflow.gd; this document, DEVELOPMENT_STATUS.md and docs/PHASE_0_PLAN.md. No geometry schema, content version or simulation changes.

Actual commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 ACTION`. TestConstruction passed 74 checks including five-lap bridge driving and exact replay. The updated graphical workflow checks pairwise handle spacing and native touch selection, dimension changes, undo/redo and capture during width selection. The initial angle test assumed screen control and geometry anchor were identical; its pointer motion now uses the same angular displacement relative to the spaced handle, preserving the requested angle-change assertion. Final capture outcome follows below.

No phone/device test or Android export was performed; full Validate was not run. Whether the symbols are immediately intuitive still needs owner feedback. Very tight geometry/extreme zoom may need panning or zooming for comfortable touch editing.

Final CaptureWorkflow passed 184 checks; total 258 passing checks with TestConstruction. Targeted git diff --check passed. Inspected [S-curve symbols](evidence/handle-affordances/direct-s_bend.png), [hairpin symbols](evidence/handle-affordances/direct-hairpin.png), [curve symbols](evidence/handle-affordances/direct-curve.png) and [pressed width feedback](evidence/handle-affordances/active-width.png). Logs and other road captures are alongside them.


## Adjust the free end (2026-09-17)

Owner request, R01/T01-T04/V03/V05: when exactly one endpoint is attached to another road, use it as the editing pivot. Attachment uses the existing 0.15 m join tolerance, excludes the selected road itself, and works for committed sections and previews.

Dimension, angle, curvature and flip edits retain the connected endpoint and its tangent, shifting/rotating the edited section so the free end takes the change. Explicit rotation pivots around the connected point. Dragging either endpoint grip moves the free endpoint, with attached-grip motion applied as a delta to prevent jumping. Endpoint drags can change the joining angle; they retain the connected position. The attached grip displays a lock pictogram. Curve angle controls move toward the free side and use the corresponding angular drag direction. Original geometry is retained for the full gesture, avoiding accumulated drift.

Neighbors remain untouched. With neither or both ends attached there is no unique attached/free pair, so existing behavior applies. Whole-piece dragging remains an explicit move/detach operation. Geometry/map bounds and bridge validation still reject invalid edits. No file schema, compiler identity or canonical simulation change.

Changed files: game/editor/road_pieces.gd, editor_canvas.gd; game/core/app.gd; game/tests/test_road_pieces.gd, test_editor_workflow.gd; this document, DEVELOPMENT_STATUS.md and docs/PHASE_0_PLAN.md.

Actual commands used `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 ACTION`:

- TestPieces: 328 checks passed. All five road types preserve either attached endpoint/tangent and move the free end on dimension changes; both-attached detection is covered. Existing curved and ordinary circuits complete five laps without contacts and replay exactly. Compiler-16 golden remains unchanged.
- CaptureWorkflow: 207 checks passed. Real touch edits on curves attached at either end, both committed and preview, preserve the join and neighbor, follow the angle drag, redirect attached-grip motion to the free end and undo exactly.
- TestConstruction: 74 checks passed, including five-lap bridge driving and exact replay.

Total: 609 passing checks. Targeted git diff --check passed. [Inspected attached-end capture](evidence/attached-road-controls/attached-free-end.png); logs are alongside it. No phone/device test, Android export or full Validate was performed. Owner acceptance of anchored gesture feel and lock discoverability remains pending.
