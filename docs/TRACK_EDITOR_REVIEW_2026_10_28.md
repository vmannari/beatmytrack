# Track editor review — 28 October 2026

The editor has a strong technical foundation, but its current interaction and save boundaries still need work before a polished mobile release. The most consequential problems are edits that cannot be recovered after crossing global limits, cancellation that commits instead of rolling back, and overlapping controls that can reverse the race direction. Night authoring and preparation latency also materially reduce usability.

Review only: no intentional production-source fixes, deployment, device query/test, APK, owner-save change, or main-index staging/commit. TER01 covers usability, TER02 performance, TER03 correctness, TER04 overall quality, and TER-Q01 reproducible evidence. The working tree contains concurrent vehicle, input, localization, Garage and backend work; this is a review of observed local states, not a frozen release certification.

## Findings, in priority order

### TER-C01 / P1 — Global limits are enforced after the edit has been accepted

[`EditorCanvas.confirm_paint`](../game/editor/editor_canvas.gd:1385) checks the stroke count but not the total paint-point allowance. [`confirm_piece`](../game/editor/editor_canvas.gd:741) checks the individual section and section count but not aggregate road length. Both commit the mutation and clear the pending preview before the document validator and writer reject it.

The new probes start with valid, successfully saved documents. Adding a two-point stroke to 16,384 existing points produces 33 committed strokes, clears the preview, and fails WIP saving with error 30. The recovery copy still contains 32 strokes. Adding one valid 120 m section to 3,960 m similarly commits 4,080 m, clears the ghost, fails saving, and leaves only 33 sections in recovery while 34 are visible. Undo can recover a valid state, but continued work can remain newer than the recoverable file.

Validate aggregate admission before committing or preserve the pending preview on rejection. Apply the same policy to global point/length/byte limits and property edits that increase resource requirements. Do not increase the limits simply to hide the failure. Evidence: [`audit-headless.json`](evidence/track-editor-review-2026-10-28/audit-headless.json), `paint_global_limit` and `road_global_limit`.

### TER-C02 / P2 — Cancelled drags are committed and autosaved

[`cancel_gesture`](../game/editor/editor_canvas.gd:186) emits `edit_finished` after a changed drag. A platform-cancelled touch also reaches the committing branch of [`_end`](../game/editor/editor_canvas.gd:578). [`Esc`](../game/core/app.gd:5101) calls the same cancellation method, although Help describes Esc as cancelling.

Moving a container from `[0,0]` to `[10,0]` and cancelling emits one finish and zero cancellation signals. Through the actual App, pressing Esc retains `[10,0]` and writes that position to WIP. The transaction/history mechanisms already provide rollback for a second finger, so the underlying capability exists. Distinguish explicit cancellation from an intentional policy to finish on focus loss, restore the captured domains, and maintain one coherent undo transaction. Evidence: `cancelled_object_touch`, `cancel_gesture_after_drag`, and `escape_during_object_drag` in the audit JSON.

### TER-C03 / P2 — Road acceptance overlaps the start-direction control

The start-arrow hit test in [`_gui_input` / `_begin`](../game/editor/editor_canvas.gd:310) precedes the road acceptance hit test. [`piece_accept_rect`](../game/editor/editor_canvas.gd:1133) and [`start_controls`](../game/editor/editor_canvas.gd:1355) position their controls independently.

The ordinary first-section selection visibly overlaps the yellow checkmark and arrow in both renderers. A controlled 4 px/m view produces a 47.25 × 56 logical-unit intersection. A tap inside both changes the start heading from 0° to 180° and leaves the section selected. This changes the track while the user is trying to finish a section selection. Layout the interactive handles together and prevent overlapping hit targets; changing event precedence alone would just make the other control unreliable. Evidence: [`selected road`](evidence/track-editor-review-2026-10-28/native/gl_compatibility/03-selected-road-1280.png), paired native observations, and `road_accept_start_flip_overlap` in the audit JSON. The first probe used a different zoom and did not overlap; that initial result is retained separately.

### TER-U01 / P2 — Night tracks are too dark to author reliably

