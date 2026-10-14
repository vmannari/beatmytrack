# Backend communication H1–H4 fixes — 2026-10-13

Owner explicitly requests the four high-priority findings from the communication review. Requirement IDs H1/H2/H3/H4, B01/B05/B07, R01, Q01. This slice fixes shared-profile recovery ownership, publication admission, pre-authentication abuse gating and proxy client identity. No canonical simulation, scoring, trajectory acceptance, lap rules, cosmetics, economy or provider integration changes are included.

## H1: durable ownership and serialized recovery

`game/backend/resume_recovery.gd` claims an active race with an atomic lease directory containing process ID, process nonce and instance nonce. A peer cannot overwrite a live claim or remove another instance's claim. Unreadable/incomplete ownership fails closed. Dead owners are retired into nonempty nonce-bound tombstones, so stale observers cannot move a newly acquired lease. Explicit leave and adapter teardown release only that adapter's claims. Failed ownership storage prevents journal admission before a charge.

A shared per-profile recovery lock covers request reservation, delivery and final retry state. After taking the lock, the adapter rechecks account/origin and rereads the persisted retry revision. Already-running peers therefore observe changed cooldowns; a waiting peer cannot duplicate an in-flight operation after its short reservation expires. Failed wait persistence prevents sending. The existing bounded scan, integer validation, active confirmation, original keys and authoritative resolution remain. Recent hitch callback counters are retained.

The real-process regression launches two pinned headless Godot child roles with mocked API responses. A live owner's pending operation cannot be abandoned; killing only the task-owned child permits exact recovery. A second process waits across an in-flight delivery, then observes its owner's 60-second failure cooldown without sending another request. Corrupt leases and refused storage preserve evidence.

## H2: publication upload boundary and terminal size failures

`backend/bmt_backend/middleware.py` gives `/v1/publications` the existing global 8 MiB upload allowance and the same concurrency semaphore as run uploads. Both compressed wire and decompressed JSON remain bounded; slots cover validation, endpoint and response lifetime.

`game/backend/backend_client.gd` reports local encoding overflow as HTTP 413 before constructing a network request. `track_lifecycle.gd` treats server/local size failures as terminal automatic-publication failures while retaining the draft, proof and operation key. `cloud_tracks.gd` likewise preserves an oversized result as a stopped upload rather than retrying forever. No global body-size increase or lossy evidence trimming is introduced.

## H3: pre-authentication admission without caching permission

The backend adds a separate bounded cold-credential admission budget (`pre_auth_limit_per_minute`, default 600) and checks the existing edge ceiling before database authentication. A 60-second bounded hint cache remembers only that a credential was previously validated; it grants a larger NAT admission ceiling, never authenticated access. Every valid authenticated request still performs expiry, revocation, disabled/development identity and per-player checks. Exhausted peer budgets and peer-scoped invalid-credential rate denials stop repeated requests without further authentication SQL. The next minute window admits requests again.

The first implementation incorrectly put unknown valid credentials behind an already-exhausted anonymous quota. The existing `test_garbage_header_cannot_bypass_public_budget_but_valid_users_have_independent_budgets` caught this (191 passed, one failed in the initial broad run). The implementation was corrected with the independent cold-credential gate; the original assertion is unchanged. Valid cold users and distinct clients remain independent, and garbage headers cannot obtain authenticated budgets.

## H4: explicitly trusted proxy chain

`backend/bmt_backend/client_address.py` resolves client addresses only when the socket peer belongs to the configured allowlist. It walks the bounded forwarded chain from right to left and stops at the first untrusted hop, ignoring caller-supplied prefixes. Untrusted peers cannot select their rate identity through headers. Malformed, excessive or non-ASCII headers fall back to the socket peer. IPv4, IPv6 and IPv4-mapped IPv6 are covered. Wildcards and network lists covering the whole internet are rejected.

`trusted_proxy_networks` / `BMT_TRUSTED_PROXY_NETWORKS` defaults empty in the application. Docker's no-proxy-header behavior remains. Compose uses the same application resolver and preserves the existing `BMT_TRUSTED_PROXY_IPS` setting as a fallback. The Cloud Run template prepares explicit loopback/link-local frontend ranges; its configuration can pin additional actual load-balancer hops. The actual deployed peer chain must be checked during an authorized rollout, especially behind an external load balancer. No wildcard Uvicorn trust is enabled.

