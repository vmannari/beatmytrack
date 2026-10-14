# Combined communication follow-up — 2026-10-13

Owner request: make another pass over the H1–H4, M1–M6 and L1–L3 fixes. Requirements B01, B05, B07, Q01; follow-up findings CF01–CF05. No production deployment, live account changes or canonical driving/scoring changes.

## Additional gaps fixed

| ID | Finding and resulting behavior |
| --- | --- |
| CF01 | Publication Retry did not honor or persist the shared 429 pause. Elapsed clockless waits could revive after controller restart, and one reused temporary filename allowed peer writes to overlap. Each pause now has an immutable nonce-specific record; all outstanding pauses are observed, expiry is durable, and retiring one nonce cannot erase another. Explicit Publish/Retry respect the same wait. 502/503/504 backpressure also defers further publication requests. |
| CF02 | Malformed Base64 saved-session framing and malformed rotation-lock JSON could emit engine errors. Framing is checked before decoding, noncanonical/oversized encodings are rejected, and lock ownership is parsed quietly while preserving uncertain ownership. |
| CF03 | Updating `CacheControl` through `--add cachecontrol==...` could write duplicate conflicting pins. Distribution names now follow [PyPA normalization](https://packaging.python.org/en/latest/specifications/name-normalization/), including runs of dots, underscores and hyphens; aliases replace the existing reviewed pin. Invalid names and alias duplicates are rejected. |
| CF04 | Verifier warmup ran outside the application's teardown guard, and a cleanup exception could skip later adapter cleanup. Failed startup now attempts readiness, blob-transport and verifier cleanup; failure of one cleanup cannot skip the others. |
| CF05 | Browser completion rechecked expiry/consumption/completion after provider IO but did not compare the snapshotted nonce. The conditional update now checks that nonce too. A challenge changed during verification is rejected without holding a DB connection during the provider call. |

CF01 retains compatibility with existing `publication-retry.json` and interrupted temporary records. New records live in `.publication-waits/<nonce hash>.wait.json`; completion receipts are tied to that nonce. Completed immutable records are retired, while the legacy receipt prevents the old relative wait from reviving. A later authoritative server clock can release a previously seeded conservative deadline. Storage refusal still keeps the wait in memory; corrupt/uncertain records preserve original jobs and evidence. A peer retiring a file between enumeration and reading is treated as absence rather than a false corruption report.

The review also exercised actual HTTPRequest cancellation and reuse: the cancelled owner's request completes once, a new owner receives its own response, and the old socket completion does not satisfy a later request. That path passed without a runtime transport change.

## Changed files

- `game/backend/track_lifecycle.gd`, `session_vault.gd`, `session_rotation_lock.gd`.
- `backend/bmt_backend/app.py`, `browser_auth.py`, `backend/deploy/lock_dependencies.py`.
- `backend/tests/test_communication_cleanup.py`, `test_lock_refresh_followup.py`, `test_medium_communication.py`.
- `game/tests/test_communication_followup.gd`, `publication_pause_worker.gd` and generated UIDs; updated `test_medium_communication.gd`, `test_resume_recovery_budget.gd`, `test_request_trace.gd`.
- `scripts/test_request_trace.py`, `scripts/test_communication_followup_postgres.py`.
- This report and task entries in `DEVELOPMENT_STATUS.md` / `docs/PHASE_0_PLAN.md`.

The dependency pins, image digest and wheel hashes remain unchanged. The lock-refresh fix was tested offline with a fictional metadata provider and temporary lockfiles; no package version was updated.

## Actual verification

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_communication_followup.gd
.tools/backend-secure-venv/Scripts/python.exe scripts/test_request_trace.py
.tools/backend-secure-venv/Scripts/python.exe scripts/test_communication_followup_postgres.py
.tools/backend-secure-venv/Scripts/python.exe build/communication-followup-2026-10-13/test_runtime_build.py
```

**254 backend tests passed, nine expected skips**, using SQLite and a generated owned PostgreSQL 17 container. This covers the combined communication fixes, real refresh/logout races, provider IO connection lifetime, modified browser nonce, startup/teardown failures, hash enforcement, package aliases and adjacent deployment-plan/storage/publication/recovery tests. Three additional invalid-name cases added after that matrix started pass in the focused follow-up run (**10 passed** including cleanup/alias cases). The owned container was removed after its label was checked. [Backend result](evidence/communication-followup-2026-10-13/backend-regression.log).

**75 Linux tests passed, two expected PostgreSQL skips** in the fresh, pinned Python runtime stage with verified local wheels and `--network=none`. The test additionally copies the lock-refresh helper needed by the offline helper tests. Runtime and project `pip check` pass: Python 3.12.15, HTTPS OpenSSL 3.0.22, cryptography 50.0.2, setuptools 84.0.0. [Linux result](evidence/communication-followup-2026-10-13/linux-runtime.log).

**513 pinned Godot checks passed**:

| Regression | Checks / failures |
| --- | --- |
| Communication follow-up | 37 / 0 |
| Medium communication | 31 / 0 |
| Local draft publication | 31 / 0 |
| Backend exception recovery | 28 / 0 |
| Session rotation | 17 / 0 |
| Shared resume recovery | 21 / 0 |
| Refreshed ticket priority | 26 / 0 |
| Resume recovery budget | 261 / 0 |
| HTTP retry | 20 / 0 |
| Network health | 28 / 0 |
| Real HTTP trace/cancellation fixture | 13 / 0 |

The follow-up includes two actual task-owned Godot child processes synchronized before writing the same publication scope. Both immutable pause files survive; the parent observes both waits and retires them after advancing its authoritative fixture clock. Children have bounded lifetimes and finish; no game/editor process is stopped. New cases cover expiry/restart, legacy migration, overlapping pauses, interrupted writes, storage refusal, clock backfill, explicit retry identity, exact evidence bytes and malformed-save/lock framing.

Ruff, local/container `pip check`, scoped whitespace and reverse-application checks pass. A fresh OSV query of all **46 pinned packages returns no advisory matches**; this is a database check rather than a claim of exhaustive vulnerability coverage.

## Reproduction and test corrections

Before the fixes, the new publication test reported **five failures in 11 checks**: elapsed wait revival, missing explicit-retry pause, repeated retry calls, restart retry calls and a Publish/bootstrap call during the wait. The package-alias tests reported **four failures**. The assertions remain and pass after the fixes.

The existing retry-identity test initially indexed a second request that is now correctly deferred after a 503. It now first verifies that restart sends no request during the pause, advances the fixture's authoritative clock past the existing fifteen-second minimum, then retains every original key/acknowledgement assertion. A focused test invocation encountered the already unavailable external fixture port; final database cases use the owned disposable container. These runs are not reported as passing.

## Limits and rollout

No full verifier/OS-library image, full Validate, physics/replay suite, Android game export/install or new physical-device test was performed. Native Keystore code is unchanged from the prior thirteen-check phone fixture; the new framing logic is verified through the real Windows adapter. No visible layout changed, so screenshots are not applicable.

Production remains on its existing image. Matching backend rollout, coordinated client restart/update, actual game sign-in/restore through Android JNI and real proxy-chain/device acceptance remain separately authorized checks. Previously documented target-host power-loss/failover and completely stalled provider/OS IO acceptance remain outside this local pass. Do not interpret the results as proof that no further bug or vulnerability can exist.

Original baselines and scoped checkpoint: `build/communication-followup-2026-10-13/` and `docs/evidence/communication-followup-2026-10-13/`. Concurrent authoring/JSON/body-validation, UI, audio and diagnostics work is retained and excluded from this task's patch.
