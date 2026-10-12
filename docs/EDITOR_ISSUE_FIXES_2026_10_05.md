# Remaining editor P1/P2 fixes — 2026-10-05

Owner request: fix the remaining P1/P2 issues following the editor review and performance pass, including the five Results/PB assertions discussed afterward. Requirements: R01, R03, T01–T04, V03–V05, Q01.

## Findings and fixes

| Review finding | Resolution |
| --- | --- |
| P1: invisible autosave failure | A persistent header badge shows recovery/committed-save state and **Save failed · Retry**. Actual failures also have visible explanatory text. Recovery retries save WIP; original-save retries repeat the original commit. A successful recovery write cannot hide a failed original write. Unsaved state and atomic backup behavior are retained. |
| P1: synchronous large-map work | The preceding [performance pass](EDITOR_PERFORMANCE_2026_10_05.md) remains in place: indexed topology, cached routes, worker compilation, cooperative initial/replacement scenery, retained thumbnails and independent Save. The new checks do not join a preview or rebuild the editor. |
| P2: pending work lost during navigation | Road, surface and object-run previews are retained per tool. Departure considers inactive pending tools too. Save confirms all valid previews before committing/leaving; incomplete/invalid previews remain available and prevent departure. Discard removes pending previews and recovery only, preserving committed originals; Cancel retains work and frees its dialog so another departure remains possible. Loading WIP compares against the actual committed original rather than silently treating recovery as an explicit Save. |
| P2: pinch commits the first finger's movement | Conversion to two-finger navigation restores the pre-gesture document/ghost and the original undo/redo stacks. Preview/compiler work is not queued for the cancelled edit. Both finger-release orders retain normal navigation handoff. Temporary stack references are released after finish/cancellation. |
| P2: Surface toolbar covers the header | Surface tools move to a separate row below title/history. Recovery state occupies a separate left area, with visible local feedback beneath it. Long creator attribution is clipped within its reserved region. Layout checks/captures cover 960×540, 1280×720 and 1600×720 physical output under real project stretch. |
| P2: Publish renders its identifier | Publish now has a defined original vector upload glyph within its icon slot; enabled/disabled rendering uses the existing editor style. |
| P2: first-only issue navigation | Each badge tap advances to the next issue and displays **Issue N/total**; navigation wraps. Distinct ends of one piece are separate issues. Focus selects committed geometry/objects even if the retained object tool was in placement mode. Pending work gets a Confirm/Discard/Cancel decision before issue selection. Blocked starts remain driving blockers; open-road issues remain compatible with untimed practice. |
| P2: barriers follow an invisible starter lap | Road-edge runs use actual road pieces/layouts or authored asphalt/dirt line strokes. The unrelated retained lap route is never a fallback. Unsupported blank/area-only maps get a visible recovery hint directing the user to a real road edge or the existing free Line mode. Existing object/road limits remain intact. |
| P2: rebuilt object thumbnails | The earlier retained controls/detail styles and bounded 48-image cache are preserved. |
| P2: stale synchronous workflow checks | Fresh fixtures isolate their documents/previews and await real preparation. Exact spawn, geometry, collision and driving assertions remain. Surface fixtures now inject isolated records/library/cloud storage before startup, preventing saved owner-session refresh from replacing a test's editor. |

## The five PB/Results failures

The Results handler correctly suppresses duplicate finish signals by remembering the Game instance. **Race Again reuses that same instance**, so the guard also suppressed subsequent real attempts. The old test changed a completed race's time and called Results again without starting another attempt, producing five dependent failures: improvement delta, slower-attempt gap, preserved PB, reloaded PB and displayed target time.

`_retry_race()` now resets the result guard only once a retry has been accepted and is about to restart. Duplicate finishes within the same attempt remain idempotent. The test uses actual retries on the same Game node before presenting controlled 109.000 / 108.816 / 109.000-second finishes. All five original assertions remain unchanged; two new checks cover duplicate finish stability and the new retry lifecycle. **TestApp passes 99 checks**. Normal summary, PB feedback and post-reload records were captured and inspected. The controlled times are storage/UI fixtures, not claimed driven races or verified online times.

No Results record format, gameplay handling, physics/rules/compiler version, race lap count or backend identity/verification contract was changed by this slice. Existing backend upload ownership/recovery work was preserved; `_results()` and `_save_result_upload()` remain unchanged from the slice's starting source.

## Actual verification

