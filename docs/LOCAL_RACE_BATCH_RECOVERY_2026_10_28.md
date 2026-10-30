# Local artificial-race batch recovery — 28 October 2026

The reported `HTTP 409: BATCH_BUILD_CHANGED` came from the active batch retaining
physics `arcade-planar-0.53`, rules v20 and its older compiler, while the approved
backend uses physics 0.75/rules v23. Its Compact configuration still matches,
but shared physics/rules/compiler differences require new canonical drives.
The original strict build fence remains in place.

**LBR01** diagnose the actual persisted contract; **LBR02** continue safely without
clearing results; **LBR03** redirect the local command while preserving journals;
**LBR04/R01/Q01** prove rollback/concurrency/native verification and validate the
minimal API rollout. See the [evidence report](evidence/local-race-batch-recovery-2026-10-28/report.json).

The same command now prepares the batch before starting Docker:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/artificial-races.ps1
```

`-PrepareOnly` performs that preparation without generating a race. `-MaxJobs`
retains its existing 1–20 bounded-attempt semantics and defaults to one.

## Recovery behaviour

The development-only operator endpoint locks the active-batch guard, checks the
recorded continuation chain and compares exact builds. A matching batch is a
no-op. An obsolete batch gets a new current-build continuation using its existing
artificial player IDs and profiles and the latest compatible published revisions.
The original batch becomes retained, superseded history; original jobs, tickets,
runs, boards and personal bests are preserved. No score or time is copied into a
new contract, and `clear_test_records` is always false for continuation.

Creation, job inserts, superseding metadata and the guard change commit in one
transaction. Inserts use batches of 256 rows. Concurrent preparations produce
one replacement. Lost replies and explicit older batch IDs follow the recorded
continuation; they cannot jump to an unrelated active fleet. Disabled/deleted
profiles, missing current tracks and excessive continuation chains fail closed.
Stale completion tokens remain fenced.

The host launcher uses the returned batch ID for its new state path and Docker
arguments. Existing old journals/recordings remain in their original directory.
The local generator continues using the deployed worker's immutable image, whose
canonical assets match the API; no new runner image or controller change is
required. Every new recording still goes through ordinary tickets/uploads and
independent server verification.

## Validation and rollout

The exact repair image passes **51 tests**, including actual PostgreSQL concurrent
continuation, commit-failure rollback, preservation of nonempty real-player
history and original jobs, development/operator gates, journal redirection and a
real native drive on a replacement revision followed by independent verification.
One broader legacy native all-track/restart harness is not run; the focused
native continuation proof runs with the exact frozen engine/project. Original
test assertions remain intact. A first rollback-test expectation was corrected
to assert the existing middleware's sanitized HTTP 500, while keeping its exact
database rollback assertion.

Only `test_population_batch.py` changes in the deployed API package. All **345
other package files and 174 canonical assets** remain exact. The host Python and
PowerShell launchers also change locally. Zero-traffic health/readiness/auth
checks precede promotion. Worker, private Studio, seven job definitions,
resources, scaling, IAM, secrets, schema and game contracts remain unchanged.
The owned probe jobs, API tag and rollout lock are removed.

<!-- LBR-LIVE-RESULTS -->
The API-only repair is deployed on `bmt-stg-e7a444ab-api-00125-ses` using immutable
`sha256:11f7d3a833403f1cf578b7690a2eb35ee96fc9842c6c8ac400e15d7be517b679`. The actual batch continues with the same
**100 drivers**, **30 current track revisions** and **3,000 jobs**. All original
**2,800 jobs** remain with their prior status counts and old journals are exact;
no results were reset. The bounded live attempt uploaded normally and the server independently verified 1 new test run(s).
The exact-image suite passes 51 checks, including the real native continuation
and independent verification proof. All 16 aggregate/evidence checks
and the scoped forward/reverse checkpoint pass.
<!-- /LBR-LIVE-RESULTS -->

The batch transition was missed in the original deployment validation. The
read-only diagnosis now checks actual persisted batch contracts rather than only
fresh fixtures and route gates. The repair retains old history and creates new
work; it does not reinterpret an old run under new physics.

No physical-device test, APK, real purchase, owner-save edit, owner-process
restart, canonical tuning, main-index staging, commit or merge is performed.
Concurrent game and backend work is preserved.
