# Game and backend code review

Repairs and subsequent verification are tracked in [CODE_REVIEW_FIXES_2026_10_03.md](CODE_REVIEW_FIXES_2026_10_03.md). Findings below describe the reviewed October 2 state; source line numbers are historical.

Reviewed on 2026-10-02 against the working tree based on Git `7ed5bcdec1421ed911e1d7c88af70ad06c3433f5`, including the substantial existing uncommitted changes. Requirements covered: Q01, G01, R01, T01–T04, B01–B07, B19, B20 and B23, together with the current checkpoint, account, creator publication and rewind overrides.

The canonical simulation and transactional backend have sound foundations, but several failure paths can lose online results or block their verification. These should be fixed before broader online testing. The NAS capacity is unestablished; a successful small functional test is not evidence that the current request, catalog and leaderboard paths will scale.

This review changes documentation and adds isolated review probes only. It does not change runtime behavior, schemas, deployed services, credentials or player files. No commit, export, deployment or physical-device test was performed. Device attachment was not checked. There are no visible UI changes requiring screenshots.

## Findings ordered by priority

P1 means a high-priority correctness or availability defect. P2 means a significant conditional defect or scaling constraint. Reproductions, source-based findings and unmeasured risks are distinguished below.

### P1 Race tickets and workers disagree after a physics upgrade

Sources: [ticket manifest](../backend/bmt_backend/runs.py), `board_manifest`, lines 68–96; [worker](../backend/bmt_backend/worker.py), lines 53–66.

Tickets upgrade stored physics versions 0.39–0.48 to 0.49. The worker instead derives its expected manifest from the original track version and applies only the checkpoint-rules transition. A legitimate 0.49 result therefore differs from the worker's expected 0.48 manifest. The worker labels it an infrastructure failure, retries it and eventually fails it without updating the leaderboard. Current-version fixtures miss this defect.

**Reproduced:** an isolated fake verifier returned valid timing and the current manifest. Ticket issuance returned 201 with physics 0.49; submission returned 202; the worker changed the run to `queued / verifier_unavailable`. The probe exercises the real API, database and worker, with the verifier result injected. [Evidence](evidence/code-review-2026-10-02/backend-probes.json).

Use one explicit compatibility transformation for ticket issuance and worker verification, then compare the complete relevant contract. Keep the original immutable track and historical boards intact. Add an end-to-end transition regression through worker finalization, including creator proof, rather than testing only the board hash.

### P1 A failed Restart discards the active online race contract

Source: [app](../game/core/app.gd), `_retry_race`, lines 1600–1615, and `_results`, lines 1478–1490.

Restart clears `cloud_ticket` before requesting a replacement. If that request fails, the function returns while retaining the old running game and its old resume ticket. Finishing that race subsequently bypasses online submission because the app no longer has its ticket. A failed replacement request has invalidated an otherwise valid attempt.

**Reproduced:** an injected failed cloud request left `game.resume_ticket_id = active-old-ticket` and `app.cloud_ticket = {}`. [Evidence](evidence/code-review-2026-10-02/client-probes.log).

Acquire the replacement into a local value and update the game and app contract together only when Restart succeeds. Bind the async operation to the current game instance and account so a delayed completion cannot restart a departed race.

### P1 Large request validation blocks the API event loop and health paths bypass its rate budget

Source: [request boundary](../backend/bmt_backend/middleware.py), lines 77–96 and 118–150; [deployment](../backend/deploy/compose.yaml), API concurrency 24 and one Uvicorn process.

The async middleware runs JSON decoding, duplicate-key checks and the complete nested-value walk synchronously, before route authentication. FastAPI then parses the bytes again. A large valid JSON body therefore stalls other connections in that API process, including small reads and health checks.

**Measured:** a supported 216,000-frame, 3,024,048-byte body delayed another scheduled coroutine by 0.555, 0.721 and 0.723 seconds on this desktop. This isolates boundary CPU work; it is not an HTTP load benchmark. [Timings](evidence/code-review-2026-10-02/boundary-timings.json).

