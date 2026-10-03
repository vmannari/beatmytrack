# Repairs for review passes two and three

All **13 findings R1–R13** from the [second review](CODE_REVIEW_PASS_2_2026_10_03.md)
and [third review](CODE_REVIEW_PASS_3_2026_10_03.md) are repaired in the local source.
Final backend verification passed **230 tests**, with one skip and 100 deselections;
the client regression suite passed **86 checks**. PostgreSQL acceptance remains
unverified because its configured disposable test service timed out.

Requirements: **Q01, G01, R01, T01–T04, B01–B07, B19, B20, B23**, including the
account, creator lifecycle and rewind overrides. Work was performed on the mixed
working tree based on `a7010f62cd70049b73e3c035dad24b46d0c719b2`. Concurrent checkpoint
work advanced the rules to **v17**; this repair preserves physics **0.49**, compiler
**20**, creator-track-v5 and the pinned **Godot 4.7.2.stable.official.ed1daf0bf**.
This task did not rebuild or restart services, deploy, export/install Android,
modify owner data or commit the mixed tree. Separate concurrent development
service work is recorded in the checkpoint documentation; these test results are
against disposable databases/files and do not establish the running service's
final source/image alignment.

## Finding-to-change mapping

| Finding | Repair | Source and regression coverage |
| --- | --- | --- |
| R1: overlapping saves conflict | Journals link local predecessors. An unsent successor advances only from its acknowledged local predecessor when the staged expected head agrees with that predecessor's base. Attempted request bodies stay pinned. Explicit Retry of an existing conflict checks both the current head and the predecessor's server idempotency receipt, then creates a fresh upload key. A different device's head still conflicts. | `game/backend/track_lifecycle.gd`, `backend/bmt_backend/tracks.py`; delayed Save, explicit own-head recovery, foreign-head rejection and authenticated operation/head API tests. |
| R2: busy Sign out retains credentials | Local credential removal and identity change precede a separate bounded server-revocation request. Session generations fence late refresh/auth completions. A durable `.signed_out` marker blocks restart restoration even if an old credential file remains; successful sign-in removes it. Startup also retries removal of credential files blocked by the sign-out fence. Storage failures and unconfirmed revocation receive accurate messages. | `backend_client.gd`, `account_controller.gd`; refresh overlapping logout, late response, stale credential file/restart, subsequent sign-in. |
| R3: rejected uploads publish blobs | Canonical preparation computes a digest without writing. Ownership/envelope checks, immutable deduplication, head checks and shared admission occur before object publication. Validation remains outside numbering/admission locks. Player locking also serializes revision creation with archive intent. | `backend/bmt_backend/tracks.py`; distinct 422/409/429 bodies leave object count unchanged; identical revisions still deduplicate when capacity is full. |
| R4: receipt history stalls racing | Durable pending marker files separate active work from permanent receipts. Markers precede job writes; terminal receipt commits retire markers. Legacy recovery scans metadata on a worker thread once per account/session. Each ordinary poll examines at most 16 markers and continues its directory iterator across batches. History is loaded on demand in pages of 100, with background enumeration and metadata reads spread across frames. Ticket status/retry/dismiss use direct receipt lookup. Creator lifecycle polling pauses during gameplay. | `cloud_tracks.gd`, `track_lifecycle.gd`, `app.gd`; 2,000 completed receipts produce no main-thread receipt reads on the next idle poll; 40 pending jobs advance 16/16/8 without dropping a boundary job. |
| R5: discovery snapshot exceeds cap | Startup, temporary page collection, snapshot accumulation and remembered publications enforce the 1,000-preview limit. Download/publication metadata and legacy identity aliases are retained separately. Favorite and last-track resolution can include retained metadata after preview eviction. Track document caches and player references are preserved. | `cloud_tracks.gd`, `track_browser.gd`, `app.gd`; 1,001-entry multi-refresh snapshot, persistence/reload bounds and retained-favorite resolution. |
| R6: health approves incompatible builds | Worker heartbeats advertise engine/verifier/physics/rules/compiler/schema/tick-rate/lap/vehicle contracts. Health requires a complete matching worker build and a raw verifier manifest unchanged by Python's compatibility transform; transform disagreement reports `api_contract_mismatch`. API liveness remains independent. | `backend/bmt_backend/contracts.py`, `operations.py`, `worker.py`; compiler/tick/schema/vehicle mismatch and old-verifier/Python-transform tests. |
| R7: standings exceed offset ceiling | Next/Previous use cursor history. Around me uses the retained board ID independently of a failed/later page. An explicit Retry action retries the current view. | `game/ui/cloud_leaderboard.gd`; cursor requests beyond the old offset ceiling, Around me after a page failure, inspected desktop captures. |
| R8: lost validation leases exceed attempts | Claiming an exhausted queued/expired validation marks it failed with `validator_unavailable`, clears the lease and does not invoke the validator again. Explicit retry resets its attempt counter. | `backend/bmt_backend/track_validation.py`; a lost third lease stays at three attempts; explicit retry resets to zero. |
| R9: deleted drafts upload/restore again | Delete durably records owner/authoring-ID archive intent before removing local files, removes deferred work and fences journal mutation/in-flight results/restoration. An idempotent archive operation is retried online. The server retains an archive even if it precedes the first upload, blocks late revisions, fences pending validation and excludes archived private heads from restore. Public versions/share links/boards remain available. | `track_lifecycle.gd`, `app.gd`, `tracks.py`, `track_models.py`, migration `0010_archive_drafts.py`; pending/delete/restore client tests, server archive-before-create, validation cancellation, reinstall-head exclusion and public-link/board retention. |
| R10: expiry retains the old profile | Client identity changes notify the controller/app immediately for expiry and logout; explicit sign-in batches its transient clear/remember transition. Outgoing editor work stays in its original library, with in-memory recovery on save failure. Transferred published drafts are not recreated. Active race tickets pin owner/origin; results use the race's original records and enqueue under its original owner even after expiry. Account transition refreshes editor/menu presentation when no race is active. A confirmed restart begins a new attempt with current-profile records, while its ticket pins the actual running vehicle/handling rather than the menu selection. | `backend_client.gd`, `account_controller.gd`, `cloud_tracks.gd`, `app.gd`; immediate Guest storage/badge transition, original-owner autosave and result/outbox ownership after expiry; Guest/new-owner restart records and vehicle/handling checks. |
| R11: late start overrides navigation | Navigation generation, starting screen, account scope, track selection and vehicle are checked before installing a ticket or showing offline fallback. Offline confirmation is bound to the same initiating state. Retry also fences backend origin and pins its replacement ticket owner. | `game/core/app.gd`; delayed ticket cannot hide Settings/create a race/install a stale ticket. |
| R12: maximum four-channel replay rejected | Invocation JSON node capacity is derived from five nodes per maximum replay frame, bounded track bytes and envelope allowance. Depth, finite numbers, input ranges, frame count and byte protections remain. | `backend/bmt_backend/verifier.py`, backend tests; HTTP and invocation accept the maximum four-channel replay plus a large bounded JSON document. A real 216,000-frame replay, with stationary inputs before the existing legal five-lap fixture, finishes under the pinned engine at exactly 216,000 ticks. |
| R13: retention scans/query count unbounded | A retention batch inspects at most 1,000 directory entries regardless of orphan count, performs two batched reference lookups and returns inspected/deferred/cursor metadata. `--object-cursor` resumes through the 256 managed digest shards. Default remains dry-run; applying still requires stopped writers and `--offline`. | `backend/bmt_backend/maintenance.py`; referenced-object traversal with 17-entry batches uses at most two reference queries and eventually finds the orphan while preserving every track revision. |