All engine commands use the pinned `4.7.2.stable.official.ed1daf0bf` through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- `-Action Validate -CommandTimeoutSeconds 300`: **passed the full gate**, including import, **303 script parses**, startup, replay/handling/checkpoints, creator/editor, records/UI, all five vehicles and all configured domain regressions. App **99**, workflow **245**, placement **26**, road approval **40**, creator **113**, road pieces **362**, new review checks **51 headless**, large-map performance/equivalence **1215 headless**, construction **104**, tyres/load **71**, hazards **151**, records **54**, eight independent raster goldens, and 13,200 / 20,500 / 2400 exact tyre/grid/pile comparisons all passed. Existing ObjectDB cleanup warnings from several driving tests remain in the logs. Numerical fixtures were not regenerated or weakened.
- `-Action TestScript -ScriptPath res://tests/test_editor_review_fixes.gd -Graphical -CommandTimeoutSeconds 120`: final **59 checks, zero failures**, with actual rendered evidence. Covers injected recovery/original write failures and correct retry, all-tool save/discard/cancel behavior, invalid pending areas, retained runs, committed/ghost pinch rollback, preserved redo, cyclic issues, real road-edge paths and three-size layout. The suite is included in Validate. An earlier graphical version passed 55 checks before the extra invalid-preview/run/redo cases were added.
- `-Action CaptureApp -CommandTimeoutSeconds 120`: **113 checks, zero failures**, including inspected first/improved Results and preserved 01:48.816 PB after reload. Headless `-Action TestApp` also passed 99 checks before and during Validate.
- `-Action TestSurfaces -CommandTimeoutSeconds 90`: **50 checks, zero failures**. Initial run used owner account storage before injection and was interrupted by asynchronous account refresh; the fixture now initializes isolated state before tree insertion. Its substantive geometry/pixel checks remain.
- `-Action TestWorkflow -CommandTimeoutSeconds 120`: final **245 checks, zero failures**. Initial runs exposed fresh scenarios retaining outgoing ghost state and issue focus retaining placement mode; scenario initialization and the runtime focus mode were corrected without weakening the original blocked-start/angle/attachment assertions.
- `-Action TestPieces`, `TestTyresLoad`, `TestObjects`: **362 / 71 / 67 checks**, zero failures. Full Validate additionally covers their current source.
- `-Action CheckScript -ScriptPath res://core/app.gd -CommandTimeoutSeconds 60`: passed at the implementation checkpoint.
- `-Action TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 90`: final **304 scripts, zero failures**, after unrelated scripts were added to the shared working tree.
- `-Action Doctor`: matching engine/templates and attached **DN2103** found. This was an enumeration, not a device exercise.
- Scoped `git diff --check`, source-hash inventory and the saved patch's reverse application check passed.

Small-map regression input handlers remain approximately 12–18 ms for placement/approval; the headless 96-piece fixture reports opening about 28 ms, Save 46 ms, undo/redo 31–33 ms and browser refresh 0.08–0.17 ms. These are diagnostic samples from the regression run, not fresh phone or guaranteed graphical frame-time measurements. The earlier cold/shared-host load-spike limitation is retained; no new claim of locked 60 fps is made.

## Changed files and evidence

Runtime: `game/core/app.gd` (recovery state, retained tool previews, departure/issue handling, toolbar layout, retry lifecycle); `game/editor/editor_canvas.gd` (pinch rollback and edge-run feedback); `editor_button.gd` (Publish glyph); `road_pieces.gd` (real road-edge candidates).

Regression: new `game/tests/test_editor_review_fixes.gd` and its UID; `test_app.gd`, `test_editor_workflow.gd`, `test_surface_modes.gd`; `scripts/dev.ps1` adds the new headless checks to Validate. Documentation: this report, status/plan entries and [evidence/editor-issues-2026-10-05](evidence/editor-issues-2026-10-05/), including exact logs, source hashes and a scoped patch. The checkpoint excludes previous performance edits and unrelated backend/art work; no mixed-tree commit was made.

Inspected actual output: [persistent recovery failure](evidence/editor-issues-2026-10-05/recovery-failed.png), [navigable issues](evidence/editor-issues-2026-10-05/issue-navigation.png), [compact Surface controls](evidence/editor-issues-2026-10-05/surfaces-960x540.png), [fixed Publish glyph](evidence/editor-issues-2026-10-05/road-1280x720.png), [improved PB](evidence/editor-issues-2026-10-05/results/improved-race-debrief.png), [PB after relaunch](evidence/editor-issues-2026-10-05/results/returning-race-home.png). Two other layout sizes are in the evidence folder. Existing artwork remains original/cleared; no reference image or new raster asset was added to shipping resources.

## Remaining acceptance limits

**No Android export, installation or physical-phone test was performed**, although Doctor found the DN2103. Human finger feel, safe areas/IME, sustained mobile frame/memory/thermal behavior and real authenticated Google/online retry acceptance remain untested by this slice. Write failures are injected at the real persistence boundary; a real full-disk/device failure was not exercised. Owner files were not deleted or migrated; tests use uniquely allocated temporary libraries/records and clean their own data.

The fixes close the functional P1/P2 findings in the editor review and the identified Results retry defect. The manual/device and cold-render acceptance limits from the performance report remain explicit; fixing them requires representative hardware measurement rather than lowering test requirements.
