# Second game and backend code review

Repair follow-up (2026-10-03): R1-R13 are repaired in local source. See the [repair record](CODE_REVIEW_REPAIRS_2_3_2026_10_03.md) for final commands/results, migration and remaining deployment/device/PostgreSQL acceptance. The original dated findings and evidence below are retained.

The second pass found **eight remaining defects: two P1 and six P2**. The highest priorities are ordinary creator saves getting stuck during autosync and Sign out leaving the session active while reporting success. The remaining findings concern storage admission, client frame stalls, discovery bounds, deployment health, leaderboard navigation and validation retry limits.

Reviewed on **2026-10-03** against the current working tree based on Git `a7010f62cd70049b73e3c035dad24b46d0c719b2`, including existing uncommitted and concurrent changes. Current contracts are rules v16, physics 0.49 and creator compiler 20. This follows the [first review](CODE_REVIEW_2026_10_02.md) and [repair record](CODE_REVIEW_FIXES_2026_10_03.md); those documents describe their dated source and test results. Their historical rules/deployment observations are not the current contract.

Requirements covered: **Q01, G01, R01, T01–T04, B01–B07, B19, B20 and B23**, with the account, creator lifecycle, checkpoint and rewind overrides. The pass concentrates on async account/save transitions, durable recovery, admission and retention, catalog/standings pagination, worker leases and compatibility. P1 denotes a high-priority correctness defect in normal use; P2 denotes a significant conditional defect or scaling constraint.

This task adds review documentation and isolated reproductions. Runtime code, schema, services, credentials and player files were not changed by this review. No commit, export, installation or deployment was performed. Doctor found a DN2103 phone attached; no physical-device test was performed. There are no visible UI changes requiring screenshots.

## Findings ordered by priority

### R1 P1 A second local save during autosync becomes a permanent conflict

Sources: [track lifecycle](../game/backend/track_lifecycle.gd), `stage` lines 87–95, `_advance` lines 210–228 and `can_retry` lines 156–162; [server revision check](../backend/bmt_backend/tracks.py), lines 205–210. Requirements B19/B20/Q01.

Saving snapshot A records its expected remote head, initially `new`. While A's upload response is outstanding, saving B records the same head. A then succeeds and updates `heads.json`, but B retains its earlier expected head. Its upload receives `REVISION_CONFLICT` even though the only remote change came from this client's own preceding save. `_advance` persists a terminal failure, `process_jobs` skips failed jobs and the retry path supports validation/proof infrastructure failures rather than this conflict. The latest snapshot cannot continue through its normal Test/Publish flow without a separate recovery action.

**Reproduced:** the real lifecycle stages B during A's delayed response. A confirms a remote revision; B subsequently sends `expected_head = new`, records the conflict and returns `can_retry = false`. An independent real API/SQLite probe returns 201 for A, 409 for the stale parent, and 201 when B instead names A's confirmed head. Both snapshots remain preserved; this is a workflow failure, not demonstrated data deletion. [Client evidence](evidence/code-review-pass2-2026-10-03/client-probes.json), [API evidence](evidence/code-review-pass2-2026-10-03/backend-probes.json).

Link locally staged descendants to their confirmed predecessor before their first request, while preserving actual cross-device conflict protection. Provide explicit recovery for already failed conflicts. Changing an already attempted request requires a new immutable operation/idempotency key. Regress delayed A followed by B/C, a restart between them and a genuine competing device revision; do not simply accept every current remote head.

### R2 P1 Sign out can retain the account while reporting success

Sources: [backend client](../game/backend/backend_client.gd), `logout` lines 254–258; [account controller](../game/backend/account_controller.gd), `sign_out` lines 189–196; [account panel](../game/ui/account_panel.gd), lines 126–127. Requirements B01/Q01.

The account controller's `busy` flag differs from the client's request flag. Background uploads or credential rotation can leave the account panel's Sign out button enabled while `client._busy` is true. `logout` then returns `BUSY` before removing saved credentials or clearing the active session. The controller treats every failed result as a completed local logout and displays “Signed out on this device. The server could not be reached.”

**Reproduced:** with real account/controller/panel classes, a fictional saved session and the client marked busy, Sign out remains enabled. After activating it, `still_signed_in = true` and `saved_session_retained = true`, alongside that success-like message. This reproduces the branch without a live account or network. [Evidence](evidence/code-review-pass2-2026-10-03/client-probes.json).

Make durable local logout independent of the background request lock. Invalidate in-flight credential completions so refresh cannot restore the session, and handle server revocation separately with an accurate result. Regress slow upload/refresh plus Sign out, late responses and process restart. Merely changing the message would leave the account-control defect.

### R3 P2 Rejected draft uploads write permanent objects before admission

