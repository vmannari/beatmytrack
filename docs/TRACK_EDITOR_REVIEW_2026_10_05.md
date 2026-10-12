# Track editor performance and usability review — 2026-10-05

Requirements: R01, T01–T04, V03–V05, Q01. Review of the current working tree, including the latest automatic-route/start-line, bridge-junction, draft-saving, publication and race-loading changes. Runtime behavior was not changed. Existing concurrent backend/client/menu edits were preserved.

The editor has useful direct geometry controls, reversible gestures, atomic WIP recovery, background compilation, coalescing of obsolete results and bounded preview caches. Small road approvals remain quick. The remaining problems are substantial: supported large tracks still block the main thread, save failures are invisible, navigation can silently discard pending work, and several visible controls are obstructed or incorrectly drawn. The September usability report should not be used unchanged: out-of-bounds road dragging, pending-road practice protection and the original pinch-on-empty-ground problem have since been addressed.

## Prioritized findings

### 1. P1 — Autosave failure has no visible warning

Every edit calls `_save_draft(true)`, which records `Could not save: …` in `editor_status`, but the status control is permanently hidden. `hint_changed` and lifecycle feedback also target that hidden control. In the isolated failure injection, save returned `ERR_FILE_CANT_WRITE`, the document remained dirty and the error text existed, but there was no visible indication that recovery had failed. Subsequent editor use can look normal while the newest changes exist only in memory. Explicit Save does show a failure dialog; ordinary editing does not.

Sources: [hidden status](../game/core/app.gd:1435), [autosave result handling](../game/core/app.gd:1840), [gesture save callback](../game/core/app.gd:1275). Evidence: [save failure capture](evidence/track-editor-review-2026-10-05/save-failure-desktop.png), final observation log.

Recommended: a persistent saved/saving/failed indicator with a retry action, distinguishing crash recovery from explicit Save. Keep failed edits dirty and retain the existing atomic persistence contract. The final probe injects the error return at the library boundary; it does not claim a real full-disk test. An earlier genuine invalid-directory write did produce an engine filesystem error and the runner correctly stopped it.

### 2. P1 — Supported large tracks still freeze editing, opening and saving

`_partner()` scans all road endpoints and repeatedly computes their poses. `joins()`, `connected_route()` and section attachment/geometry use it repeatedly. Automatic routing runs synchronously in every `_save_draft`, including object/title changes and undo. Issue refresh runs another join scan. This produces roughly quadratic authoring cost before the worker can help.

The final graphical probe measured a valid 96-piece open draft: **4.626 s opening**, **104.952 ms save-and-queue**, **202.953 ms undo**, **69.567 ms issue refresh**, and a **286.177 ms** frame interval while its replacement settled. All sections passed authoring validation. A separate **connected, valid 96-piece lap** took **6.603 s to open** and **182.071 ms to regenerate its route**. Thus this is not confined to malformed or disconnected documents.

Initial `_editor()` construction compiles synchronously; `EditorWorld` enables scenery slices only when a previous visual already exists. `_finish_preview_thread()` also joins pending compilation on navigation and foreground Save. On the connected fixture, changing only the name cost **218.936 ms** to save and queue; an immediate foreground save cost **1.221 s**. Scenery then took another **6.556 s** to settle with a **1.726 s** frame interval. Metadata-only changes still fail the full-document `_same_ground()` comparison and trigger geometry work. The nominal six-millisecond slice budget is cooperative, not a bound on each indivisible operation.

Sources: [endpoint matching](../game/editor/road_pieces.gd:148), [route generation](../game/editor/road_pieces.gd:240), [synchronous authoring save](../game/core/app.gd:1840), [opening preview](../game/core/app.gd:2812), [initial scenery versus replacement](../game/editor/editor_world.gd:130), [ground comparison](../game/editor/editor_world.gd:113), [worker join](../game/core/app.gd:101), [rename save](../game/core/app.gd:3076).

Recommended: prepare endpoint poses and an adjacency index once per geometry revision; share that result between route, joins and attachment checks. Skip geometry/routing work for metadata and ordinary prop edits. Make initial opening and foreground persistence use a visible, cancellable preparation flow; saving authoring data should not need to finish its render preview. Profile and split the remaining indivisible scenery work. Preserve exact compiler, collision and route results with equivalence checks; do not lower the supported authoring limits to hide the cost.

