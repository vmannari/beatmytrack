# Backend exceptions and recovery review — 2026-10-05

Requirements: B01–B07, B19–B20, B23, WR03–WR08, RW05–RW07 and Q01. Reviewed the current implementation, including the scalability repairs. Production is a future cloud environment with load-balanced APIs and independently scaled verification workers. Local development capacity is not a production player limit.

This is an analysis/probe slice: no runtime fixes, schema changes, service restarts, deployment, credentials or real player-data changes. The probes use isolated SQLite, fake identities/HTTP responses and workspace-only client files. Existing concurrent work is preserved.

Integrity checks are stronger than recovery paths. Invalid timing/physics does not become a verified PB; interruptions can still lose a locally unsaved attempt, strand uploads, exhaust retries or force reauthentication. The review found three P1 and nine P2 items.

## Findings

### 1. P1 — leaving Results can discard a failed asynchronous save

Replay hashing/writing may still run when Home, Tracks or the next race frees/replaces the completed game. In [app.gd:2236](../game/core/app.gd#L2236), game validity is checked before handling `queued == false`. If storage is full/unwritable or a thread cannot start, the coroutine returns without a durable job or retry dialog. A shared `_result_save_busy` latch also permits only one App save, instead of retaining independent completed attempts.

This is a recovery gap in the recent asynchronous Results change. Normal Results must still appear immediately. The Retry action has an additional ticket guard; Home/Tracks/next-race navigation do not provide that guard.

**Confirmed native observation:** a delayed save returned false after its game was freed; one save attempt, zero recovery dialogs, no saved job, busy flag released.

**Current recovery:** if the completed game remains alive, free storage and use Retry saving. After leaving in this failure case, online-upload recovery is absent; a local timing record does not reconstruct all canonical inputs.

**Required repair:** transfer immutable completed inputs/ticket into a save service that owns them independently of screens, retain failures for recovery and track saves per attempt.

### 2. P1 — a rolling API upgrade can permanently reject a valid recording

Bootstrap from a new replica advertises packed inputs/gzip. A subsequent request routed to an older replica can reject the envelope. Capabilities are cached per origin in [backend_client.gd:308](../game/backend/backend_client.gd#L308); unsupported transport does not renegotiate. [cloud_tracks.gd:683](../game/backend/cloud_tracks.gd#L683) makes a 422 terminal and removes its pending marker.

**Confirmed native observation:** a packed recording reached a simulated older decoder; the job became `Unsupported replay envelope` and a second flush sent nothing. Uniform older-server fallback was tested previously; this fixture models a mixed-fleet deployment possibility, not an existing cloud deployment.

**Current recovery:** the recording remains on disk until dismissal, but a rejected initial upload without a Run ID has no ordinary Retry action. Server rollout completion alone does not requeue it.

**Required repair:** a fleet-common capability floor, versioned routing or a coordinated switch after old targets drain; definitive transport rejections should renegotiate losslessly while preserving the original key and canonical controls/launch/receipts. Physics/rules incompatibility must continue to fail closed.

### 3. P1 — incompatible workers can claim and exhaust legitimate jobs

[worker.py:55](../backend/bmt_backend/worker.py#L55) claims eligible jobs without filtering their pinned build against the worker's actual capabilities. Heartbeat manifests do not gate claiming; result compatibility is checked after expensive verification. Competition health can report readiness when any worker matches, while another incompatible worker still claims work.

**Confirmed probe:** an old-physics worker claimed a valid newer-contract job three times and exhausted it as `failed/verifier_unavailable`. No PB was published. The fixture explicitly advanced backoff rather than waiting.

**Current recovery:** restore compatible workers, then use Uploads → Retry for a retained failed Run. This keeps the same Run/ticket/replay. Unsupported historical contracts return `CONTRACT_UNSUPPORTED` and must not be silently rescored.

**Required repair:** compatible job routing/claim filters or coordinated queue-cohort draining. Incapable workers should not spend an attempt budget. Weekly groups need a deployment policy preserving their pinned rules.

### 4. P2 — malformed success responses abort upload processing

[cloud_tracks.gd:689](../game/backend/cloud_tracks.gd#L689) assumes every successful submission has `run_id`; other paths assume `status` and endpoint-specific dictionary fields. The HTTP adapter validates JSON dictionary shape, not complete success contracts.

**Confirmed fault:** HTTP 202 with `{}` causes a real GDScript `Invalid access ... run_id` error. The unchanged fail-fast development runner exits 1. The aborted source path has no guaranteed cleanup of the flush latch.

**Current recovery:** correct the server/proxy response contract and restart the client to clear process-local latches; the saved recording is preserved. Repeated malformed responses reproduce the fault.

**Required repair:** endpoint-specific field/type validation, bounded retryable protocol errors and latch cleanup on every path.

### 5. P2 — refresh outages can force sign-out

[backend_client.gd:45](../game/backend/backend_client.gd#L45) only retries refresh on proven non-delivery, explicit rate limiting and `REQUEST_VALIDATION_BUSY`. DB-unavailable 503, proxy 502/504, ambiguous timeout or a lost successful refresh response can clear the session. Server rotation is single-use; reusing a consumed token revokes its family in [auth.py:237](../backend/bmt_backend/auth.py#L237).

**Confirmed native observation:** expired access followed by refresh `503/DATABASE_UNAVAILABLE` signs the client out. This is security-conservative: an ambiguous request might have committed token rotation.

**Current recovery:** restore service and sign in again to the same account. Its scoped outbox can continue; do not blindly resend a possibly consumed refresh token.

**Required repair:** clearer reauthentication/recovery UI and a narrowly scoped secure recovery protocol for ambiguous refresh delivery. Preserve reuse detection; do not allow unrestricted token reuse or store plaintext credentials in generic retry records.

Account error text currently tells users to start the PC backend for some network failures. Production recovery messages must instead explain reconnect, service retry, sign-in or local-play choices; developer setup instructions should stay in development flows.

### 6. P2 — an uncertain resume is not durable across leaving/restart

Server consumption and its receipt are atomic/idempotent. Client pending state is only in `ResumeCredits.pending` and `begin()` clears it. There is no durable reconciliation route for an abandoned uncertain operation.

**Confirmed probes:** an ignored successful consume response had already spent the free allowance and created exactly one receipt. Same-key retry recovered it without another spend. Native pending state survived the transport error but disappeared at a new race.

The UI already locks the selected point and offers Retry or Leave race, explaining that the resource may be spent. [game.gd:863](../game/core/game.gd#L863) prevents continuing that uncertain race. Omitting an authorized event fails receipt validation. No double-spend or hidden continuation was demonstrated.

**Current recovery:** stay in the paused race, reconnect and retry the unchanged selection/key. Leaving can forfeit the resource; a restart/new race loses the pending operation identity.

**Required repair:** durable pending-operation tracking and an explicit reconciliation/abandonment policy for banked/daily resources, preserving exact receipts and the three-resume limit.

### 7. P2 — missing accepted Runs can be polled indefinitely

A DB snapshot restore may retain a ticket but precede its accepted Run. [cloud_tracks.gd:697](../game/backend/cloud_tracks.gd#L697) retries status 404 every 15 seconds, without reconciling its saved ticket/key/replay or displaying a terminal recovery state.

**Confirmed probes:** the client only polled its missing Run; after a consistent isolated rollback of Run plus its submission retry record, the original submission could be accepted again while the ticket remained valid.

**Current recovery:** no automatic client resubmission in this case. An operator/client recovery tool can reconcile the original submission if ticket, receipts and original key are still valid. Once expired, show an explicit unverified outcome and start a new race. Ordinary process restart preserves data and is distinct from snapshot restore/data loss.

**Required repair:** missing-Run reconciliation and explicit expired/restore outcomes; never mint a replacement credit or change the recording/key blindly.

### 8. P2 — restart/outage recovery can wait four minutes and become manual

Default leases are 240 seconds and infrastructure work has three attempts. A failed finalization/heartbeat after claim leaves the job fenced, but the computed result may be discarded until lease reclamation. Exhausted failures retain evidence and pause automatic client work.

The CLI loop survives exceptions, but has no explicit SIGTERM/drain handler to stop claiming, finish current work and close its engine. A Compose grace period alone does not implement worker draining.

**Current recovery:** restore DB/storage/compatible worker access; wait for the lease to expire and automatic reclamation. If exhausted, use Uploads → Retry. Existing crash, stale-lease and finalization fault tests passed; real cloud shutdown/failover timing was not measured.

**Required repair:** graceful scale-in, outage-aware retry accounting, bounded retry of a computed fenced result where possible and clear recovery messaging. Keep lease fences/hard queue bounds.

### 9. P2 — a fake Authorization header increases public traffic allowance

[middleware.py:193](../backend/bmt_backend/middleware.py#L193) selects the generous edge budget whenever the header exists. Public bootstrap/discovery do not validate it with `current_player`. Protected endpoints remain secure.

**Confirmed probe:** with public allowance 2 and edge allowance 100, anonymous bootstrap returned 200/200/429; three requests with garbage Authorization returned 200/200/200. `/me` still returned 401. Defaults are 600 versus 12,000 requests/minute.

**Current recovery:** operational edge throttling can contain a burst; invalid credentials grant no protected API access. Existing app rate classification still grants the larger public allowance.

**Required repair:** classify public reads independently or validate identity before granting a separate budget. Preserve legitimate NAT behavior and configure only trusted cloud proxies.

### 10. P2 — wrong phone clocks reject fresh operations

Timestamped keys use the phone wall clock at [backend_client.gd:209](../game/backend/backend_client.gd#L209). Server expiry/future checks are correct for retry retention, but new keys do not use server-adjusted time. Retry scheduling also uses wall time.

**Confirmed API probe:** two days ahead gives 422; 91 days behind gives 410. Tickets, saves and resource writes can be blocked.

**Current recovery:** correct the device clock before creating new operations. Fresh ticket attempts can then generate valid new keys. Persisted clock-invalid upload keys need an explicit recovery flow that the current ordinary UI does not fully provide. Do not replace keys for uncertain accepted requests or bypass expiry.

**Required repair:** bounded server-time offset for new keys and monotonic in-process retry waits, preserving original durable identities.

### 11. P2 — internal ValueError can be labeled invalid client replay

[worker.py:129](../backend/bmt_backend/worker.py#L129) treats all ValueErrors during storage/verifier/ghost work as terminal `invalid_replay`. Standard checksum/gzip failures correctly raise OSError and retry. A malformed server-side digest raises ValueError before canonical verification.

**Confirmed probe:** corrupting a legitimate queued Run's stored digest produced `rejected/invalid_replay`, `retryable=false`. No PB was published, but an infrastructure/data failure was blamed on the recording.

**Current recovery:** an operator must repair/restore trusted metadata/evidence; the ordinary rejected-Run retry route refuses it. An actually invalid replay requires a new valid race.

**Required repair:** catch explicit canonical `VerificationError` for invalid submissions and classify storage/metadata/adapter faults separately.

### 12. P2 — recovery observability is incomplete

Workers emit `verification_seconds`, but [observability.py:19](../backend/bmt_backend/observability.py#L19) drops it from structured logs. It remains in the latest heartbeat details, but competition health does not expose duration distributions. A formatter probe confirmed the loss.

API readiness checks schema/object IO, while separate competition health checks worker builds/age. API readiness can be healthy during verifier outage. No cloud alert/autoscaling integration is deployed.

**Current recovery:** inspect separate competition health, queue/failure counts, worker heartbeat details, structured exception types and backup markers. Healthy API routing alone does not prove verification works.

**Required repair:** compatible capacity, service-time distribution, lease/retry exhaustion, pending age and phase-specific metrics, plus synthetic verification alerts. Keep secrets and submitted bodies out of logs.

## Exception and recovery matrix

| Exception | Automatic behavior | Player/operator recovery | Preserved data / limit |
| --- | --- | --- | --- |
| Connection lost while driving | Canonical racing stays local. | Reconnect; ordinary local racing remains available. | Online resumes need server authority; a first submission still needs a valid ticket. |
| Submission accepted, response lost | Retry original durable key/content returns the same Run. | Let outbox retry; sign into the same account if necessary. | Confirmed across recreated API; no duplicate Run. |
| API restart or replica replacement | Durable DB sessions/jobs/receipts remain; interrupted requests retry. | Restore healthy routing; keep origin/account configuration stable. | Instance-private caches are dispensable; shared DB/object store is required. |
| DB unavailable / transaction failure | Bounded API 503, transaction rollback, surviving worker loop. | Restore DB connectivity/pool/failover, then allow retries; expired access may require sign-in. | Unknown commit outcome must be reconciled with original key, not a fresh write. |
| Storage missing/corrupt/unreachable | Normal checksum/gzip failures fail closed as infrastructure errors. | Restore provider permissions/network/evidence from a coherent backup, then retry. | Do not fabricate missing proof or delete pending recordings. |
| Worker crash / stale lease | Lease reclamation and token fencing prevent stale finalization. | Wait for lease or retry an exhausted infrastructure failure after repair. | Original ticket/replay remains; default delay can approach four minutes. |
| Invalid controls/time/checkpoints/receipts | Reject malformed proof; no PB/publication. | Update/repair the client and complete a new valid race. | Do not retry an invalid proof indefinitely or call every rejection cheating. |
| Version/vehicle/config mismatch | Exact pinned contract blocks acceptance. | Install compatible client/backend cohort; retained infrastructure failures may retry with the original contract. | Historical standings remain unchanged; mixed-fleet recovery gaps above. |
| Unknown resume spend | Same-key retry recovers the original receipt. | Retry the unchanged selection while paused; Leave may forfeit the spent resource. | Current pending state is not durable across leaving/restart. |
| Expired ticket/week | First late submission is rejected. | Display unverified/expired outcome and race again. | Two-hour ordinary tickets; rivalry also ends at week boundary. Prior accepted same-key responses can still recover. |
| Duplicate write / conflict | Same operation recovers; changed content with the same key returns 409. | Retry original identity or use the explicit draft conflict flow. | Grants/receipts are idempotent; immutable revisions are not overwritten. |
| Token revoked / disabled account | Reject sessions, clear local identity and scope fences. | Reauthenticate if allowed; owner/moderation decision for disabled accounts. | Account-specific outbox remains; another account must not adopt it. |
| Optional ghost/catalog failure | Missing ghost does not delay race start; bounded scoped caches remain. | Retry presentation/download when online; use local tracks. | Ghost poses are never timing proof; required uncached cloud track data must finish downloading. |
| Phone storage full / corrupt pending files | Atomic writes fail; corrupt files are preserved for recovery. | Free storage, stay on failed Results and Retry saving; recover backed-up files rather than deleting them. | Leaving during failed async save is P1; process-killed unsaved/in-progress racing is not persisted. |
| Snapshot restore / pending status 404 | Current client keeps polling. | Reconcile original ticket/key/recording if valid; otherwise explain the restore/expiry outcome. | No current automatic missing-Run resubmission; backup recovery-point losses must be stated. |
| Malformed backend success | Current outbox can abort. | Repair response contract, restart client; replay remains on disk. | P2: validate endpoint responses and release latches before relying on retry. |

## Cheating scope and robust boundaries

The API accepts only bounded quantized input recordings, rather than client-reported times/state. Canonical simulation computes completion/time, with exact ticket/account/version and rewind receipt binding. Invalid attempts do not produce PBs or creator publication proof. Resource balance/fulfillment is server-owned; duplicate receipts/grants do not mint another resource.

Verification proves a legal deterministic result, not human input provenance. A bot can generate/reuse legally valid recordings under this model. Public ghost poses are not trusted proof. Artificial test identities are isolated, which is distinct from detecting automation by a normal account. Production ad/store fulfillment remains unconfigured; the owner-authorized temporary ad_preview path does not claim an ad was watched or mint banked rewards.

Shaped-but-invalid long recordings or expensive authored geometry can still consume verification CPU before rejection. Per-player pending limits, shared admission limits, maximum frames/bytes, engine deadline and process/container limits bound the work; they do not eliminate abuse by many accounts. Production acceptance should measure repeated expensive invalid inputs and complex UGC, cost-aware fairness/cooldowns and legitimate-user queue delay. Those adversarial resource costs were not measured in this review.

Ownership, disabled-account checks, cancellation and account/origin fences protect private data/cache adoption. Immutable creator versions, conflict snapshots and original retry keys are retained. These were reviewed and covered by the relevant regression batch; this is not a claim that every possible cheating strategy was tested.

## Cloud recovery acceptance

Operator recovery should proceed in this order:

1. Identify the failed dependency/build cohort using API readiness, separate competition health, queue age and storage/DB status. Preserve authoritative volumes, pending recordings and operation identities. Do not reset the DB/queue or delete retries to clear an alarm.
2. Restore the original shared authority, or a deliberately selected consistent DB/object recovery point. Existing pools pre-ping and reconnect; a simple connection outage does not require restoring a backup. A snapshot restore can lose runs, receipts and wallet writes within its recovery-point window.
3. Ensure API/worker/schema/contracts agree and incompatible workers stop claiming. Verify readiness and a synthetic or authorized private end-to-end completion before relying on throughput/health claims.
4. Let fenced leases and original-key retries reconcile pending work. Retry exhausted infrastructure Runs only after the dependency/build is repaired. Reauthentication must retain the same player/outbox scope.
5. Inspect unresolved/expired/missing operations explicitly, including uncertain resource spends. Check queue drain, unique PB/outcome/receipt writes and resource balances. Do not blindly replay lost fulfillment/credit writes after restore or claim lost evidence was verified.
6. Reopen/scale normal traffic with gradual warm capacity, bounded retry jitter and monitoring. Perform an actual restore rehearsal and rolling-cohort test; a backup completion marker or a healthy HTTP endpoint alone is insufficient.

Deployment must share DB/object authority across replicas, configure trusted proxy IPs, coordinate migrations/build contracts and retain compatible capacity while draining. More API replicas cannot repair a failed shared dependency or incompatible worker fleet.

Failure retries currently use largely fixed 15-second upload/five-second rivalry delays; success polling has jitter. A common outage can synchronize retries. Add bounded exponential backoff/jitter, preserve operation identities, respect Retry-After and expose definitive failures instead of unlimited retries.

Required target tests: disconnects at each commit/response boundary; TLS/DNS/proxy 502/504; routing across protocol/build cohorts; SIGTERM during every worker phase; actual PostgreSQL restart/failover/unknown commits; provider permissions/timeouts/corruption; migration failure/rollback; phone process kill/full storage/backgrounding; reauthentication during pending uploads/resumes; reconnect storms; coherent backup/restore with traffic.

No cloud, real Google, external object-provider, physical-phone or NAS test was performed here. Phone attachment was not re-enumerated. No full physics validation/export was performed; canonical rules are unchanged.

## Actual verification and changed files

- Relevant existing auth/replay/receipt/lease/storage/recovery tests: **117 passed, 3 skipped, 126 deselected**. The three skips require PostgreSQL cross-connection/row-lock acceptance; PostgreSQL and selected canonical-engine cases were explicitly excluded.
- API/worker observations: **9 passed, 6 PostgreSQL parametrizations deselected**. Probes assert current behavior, including gaps; passing does not mean those gaps are repaired.
- Five native client scenarios were recorded with default diagnostic exit 0. A separate malformed-success injection produced the real GDScript error and **exit 1** through the unchanged fail-fast runner; it is not reported as passed.
- Pinned Godot `4.7.2.stable.official.ed1daf0bf`. Python probe Ruff passes. Initial helper unpacking and diagnostic ordering were corrected without changing production assertions.

Changed files: this report; evidence/probe files; `game/tests/review_backend_exceptions.gd`; new status/phase review notes. No production runtime fix was applied. Source hashes, exact commands, saved results and scoped checkpoint: [evidence/backend-exception-review-2026-10-05](evidence/backend-exception-review-2026-10-05/README.md).