Sources: [track endpoints](../backend/bmt_backend/tracks.py), lines 146, 166–180 and 205–217; [shared admission](../backend/bmt_backend/queueing.py). Requirements B19/B23/Q01; follow-up to first-pass F12/F13.

`_prepare_revision` writes a content-addressed blob before authoring-ID/head checks and queue admission. A new deferred draft rejected with 429 therefore leaves its object on disk without a revision or validation job referencing it. Head conflicts and later envelope checks have the same ordering problem. Queue capacity bounds accepted computation, but does not bound retained bytes from rejected unique bodies. The existing request-rate limit bounds arrival rate, not cumulative storage. Offline, age-based orphan retention does not enforce admission at this boundary.

**Reproduced through the real API:** eight drafts fill the owner's accepted active-job allowance. Three further distinct drafts of approximately 420 kB each receive 429. Object count rises from 8 to 11 while validation rows remain 8; total object bytes are 1,261,730. The isolated test raises request-rate limits to expose storage ordering without unrelated throttling. This is not a measured NAS exhaustion or traffic-capacity result. [Evidence](evidence/code-review-pass2-2026-10-03/backend-probes.json).

Perform ownership/head/admission preflight before durable publication, with transactional reservation or bounded temporary staging to close races. Clean rejected staging safely without deleting a deduplicated object another revision references. Regress repeated distinct 429/409 bodies, concurrent admission, deduplication and retry; assert bounded object count/bytes as well as queue rows.

### R4 P2 Completed upload history stalls the game thread every two seconds

Sources: [cloud outbox](../game/backend/cloud_tracks.gd), `upload_jobs` lines 400–414 and `flush_outbox` lines 442–456; [application timer](../game/core/app.gd), lines 148–155. Requirements G01/R01/Q01; follow-up to F4/F13.

Each flush enumerates, sorts, opens and parses every receipt before filtering completed/failed jobs. Completed receipts are retained for durability/idempotency, including dismissed receipts. The app invokes this path every two seconds while authenticated, including during racing. The scan occurs synchronously before the first network await, so an empty pending queue still consumes game-thread time proportional to permanent history.

**Measured with real Godot/FileAccess and completed receipt files:**

| Completed receipts | Three scan measurements | Flush with no pending jobs |
| --- | --- | --- |
| 500 | 94.475 / 86.685 / 85.162 ms | 85.832 ms |
| 2,000 | 385.395 / 365.921 / 372.876 ms | 400.600 ms |

These are warmed desktop filesystem measurements in an isolated directory, not physical-phone or in-motion frame measurements. The observed synchronous work is sufficient to explain a periodic stall under that history size; mobile severity remains unmeasured. [Evidence](evidence/code-review-pass2-2026-10-03/client-probes.json).

Keep a bounded pending-job index separate from permanent receipts and page history on demand. Move potentially large filesystem scans away from the game thread, with safe completion/ownership handoff. Preserve deduplication and durable tombstones rather than deleting history indiscriminately. Regress an empty pending queue with thousands of completed/dismissed receipts and measure game-thread time during racing.

### R5 P2 A completed catalog snapshot bypasses the cache limit

Source: [cloud catalog](../game/backend/cloud_tracks.gd), `_snapshot_entries` and `refresh` lines 88–100; `load_cached` lines 48–52. Requirements B03/Q01; follow-up to F10.

Intermediate refresh pages trim `entries` to 1,000 items, but `_snapshot_entries` accumulates every page without a bound. On the final page, `entries` is replaced by a deep copy of that full snapshot and persisted without trimming. Loading the cache also accepts all saved entries. Per-refresh request limits therefore leave memory and final cache size proportional to the entire public catalog. Repeated filtering/copying of the accumulated arrays further increases work as the catalog grows.

**Reproduced:** four refresh calls over 1,001 valid mocked catalog entries produce sizes 300, 600, 900 and 1,001. Both the finished snapshot and saved cache contain 1,001 despite the configured 1,000 cap. Larger-catalog growth follows from the source; exceeding the 8 MiB cache limit was not measured here. [Evidence](evidence/code-review-pass2-2026-10-03/client-probes.json).

Bound the staging structure and final committed catalog, retaining only compact traversal state needed for consistency. Keep downloaded/favorite track references durable independently of the discovery preview cache. Regress more than 1,000 entries, a much larger catalog, resumed refresh, cached restart and search during refresh. The fix needs to bound temporary memory as well as the written file.

### R6 P2 Competition health can approve a build that cannot issue tickets

Sources: [competition health](../backend/bmt_backend/operations.py), lines 40–49; [compatibility transformation](../backend/bmt_backend/contracts.py), lines 10–14; [ticket compatibility check](../backend/bmt_backend/runs.py), lines 147–158. Requirements B20/B23/Q01; follow-up to F14.

