# Creator usability review — 2026-09-13

Reviewed checkpoint: `9377e0b`. Scope: R01, T01–T04 and V05, from blank creation through placement, adjustment, practice and sharing. This is a review, not an implementation of the fixes below. Existing full-screen framing, contextual tool placement, direct geometry handles and Edit here provide a sound base; the remaining problems primarily concern preserving work and explaining when a map is ready to race.

## Findings, in priority order

### 1. High: a visually closed track can be shared with the wrong lap route

Reproduction: start blank, place four connected 90-degree curves, then inspect Test, Share and the issue badge without pressing Race > Use roads. The road is closed, Test and Share are enabled, and there are zero issues. However, **180 of 219 compiled lap samples are off asphalt** because the hidden default lap still belongs to the old starter track. Practice starts on the new road and deliberately does not count laps, so driving it does not expose the incorrect timed route. A previously derived route also stays unchanged when roads are moved later.

Cause: `TrackDocument.create_blank()` retains the starter lap; structural validation accepts it. `_update_editor_issues()` checks open piece endpoints and practice-start collision, not route/map agreement. Sharing uses structural validity. Sources: [blank document](../game/editor/track_document.gd:21), [issue checks](../game/core/app.gd:710), [sharing](../game/core/app.gd:883).

Recommended: distinguish **draft saved**, **practice available** and **race ready**. Track whether a route was deliberately authored and whether subsequent map edits invalidate it. Offer Generate lap when a simple loop closes, then show direction/start/checkpoints for review. Preserve manual routes and free intersections. Require race-readiness checks for a raceable share, while allowing clearly labelled draft export. Do not silently regenerate an intentionally authored route.

### 2. High: independent road widths conflict with the connection rules

Reproduction: on a closed 10 m-wide loop, widen one piece to 12 m. The visible road still touches, but the editor reports **four open endpoints** and Use roads refuses the loop. Snapping the widened piece back changes it to **10 m**, undoing the requested width.

Cause: endpoint matching requires equal whole-piece widths within 0.1 m; snapping replaces the moved piece's width. This means a fully joined loop cannot retain genuinely different section widths. Sources: [snap width replacement](../game/editor/road_pieces.gd:102), [join requirement](../game/editor/road_pieces.gd:120).

Recommended: allow connected sections to have different widths, with explicit transition geometry or independent endpoint widths. Geometry editing should preserve the owner's width choice, with a clear transition warning instead of a misleading “Open road end.” Local radius/length edits also need a way to reconnect or adjust adjacent sections without manually rebuilding the loop.

### 3. High: an ordinary drag can put the entire draft into an unsaved state

Reproduction: select a committed piece, disable snapping and drag it beyond the map. Its position becomes invalid. The edit remains visible but the saved document and native preview remain at the previous valid state. Later edits cannot save while that invalid piece remains. There is an “Unsaved change” status message, but switching tools replaces it with tool instructions; exiting the editor is still allowed. Closing the application loses those unsaved changes.

Cause: moving a piece writes coordinates without the bounds checks used by geometry handles. Persistence rejects the entire invalid document, and `_save_draft()` cannot communicate failure to navigation. Sources: [piece movement](../game/editor/editor_canvas.gd:544), [save handling](../game/core/app.gd:857), [persistence validation](../game/persistence/track_library.gd:38).

Recommended: prevent invalid placement by checking the complete piece footprint and retaining the last valid position. Keep an always-visible dirty/error indicator until resolved. Separately consider saving structurally safe but incomplete drafts; race validity should not control whether the owner's work can be recovered.

### 4. Medium: Test silently discards the road preview

Reproduction: add an unconfirmed straight preview to an existing road, adjust it, press Test, then return. Practice launches with only the four committed sections; the fifth preview and its adjustments are gone.

Cause: practice compiles only committed document data; saved editor view state omits the ghost. Sources: [practice launch](../game/core/app.gd:875), [view retention](../game/core/app.gd:992).

