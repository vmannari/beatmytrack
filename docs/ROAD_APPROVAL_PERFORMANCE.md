# Road approval performance — 2026-09-17

Requirements: R01/T01–T04/V03/V05/Q01. Owner request: approving a road sometimes takes too long.

Approval previously compiled the complete track and rebuilt its scene before the click could return. It now commits and autosaves the document immediately, shows a lightweight accepted road, and compiles a snapshot using the existing single preview worker. Rapid approvals coalesce; stale results cannot replace newer edits. Detailed scene application waits until the current pointer gesture ends. Practice remains disabled until the compiled preview is current. Undo, redo and explicit save settle outstanding work.

The temporary road has neutral edges and no edit handles. Detailed shoulders, kerbs and bridge elevation arrive with the compiled scene. Automatic route derivation and autosave remain synchronous. Final scene rebuilding still runs on the main thread and can take time on large tracks; this change removes compilation from the approval path, not every possible frame spike.

## Measurements and evidence

Windows desktop, Godot 4.7.2, Compatibility renderer, RTX 3090. Fixture starts with a four-piece oval and approves three additional curves through actual touch events on the accept buttons.

| Graphical run | Click handling, ms | First rendered frame, ms |
| --- | --- | --- |
| Before | 450 / 507 / 590 | 459 / 513 / 596 |
| After | 10 / 13 / 18 | 18 / 26 / 26 |

The final after run overlapped other regression tests. These are three desktop samples, not phone performance guarantees. The headless follow-up measured 9 / 27 / 11 ms for click handling; headless frame timing is not visual latency.

Inspected screenshots: [accepted roads while compilation runs](evidence/road-approval/road-approval-pending.png), [completed preview](evidence/road-approval/road-approval-ready.png). The disconnected curves deliberately produce validation issues in this fixture.

## Actual validation

Commands used `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` with these actions:

| Action | Outcome |
| --- | --- |
| ProfileRoadApproval | Before/after measurements; final run 19 checks passed |
| TestRoadApproval | Same 19 checks passed headlessly |
| TestWorkflow | 189 checks passed |
| TestConstruction | 74 checks passed, five bridge laps, zero contacts, exact replay |
| TestPlacement | 24 checks passed |
| TestRefinement | 32 checks passed; existing two ObjectDB instance leak warning at exit |

338 distinct checks passed. The road checks cover immediate commit/visibility/autosave, rapid approvals, exact compiled cells/hash, latest snapshot metadata, undo during pending work, redo and explicit save. Logs are retained in [evidence/road-approval](evidence/road-approval). `git diff --check` passed (line-ending warnings only).

Changed files: `game/core/app.gd`, `game/editor/editor_canvas.gd`, new `game/tests/profile_road_approval.gd`, `scripts/dev.ps1`, this document/evidence, `DEVELOPMENT_STATUS.md`, and `docs/PHASE_0_PLAN.md`. No simulation, schema or compiler-version change.

No phone/device test or Android export was performed. Full Validate was not run. Remaining acceptance: owner interaction review and phone profiling on large tracks, including the final detailed scene rebuild.
