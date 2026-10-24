# Legacy cleanup recovery and review fixes

2026-10-24. All five findings from the second legacy review are addressed.
Saved input-only uploads can recover without replacing their original operation
keys. Ordinary race submissions continue to require trajectory evidence.

## Findings resolved

| Requirement | Change |
| --- | --- |
| LCRR01 pending uploads | A bounded persistence-only encoder validates up to 216,000 canonical inputs and three exact rewind events. The private ticket lookup recovers accepted uploads before reading/re-encoding evidence. Unaccepted input-only jobs retain their original canonical body and key. Lost replies and an older in-flight submission winning a conflict reconcile through that ticket. Jobs stranded by the previous local `INVALID_REPLAY` rejection recover on restart after their source hash and contents validate. Worker plans publish on the owning main thread only if the journal hash still matches; dismissed, corrupt and changed jobs remain protected. Failed journal replacement preserves the original document. |
| LCRR02 archive guard | Every existing source, destination and report ancestor below the workspace is checked, including generated hash directories. Hash-directory, source-directory and report-directory junctions are rejected before mutation. Ordinary hard-linked native file names remain supported. |
| LCRR03 migration regression | The preservation test explicitly allows only `discovery_budget` and `discovery_snapshots` to retire, asserts their absence and retains exact row hashes for every surviving preexisting domain table. |
| LCRR04 deployment guide | The active guide requires `compact`, discovery v3, trajectory support and the private submission-recovery capability. It removes the retired transport setting and the promise of a normal frame fallback. |
| LCRR05 unused helpers | Removed `_sand_bend_sample`, `_save_settings`, `_creator_name` and `_rename_dialog_position`. The browser test uses the real keyboard adapter; a focused actual-App test covers dialog creation, focus, timer attachment, layout and Apply. Historical controls remain excluded from shipping. |

## Validation

The local SQLite/ASGI ranking and saved-input run passed 25 tests with one skipped;
the separate exception-recovery run passed 17. The migration preservation test
that failed during review now passes. Selected backend Ruff checks pass.

| Native suite | Passing checks |
| --- | ---: |
| Pending input recovery | 37 |
| Existing legacy boundary checks | 23 |
| Actual rename flow with explicit headless screen geometry | 8 |
| Backend scalability | 17 |
| App composition | 141 |
| Rendered keyboard layout | 21 |
| Rendered actual rename flow and capture | 9 |
| Native archive filesystem checks | 10 |

The final parser compiled 1072 scripts with zero failures. Real-resource
retention dry-run completed module inspection, protected all four descriptor
selected Windows libraries/dependencies and found no archive candidates.

The broad object-browser suite retains six assertions about placement, selection
and cliff scale. The preserved pre-change fixture reproduces the identical six
labels. Its old synthetic positioning helper is contained inside the excluded
control fixture, with every original assertion retained. The final rendered
browser run adds no failure from this change. No broad browser pass is claimed.

The unchanged general keyboard fixture initially failed two positioning assertions
under the headless display, which has no physical window height. Its real-window
run passes all 21. The updated browser and focused rename fixture use the current
pixel-to-viewport adapter with explicit headless geometry, and the actual layout
in a real window. A concurrent Garage edit briefly referenced a not-yet-created
module; after those independent files appeared, the rendered checks passed with
the same six preexisting browser failures. Initial trial logs are retained.

## Evidence and rollout

[Actual commands, source hashes and results](evidence/legacy-cleanup-followup-2026-10-24/report.json),
[native rename view](evidence/legacy-cleanup-followup-2026-10-24/rename-keyboard.png)
and the scoped Git-checkable patch are retained beside the report. The comparison
uses private Git trees and leaves the repository index and concurrent changes intact.

Restart the client to load these changes. The already-required matching API with
`submission_recovery_version: 1` and migration 0062 with its 0060/0061 prerequisites
remain a rollout requirement; this follow-up adds no new database migration.
An older service leaves the original saved job pending. Owner/device acceptance
of the updated client remains.

No phone/tablet attachment check, physical-device test, APK/export/install, live
account/backend mutation or deployment was performed. PostgreSQL and production
migration behavior are outside these local SQLite checks.
