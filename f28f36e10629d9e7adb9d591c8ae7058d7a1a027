# Selected-car compatibility, 27 October 2026

Electric-only refinements must leave the other six cars playable online. The local app and backend now accept the proven physics 0.74/0.75 equivalence for those six cars while retaining their original tickets, boards, PBs, challenge contracts and weekly memberships. Electric keeps its distinct handling contract. This change is implemented and tested locally; it has not been deployed.

The owner clarified that routine UI/art changes and Electric refinement must not invalidate unrelated cars. Requirements: **BC01** distinguish release identity from racing identity; **BC02** scope car-only updates to the selected car; **BC03** retain immutable records and evidence; **BC04** apply the same decision throughout race entry and processing; **Q01** prove acceptance and rejection; **R01** document rollout and validation limits.

## Findings and resulting policy

| Change | Effect on online racing |
| --- | --- |
| UI, car artwork, renderer or release/build identifier | Already outside race compatibility, provided the canonical contracts stay unchanged. |
| Electric handling version/hash only | Other six cars retain the exact same ticket, board and weekly contract. Electric requires its matching tune. |
| Known Electric-only shared label transition, physics 0.74 ↔ 0.75 | Now accepted for Compact, Pickup, Classic, Formula, Kart and Forklift, with every selected handling hash still exact. |
| Unrecognized physics transition | Requires its matching contract. There is no permissive version range. |
| Different selected handling, engine build, compiler, track hash, rules, schema, tick rate or lap count | Existing requirements remain. No cross-tune score merging or geometry substitution. |

For future parameter-only car changes, increment that car's handling version and resulting configuration hash. Keep the shared physics version when shared behavior is unchanged. If an optional simulation branch changes for one car, prove the other cars unchanged before declaring a specific per-car equivalence. A genuine common simulation change still needs a shared version. This prevents car development from needlessly demanding an all-car/backend rollout.

The recent Electric update changed the global physics label from 0.74 to 0.75 although six configuration hashes stayed exact. The original client rejected the label for every car; the backend rejected tickets and removed old contracts from worker/weekly eligibility. This was independent of UI/art release identity. The reproduced seven-car matrix blocked all seven before this repair; afterward the six unchanged cars receive tickets and the old Electric tune remains rejected by the new verifier.

Ticket creation also compared the entire selected vehicle metadata dictionary, and weekly eligibility iterated every metadata key. An additive informational field could reject tickets despite matching the two competitive identifiers. These paths now use the selected `handling_version` and `config_hash`. Weekly contract hashing uses the same projection; unrelated cars and optional metadata cannot change it.

## Implementation and data preservation

`contracts.py` declares only the explicit, symmetric 0.74/0.75 six-car equivalence. `job_contracts.py` applies it in Python capability checks and both SQL queue/worker predicates. Tickets, retries, challenges, creator publication proofs, automatic weekly drivers and worker admission use that decision. The worker still compares the actual verifier output against the complete expected current manifest and checks immutable track content, timing and replay evidence.

`race_compatibility.gd` mirrors the small declaration for the actual `CloudTracks.ticket` entry path. No simulation step, handling resource, engine pin, compiler, rules version, schema or source document changes.

Weekly lookup and ticket issue accept either proven equivalent contract key. Existing memberships, groups, circuits and track lineups retain their stored key and board IDs. A joining peer can use an existing compatible group. Lookups remain bounded to at most two indexed contract keys; group reservation retains its capacity locks and original 100-candidate limit. Existing independent boards and PBs are not merged or relabeled.

Full-fleet catalogue deployment checks and overall worker health continue to describe the complete build. An old Electric contract still makes a full-fleet rollout incomplete; it no longer makes an unrelated car's race contract incompatible. Geometry-cache invalidation remains conservative. No latency or cost improvement is claimed.

## Validation

Evidence and hashes: [report.json](evidence/backend-app-compatibility-2026-10-27/report.json). The audit scripts are diagnostic characterizations; the production regressions define the intended behavior.

| Check actually run | Outcome |
| --- | --- |
| New unchanged-car, rollback, future Electric-only tune, metadata, challenge, weekly/circuit and creator-proof regressions on SQLite | **30 pass** within the final focused run. |
| Exact same new regressions against isolated task-start source copies | **17 expected failures / 13 pass**; no production rollback. |
| Final focused run including existing challenge discovery/series checks | **43 pass / 42 deselected**. |
| Native actual client gate, seven cars and strict negative cases | **123 checks / 0 failures**, including the differential checks below. |
| Exact old versus current integrator, six cars × four initial speeds × 2,400 inputs | **57,600 every-state comparisons exact**. Includes throttle, braking, steering, reverse and handbrake phases. |
| Real staged Godot geometry, HTTP ticket/submission and actual worker | **2 pass**: original Compact 0.74 board accepts the 12,757-tick/five-lap path under the 0.75 verifier; a tampered path is rejected without a PB. |
| Backend compatibility characterization | **19 scenarios + 7 historical-car ticket checks**, pass; six unchanged cars blocked before, zero afterward. |
| Existing publication checks | **21 pass / 2 skip / 22 deselected**. |
| Broader existing backend checks | **120 pass / 3 skip / 2 failures / 105 deselected**. Both failures reproduce with exact task-start runtime sources. |
| Existing native Rivalry entry failures | **29 checks / 0 failures**. |
| Pinned Godot script parser | **1,337 scripts / 0 failures**. |
| Focused Ruff on the other changed Python sources and both new test files | Pass. `rivalry.py` retains one existing SIM102 in unrelated deleted-owner snapshot formatting. |
| PostgreSQL predicates compiled with the PostgreSQL dialect | **2 pass**, syntax compilation only. |