Paths abbreviated above are relative to `game/backend/` or the named directory.
Additional changed test/tool files: `backend/tests/test_review_followups.py`,
`backend/tests/test_review_reliability.py`, `backend/tests/test_verifier.py`,
`game/tests/test_review_followups.gd`, `game/tests/test_review_reliability.gd`, `game/tests/capture_review_followups.gd` and
`scripts/dev.ps1` (`TestScript -Graphical`). The archive and pending-marker formats
are documented in `docs/schemas/track-archive-v1.schema.json` and
`docs/schemas/run-pending-marker-v1.schema.json`. Historical review probes/results
were not rerun or overwritten.

## Actual verification

Commands used the repository virtual environment and `scripts/dev.ps1`; the
Godot PATH alias was not used. Evidence is under
[the repair evidence directory](evidence/code-review-repairs-2026-10-03/).

| Actual command | Actual result |
| --- | --- |
| `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests -k 'not postgres' -m 'not postgres' -q --tb=short --show-capture=no --junitxml=build/review-followups-final-backend.xml` | **230 passed, 1 skipped, 100 deselected**, 136.59 s. Includes authentication/admin/domain/retention/validation tests, real pinned-engine replay verification and both HTTP/Godot cloud/lifecycle integrations. The skip is the existing SQLite concurrency exclusion. |
| Same broad command, earlier output `build/review-followups-full-backend.xml` | 227 passed, 1 skipped, 97 deselected, 147.80 s before the additional operation/head regression. |
| `python -m pytest backend/tests/test_review_followups.py -k 'not postgres' -q --tb=short --show-capture=no --junitxml=build/review-followups-final.xml` | **12 passed**, 11 deselected, 4.20 s. |
| `python -m pytest backend/tests/test_verifier.py -k maximum_four_channel_finished_race -q --tb=short --show-capture=no --junitxml=build/review-followups-max-replay.xml` | **1 passed**, 52 deselected, 17.66 s, actual completed maximum replay through Godot. Also passes in the broad runs. |
| `python -m pytest backend/tests/test_review_followups.py -q --tb=short --show-capture=no --junitxml=build/review-followups-postgres.xml` | **11 passed, 10 setup errors**, 107.48 s before adding the later operation/head test. Every PostgreSQL setup timed out against localhost:55439; no PostgreSQL acceptance is claimed. |
| `python -m pytest backend/tests/test_review_followups.py backend/tests/test_review_reliability.py -k 'not postgres' -q --tb=short --show-capture=no --junitxml=build/review-followups-final-health.xml` | **48 passed**, 46 deselected, 13.71 s; includes matching-but-incomplete raw manifest rejection. |
| Broad rerun before the final startup cleanup correction, preserved as `build/review-followups-startup-regression.xml` | **229 passed, 1 failed, 1 skipped**, 100 deselected, 138.53 s. Account UI correctly rejected authentication behind the sign-out fence, but a newly injected stale credential file remained. Startup now removes those leftovers; the existing assertion was preserved. |
| `python -m pytest backend/tests/test_account_client.py backend/tests/test_cloud_client.py -q --tb=short --show-capture=no --junitxml=build/review-followups-final-http.xml` | **3 passed**, 47.33 s after startup cleanup: real account menu, cloud library and durable publication integrations. |
| `python -m ruff check backend` | Passed. |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_review_followups.gd -CommandTimeoutSeconds 120` | **86 checks, 0 failures**. Earlier runs 69/73/80/82 also passed after correcting the initial fixture's Dictionary-to-Node assignment error. |
| Same entry point, `-Action TestScript -ScriptPath res://tests/test_script_parse.gd` | **259 scripts, 0 failures**. |
| Same entry point, `-Action TestReview` / `TestApp` / `TestDeleteTracks` / `TestRecords` / `TestRewind` | **17 / 96 / 20 / 54 / 57** checks, all with zero failures. |
| Same entry point, `-Action TestScript -Graphical -ScriptPath res://tests/capture_review_followups.gd` | **4 desktop screenshots**, fictional scores/accounts and isolated files. Final screenshots inspected. Initial delete text overflow was corrected with wrapping and recaptured. |
| Same entry point, `-Action Doctor` | Pinned engine, matching templates and prerequisites found; **DN2103 attached**. This is not a physical-device test. |
| `git diff --check -- <repair-related tracked source files>` | Passed; existing CRLF/LF notices only. Unrelated dirty files were excluded. |