## Changed files and review checkpoint

Runtime: `game/backend/resume_recovery.gd`, `backend_client.gd`, `cloud_tracks.gd`, `track_lifecycle.gd`; `backend/bmt_backend/middleware.py`, `config.py`, new `client_address.py`.

Deployment preparation/docs: `backend/deploy/compose.yaml`, `backend/deploy/gcp/staging.py`, `backend/deploy/README.md`; this report, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`.

Regressions: new `game/tests/test_shared_resume_recovery.gd`, expanded `game/tests/test_resume_recovery_budget.gd`; new `backend/tests/test_communication_boundary.py`, new `scripts/test_communication_postgres.py`.

The workspace contains substantial unrelated changes. A task-start source baseline was saved before edits; the [task-only patch](evidence/communication-h1-h4-2026-10-13/task-only.patch) is the review checkpoint and excludes prior work. No broad staging or merge is implied.

## Actual validation

Pinned build: 4.7.2.stable.official.ed1daf0bf from `godot-version.txt`, launched through `scripts/dev.ps1`. Native tests use a task test profile (`APPDATA=build/communication-h1-h4-user`) and fictional/mocked API identities.

`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/<file>`:

| File | Actual final outcome |
| --- | --- |
| `test_shared_resume_recovery.gd` | 21 checks, zero failures; two actual task-owned child-process scenarios |
| `test_resume_recovery_budget.gd` | 253 checks, zero failures; includes terminal server/local size handling |
| `test_backend_exception_recovery.gd` | 28 checks, zero failures |
| `test_local_draft_publication.gd` | 31 checks, zero failures; actual local creator trajectory retained |
| `test_session_rotation.gd` | 17 checks, zero failures |
| `test_mission_outbox.gd` | 11 checks, zero failures |
| `test_refreshed_ticket_priority.gd` | 26 checks, zero failures |
| `test_rewind.gd` | 61 checks, zero failures |
| `test_race_hitch_monitor.gd` | 36 checks, zero failures; observer behavior only, not a performance claim |

Total 484 native checks. The initial refused-storage test emitted an engine directory error, which the dev runner correctly treated as a failure. The adapter now detects a blocking ancestor file before mkdir; the ownership/refusal assertions remain and the final shared-process test passes.

`.tools/backend-venv/Scripts/python.exe scripts/test_communication_postgres.py`: final broad matrix **192 passed, six expected platform/concurrency skips**, using SQLite and a newly created, ownership-labelled PostgreSQL 17 container. This covers actual Godot wire, recovery/refunds/idempotency, authentication, publication, scalability, and Cloud Run plan/update tests. The owned database was removed after verifying its label. [Actual backend output](evidence/communication-h1-h4-2026-10-13/backend-regression.log).

`python -m pytest backend/tests/test_communication_boundary.py -k 'not postgres' -q --tb=short --show-capture=no`: final **26 passed, two PostgreSQL cases deselected**, including two additional peer-denial/budget-window checks added after the broad run began. Earlier auth/plan/boundary runs passed 65 and 94 checks; overlap is not added to the final total. New tests cover identity/gzip publications above 32 KiB, global overflow, held upload slots, fresh invalid credentials after exhausted admission, disabled users despite warm hints, proxy-isolated auth quotas, spoofed chains and unsafe configuration rejection.

Ruff on changed Python sources/tests/helper and `git diff --check` pass. Actual Docker Compose JSON rendering with an explicit fictional environment file passes and preserves a configured legacy proxy address. An initial renderer attempt supplied Windows environment variables to the WSL Docker command; they were not forwarded, so interpolation correctly rejected missing `GODOT_SHA256`. The explicit env-file rerun passes without starting services.

## Remaining acceptance

Final Doctor succeeds and reports an attached DN2103 Android phone. No device race, Android export/install, live backend write, deployment, full Validate or physics merge was performed. No visual layout changed; new UI captures are not applicable.

Restart all same-profile game instances together to load H1 and participate in the new ownership protocol; older processes do not write leases. Existing operation records are preserved. H2–H4 require deployment of the updated backend/configuration, separately authorized by the owner. During rollout, verify the actual proxy chain, independent clients and supplied spoofed prefixes before promotion. Local proxy tests and prepared configuration are not a claim that the currently deployed service has changed.
