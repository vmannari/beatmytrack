# Exception/recovery review evidence ? 2026-10-05

See [findings, current recovery and operator sequence](../../BACKEND_EXCEPTION_REVIEW_2026_10_05.md). This is a review of the existing implementation for future load-balanced cloud production. No production runtime fix, service restart/deployment or existing player-data change was made.

`probe_exception_paths.py` runs against disposable SQLite with inherited domain/auth fixtures. Its nine passing tests assert observed behavior, including recovery gaps; passing does not mean those gaps are fixed. `probe-api.xml` records 9 passed/6 PostgreSQL parametrizations deselected. `regressions.xml` records 117 existing tests passed/3 PostgreSQL-only cases skipped/126 deselected. No live PostgreSQL restart, real cloud provider or physical device was tested.

`client-observations.json` and `client-probe.log` record five native diagnostic scenarios using fake network responses and workspace-only files: failed save after leaving Results, refresh DB failure, uncertain resume state, missing-Run polling and mixed API transport. The real adapters/App save method are invoked; this is not a full graphical user/device interaction test. The source is `game/tests/review_backend_exceptions.gd` and is excluded from shipping test-free exports.

`malformed-success.log` is an intentionally failing native reproduction: HTTP 202 with an empty dictionary triggers the actual missing-run_id error in cloud_tracks.gd. The pinned build entry kills on Script Error and exits 1; its failure checks were not relaxed. That fault is not counted as a passed test. Default native diagnostic exits 0 while recording current problematic states.

Commands actually executed from the workspace root:

```powershell
.tools/backend-venv/Scripts/python.exe -m pytest docs/evidence/backend-exception-review-2026-10-05/probe_exception_paths.py -q -k 'not postgres' --tb=short --show-capture=no --junitxml=build/backend-exception-probes.xml
.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_auth.py backend/tests/test_domains.py backend/tests/test_review_followups.py backend/tests/test_review_reliability.py backend/tests/test_resumes.py backend/tests/test_track_lifecycle.py backend/tests/test_scalability.py -q -k 'not postgres and not full_manifest and not canonical and not recorded_practice' --tb=short --show-capture=no --junitxml=build/backend-exception-regressions.xml
.tools/backend-venv/Scripts/python.exe -m ruff check docs/evidence/backend-exception-review-2026-10-05/probe_exception_paths.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/review_backend_exceptions.gd
$env:BMT_EXCEPTION_FAULT='malformed'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/review_backend_exceptions.gd
```

Run fault injection in a fresh shell, or remove that task-specific variable afterward before the normal diagnostic. Native runs required normal Windows certificate-store access, using the exact `4.7.2.stable.official.ed1daf0bf` engine. Initial helper tuple unpacking and intentional-error capture ordering were corrected; production assertions were untouched.

`source-hashes.json` fingerprints reviewed runtime/probe files. `scoped-change.patch` includes only this review's new documents/diagnostics and status/phase notes, excluding earlier backend repairs and concurrent menu edits. Separate local checkpoint branch: `backend-exception-review-2026-10-05`, based on the completed scalability checkpoint. Active branch, shared index and working files remain unchanged by checkpoint creation. No merge or deployment.