The final client evidence measures an idle poll with 2,000 completed receipts at
**206 μs (0.206 ms)** and zero receipt metadata reads. The prior review measured
400.600 ms for its old full scan. This is desktop evidence from one run, not a
phone frame-time guarantee or a NAS capacity measurement.

## Desktop evidence

The [cursor page](evidence/code-review-repairs-2026-10-03/scores-cursor-1280x720.png)
shows fictional ranks above 10,000 with Next/Previous; the
[score error view](evidence/code-review-repairs-2026-10-03/scores-retry-1280x720.png)
shows Retry alongside Around me. The
[history page](evidence/code-review-repairs-2026-10-03/uploads-history-page-1280x720.png)
shows pagination without loading all receipt metadata into the UI. The
[delete confirmation](evidence/code-review-repairs-2026-10-03/delete-draft-1280x720.png)
explains the archive intent and preservation of shared versions.

## Rollout and remaining acceptance

New databases and disposable upgrade tests reach **`0010_archive_drafts`**. Existing
installations need that migration plus matching API/worker/client artifacts for
the new archive/head endpoints and complete heartbeat build contract. An older
worker heartbeat intentionally cannot make new competition health report ready.
Deployment/source alignment must be checked in the environment receiving the
rollout; this task performed no service replacement or production migration.

Legacy completed receipts remain permanent deduplication records. Their initial
recovery scan and on-demand history filename enumeration still scale with total
history, but run on a worker thread; ordinary polls inspect only active markers.
The pending index is reconstructed after restart. No history/player file is
discarded to achieve the performance result.

Retention cursors are best-effort directory traversal positions, not immutable
snapshots. Resuming a shard skips its earlier names; it bounds stat/database work,
but name traversal can grow with a very large shard. Keep writers stopped for an
apply sequence and start another cycle from no cursor after a directory-changing
cleanup to catch reordered/new candidates. An exact deferred-object count would
require another full traversal; the API reports a deferred flag instead.

Private archive is permanent for the authoring ID; subsequent authoring uses a
new ID. Public immutable data remains retained. Storage corruption/permission
failures preserve recovery files and require repair; if outgoing autosave fails,
its account-scoped in-memory copy cannot survive process termination. The
sign-out fence prevents credential restoration when it can be written, and a
storage failure is reported rather than claiming successful durable removal.

Remaining manual acceptance: PostgreSQL migration/locking/concurrent admission
and archive races on an available disposable server; real Google and weak-network
sign-out/refresh/restart; phone navigation/standings/history/delete UX and frame
time; NAS capacity/retention/backup restore; human publication/deletion acceptance.
**No phone driving, Android export/install, NAS load/restore, production rollout
or full game `Validate` was performed by this task.** Canonical physics was not
changed; the real verifier and relevant game regressions passed. No mixed-tree
commit was created.