[`EditorWorld._apply_theme`](../game/editor/editor_world.gd:358) applies the racing lighting directly. [`TrackTheme.apply_lighting`](../game/track/track_theme.gd:52) uses ambient energy 0.045 and directional energy 0.025 for Night. The result is a readable toolbar above a nearly black road and scenery. Authored lights improve only small areas.

This is visible in both Compatibility and desktop Vulkan Mobile captures, after preparation has finished. Add an authoring-light or exposure mode while retaining an explicit race-lighting preview. Evidence: [`Night`](evidence/track-editor-review-2026-10-28/native/gl_compatibility/20-theme-night_city.png), [`Night with lights`](evidence/track-editor-review-2026-10-28/native/gl_compatibility/22-night-with-authored-lights.png), and the paired Mobile images.

### TER-P01 / P2 — Final preparation and first practice entry remain slow

The current App profile uses the original retained-editor assertions from `test_editor_t01_t04.gd`, without running its frozen geometry comparisons. On this RTX 3090 Windows desktop, one width edit on a 96-section track took **4,332.945 ms** to settle, retaining 85 of 104 road nodes. First practice entry took **26,865.449 ms**, the repeat took **2,057.647 ms**, and returning took **13.736 / 13.739 ms**.

The distinction matters: the planning drag itself was responsive, with a 0.538 ms mean handler and 0.841 ms p95 over 120 synthetic events. These measurements do not show a 4-second blocked input handler. They show a long wait for completed detail and practice readiness. The relevant paths are [`_test_document`](../game/core/app.gd:3955), its preparation/start helpers, and [`road_update.gd`](../game/editor/road_update.gd:8). Desert/Winter, paint changes, bridge/spline cases deliberately retain broader preparation for correctness.

Prioritize the remaining preparation phases and cold practice construction/shader work, while preserving cancellation, exact geometry, and the successful retained return. Evidence: [`profile results`](evidence/track-editor-review-2026-10-28/performance/gl_compatibility/results-gl_compatibility.json). These are one-session desktop observations, not phone latency, sustained FPS, or a percentile guarantee across tracks.

### TER-P02 / P2 — Large-document history consumes a substantial input budget

[`EditorSession.remember`](../game/editor/editor_session.gd:15) synchronously calls [`EditorHistory.capture`](../game/editor/editor_history.gd:8) and trimming. Unchanged object chunks share memory, but every capture still serializes every object and scans retained state.

An isolated 40-edit profile of the actual session method measured a **0.440 ms median** for 32 objects, **1.606 ms** for 512, and **11.647 ms median / 18.249 ms p95 / 20.451 ms maximum** for the supported 4,096 objects. That cost occurs before the rest of an edit's input work. All forty checkpoints remain, using 2,457,496 estimated bytes in the large case. Use mutation-aware chunk updates and incremental accounting while preserving immutable history and the shared byte bound. Evidence: [`history-profile.json`](evidence/track-editor-review-2026-10-28/history-profile.json). The earlier capacity-suite timing ran alongside other review work and is not used as the isolated latency result.

### TER-U02 / P2 — Some rejected edits provide invisible feedback

[`_change_piece`](../game/core/app.gd:3573) assigns validation errors to `editor_status.text`, while the editor hides that label by default. It bypasses the existing [`_editor_hint`](../game/core/app.gd:3268) display path.

A valid straight near the map edge remains unchanged after an invalid length increase; the label contains “Keep the whole road section inside the map.” but `is_visible_in_tree()` is false. The user sees a nonresponsive control. Route rejected edits through visible, consistent feedback. Evidence: `invalid_parameter_feedback` in the audit JSON.

### TER-C04 / P2 — Share silently excludes pending road work

[`_share_dialog`](../game/core/app.gd:3986) checks active surface points but does not use `_has_pending_editor_work()`. Save resolves previews and Test/Publish guard pending work, while Share opens with a road ghost still visible.

The actual App probe opens “Share your circuit” with `pending_work=true` and a straight ghost; the serialized document still has only its one committed section. Copy/export therefore excludes the visible proposed addition without a resolution step. Apply the existing confirm/discard/cancel policy consistently, including hidden tool previews. The probe only opens the local dialog; no clipboard change, external share or message was performed. Evidence: `share_pending_road` in the audit JSON.

## What is working well