### 3. P2 — Pending work is discarded by navigation without being treated as dirty

On a clean saved oval, choose a Curve and change its radius. The document stays unchanged until confirmation, so `_editor_has_unsaved_changes()` returns false. Close exits straight to Race with no Save/Discard/Cancel dialog; the adjusted road is lost. Track → Objects also unconditionally clears the ghost. Paint previews and object runs have similar transient-state exposure through `cancel_gesture()` and view retention. The observed reproduction directly covers road previews.

Sources: [dirty calculation and departure](../game/core/app.gd:2518), [category change](../game/core/app.gd:1501), [retained editor state excludes previews](../game/core/app.gd:260), [gesture cancellation](../game/editor/editor_canvas.gd:136).

Recommended: retain per-tool pending geometry, or consistently resolve Confirm/Discard/Cancel before losing it. Include pending edits in the departure policy. Existing prevention of practice with a road ghost is useful, but navigation does not provide equivalent protection.

### 4. P2 — A pinch can accidentally commit the first finger's road movement

Touch inside a committed straight, move the first finger 14 logical units, then add a second finger to pan/zoom. The road has moved, history contains one edit, and a preview worker starts. The second-touch handler calls `edit_finished` rather than restoring the gesture's original geometry. The earlier fix that defers empty-ground ghost placement does not cover this case.

Sources: [second-touch handoff](../game/editor/editor_canvas.gd:181), [road movement threshold](../game/editor/editor_canvas.gd:753). Recommended: restore the pre-gesture document when converting a content gesture into navigation, or distinguish an intentional completed edit from the short first-finger movement typical of a pinch. Keep subsequent handoff of either remaining finger working.

### 5. P2 — Surface controls cover naming and history controls

At 960×540 physical output, the project's stretch preserves a 1280×720 logical canvas. In Surface mode the toolbar occupies `(370,8,540,102)` while the name/history container occupies `(16,16,503,52)`: they intersect. The inspected [surface capture](evidence/track-editor-review-2026-10-05/surface-compact.png) shows the Free/Area controls drawn over the rename/history area. The ordinary Road header containers do not overlap in this fixture. Shrinking only the title to 130 logical units is insufficient.

Sources: [absolute toolbar placement](../game/core/app.gd:1421), [category title shrink](../game/core/app.gd:1547). Recommended: give the toolbar its own layout row or reserve nonoverlapping space responsively. Validate every visible control's bounds across editing modes, long account names, wide/narrow ratios and device safe areas.

### 6. P2 — Publish renders its icon identifier as oversized text

The editor passes `"publish"` to `EditorButton.action`, but `EditorButton._draw()` has no corresponding glyph branch or symbol mapping. Its fallback draws the literal word at 28-point size, centered in the icon slot. It spills into the Test area and overlaps the Publish caption in both inspected desktop and compact captures. This is an unknown glyph, not an intentional second label.

Sources: [Publish button](../game/core/app.gd:1372), [glyph fallback](../game/editor/editor_button.gd:130). Evidence: [road desktop](evidence/track-editor-review-2026-10-05/road-desktop.png), [road compact](evidence/track-editor-review-2026-10-05/road-compact.png). Recommended: a defined shared publish/upload glyph and a check that every editor icon identifier is supported. Inspect disabled/enabled states; bound icon drawing to its reserved area.

### 7. P2 — The issue badge cannot move past the first issue

An oval with one displaced straight produces four issues. Three badge taps select `[0,0,0]`; `_focus_issue()` always reads `editor_issues[0]`. The on-map callout is visible, but additional explanatory status remains hidden. On the large draft the badge reports 192 issues with the same navigation limitation.

Source: [issue focus](../game/core/app.gd:1733). Evidence: [issues capture](evidence/track-editor-review-2026-10-05/issues-desktop.png). Recommended: an actionable list or next/previous navigation with “1 of N,” selectable markers and clear distinction between blocked starts and open endpoints. Open roads may remain valid for untimed practice; do not turn informational join issues into an unexplained universal driving ban.

### 8. P2 — Road-edge runs can follow an invisible road on a blank map