The rate-limit exemption checks only the path. `POST /healthz` and `POST /readyz` still buffer and validate their body before the router rejects the method. **Reproduced:** 40 health POST requests returned 405 with zero rate-budget increments. Large bodies can use this unmetered path to invoke the same expensive validation. [Evidence](evidence/code-review-2026-10-02/backend-probes.json).

Exempt only the intended bodyless health requests, reject unsupported health methods/bodies early, and move expensive validation off the event loop with bounded concurrency. Preserve duplicate-key, finite-number, Unicode and nesting checks. Measure the subsequent framework parse and peak memory as well; simply moving one pass does not remove duplicate work.

### P1 The durable outbox can reject a completed race because unrelated jobs fill one file

Sources: [cloud adapter](../game/backend/cloud_tracks.gd), `_read`, `_write`, `queue_run`, lines 18–35 and 185–199; [result handling](../game/core/app.gd), lines 1484–1490.

All replay bodies share an 8 MiB outbox file. The limit applies to the entire queue rather than each supported replay. Failed jobs retain their frames and are neither retried nor pruned; completed jobs are pruned only when another race is queued. Once the aggregate limit is exceeded, saving a new result fails. The app nevertheless clears that attempt's ticket and allows navigation away, leaving no durable retry for it.

**Reproduced:** two maximum-length four-channel replays saved successfully; the third failed, leaving two persisted jobs. Ordinary shorter races require more backlog to reach the same failure. [Evidence](evidence/code-review-2026-10-02/client-probes.log).

Store each immutable replay separately with a small atomic queue index. Make disk-full/corrupt-index recovery explicit, retain the attempt until durable enqueue succeeds, and provide a way to inspect and retire terminal failures. `_read` currently treats missing, unreadable, oversized and corrupt files identically as `{}`, so later writes can also replace evidence of a damaged queue without recovery.

### P2 Checkpoints do not distinguish the bridge deck from the ground below

Sources: [session](../game/race/track_session.gd), `_configure` and `advance`, lines 35–107 and 171–208; [canonical runner](../game/backend/runner.gd), lines 195–200.

Gate construction samples the intended elevated surface, but gate acceptance receives only planar endpoints and a route hint. That hint affects display progress; the crossing test does not verify the car's layer or height. A ground-level crossing can consequently consume a gate intended for an elevated road. Finish acceptance has the same missing distinction.

**Reproduced at the gate boundary:** in the supported creator bridge fixture, elevated gate 4 advanced to gate 5 with a ground route hint and a drivable ground cell. The probe directly supplies the crossing; it does **not** prove a complete shortcut replay on a shipping track. [Evidence](evidence/code-review-2026-10-02/client-probes.log).

Pin each gate's required layer and pass canonical layer state into acceptance. Test both legitimate bridge junctions and underpasses. This is a race-rule contract change and needs a new rules key, replay regressions and human inside-line acceptance; do not silently rescore existing boards.

### P2 Cached cloud tracks wait for optional standings before they become playable

Sources: [browser](../game/ui/track_browser.gd), `_finish_selection` and `_load_cloud_detail`, lines 418–455; [HTTP adapter](../game/backend/backend_client.gd), lines 92 and 167–183.

Even after a track is cached and compiled, the browser disables Race and waits for leaderboard loading. A populated board adds sequential histogram and around-me requests. Every request has a 30-second timeout, and all requests share one `_busy` gate. A weak connection or slow score upload can therefore hold a cached track's selection for a long time. Rapid selection discards stale responses only after their network work completes; it cannot cancel obsolete requests.

This is source-confirmed, not a measured mobile delay. Publish the resolved track immediately and hydrate records independently. Keep offline racing accessible, show records as pending or stale, cancel obsolete reads and prioritize explicit player actions. Preserve single-flight refresh-token rotation while allowing independent public reads to proceed.

### P2 A transport failure during refresh erases the remembered account