The editor maintains a useful separation between document/session state, controls, CPU jobs and presentation. Revision fencing, bounded shared undo history, coalesced analysis/writes, atomic recovery, retained geometry, exact practice copies and cancellation-aware workers are substantive safeguards. Current autosave ordering, stale-analysis fencing and save-retry regressions pass.

The three-category rail, direct road handles, real model thumbnails, selected-object tools, explicit Test/Publish workflow and retained camera on practice return give the editor a coherent structure. The native review covered blank/selected tracks, splines, surface modes/options, object options, population, issues, Map/Help, five themes, and scaled/wide layouts. Dense overview detail reduced this fixture from 368 to 200 draws while preserving the tested selection/detail restoration behavior; that is a work-count observation, not a measured mobile FPS gain.

A 960×540 physical window with the normal 1280×720 logical scale is usable in the captures. Forcing only 960×540 logical space overlaps the fixed identity/history header with top actions, and the save label overlaps a surface caption. This is a layout hardening observation, not a claim that production 16:9 phone scaling uses that forced logical configuration. Small scenery thumbnails also merit a contrast/readability pass.

## Checks and limits

| Check | Actual result |
| --- | --- |
| Original workflow | 254 checks, 0 failures |
| T05–T11 editor behavior/history/memory | 321 checks, 0 failures |
| T11–T15 session/gesture/import/ownership | 305 checks, 0 failures |
| Existing review/recovery fixes | 69 checks, 0 failures |
| Creator capacity | 2,970 checks, 0 failures; seven-car state corpus as loaded during that run |
| Actual retained-App profile | 60 original assertions, 0 failures |
| Original practice suite | **39 checks, 4 failures**, followed by a nil-access diagnostic after the expected finish was absent |
| Current creator-document practice control | 53 inherited checks, 0 failures; six laps, 15,259 ticks, zero contacts |
| Full script parse | 1,371 scripts, 0 failures |
| Native review | 27 saved captures in each renderer; 0 capture/deadline failures |

The original practice suite's `ellipse.json` AI witness completed zero laps with 27,678 contacts in 28,800 ticks, and its ordinary-race witness did not finish. The separate control compiles the current `verified_oval.json` creator document and retains the original test methods/assertions. Its success supports the creator practice path but **does not make the original suite green or establish the cause of that failure**. No production physics, track or assertion was changed to obtain it.

The preferred `scripts/dev.ps1` runs were attempted first. The initial shell execution-policy issue, default-profile log denial, and the wrapper's fatal treatment of this sandbox's root-certificate-store error are retained. Direct controls use the same pinned `4.7.2.stable.official.ed1daf0bf` engine, an offline workspace profile and Dummy audio; the certificate diagnostic remains in those logs. Test outcomes above refer to actual assertions/exit receipts, not the failed wrapper attempts. A CIM process-inspection attempt was also denied; it is not an editor defect.

The five new scripts under `game/tests` and two Python evidence runners are review helpers only. `run_probe.py` records the exact engine command, exit code, duration and script hash. The visual helper only redirects the existing review capture destination. Review probes record observed defects rather than asserting that broken behavior is desirable. Initial incomplete probes remain in the numbered initial/second/third audit files.

Runtime/editor source hashes are retained, and each native capture run reported stable source hashes within that run. App, vehicle, input, localization, fixture and backend files changed concurrently across the review; there is no whole-tree stability claim. The capacity test's incidental tracked historical result was archived here and restored to its clean task-start bytes. Our wrapper-generated build metadata was superseded by concurrent work and was preserved, with before/current copies recorded instead of rolling back the owner's newer identity.

No physical-device query or test, APK, production performance certification, real authentication/purchase, backend write/deployment, owner-process restart, owner-save mutation, or root-index staging/commit/merge was performed. Mobile captures mean the desktop Vulkan Mobile renderer. Remaining acceptance includes physical touch/gesture behavior, Night visibility, cold/thermal/large-track latency and long-session memory on the target Android device, plus the unresolved original practice regression.

Evidence and machine-readable findings: [`report.json`](evidence/track-editor-review-2026-10-28/report.json). The immediate correction order is global admission and gesture rollback, overlapping controls, Night authoring visibility, then preparation/history cost and consistent feedback/share handling.
