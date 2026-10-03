# Track lifecycle implementation checks — 2026-10-03

Requirements B01-B07/B19/B20, R01, T01-T04, Q01. Exact engine:
`4.7.2.stable.official.ed1daf0bf`. Scope and source changes:
[TRACK_LIFECYCLE.md](../../../TRACK_LIFECYCLE.md).

Actual commands used the repository backend venv and
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`.

- `python -m pytest backend/tests -q -k 'not postgres'`: **193 passed, 1 skipped,
  67 deselected**, 134.48 seconds. This snapshot precedes the final narrow creator
  admission/deduplication changes; their tests below subsequently passed.
- `python -m pytest backend/tests/test_track_lifecycle.py -q`: **19 passed,
  1 skipped**, 115.19 seconds. Uses disposable SQLite and PostgreSQL schemas;
  SQLite deliberately skips the cross-connection concurrency acceptance case.
- Earlier combined lifecycle/review/official tests: **41 passed, 1 skipped**,
  244.69 seconds, before the additional lifecycle fault cases.
- `BackendTestLifecycle`: **2 passed**; real HTTP, canonical Godot and background
  worker. Graphical rerun **2 passed**, 33.22 seconds, with **51 cloud race checks**
  and **38 creator lifecycle checks**, both zero failures. Covers saved proof and
  controller restart, corrupt primary journal/recovery, private master reinstall
  recovery, Guest draft visibility, explicit publication, lost response,
  cache-index write failure, newer-edit preservation, preferences/UID migration,
  cache reload, second revision under the same card, invalidation of the old
  compiled cache, retained immutable share link and authoritative hidden removal.
  Final account-scope fault extension: `python -m pytest
  backend/tests/test_cloud_client.py -q -s -k durable` with the graphical capture
  directory configured: **1 passed, 1 deselected**, 12.76 seconds, **40 checks,
  0 failures**. An account-scope change after server publication preserves the
  source and pending receipt; returning to the original account finishes recovery.
- `TestApp`: **96 checks, 0 failures** after the final catalog availability/load
  correction. `TestWorkflow`: **207 checks, 0 failures**. `TestPractice`: **53
  checks, 0 failures** (three ObjectDB instances reported at exit). `TestCatalog`:
  **21 checks, 0 failures**. `TestReview`: **17 checks, 0 failures**.
- Scoped Ruff: **all checks passed**. Scoped `git diff --check`: **passed**.
- `BackendStart`: final PC development build/migration and full API/worker
  manifest equality **passed**. Linux image acceptance verifies the 12,757-tick
  five-lap fixture and the approved ten-second rewind.
- `GenerateBackendStarter`: **passed** after converting the original pre-piece
  polygon to current connected roads and choosing a valid cyclic sampling origin.
- `ReconcileBackendTracks`: **6 publications, 6 hash-checked playable caches,
  6 compatible race contracts**; repeated check passed. The five original logical
  IDs are unchanged and no corresponding local master/WIP/lock/tested copies
  remain. See [live-reconciliation.json](live-reconciliation.json).
- Before live cleanup, userdata, database and object backups completed under
  ignored `build/track-lifecycle-backup-2026-10-03/` (DB dump 102,236 bytes;
  object archive 35,049 bytes).

Inspected `creator-verified.png` and `race-backend-catalog.png`; screenshots use
the real disposable HTTP backend. Cloud menu/result captures also cover 960×540.
ADB reports DN2103 attached. No Android export/install/physical-device flow,
Google-owner publication or NAS/production deployment was performed.

Earlier failed executions were retained in ignored build logs and corrected:
discovery accidentally bypassed compact projections, a launcher test mock lacked
manifest probe responses, a stale Linux fixture attempted twenty-second rewind,
test identity expectations used version IDs, and a menu constructed its details
before cloud catalog hydration. An intermittent SQLite wallet 503 is exercised
through the supported cancel/retry flow; no allowance is granted on failure.
No failing invariant was removed. Unrelated work continued in the workspace;
there is no claim of a clean-tree or complete mobile regression, and no mixed
working-tree commit was made.