Source: [HTTP adapter](../game/backend/backend_client.gd), `restore_session`, lines 51–69, and `request_api`, lines 167–183.

Session restore removes the saved refresh token before attempting its request, and every failed response clears the session. Runtime refresh does the same on any failure. DNS/connect failure or service unavailability is consequently treated like invalid credentials. Account-scoped drafts, records and pending uploads then become inaccessible until the player signs in again.

**Reproduced:** a `NETWORK_ERROR` during restore left no saved session and no signed-in identity. [Evidence](evidence/code-review-2026-10-02/client-probes.log).

The security motivation is valid: a refresh may have committed despite a lost response, and blindly reusing that token triggers family revocation. Preserve transport outcome information and retain credentials when failure is definitively before delivery. For ambiguous delivery, design recoverable refresh receipts or an explicit recovery flow while retaining reuse detection. Do not solve this by simply retrying single-use refresh tokens or weakening replay protection.

### P2 Browser polling shares a small authentication quota with every player behind one IP

Sources: [request boundary](../backend/bmt_backend/middleware.py), lines 77–92; [settings](../backend/bmt_backend/config.py), auth limit 30/minute; [account controller](../game/backend/account_controller.gd), Google poll interval five seconds.

Browser start/prepare/complete, five-second polling and token refresh all consume the same IP-level authentication bucket. Three simultaneous waiting sign-ins can make 36 poll requests/minute before any setup or completion requests. A household, school or carrier network can therefore exhaust the quota through legitimate use. The controller exits its sign-in loop on any failed poll, including 429, rather than waiting for the budget to reset.

**Reproduced at the boundary:** the first 30 authentication requests from one peer succeeded and the 31st returned 429. This does not constitute a real Google/network test. [Evidence](evidence/code-review-2026-10-02/backend-probes.json).

Keep an IP abuse ceiling, but use separate bounded polling and refresh budgets tied to their verified session or handoff identity. Return retry timing and honor it in the client without abandoning an otherwise live login. Verify behavior with multiple players behind one NAT before public sign-in acceptance.

### P2 Track validation runs inside HTTP requests with incompatible time budgets

Sources: [track writes](../backend/bmt_backend/tracks.py), `_validate_and_store`, `create_track`, `create_version`; [verifier](../backend/bmt_backend/verifier.py), lines 123–165; [client](../game/backend/backend_client.gd), line 92.

Uploads synchronously launch the canonical engine. One process-wide semaphore rejects competing validation calls immediately, and the verifier can run for 90 seconds while the client stops waiting after 30. Version creation also holds the logical track row lock while validation runs. A slow but allowed track can time out on the device and still commit on the server; concurrent creator work can receive avoidable 503 responses.

The current upload idempotency map helps recover unknown outcomes, but does not make the experience responsive. Separate upload acceptance from queued validation with a status endpoint, or first align explicit budgets and expose safe retry state. Perform expensive validation before taking the numbering lock, then recheck ownership and allocate the immutable version transactionally. Keep validation fail-closed.

### P2 Discovery requires downloading the whole catalog and eventually cannot refresh

Sources: [cloud catalog](../game/backend/cloud_tracks.gd), `refresh`, lines 50–83; [browser](../game/ui/track_browser.gd), `_load_catalog`; [server discovery](../backend/bmt_backend/tracks.py), lines 228–262.

Opening the browser triggers a sequential full-catalog refresh in 100-item pages. Search/filtering then happens locally. Every server result includes its complete manifest, and `discovery_payload` reads and hashes the source blob to extract preview metadata. The isolated probe confirmed one blob read per returned row. Substring name/creator search and the latest-published-version aggregation add database work as the corpus grows.

With more than 10,100 default-page results, the next offset exceeds both API/client browsing bounds. The client abandons the collected catalog and keeps the old one, so growth can permanently prevent refresh. Offset paging across separately executed requests also permits duplicate or skipped entries when publication changes the ordering during refresh.

