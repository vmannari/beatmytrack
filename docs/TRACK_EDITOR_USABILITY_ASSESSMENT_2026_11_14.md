# Track editor usability assessment

The editor has reproducible problems with picking, tool state and unfinished work. The most serious findings are losing a surface preview through ordinary toolbar actions and editing the previous object through controls presented as placement settings. These are sufficient to make routine authoring unpredictable, even though basic selection and gesture rollback work.

This is an assessment of the current implementation on 14 November 2026. It includes seven interaction findings and one supporting visibility observation. No production editor fix is included.

## Findings

Priority 1 means loss of work through a routine action. Priority 2 means an incorrect target, unintended edit, or inconsistent interaction that materially disrupts authoring. Priority 3 identifies a visibility weakness. These priorities are engineering judgments, not measured user failure rates.

### EUI01 Unrelated toolbar clicks discard a surface preview

**Priority 1. Confirmed through actual App mouse input.**

Choose Surfaces and Area, then tap three points. Clicking the already-active Area button removes all three points. Opening Map also removes the pending area. Neither action asks whether to discard it. In the Area-button reproduction, the history remains empty and pending work becomes false, so Undo has no checkpoint for the removed preview.

Both actions call `cancel_gesture()`, which also clears `paint_points`. Cancelling an in-progress pointer transaction and discarding a completed but unconfirmed preview currently share that operation. The Map action calls it before opening its panel, and paint-mode buttons call it even when the chosen mode is unchanged.