Health declares competition ready when a fresh worker's four reported build fields match the API's bundled verifier. It does not check whether the current Python compatibility transformation produces contracts that this verifier can execute. A mixed deployment can therefore have matching API/worker verifier artifacts while transformed track contracts are incompatible. Other pinned compiler/schema/vehicle fields are also absent from this readiness comparison.

**Reproduced:** an isolated v14 verifier manifest with a fresh matching v14 worker heartbeat produces `competition_status = ready`. Current Python transforms the track contract to v16, and the real ticket endpoint returns 409 requiring a different verifier build. The verifier manifest and heartbeat are injected; API/DB/health/ticket paths are real. [Evidence](evidence/code-review-pass2-2026-10-03/backend-probes.json).

**Current live observation:** read-only public requests at 14:53 UTC on October 3 return 200 for health/readiness, and both the live manifest and one public board report v16/0.49/compiler 20. The earlier live v14 mismatch is no longer current. This finding is the missing deployment guard, not a claim that the present PC deployment is broken. No authenticated competition-health or live ticket write was performed. [Live evidence](evidence/code-review-pass2-2026-10-03/live-public-contracts.json).

Validate the effective supported ticket contracts and complete relevant pinned/vehicle contract before reporting competition ready. Distinguish verifier agreement from compatibility with current ticket issuance. Preserve independent API readiness for noncompetitive operations. Regress matching-but-obsolete artifacts, compiler/vehicle mismatches, stale workers and a fully matching build.

### R7 P2 High scores ignore cursors and fail beyond the offset ceiling

Sources: [high-score dialog](../game/ui/cloud_leaderboard.gd), lines 26–31, 41–44 and 51–58; [leaderboard endpoint](../backend/bmt_backend/runs.py), lines 345–346. Requirements B04/B05/Q01; follow-up to F11.

The server supports cursor paging, but the dialog only follows `next_offset`. At offset 10,000 a populated board can offer offset 10,020; the next request violates the server's explicit 10,000 offset maximum. Around me also first reloads the current page to obtain a board ID, so after that failure it repeats the invalid page request and never reaches the indexed neighborhood endpoint.

**Reproduced:** the real dialog with server-shaped fixture responses offers 10,020, requests it, displays `INVALID_INPUT`, then repeats it for Around me without making an around-me request. Separately, the actual FastAPI route rejects `offset=10020` with 422/`INVALID_INPUT`. A 10,000-player live dataset was not populated; the boundary and client path are exercised independently. [Client evidence](evidence/code-review-pass2-2026-10-03/client-probes.json), [API evidence](evidence/code-review-pass2-2026-10-03/backend-probes.json).

Use returned cursors with a page-history stack for Previous. Retain/fetch board identity independently of the current page so Around me remains usable after a paging failure. Regress traversal past the ceiling, ties, previous-page navigation and Around me after an error. Increasing the offset limit would retain progressively expensive offset paging.

### R8 P2 Expired validation leases bypass the attempt limit

Sources: [track validator](../backend/bmt_backend/track_validation.py), lines 14–26 and 40–48; compare [race worker](../backend/bmt_backend/worker.py), lines 74–78. Requirements B07/B19/B23/Q01; follow-up to F9/F12.

The validator reclaims expired queued/validating jobs and increments `attempts` without checking the configured maximum before execution. That maximum is enforced only when a failure reaches finalization. A worker crash or expired lease skips that finalizer, allowing more canonical validation work on subsequent claims. The race worker already has a preclaim exhaustion check. Repeated validation process failures or lease loss can therefore exceed the intended expensive-work bound indefinitely.

**Reproduced:** a validation job is placed in the production-shaped expired-lease state with three attempts at a configured maximum of three. `process_one` executes a fourth attempt and records `attempts = 4`, `status = validated`. This injects the expired claim state rather than crashing a container; the fake verifier avoids actual expensive computation. Ordinary finalized infrastructure failures remain bounded. [Evidence](evidence/code-review-pass2-2026-10-03/backend-probes.json).

Fail exhausted claims before invoking the verifier, preserving the draft and an explicit infrastructure retry state. Keep lease fencing and reset the attempt budget only on the authorized retry path. Regress repeated expired claims, an obsolete worker's late completion and explicit retry.

## Actual verification

Commands ran from the repository root. `python` below means `.tools/backend-venv/Scripts/python.exe`. The Godot entry point below means `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`, which selected **4.7.2.stable.official.ed1daf0bf**. Probes use fixture identities/responses and isolated directories; the public live observation uses no credentials.