Recommended: retain the preview across testing, or make Test clearly unavailable until placement is confirmed/cancelled. The same pending-work policy should apply consistently to category changes, issue focus, undo and exit. A placement checkmark is useful, but losing adjusted geometry should not be an incidental side effect of navigation.

### 5. Medium: beginning a pinch moves the pending road

Reproduction: while a road preview is active, place the first finger on empty ground, then the second finger to zoom. The preview has already moved to the first finger, before any pinch movement occurs.

Cause: `_begin_road()` immediately treats the first press outside the ghost as placement. Conversion to a two-finger gesture does not restore the original preview. Source: [road press handling](../game/editor/editor_canvas.gd:509).

Recommended: defer empty-ground placement until release, or retain a pre-gesture preview snapshot and restore it when a second finger joins. Navigation should not change the content being positioned. The existing tests cover committed geometry during pinch, but did not cover an active ghost.

### 6. Medium: barrier runs can follow a road that does not exist

Reproduction: on a blank map, choose Barrier and tap two locations. **13 barriers** are placed even though there are no road pieces or paint strokes. They follow the invisible starter lap. The same fallback can affect free-painted roads when the manual lap has not been updated.

Cause: `barrier_run()` falls back to the lap guide without checking whether it follows actual road. Runs also become independent objects immediately; moving a road later does not carry its roadside objects with it. Source: [barrier-run fallback](../game/editor/road_pieces.gd:193).

Recommended: require a real selectable road edge for “Follow road,” or offer a clearly distinct straight-line run when no edge exists. Preview the complete run before committing. Retaining a run as an editable group would make changing/removing long barrier chains much easier on a phone.

### 7. Medium: the issue badge cannot navigate through its issues

Reproduction: create the width mismatch above. The badge shows four issues, but every tap focuses the same first endpoint. There is no next/previous action or list. Source: [issue focus](../game/core/app.gd:740).

Recommended: show “1 of 4,” allow next/previous, and make markers selectable. Distinguish open ends, width transitions, blocked starts and invalid data so the action matches the actual problem.

### 8. Low: Clear map retains hidden setup

Reproduction: place a practice start on a generated route, then Surface > Brush > Clear map. Roads and props disappear, but the custom practice start and all 40 generated lap nodes remain. Test is disabled until road is added; later work inherits those old settings. Source: [Clear map](../game/core/app.gd:1124).

Recommended: either call this “Clear roads and objects” and state what it preserves, or clear all authored map/race setup together. Keep the existing one-step undo.

## Suggested next implementation slice

1. Protect edits: valid-position dragging, persistent save-state feedback, pending-preview retention and pinch rollback.
2. Make a completed track trustworthy: explicit lap setup/readiness, separate draft sharing, width transitions and useful issue navigation.
3. Improve repeated editing: real-edge barrier previews and grouped runs, connected-section adjustment, and clear reset semantics.

Usability risks still needing a physical phone: thumb reach, finger occlusion at geometry handles, safe areas, pan/paint intent, palette scrolling and rebuild latency on large maps. Desktop tests do not establish phone acceptance. No phone test was performed; Android tooling was unavailable at the reviewed checkpoint. No newly changed UI needs visual sign-off in this review-only checkpoint.

## Verification and changed files

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestWorkflow`: **96 checks passed**. The happy-path baseline remains green.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action ReviewCreator`: all eight exploratory scenarios executed successfully; actual values are recorded in [the observation log](evidence/creator-usability-review.txt). These are observations of current behavior, not assertions that lock bugs into future regression tests. The command deliberately does not run as part of Validate.
- Source review traced draft creation, native compilation, saving, navigation, snapping, barrier runs, issue handling and reset. No code was changed to fix or suppress the findings.
- Added `game/tests/review_creator_usability.gd` and the `ReviewCreator` entry in `scripts/dev.ps1`, plus this report, log and status/plan references. All scenario writes used a unique disposable test folder; owner drafts and records were untouched. No new dependency was installed.
- `git diff --check` passed. Application behavior is unchanged.