Sources: [gesture cancellation](../game/editor/editor_canvas.gd#L232), [Map action](../game/core/features/editor.gd#L172), [paint-mode buttons](../game/core/features/editor.gd#L2197).

Native evidence: [three pending points](evidence/editor-interactions-2026-11-14/native-final/05-pending-area.png), [zero points after clicking Area](evidence/editor-interactions-2026-11-14/native-final/06-area-lost-on-active-tool-click.png). The JSON observations also reproduce loss on Map entry.

Recommended behavior: clicking an active tool should preserve its state. Opening settings should preserve the preview. Deliberate preview cancellation should have a separate, explicit action.

### EUI02 Placement orientation changes the last placed object

**Priority 2. Confirmed through the actual object palette and orientation buttons.**

Choose a wooden crate, place it, and change Orientation to 90 degrees while remaining in placement mode. The placed crate changes from 0 to 90 degrees and an Undo entry is added. The placement angle also becomes 90 degrees.

At the time of the edit, `mode` is `place` and the property controls report `selected = false`, but `selected_object` still refers to the placed crate. The controls construct a placement-settings view; the rotation handler instead treats any nonnegative object selection as an instruction to edit that object. Size explicitly checks whether the controls are editing a selected object, making rotation inconsistent with its neighboring control.

Sources: [selection after placement](../game/editor/editor_canvas.gd#L641), [property-control target](../game/core/features/editor.gd#L924), [rotation handler](../game/core/features/editor.gd#L972).

Native evidence: [placement controls](evidence/editor-interactions-2026-11-14/native-final/03-after-placement.png), [orientation adjustment](evidence/editor-interactions-2026-11-14/native-final/04-stamp-rotation-changed-existing.png). The object-angle change is recorded in JSON; a square crate's footprint alone is insufficient to prove a 90-degree rotation visually.

Recommended behavior: placement controls should update the next placement. Editing an existing object should require an explicit selected-object context.

### EUI03 Road picking favors selection and insertion order over the clicked road

**Priority 2. Reproduced with mouse-equivalent canvas coordinates and native touch events.**

The controlled case contains two separate parallel roads, each 6 m wide, with centers 8 m apart. At overview zoom their centers are 21.049 pixels apart. Clicking the exact center of road 0 selects road 1 when nothing is selected. After selecting road 0, clicking the exact center of road 1 keeps road 0 selected.

The road picker first tries the current selection, then tries other pieces in reverse insertion order. It accepts the first piece with a sampled centerline point inside a minimum 24-pixel radius. It does not rank candidates by distance. At this zoom, that invisible tolerance extends beyond the visible road and includes the neighboring road's center.

Source: [road candidates and hit testing](../game/editor/editor_canvas.gd#L888). The object picker already ranks containment and distance; the road picker uses a different rule.

Layer/cycling reaches the other road in the control case, but requiring it for a click directly on a separate road creates unnecessary recovery work.

Recommended behavior: rank road hits by the visible geometry and distance, then provide cycling for ambiguous overlaps. Avoid letting an existing selection override a clearly closer road.

### EUI04 Clicking an object permanently leaves placement mode

**Priority 2 usability issue with intentional implementation behavior. Confirmed through actual App mouse input.**

Choose a crate for placement and click an existing crate. The mode changes from `place` to `objects`. Click empty ground next: nothing is placed, and the mode remains `objects`. Resuming placement requires choosing an asset again.

The transition is deliberate: the canvas changes mode when placement input intersects an authored object. Direct access to object editing is useful, but the incidental hit also changes the meaning of subsequent clicks. Both states keep the Objects rail highlighted, and ordinary contextual guidance is hidden as described in EUI08.

Source: [placement-to-selection transition](../game/editor/editor_canvas.gd#L388). Native evidence: [placement palette](evidence/editor-interactions-2026-11-14/native-final/01-place-before-click.png), [object editing after the click](evidence/editor-interactions-2026-11-14/native-final/02-placement-became-selection.png).

Recommended behavior: expose Select and Place as clear states. If clicking an object temporarily selects it during placement, provide an obvious way to resume the pending placement.

### EUI05 A one-pixel movement can move an object substantially

**Priority 2. Reproduced directly against the production canvas input handler.**

With the default 1 m object grid, an object at `(0.49, 0.49)` moves to approximately `(1, 0)` after a one-pixel horizontal drag. Its resulting screen displacement is 5.497 pixels. The initial coordinates are legal; imported objects, rotation and free-placement operations can produce coordinates outside the active grid.

The drag path snaps the absolute target before deciding whether the gesture is an edit. It uses a world-distance threshold of 0.1 m rather than a screen-space drag threshold. Small pointer movement can therefore start an edit and snap both axes, including an axis the pointer did not move along.

Source: [object movement and edit threshold](../game/editor/editor_canvas.gd#L545). A pure tap leaves the document unchanged, so this is specifically a movement-discrimination problem.

Recommended behavior: require a screen-space drag threshold before editing, and apply grid snapping to the intended movement without immediately relocating an off-grid selection.

### EUI06 Escape leaves placement and the previous object targeted

**Priority 2. Confirmed through actual App keyboard and mouse input.**

After choosing a crate, press Escape and click empty ground. A crate is still placed. After placing an object, Escape also leaves `selected_object` intact; pressing Delete next removes that object. In the controlled sequence the object count falls from two to one.

Escape clears the road ghost and road selection, but does not clear the object selection or exit object placement. The help says “Esc cancels” without explaining that difference. Undo can recover the deletion; this finding concerns inconsistent cancellation and continued targeting.

Source: [Escape handling](../game/core/features/editor.gd#L1436), [object deletion](../game/core/features/editor.gd#L906).

Recommended behavior: define one cancellation sequence across tools, such as cancelling the active gesture first, then clearing the preview/selection or returning to Select on another Escape. Show when a placement tool remains armed.

### EUI07 Tab can switch Surfaces to Track

**Priority 2. Confirmed through the actual App keyboard handler.**

Choose Surfaces and Line, click on a road, then press Tab with no text field focused. The mode changes from `paint` to `road`, a road is selected, and the surface toolbar disappears.

The shortcut cycles objects only in `objects` mode. Every other mode calls `cycle_piece()`, which sets the road mode. This route bypasses the normal category-switch handler. The help describes Tab as cycling overlapping roads, but its implementation is not limited to road editing.

Sources: [Tab handling](../game/core/features/editor.gd#L1461), [road cycling changes mode](../game/editor/editor_canvas.gd#L1390). Native evidence: [surface tool replaced by road controls](evidence/editor-interactions-2026-11-14/native-final/07-tab-switched-to-road.png).

Recommended behavior: scope cycling to its active domain and preserve conventional focus navigation where appropriate.

### EUI08 Useful guidance exists but is normally hidden

**Priority 3 supporting observation.**

The UI computes tool instructions, including how to place, move, reshape and cycle components, but hides the feedback label when there is no save error or temporary hint. The native review records a nonempty road instruction with `guidance_visible = false`. Error hints do appear; the limitation is ordinary mode guidance.

Source: [guidance stored then hidden](../game/core/features/editor.gd#L754). Native evidence: [road preview without the computed guidance](evidence/editor-interactions-2026-11-14/native-final/08-road-guidance.png).

A compact persistent state such as “Place: Wooden crate” or “Select objects” would help users predict their next click without displaying the full help text continuously.

## What works

The control cases retain useful behavior: a pure object-selection tap does not alter document data; cancelling a moved-object gesture restores its original position; switching away from and back to Track preserves an unfinished road preview; and road cycling can reach the otherwise obscured candidate. These findings do not establish a general failure of selection, cancellation or preview retention. The problems occur at specific state transitions and input boundaries.

## Recommended order

1. Preserve unfinished surface work and separate placement settings from existing-object edits.
2. Correct road candidate ranking and object drag discrimination.
3. Make placement/selection state explicit, align Escape behavior, and constrain shortcuts to their tool domains.

This work should precede further cosmetic editor changes. Verification should exercise the complete click sequences above, including the next click after a mode transition, and check both document state and visible controls.

## Evidence and scope

The [review script](../game/tests/review_editor_interactions_2026_11_14.gd) uses validated disposable fixtures, actual App controls, viewport mouse/keyboard events and direct native-touch canvas events. It runs offline with workspace-owned profiles, draft libraries and records. The ready-editor gate waits for the real native preview, canvas preparation, world construction and pending writes. No production assertion was weakened.

The final graphical Compatibility run completed **41 fixture/control checks with zero fixture failures**, produced eight native screenshots and reproduced the findings above. The final headless run and a further run through `scripts/dev.ps1` each completed **33 checks with zero fixture failures** and reproduced the same observations. These counts qualify the probes and controls; they are not a claim that the editor has no defects. [Graphical measurements and source hashes](evidence/editor-interactions-2026-11-14/native-final/report.json), [headless measurements](evidence/editor-interactions-2026-11-14/headless-final/report.json), [preferred-runner measurements](evidence/editor-interactions-2026-11-14/preferred-final/report.json).

The engine is the pinned `4.7.2.stable.official.ed1daf0bf`. The preferred entry-point command is:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 `
  -Action TestScript `
  -ScriptPath res://tests/review_editor_interactions_2026_11_14.gd `
  -CommandTimeoutSeconds 150 `
  -TestArgument '--review-out=C:/Codes/Godot/Beat my track/docs/evidence/editor-interactions-2026-11-14/preferred-final'
```

Before execution, the process environment assigns `APPDATA` and `LOCALAPPDATA` to a review profile under `build/editor-interactions-2026-11-14/` and clears `BMT_API_URL` and `BMT_DEV_AUTH_KEY`. Direct final runs use the exact pinned console executable with `--path game --script res://tests/review_editor_interactions_2026_11_14.gd`, adding either `--headless` or `--rendering-method gl_compatibility`. Final raw logs and command receipts accompany the measurements.

Initial attempts are excluded from finding qualification: one did not await lazy editor entry; another fixture assigned a new dictionary key through property syntax, producing a key type rejected by the unchanged document validator; and a later palette-input fixture omitted paging to the crate. Corrected fixtures validate before entry, wait for actual readiness and click through the palette pages. Their original logs/reports are retained under [attempts](evidence/editor-interactions-2026-11-14/attempts). Those setup failures are not attributed to editor usability.

Changed files are this assessment, the review script and its evidence. The five reviewed production sources have exact before/after hashes within each final run. The normal development wrapper refreshes generated build metadata; concurrent repository work remains intact. The review adds no production editor behavior, asset or quality-setting change.

The [source checkpoint](evidence/editor-interactions-2026-11-14/task.patch) contains only the new review script and this assessment. Its verification receipt records exact forward/reverse application in a private repository and equality of the final observations across all three accepted runs. No main-index staging or commit is included. The checkpoint verifier initially encountered Windows automatic line-ending conversion; the private validation repository explicitly disables it for byte-exact application. An earlier receipt check also ran before the checkpoint existed; both verification setup errors were corrected.

The prescribed build-retention cleaner ran at closeout. Automatic approval review rejected direct deletion of `build/editor-interactions-2026-11-14` as “blocked by policy,” so its disposable profiles and private validation output remain under normal retention. The [cleanup receipt](evidence/editor-interactions-2026-11-14/build-cleanup.json) records the shared build total and protected/recent output above the target. The root-level initial report and the `attempts` directory contain excluded fixture results; accepted results are only the three `*-final` directories.

The assessment covers deterministic interaction behavior on Windows at 1280 by 720, with a small Pine fixture. It is not a user study, a performance benchmark, a full editor regression pass or a physical-device result. Phone ergonomics, sustained touch use, dense/large documents and other biomes remain acceptance work. No device test, APK/export, live backend operation, deployment, external share or owner-process action was performed.
