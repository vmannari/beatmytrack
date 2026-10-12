# Exception recovery fix evidence ? 2026-10-05

See [repairs, security/resource policies and acceptance](../../BACKEND_EXCEPTION_FIXES_2026_10_05.md). Twelve reviewed P1/P2 findings are addressed. No existing service/player data, cloud resource, deployment or physical device was changed.

JUnit batches overlap. Broad regressions precede the final atomic refresh and bounded-expiry refinements; final authority/retention batches cover those changes. Native account follows correction of browser response-shape validation, and the final seven upload/rivalry HTTP cases pass. Diagnostics use synthetic accounts/private temporary files; no credential files or DB dumps are copied.

`native-recovery.log` records 28 passing checks, `graphical-recovery.log` 29, `admob.log` 44 and `parser.log` 302 scripts without failure. `uploads-recovery.png` was visually inspected. No presentation/art/camera redesign or canonical simulation change was made. The screenshot shows a retained failed save and Retry saving action.

Actual representative commands from the workspace root:

```powershell
.tools/backend-venv/Scripts/python.exe -m pytest backend/tests -q -m 'not godot and not postgres' -k 'not postgres and not persistent' --tb=short --show-capture=no --junitxml=build/backend-exception-fix-regression.xml
.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_account_client.py -q --tb=short --show-capture=no --junitxml=build/backend-exception-fix-account-final.xml
.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_rivalry_http.py backend/tests/test_cloud_client.py -q --tb=short --show-capture=no --junitxml=build/backend-exception-fix-native-final.xml
.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_exception_recovery.py -q -k sqlite_concurrent --tb=short --show-capture=no
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_backend_exception_recovery.gd
$env:BMT_CAPTURE_RECOVERY='1'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_backend_exception_recovery.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_admob_development.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd
.tools/backend-venv/Scripts/python.exe -m ruff check backend/bmt_backend backend/tests/test_exception_recovery.py backend/tests/test_track_lifecycle.py backend/tests/test_domains.py
```

PostgreSQL commands loaded only the ignored lab URL into the child process, then invoked pytest on test_exception_recovery/test_auth_postgres/domain/track lifecycle/scalability and later final authority/readiness/retention/replica/lifecycle selections. Only generated schemas in the disposable `bmt-exception-pg-20261005` loopback container were used. The private URL is deliberately omitted. Raw selection/results are in their named XML. The lab is stopped after final verification; existing containers are untouched.

`source-hashes.json` enumerates owned changed paths and their starting/final bytes. `scoped-change.patch` excludes parallel editor, GCS staging, readiness and lifecycle changes; App's baseline is reconstructed to isolate only its save-service handoff. Status/phase/deployment docs use late saved baselines to retain other work. A separate local Git checkpoint contains this delta; the active branch/index remain unchanged. Baseline ancestry distinguishes pre-existing uncommitted dependencies from this task's repairs.

New tests assert correct recovery rather than mirroring the historical review's failing observations. Initial timer/config/exception-interface/retention fixture mistakes and browser reply classification were repaired without reducing invalid-replay, reuse, receipt or PB checks. No full physics replay, real external provider/Google, phone or cloud failure drill was performed.