The broader failures are the pre-existing downgrade guard requiring creator achievement events to be drained before migration 0054, and a historical World Ranking fixture whose resume ticket is already closed. The original assertions remain untouched. Their original and task-start reproduction receipts are retained.

The configured local PostgreSQL server timed out: the initial full run has 17 SQLite passes and 16 PostgreSQL setup errors. A separate read-only `SELECT 1` probe also failed outside the sandbox. No PostgreSQL execution pass is claimed; Docker is unavailable here. Test database credentials in the two failure artifacts were redacted (128 occurrences), without exporting credentials or player data.

Initial diagnostic attempts encountered PowerShell execution policy, sandboxed user-log/certificate access and a missing probe import path. The archived fixture also carried an older rules label; the audit now applies the existing unchanged `current_manifest` normalization, exactly as production ticket issuance does. The normal wrapper's generated build metadata was left current and excluded from the scoped change. No historical evidence was regenerated.

## Actual commands

Run from the repository root unless the command first changes directory. Native commands used an isolated `APPDATA` under `build/compatibility-audit/appdata`; startup required Windows certificate-store access. Python commands used the existing secure virtual environment. Output redirection is omitted below for readability; logs and JUnit receipts are in the evidence directory.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/audit_backend_compatibility.gd -CommandTimeoutSeconds 120
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_start_failure.gd -CommandTimeoutSeconds 180
& .tools/backend-secure-venv/Scripts/python.exe -m pytest docs/evidence/backend-app-compatibility-2026-10-27/probe_backend.py -k sqlite -q --basetemp build/compatibility-audit/pytest-matrix
& .tools/backend-secure-venv/Scripts/python.exe docs/evidence/backend-app-compatibility-2026-10-27/verify_task_start.py --reuse
```

From `backend/`, with `../.tools/backend-secure-venv/Scripts/python.exe -m pytest`:

```text
tests/test_car_compatibility.py tests/test_challenges.py::test_create_requires_owned_verified_compatible_result_and_idempotency tests/test_challenge_discovery.py tests/test_challenge_series.py -k "not postgres" -q --basetemp ../build/compatibility-audit/pytest-final-focused
tests/test_car_compatibility_native.py -k "not postgres" -q --basetemp ../build/compatibility-audit/pytest-native
tests/test_publication_intents.py tests/test_publication_background_priority.py -k "not postgres" -q --basetemp ../build/compatibility-audit/pytest-publication
tests/test_catalog_builds.py tests/test_exception_recovery.py tests/test_challenges.py tests/test_challenge_discovery.py tests/test_challenge_series.py tests/test_rivalry.py tests/test_rivalry_planning.py tests/test_rivalry_week_completion.py tests/test_world_ranking.py tests/test_review_followups.py -k "not postgres" -q --basetemp ../build/compatibility-audit/pytest-regression
tests/test_car_compatibility.py -q --basetemp ../build/compatibility-audit/pytest-car-full
```

The two broader failures were rerun against the frozen task-start package with `-k "sqlite and (additive_attempt_migration or shared_circuit_group_independence)"`; both reproduce. The evidence scripts verify the original source copies before reusing that package. The source-only checkpoint is `evidence/backend-app-compatibility-2026-10-27/scoped.patch`, checked against an isolated copy without touching the main index.

## Scope and remaining acceptance

Runtime changes: ten existing app/backend sources plus the new client compatibility helper. Supporting changes: three test sources, diagnostic/evidence scripts, this document and a brief status/instruction entry. Exact task-start runtime copies and a source-only patch are retained. Concurrent workspace changes remain outside the checkpoint.

The updated client must be reloaded/rebuilt. Deploy the matching API and worker before relying on the relaxed server-side gates. Existing old binaries still contain their original strict client check and cannot gain this behavior remotely. Electric tuning still requires a matching verifier and a correctly published Electric race contract. Actual PostgreSQL execution, rollout and owner acceptance remain.

No physical-device attachment check or device test, APK, real authentication or purchase, owner-save/live data mutation, cloud deployment, service/owner-process restart, main-index staging, commit or merge was performed.