`RoadPieces.barrier_run()` on a blank document with no pieces, paint or layout creates **eight barriers** between the probe locations by falling back to the document's retained lap route. The object browser exposes Road edge placement, so the result can suggest that a real road exists where it does not.

Source: [fallback route](../game/editor/road_pieces.gd:312). Recommended: require an actual road edge, or explicitly offer the existing straight/free-run modes. Preview the run before committing it and explain an unavailable road-edge choice visibly.

### 9. P2 — Object selection recreates all visible 3D thumbnails

`choose()` calls `refresh()`, which clears the tile row and creates new `ObjectThumbnail` controls. Each thumbnail creates its own 208×128 4×MSAA 3D viewport, prop meshes, camera, light and environment. Placement-mode changes also call `refresh()`, even when the artwork is unchanged. The final desktop probe measured **35.822 / 35.651 / 39.648 ms** for an eight-tile refresh, excluding subsequent GPU rendering and deferred destruction. Earlier samples measured 30–32 ms. This consumes multiple 60 Hz frame budgets for a selection change.

Sources: [browser refresh](../game/editor/object_browser.gd:81), [thumbnail construction](../game/editor/object_thumbnail.gd:4). Recommended: cache rendered thumbnails by biome/asset/visual-kit identity and update selection styles and detail controls independently. Preserve the shared gameplay mesh source and bound cache memory. These desktop numbers do not establish phone GPU cost.

### 10. P2 — Workflow regression no longer waits for asynchronous practice launch

`TestWorkflow` completes **201 checks with two failures**, at the tight-bend and closed-circuit practice launch checks. Both emit Test and await just one `process_frame` before reading `app.game`. `_test_document` now awaits preparation and the multi-frame race-loading flow. The separate practice suite passes 54 checks; the race-loading suite passes 20, including an awaited editor-practice launch. This is strong evidence of stale timing expectations, but the failing suite has not been fixed here, and a complete green workflow regression is not claimed.

Sources: [tight-bend assertion](../game/tests/test_editor_workflow.gd:321), [closed-loop assertion](../game/tests/test_editor_workflow.gd:435), [async launch](../game/core/app.gd:1883). Recommended: await actual loading/preparation completion with a bounded deadline, then retain every spawn, exact-content and driving assertion. Keep an isolated guest fixture so saved sessions/backend availability cannot affect this local workflow gate.

## Measured performance

Windows, pinned Godot `4.7.2.stable.official.ed1daf0bf`, Compatibility renderer, RTX 3090. Measurements are handler elapsed time and sampled process-frame intervals, not CPU-profiler attribution, locked frame rate, input-to-photon timing or sustained device acceptance. The final large-map probe was run without this task's regression suites running concurrently. Other host activity was not controlled; use these as diagnostic evidence, not hardware guarantees.

| Fixture/action | Final observation |
| --- | ---: |
| Small oval: three road approval handlers, existing graphical profiler | 12.801 / 15.502 / 16.327 ms |
| Same approvals: first rendered frame | 42.238 / 36.825 / 36.966 ms |
| Same approvals: complete detail / maximum sampled frame interval | 1.889 s / 125.912 ms |
| Same profiler: undo / redo | 42.510 / 14.529 ms |
| Route attempt plus issue scan: 4 pieces, three samples | 0.261–0.279 ms |
| Same: 24 pieces | 8.589–9.423 ms |
| Same: 48 pieces | 32.887–34.128 ms |
| Same: 96 pieces | 145.751–169.705 ms |
| Open 96-piece draft: opening / undo | 4.626 s / 202.953 ms |
| Connected 96-piece lap: opening / foreground save during preview work | 6.603 s / 1.221 s |
| Connected lap after name change/save: settle / maximum sampled frame interval | 6.556 s / 1.726 s |

The existing road profiler's reconstructed synchronous undo measured 292.764 ms. It uses current caches and is not a historical binary comparison. Its correctness assertions passed. This review does not infer that the earlier September sliced-build timings were false; the current supported-size probes expose work those smaller fixtures did not bound.

## Actual commands, outcomes and evidence

All engine actions used `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action <Action> -CommandTimeoutSeconds 90`, unless specified below. The exact local build was checked by the runner. Copied per-process logs are in [the evidence directory](evidence/track-editor-review-2026-10-05/).