Use server-side bounded search/filter queries, stable cursor pagination and a compact indexed discovery projection containing preview fields. Cache or persist that projection independently of full documents. Deduplicate version IDs and preserve successful page progress. PostgreSQL trigram indexes are a candidate for measured substring-search bottlenecks; they support `LIKE`/`ILIKE`, but index usefulness still depends on query shape and terms. [PostgreSQL index documentation](https://www.postgresql.org/docs/17/pgtrgm.html).

### P2 Small leaderboard responses still perform work across the board population

Source: [leaderboards](../backend/bmt_backend/runs.py), `ranked_population`, `top`, `around_me`, `histogram`, lines 262–381.

The PB index is useful, but around-me constructs the window-ranked population and issues separate count, own-row, neighborhood and slower-player queries. Histogram adds min/max and grouped scans. Selecting a cloud track requests these projections sequentially. A seven-row response is therefore not seven-row database work. Window ordering/filtering semantics support this source-based assessment; actual PostgreSQL planner costs were not measured in this review. [PostgreSQL window documentation](https://www.postgresql.org/docs/17/tutorial-window.html).

Retain the coherent read snapshot and exact disabled-player/tie semantics. Measure `EXPLAIN (ANALYZE, BUFFERS)` with representative board sizes, then consider indexed predecessor/successor queries, rank counts and short-lived board aggregates. Avoid constructing full ranking windows for projections that only need counts. Use cursor pagination for board browsing beyond the current offset cap.

### P2 Verification admission has a per-player limit but no service capacity budget

Sources: [submission](../backend/bmt_backend/runs.py), lines 210–229; [worker](../backend/bmt_backend/worker.py), lines 23–59; [Compose](../backend/deploy/compose.yaml), worker configuration.

Eight outstanding jobs per player prevent one account from flooding the queue. They do not bound total backlog across accounts. One configured worker processes jobs serially in creation order, so many accounts or long replays can increase result latency for everyone. There is no global admission budget, player fairness policy or published expected wait time.

**Desktop baseline:** a 12,757-frame five-lap oval took 2.222, 1.913 and 1.908 seconds to verify. The median implies approximately 31.4 such replays/minute before database, storage and other overhead. This is a rough single-worker desktop estimate, not a NAS guarantee or public capacity claim. Cold manifest startup took 0.633 seconds. [Timings](evidence/code-review-2026-10-02/verifier-timings.json).

Measure the DS925+ under realistic replay lengths and track complexity. Track queue depth, oldest age, arrival rate and processing percentiles. Size workers from those measurements; add bounded global admission and fair scheduling while retaining leased claims, fencing and idempotent PB updates. For cloud replication, provision the shared object storage and database connection budget as well as worker CPUs. A new broker is unnecessary until the database queue itself is the measured constraint.

### P2 Race and object history have no bounded storage lifecycle

Sources: [maintenance](../backend/bmt_backend/maintenance.py), lines 13–25; [persistent models](../backend/bmt_backend/track_models.py); [object store](../backend/bmt_backend/storage.py); [resume models](../backend/bmt_backend/resume_models.py).

Maintenance deletes expired authentication and rate records only. Submitted replay blobs, terminal runs, unused expired tickets, domain idempotency responses, resume races/receipts and orphan blobs have no retirement policy. Blob publication occurs before the database commit, so failed writes can create unreferenced objects. Growth increases database/index size, disk pressure, backup duration and restore time even if active traffic stays modest.

Retention of shared content, PB evidence and credits is intentional and must remain correct. Define separate retention rules for those records and expendable history; archive when appropriate and perform reference-aware garbage collection. Protect PB ghosts, creator publication proofs, receipt auditing and idempotency guarantees before deleting anything. Measure backup size/restore duration and rehearse interrupted cleanup.

### P2 Health checks do not reveal whether verified competition is operating

Sources: [readiness](../backend/bmt_backend/app.py), lines 55–64; [worker](../backend/bmt_backend/worker.py); [logging](../backend/bmt_backend/observability.py); [admin console](../backend/bmt_backend/admin_ui/app.js).

Readiness checks the schema and object store, but not worker freshness, queue age or verifier compatibility. A stopped worker or the manifest defect above can leave the API healthy while all results remain pending. Worker infrastructure logs expose only the exception type, so the physics mismatch is difficult to diagnose from logs alone. The console honestly reports that worker/disk/backup monitoring is not configured.

Add worker heartbeat, processing/error counters, oldest pending age, verifier-build identity and disk/backup observations. Emit safe structured failure reasons and nonsecret contract differences. Distinguish API readiness from competition health; do not make public reads fail merely because verification is temporarily unavailable. Every read currently also writes a rate bucket, and `Cache-Control: no-store` is applied even to immutable public documents. Measure that database write load and allow bounded public document caching with ETags where restriction semantics permit it.

### P2 The broad app regression is stale and can hang validation indefinitely

Sources: [app test](../game/tests/test_app.gd), lines 51–60 and 135; [validation wrapper](../scripts/dev.ps1), `Invoke-Checked`, `Invoke-Validation`.

The app suite expects Race and its browser after two frames, while the app now starts at Account unless session restoration succeeds. It then dereferences missing UI controls. Some later assertions also use controls retired by the search/filter drawers. The SceneTree never quits after these script errors, and `Invoke-Checked` has no timeout and buffers its output until the child exits. The full validation/export path can therefore stall without exposing the diagnostic output.

**Observed:** TestApp did not complete within the review's 90-second bound. A second isolated diagnostic, with backend access disabled, reported three startup failures and null-instance script errors at lines 135 and 60, then also required termination after 20 seconds. Only the exact probe process trees were stopped. [Diagnostic](evidence/code-review-2026-10-02/app-direct.log).

Make startup/auth fixture state explicit, await an actual readiness condition, guard prerequisites before dependent UI assertions, and update the integration journey to the current controls. Add suite time bounds and stream output in the wrapper. Preserve failing invariants; repair the fixtures rather than deleting assertions or substituting quick deployment checks for the full gate.

## Maintainability and contract risks

The game has useful domain boundaries: quantized input, canonical vehicle state, race rules, compilation, presentation, persistence and backend adapters are largely separated. The Python backend similarly separates identity, tracks, competition, resumes and storage. Canonical physics inspection found no network, file access, wall-clock calls or display-rate delta dependency inside the simulation step. This is a positive source finding, not a proof of every cross-platform trajectory.

`app.gd` now combines navigation, editor tools, undo/redo, account storage, asynchronous publication, race contracts and results in more than 2,300 lines. `track_browser.gd` combines catalog queries, threads, network loading and animations. Extract a race/publication coordinator first: findings 1 and 2 show that contract ownership deserves explicit state and transaction boundaries. Then move editor history and catalog loading behind focused interfaces, preserving current behavior with meaningful integration tests.

Transport/status dictionaries are used as implicit schemas, and several callers access private adapter fields directly. Introduce typed operation results and explicit methods for account identity, configured origin, saved-session state and failure classification. Do not serialize unrelated public reads just to protect refresh rotation.

Version and policy changes require editing multiple independent validators and mappings. The Python replay validator still describes and allows a 20-second rewind while authorized receipts and the current UI limit it to ten seconds. Receipt validation presently prevents a shipping 20-second resume, so this is contract drift rather than a demonstrated authorization bypass. Centralize policy definitions or generate consistent fixtures and add cross-boundary contract checks.

The documented current behavior is obscured by long duplicated chronological status histories and outdated sections labeled as current. Keep a short authoritative current-state summary and explicit open acceptance list, then move historical evidence into dated references. In particular, avoid letting old deferred-backend, retired-content or three-lap prose look like current requirements.

Editor navigation calls `wait_to_finish()` on the main thread, and normal race scene construction remains synchronous. These are plausible responsiveness constraints on complex tracks, but this review did not profile them on a phone. Existing cache and incremental-preview work should be preserved; measure worst-case track construction and cancellation before proposing a larger rewrite.

## Verification performed

| Actual command or check | Outcome |
| --- | --- |
| `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_auth.py backend/tests/test_browser_auth.py backend/tests/test_google_crypto.py backend/tests/test_usernames.py backend/tests/test_storage.py backend/tests/test_resumes.py backend/tests/test_admin.py backend/tests/test_maintenance.py backend/tests/test_official_tracks.py backend/tests/test_domains.py -q -k "not postgres"` | 109 passed, 38 deselected, 23.32 seconds. Temporary SQLite, not PostgreSQL concurrency verification. |
| Set `BMT_GODOT_BIN` to the pinned 4.7.2 console executable; `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_verifier.py -q -k "not adapter and not standalone"` | 50 passed, 2 deselected, 20.73 seconds. Includes actual canonical engine replays. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestRewind` | 57 checks, zero failures. |
| `.tools/backend-venv/Scripts/python.exe docs/evidence/code-review-2026-10-02/run_game_checks.py` | Uses the same pinned development entry point: Menus 48, Records 54, MenuLoading 38, Creator 113 checks pass. TestApp timed out after 90 seconds; not a pass. [Results](evidence/code-review-2026-10-02/game-checks.json). |
| `.tools/backend-venv/Scripts/python.exe docs/evidence/code-review-2026-10-02/probe_app_failure.py` | Engine pin checked, backend disabled, direct diagnostic confirms startup/null-instance failures and a 20-second timeout. |
| `.tools/backend-venv/Scripts/python.exe docs/evidence/code-review-2026-10-02/reproduce_backend.py` | Physics transition, discovery blob-read, shared-IP auth quota and health-path budget probes reproduced. |
| Pinned Godot `--headless --path game --script <absolute repository path>/docs/evidence/code-review-2026-10-02/reproduce_client.gd` | Final probe exits zero without script errors: lost session, lost active retry ticket, aggregate outbox limit and missing elevated-gate check reproduced. The helper stores only synthetic data in a unique temporary directory. |
| `.tools/backend-venv/Scripts/python.exe docs/evidence/code-review-2026-10-02/benchmark_verifier.py` and `benchmark_boundary.py` | Three samples each; raw timing files linked above. Not load tests. |
| `.tools/backend-venv/Scripts/python.exe -m ruff check --config backend/pyproject.toml backend/bmt_backend backend/tests backend/deploy --output-format concise` | Fails on one existing import-order issue, `backend/tests/test_domains.py:664`. [Output](evidence/code-review-2026-10-02/backend-lint.log). |

The two pytest runs emit a Starlette/httpx test-client deprecation warning. Overall, 159 selected Python tests and 310 checks in five selected Godot suites pass. These results do not override the failing app integration or the newly reproduced defects. The broad backend suite, PostgreSQL concurrency/load tests, full physics regression, Android export, real Google sign-in, TLS deployment, NAS restore/capacity and physical-device UX/thermal tests were not run in this review.

## Recommended repair order

1. Fix manifest compatibility and active-race ticket replacement; add worker and client regressions for both failure paths.
2. Close the health-path validation bypass and bound/offload request parsing without weakening strict input checks.
3. Make replay enqueue durable per attempt and recoverable after queue/storage failure; then repair refresh recovery and allow cached-track play while standings load.
4. Repair the full app test and bounded validation runner so future work has a reliable integration gate.
5. Validate bridge layer acceptance with a physical replay before changing the rules key.
6. Measure NAS arrival/processing rates, representative PostgreSQL query plans, memory and restore time. Use those results to size workers, paginate discovery, optimize standings and define retention/monitoring.

The existing leased worker fencing, conditional PB upsert, ownership checks, Google nonce flow, single-use refresh protection, development-session rejection, immutable blob integrity and transactional resume receipts should be retained throughout these changes.