| Actual command | Actual outcome |
| --- | --- |
| `python docs/evidence/code-review-pass2-2026-10-03/backend_probes.py` | Exit 0; records rejected-upload storage, stale revision parents, mixed-build health, offset validation and expired validation claims. |
| Godot entry point `-Action TestScript -ScriptPath res://tests/review_pass2_probes.gd -CommandTimeoutSeconds 120` | Exit 0; records busy Sign out, delayed revision autosync, 1,001-entry refresh, leaderboard failure and 500/2,000-receipt timings. This is a defect reproduction, not a passing invariant test. |
| `python -m pytest backend/tests/test_review_reliability.py backend/tests/test_track_lifecycle.py backend/tests/test_maintenance.py -k 'not postgres' -q --tb=short --show-capture=no --junitxml=build/review-pass2-baseline.xml` | 40 passed, one skipped, 39 deselected; 11.26 s. |
| `python -m pytest backend/tests/test_auth.py backend/tests/test_browser_auth.py backend/tests/test_admin.py backend/tests/test_resumes.py -k 'not postgres' -q --tb=short --show-capture=no --junitxml=build/review-pass2-auth-admin-resumes.xml` | 64 passed, eight deselected; 17.14 s. |
| `python -m pytest backend/tests/test_verifier.py -k 'real_engine_manifest or real_five_lap or real_creator_practice or godot_http_adapter or server_accepts_overlapping_bridge or handbrake_board_upgrade' -q --tb=short --show-capture=no --junitxml=build/review-pass2-canonical.xml` | 15 passed, 37 deselected; 8.69 s. Includes actual pinned-engine verification and HTTP adapter paths. |
| `python -m ruff check backend` | All checks passed. |
| `python -m ruff check --select F docs/evidence/code-review-pass2-2026-10-03/backend_probes.py docs/evidence/code-review-pass2-2026-10-03/capture_public_contracts.py` | All checks passed for the review scripts. |
| Godot entry point `-Action TestReview -CommandTimeoutSeconds 150` | 17 checks, zero failures; exit 0. |
| Godot entry point `-Action TestScript -ScriptPath res://tests/test_bridge_entry_checkpoints.gd -CommandTimeoutSeconds 180` | 258 checks, zero failures; exit 0. Includes a five-lap compact Over and under replay at 25,685 ticks. |
| Godot entry point `-Action TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 120` | 252 scripts parsed, zero failures; exit 0. Script count reflects the current concurrent working tree. |
| Godot entry point `-Action Doctor` | Pinned engine/templates and prerequisites passed; DN2103 attached. No device test performed. |
| `python docs/evidence/code-review-pass2-2026-10-03/capture_public_contracts.py` | Read-only local public health/readiness/catalog/manifest/board requests returned 200; sampled current contracts agree on v16/0.49/compiler 20. |
| `git diff --check -- DEVELOPMENT_STATUS.md docs/PHASE_0_PLAN.md docs/CODE_REVIEW_PASS_2_2026_10_03.md docs/evidence/code-review-pass2-2026-10-03 game/tests/review_pass2_probes.gd` | Exit 0; tracked documentation changes have no whitespace errors. Git warns about CRLF conversion. Newly added untracked files are outside Git's diff check. |

The selected backend runs total **119 passed and one skipped**; PostgreSQL cases were excluded in the first two runs. The Python test harness emitted the existing Starlette/httpx deprecation warning. These passing tests do not cover the newly reproduced transitions and bounds. Neither the full backend suite nor full Godot `Validate` was rerun in this pass. Historical broad-run/native shutdown failures remain recorded in the repair report and are not reclassified as fixed by these selected checks.

## Review files and acceptance limits

Added files: this report; [backend reproduction](evidence/code-review-pass2-2026-10-03/backend_probes.py) and its [results](evidence/code-review-pass2-2026-10-03/backend-probes.json); [client reproduction](../game/tests/review_pass2_probes.gd), its generated `.gd.uid` and its [results](evidence/code-review-pass2-2026-10-03/client-probes.json); [public observation script](evidence/code-review-pass2-2026-10-03/capture_public_contracts.py) and its [results](evidence/code-review-pass2-2026-10-03/live-public-contracts.json). Development status and Phase 0 plan receive review pointers. These scripts record observations and are not wired into a shipping flow or used to weaken an invariant.

The temporary SQLite database/object store is disposed after the backend probe. Godot fixture files remain under an isolated ignored `build/review-pass2-*` directory. No owner data was deleted or migrated. The substantial pre-existing changes and other concurrent work were preserved; no mixed-workspace Git checkpoint was created.

Remaining acceptance after fixes: targeted regressions for all eight findings; real account/save behavior under weak or interrupted networks; process/power-loss and disk-full recovery; a clean full regression run; PostgreSQL concurrent admission/lease behavior; DS925+ sustained load, disk growth and worker latency; phone frame/thermal measurements with accumulated history; and human touch/UX acceptance. Desktop timings and fixture probes establish these defects, but do not establish backend capacity or physical-device performance. Provider-backed Google/ads/store acceptance remains outside this review.