| Action | Outcome |
| --- | --- |
| `Doctor` | Passed after approved local tool access; matching templates found; DN2103 attached |
| `TestWorkflow` | 201 checks, **two failures** described above |
| `ProfileRoadApproval` | Graphical, 38 checks, zero failures; snapshots and exact mesh/cache/supersession assertions |
| `TestPractice` | 54 checks, zero failures; cleanup warning for four leaked ObjectDB instances |
| `TestPlacement` | 24 checks, zero failures |
| `TestStartLine` | 27 checks, zero failures |
| `TestFreeEditor` | 45 checks, zero failures |
| `TestConstruction` | 104 checks, zero failures; five bridge laps/exact replay; cleanup warning for two leaked ObjectDB instances |
| `TestScript -ScriptPath res://tests/test_race_loading.gd` | 20 checks, zero failures |
| `TestScript -ScriptPath res://tests/review_track_editor_2026_10_05.gd -Graphical -CommandTimeoutSeconds 120` | Final run exited 0 and printed `EDITOR_REVIEW_COMPLETED`; observations, not assertions treating bugs as desired behavior |
| Scoped `git diff --check` | Passed |

The passing focused suites total **312 checks**; the failing workflow suite is separate. Placement/start-line/free-editor/construction suites ran in parallel after the final graphical performance probe; their headless timing output is not used as a benchmark. No assertions were removed or weakened.

Initial sandbox attempts could not write Godot logs or initialize adb and were rerun with approved access. The first exploratory run used an invalid `res://..` directory-creation path; it was corrected to an absolute evidence path. A genuine save-failure attempt correctly stopped on the runner's fatal engine-error policy, so the completed probe uses a controlled persistence-boundary error injection. One expanded run collected observations but then failed cleanup of an already-removed disposable directory; the final version checks existence and completed successfully. These aborted runs are not counted as passing checks.

Inspected actual engine output: [Road desktop](evidence/track-editor-review-2026-10-05/road-desktop.png), [Objects desktop](evidence/track-editor-review-2026-10-05/objects-desktop.png), [Issues](evidence/track-editor-review-2026-10-05/issues-desktop.png), [Save failure](evidence/track-editor-review-2026-10-05/save-failure-desktop.png), [Road compact](evidence/track-editor-review-2026-10-05/road-compact.png), [Surface compact](evidence/track-editor-review-2026-10-05/surface-compact.png), [Objects compact](evidence/track-editor-review-2026-10-05/objects-compact.png), [Open large draft](evidence/track-editor-review-2026-10-05/large-ready.png), [Connected large lap](evidence/track-editor-review-2026-10-05/closed-large-ready.png). Compact captures use real project stretch; they are not phone screenshots.

## Suggested repair sequence and acceptance

1. Make failed recovery saves visible; preserve/resolve pending tool work on navigation and pinch handoff.
2. Cache adjacency and geometry by revision, remove metadata-only scene rebuilding, and move initial opening/foreground preview waits out of input handlers. Verify exact output and measure all frames through settled scenery on 4/24/48/96-piece connected and open tracks, dense objects and heavily painted maps.
3. Fix Surface/header layout and Publish artwork, make issues navigable, require real edges for Road edge runs, and reuse thumbnails.
4. Repair the workflow suite's asynchronous expectations without dropping spawn/driving assertions, then run the complete relevant regression gate.

Changed files by this review: this report; `game/tests/review_track_editor_2026_10_05.gd`; evidence/logs/source hashes/scoped review patch; review entries in `DEVELOPMENT_STATUS.md` and `docs/PHASE_0_PLAN.md`. The new diagnostic runs only when explicitly selected via `TestScript`; it is not added to Validate. No runtime, schema, compiler/physics version, service, owner draft/record or backend configuration changed. Disposable probes used unique library/record folders and cleaned their own files. Existing unrelated working-tree changes remain outside the review patch.

**No Android export, install or physical-phone editor test was performed**, although Doctor listed the DN2103. No full Validate, GPU/memory attribution, thermal run, real full-disk test, phone IME/safe-area/gesture acceptance, real Google/publication integration or deployment was performed. Required remaining acceptance includes human placement/drag/pinch feel, finger occlusion at nearby handles, long-session memory with the bounded caches, and sustained mobile frame times on a large representative owner track. These limitations should remain explicit until measured.
