"""Generate the documentation-only backend improvement backlog and validate its DAG."""
import csv
import difflib
import hashlib
import json
import subprocess
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
DOC = ROOT / "docs/BACKEND_EXCELLENCE_BACKLOG_2026_10_26.md"
AUDIT = ROOT / "docs/BACKEND_COMPREHENSIVE_AUDIT_2026_10_26.md"
TASKS = []


def task(identity, area, title, priority, effort, owner, dependencies, sources, change, acceptance, findings=""):
    TASKS.append(dict(id=identity, area=area, title=title, priority=priority, effort=effort,
        owner=owner, dependencies=dependencies.split() if dependencies else [], sources=sources.split(),
        change=change, acceptance=acceptance, audit_findings=findings.split(), status="Planned"))


task("FND-01", "Foundation", "Freeze an auditable release baseline", "P1", "S", "Backend + release owner", "",
    "backend/bmt_backend/migrate.py backend/deploy/gcp/update.py backend/deploy/stage_verifier.py game/core/build_identity.gd",
    "Inventory the current working source, effective routes, migration head, workload grants, client capabilities, verifier/content contracts and deployed image digests. Produce one versioned release manifest; distinguish website-only image differences from protocol differences.",
    "Manifest identifies every participating artifact and its hash, the exact supported old cohorts and all undeployed changes. No finding is marked fixed merely because the source exists. Refresh the audit snapshot without overwriting unrelated work.", "AUD-F08")
task("FND-02", "Foundation", "Approve measurable service, cost and integrity objectives", "P1", "S", "Owner + backend/SRE lead", "FND-01",
    "docs/BACKEND_COMPREHENSIVE_AUDIT_2026_10_26.md backend/load_budgets.json backend/bmt_backend/config.py",
    "Record approved load/retention/cost envelopes, user-visible SLOs, availability/RPO/RTO, competition verification policy and purchase/refund semantics. Adopt or amend the proposed gates below explicitly; retain unlimited ordinary racing and server-owned rewards.",
    "Each target has an owner, measurement boundary and pass/fail rule. Lightweight verification risk and clean-race trust have an explicit commercial decision. An unresolved material gate or known exploitable authority weakness prevents the affected area receiving 10/10. Budget agreement does not authorize spending or deployment.", "AUD-F01 AUD-F02 AUD-F06 AUD-F07")
task("FND-03", "Foundation", "Repair the load generator to use today's real client protocol", "P1", "S", "Backend + performance engineer", "FND-01",
    "backend/bmt_backend/loadtest.py backend/bmt_backend/load_fixtures.py backend/bmt_backend/replay_wire.py backend/LOAD_TESTING.md",
    "Generate a valid current trajectory envelope and preserve its proof through actual packing/upload. Exercise discovery v3/daily, content reuse and completion paths. Label synthetic, trajectory and native diagnostic execution accurately.",
    "A contract test drives one generated request through real decoding, queue claim, real current verification and atomic result/reward publication. It completes five ordered laps with no synthetic verifier substitution and no native replay fallback. Historical rejected-body probe becomes a retained regression.", "AUD-F10")

task("CST-01", "Cost efficiency", "Measure the cost of complete player sessions", "P1", "M", "Backend + SRE/finance", "OBS-01 FND-02",
    "backend/bmt_backend/http_costs.py backend/bmt_backend/worker.py backend/bmt_backend/gcs_storage.py game/backend/backend_client.gd",
    "Measure new/returning sessions, menu browsing, ten-race sessions, selected ghosts, social actions and sparse publishing. Attribute wire bytes, cache misses, object calls, SQL CPU/WAL, retained bytes and worker occupancy by feature; include background amplification.",
    "Publish reproducible per-session/per-1,000-race inputs and P50/P95 player-day transfer, separating measurement from assumptions. Provider bytes and accounted usage reconcile within 10%, or every material residual has an identified cause. Measure real optional-event consent instead of assuming all players consent.", "AUD-F02 AUD-F11")
task("CST-02", "Cost efficiency", "Validate and release existing download reuse", "P1", "M", "Client + backend", "CST-01 TST-01",
    "game/backend/recording_cache.gd game/backend/recording_downloads.gd game/backend/preview_dictionary.gd game/backend/backend_client.gd backend/bmt_backend/ghost_http.py backend/bmt_backend/immutable_payloads.py",
    "Complete compatible rollout preparation for persistent exact-identity ghost reuse, bundled/hash track reuse, preview dictionaries and GET coalescing. Remove only measured duplicate fetches; preserve current access/withdrawal checks.",
    "The same unchanged authorized recording transfers its body once across repeated opens and app restarts; corruption, account/origin changes and source withdrawal recover safely. No speculative unused download regression. Representative measured calls/bytes meet the agreed envelope without reducing content or racing features.", "AUD-F02 AUD-F12")
task("CST-03", "Cost efficiency", "Bound retained history without weakening durable promises", "P1", "L", "Backend/database + privacy owner", "CST-01 REL-02 DB-04 COR-02",
    "backend/bmt_backend/cost_archives.py backend/bmt_backend/cost_maintenance.py backend/bmt_backend/packed_storage.py backend/bmt_backend/maintenance.py backend/bmt_backend/economy_models.py",
    "Calibrate and prepare explicit packing/archive/GC enablement. Define lifecycle for every large table/object class, including challenge/day/attempt milestones and protected references. Implement safe missing compaction or archival only after its exact retry/reward semantics are specified.",
    "On PostgreSQL, archival preserves exact answers and cannot mint rewards twice; current PB/creator/challenge/purchase references remain readable. Pending and packed bytes survive restore. Maintenance drain rate exceeds arrivals at certified load, storage growth matches declared permanent history, and total SQL+GCS+backup cost improves after WAL/compaction overhead.", "AUD-F02")
task("CST-04", "Cost efficiency", "Tune billing, logging and allocations from measured net cost", "P2", "M", "SRE + finance owner", "CST-02 CST-03 OBS-03 SCL-04",
    "backend/deploy/gcp/cost_profile.py backend/deploy/gcp/staging.py backend/bmt_backend/http_costs.py docs/evidence/backend-comprehensive-audit-2026-10-26/cost_model.py",
    "Compare request/instance billing, warm floors, worker allocations and application/provider log sampling using actual traffic shape. Produce reviewed provider changes and reconcile a full billing cycle; commitments/CDN/new regions remain optional business cases.",
    "Meet approved cost per DAU/MAU/session/1,000 races at each certified scale, including recovery, storage age, logs, egress and idle floors. Show a net bill improvement with SLOs unchanged and no missing required audit evidence. Any paid change and live application require separate authorization.", "AUD-F02 AUD-F03 AUD-F11")

task("SCL-01", "Scalability", "Profile every worker role and the full job service time", "P1", "M", "Backend + performance engineer", "OBS-01 FND-03 TST-01",
    "backend/bmt_backend/service_worker.py backend/bmt_backend/worker.py backend/bmt_backend/publication_worker.py backend/bmt_backend/discovery_worker.py backend/bmt_backend/product_worker.py backend/bmt_backend/world_ranking_worker.py",
    "Measure CPU, RSS, SQL wait, object wait, cold preparation and complete occupancy separately for each role. Separate artificial-driver demand from representative real-player demand without changing active owner workloads.",
    "Explain the audit's busy-worker observation with role evidence. Publish cold/warm service-time distributions and arrival/drain rates. No fleet sizing derives solely from the roughly millisecond checker kernel; include publication, telemetry, ranking and maintenance interference.", "AUD-F03")
task("SCL-02", "Scalability", "Redesign connection and queue budgets for the declared burst", "P1", "M", "Backend/database + SRE", "SCL-01 COR-02",
    "backend/bmt_backend/db.py backend/bmt_backend/queueing.py backend/bmt_backend/run_signals.py backend/bmt_backend/config.py backend/deploy/gcp/staging.py",
    "Budget all workload pools, notifications, operator reserve and full revision overlap. Size durable backlog from tolerated consumer outage. Replace finite-slot admission sampling where it creates false busy responses at larger capacities; retain exact bounded admission.",
    "Connection maximum is never exceeded in old/new overlap or degradation. At 90%, 99% and 100% queue occupancy, no false capacity report when a reservable slot is available, no over-admission, no stranded reservation and no lost acknowledged attempt. Backlog meets the approved outage window and drains within the agreed recovery SLO.", "AUD-F04")
task("SCL-03", "Scalability", "Scale acceptance independently of measured background contention", "P1", "L", "Backend + SRE", "SCL-01 SCL-02 ARC-03",
    "backend/bmt_backend/service_worker.py backend/bmt_backend/worker_lifecycle.py backend/deploy/gcp/staging.py backend/deploy/gcp/update.py",
    "Implement a bounded scaling policy based on oldest eligible work, arrival/drain rate and measured CPU/RSS. Reuse role entry points to separate only workloads proven to contend; include cooldown, hysteresis, caps and compatible-build awareness.",
    "A step increase raises useful capacity without multiplying every low-priority process. Idle demand returns to approved floors; a dead controller cannot create unbounded spend. Scaling, worker loss and draining preserve once-only effects and confirmation/freshness targets.", "AUD-F03 AUD-F04")
task("SCL-04", "Scalability", "Certify each population and arrival envelope", "P1", "L", "Performance engineer + SRE", "FND-03 SCL-03 DB-01 DB-02 TST-03 CST-02 LAT-03",
    "backend/bmt_backend/loadtest.py backend/LOAD_TESTING.md backend/load_budgets.json",
    "Run the controlled 1k/10k/100k/1m DAU ladder with production-shaped history and open-loop arrivals. Include concentrated tracks/boards, large ties, week rollover, cache misses, background settlement and a bounded 10x surge.",
    "For every claimed scale, offered load, drops, retries, endpoint/confirmation tails, lock/pool waits and recovery are recorded; all approved peak SLOs pass. Record the first failing rate and limiting resource. A larger seeded population alone is never a capacity pass. No uncontrolled production test or unapproved billable environment.", "AUD-F03 AUD-F04 AUD-F05 AUD-F10")

task("LAT-01", "Player responsiveness", "Trace the blocking path of every important journey", "P1", "M", "Client + backend/performance", "OBS-01 FND-03",
    "game/backend/account_controller.gd game/backend/cloud_tracks.gd game/backend/weekly_rivalry_client.gd game/backend/challenges_client.gd backend/bmt_backend/runs.py",
    "Capture startup/sign-in, menu, discovery/detail, race preparation, ghost, upload, reward/result, Rivalry, leaderboard, Garage/Store and friends. Mark mandatory authority calls, safe cached reads and background work; include cold and returning cases.",
    "Each journey has an explicit dependency diagram and measured client/server P50/P95/P99, including queue/transfer/decode/render. A report distinguishes deliberate waits, provider interaction and network RTT from server processing. No service-wide percentile is substituted for an endpoint percentile.", "AUD-F11 AUD-F12")
task("LAT-02", "Player responsiveness", "Remove measured optional work from navigation's critical path", "P2", "M", "Client + backend", "LAT-01 ARC-04 COR-04",
    "game/backend/weekly_rivalry_client.gd game/backend/appearance_sync.gd game/backend/account_controller.gd game/backend/menu_snapshot_cache.gd",
    "Decouple standings display from dirty appearance synchronization where authority allows. Render valid cached menus/results immediately; consolidate redundant bootstrap/profile/detail reads while retaining explicit capability refresh.",
    "Current/join no longer waits for unrelated cosmetic writes. Ordinary local menu navigation has no new online dependency. Cold, offline and account-switch flows never display another account's data; slow sync or failed reads cannot blank a usable cached view. Demonstrate the removed RTTs with paired traces.", "AUD-F12")
task("LAT-03", "Player responsiveness", "Make result completion one efficient reliable flow", "P1", "M", "Client + backend", "LAT-01 COR-02",
    "game/backend/cloud_tracks.gd game/backend/backend_client.gd backend/bmt_backend/completion_reads.py backend/bmt_backend/run_signals.py backend/bmt_backend/runs.py",
    "Use one coordinated outbox/upload/completion owner, compact batched reads, bounded waits and jittered retry/poll fallback. Remove duplicate consumers only after measuring them; preserve local results before verification.",
    "Local results appear immediately; complete ordinary confirmation meets P95 2s/P99 5s after durable upload ACK at certified peak. Lost notifications, app restart and lost replies recover the same outcome/reward. Waiting clients cannot exhaust ordinary HTTP or SQL capacity.", "AUD-F04 AUD-F12")
task("LAT-04", "Player responsiveness", "Validate cold, device and international tail latency", "P2", "L", "Client QA + SRE/performance", "LAT-02 LAT-03 SCL-04",
    "backend/load_budgets.json game/backend/network_health.gd game/backend/client_quality.gd backend/deploy/gcp/staging.py",
    "Measure target Android hardware and controlled Europe/North America/Asia network cohorts for new install, returning install, cold service, poor connection and cache miss. Tune existing warm/cache/prefetch settings; propose new geography/CDN only for a demonstrated gap.",
    "Meet the approved per-region journey targets with published sample counts, device/network conditions and P95/P99. No cache authorization regression or extra unused prefetch. Any topology change has measured latency benefit and a complete incremental cost/authority plan.", "AUD-F12")

task("DB-01", "Database efficiency", "Establish PostgreSQL query, trigger and physical-write budgets", "P1", "M", "Database/performance engineer", "FND-03 OBS-01 TST-01",
    "backend/bmt_backend/race_acceptance.py backend/bmt_backend/runs.py backend/bmt_backend/discovery_v3.py backend/bmt_backend/operations.py backend/bmt_backend/migrations/versions/0055_bounded_rank_reads.py",
    "Profile actual SQL plans and trigger work for each major operation with realistic data and production roles. Capture statement fingerprints, rows/buffers, CPU, WAL, lock waits, pool waits and table/index deltas; rank the dominant costs.",
    "Every critical operation has a reproducible PostgreSQL profile and a regression budget. No unbounded foreground scan, N+1 per returned row or hidden trigger cost remains unexplained. Separate the workload for first finish, improving PB, slower race, ties and account restriction.", "AUD-F05 AUD-F11")
task("DB-02", "Database efficiency", "Remove hot-board write contention while preserving exact authority", "P1", "L", "Database + backend", "DB-01 COR-01 COR-02",
    "backend/bmt_backend/migrations/versions/0013_scalability.py backend/bmt_backend/migrations/versions/0045_reward_rank_index.py backend/bmt_backend/migrations/versions/0055_bounded_rank_reads.py backend/bmt_backend/worker.py",
    "Optimize proven shared board/version counter, prefix/tie and invalidation contention. Prefer shorter transactions and coalesced derived work; introduce striped counters or eventual presentation only if measured and compatible with exact reward/rank semantics.",
    "Hot-board/tie tests meet foreground and confirmation SLOs at certified peak. PB/rank/reward outputs match the independent oracle through insert, improvement, restriction, deletion and correction. Lock waits and WAL improve against the same baseline, rather than merely moving cost to another table.", "AUD-F05")
task("DB-03", "Database efficiency", "Make growth, retention and indexes predictable", "P1", "M", "Database + backend", "DB-01 CST-01 FND-02",
    "backend/bmt_backend/maintenance.py backend/bmt_backend/cost_archives.py backend/bmt_backend/discovery_retention.py backend/bmt_backend/telemetry_processing.py backend/bmt_backend/economy_models.py",
    "Document every table's growth key, retention/protection, query indexes and cleanup owner. Repair missing lifecycle/index coverage; partition only where measured age-based maintenance or locality justifies it. Size vacuum/index-build headroom.",
    "At one-year modeled history, cleanup does not scan the whole history per request/batch, protected rows survive, dead tuples/index growth stay within declared bounds, and the storage projection reconciles with measured physical bytes. No blanket bucket age-delete rule covers mixed permanent/transient content.", "AUD-F02 AUD-F05")
task("DB-04", "Database efficiency", "Rehearse safe migrations and workload grants at real data sizes", "P1", "M", "Database + release engineer", "TST-01 ARC-04 DB-03",
    "backend/bmt_backend/migrate.py backend/bmt_backend/database_privileges.py backend/bmt_backend/migrations backend/deploy/gcp/update.py",
    "Rehearse supported old-head to target-head migrations, bounded backfills, concurrent indexes, interrupted retries and exact effective grants on invented representative data. Define the drain/overlap policy for each migration.",
    "One unambiguous head, no invalid indexes or widened effective runtime grants, exact required preexisting data, and measured migration lock/time/disk budgets. Downgrades never discard accepted packed/archive data; configuration rollback retains compatible readers. No production migration as part of the rehearsal.", "AUD-F08")

task("COR-01", "Correctness and consistency", "Specify authoritative state transitions and independent oracles", "P1", "M", "Backend/domain owner", "FND-01 ARC-01",
    "backend/bmt_backend/worker.py backend/bmt_backend/economy.py backend/bmt_backend/rivalry.py backend/bmt_backend/challenges.py backend/bmt_backend/commerce.py backend/bmt_backend/resumes.py",
    "Write explicit transition/invariant tables for tickets, results/PBs, challenge tries, weekly awards, coins/resumes, slots/gifts, purchases and deletion. Identify strong versus eventual effects and immutable idempotency identities; add independent SQL/balance/ranking oracles.",
    "For each operation, the durable acknowledgement boundary and duplicate/out-of-order behavior are explicit. Ordinary racing/base rewards stay unlimited; balances, attempts, competitive results and recipients are server-owned. No test oracle simply repeats the implementation's arithmetic.", "AUD-F01 AUD-F07")
task("COR-02", "Correctness and consistency", "Prove concurrent and retry correctness in PostgreSQL", "P1", "L", "Backend + test/database engineer", "COR-01 TST-01",
    "backend/tests/test_race_acceptance_sql.py backend/tests/test_slot_gifts.py backend/tests/test_rivalry_concurrency.py backend/tests/test_auth_postgres.py backend/tests/test_privacy_postgres.py",
    "Exercise independent transactions/processes for duplicate tickets/uploads, PBs/rewards, opposite gifts, attempts/resumes, account restriction/deletion and refresh rotation. Inject failures just before/after durable effects and replay changed/same request bodies.",
    "All independent oracles remain exact: no duplicate grant/consumption, lost accepted result, stale account resurrection or recipient change. Test retries after process death and lost response. No SQLite-only pass substitutes for row-lock/isolation proof; intended retries complete within bounded deadlines.", "AUD-F04 AUD-F05 AUD-F07")
task("COR-03", "Correctness and consistency", "Complete durable provider purchase settlement", "P1", "L", "Backend/commerce + platform engineer", "COR-01 COR-02 ARC-02",
    "backend/bmt_backend/studio_finance.py backend/bmt_backend/studio_providers.py backend/bmt_backend/provider_proofs.py backend/bmt_backend/commerce_models.py backend/bmt_backend/commerce.py",
    "Add a secure durable provider-completion outbox, claim/retry state, verified notifications and reconciliation/reversal policy. Make fulfilment and completion intent atomic; retain buyer/immutable recipient and exactly-once grant identities. Keep raw provider credentials outside logs.",
    "A client can disappear after fulfilment and acknowledgement/consumption still completes. The audit's two 503 responses recover with one grant. Pending, cancelled, refunded/revoked, duplicate/out-of-order notifications, token reuse and gifts all yield the agreed result. Provider outage does not hold wallet/database locks.", "AUD-F07")
task("COR-04", "Correctness and consistency", "Verify time boundaries and cache/account invalidation", "P1", "M", "Backend + client/test engineer", "COR-01 TST-01 ARC-04",
    "backend/bmt_backend/rivalry.py backend/bmt_backend/track_of_day.py backend/bmt_backend/world_ranking_build.py backend/bmt_backend/challenges.py game/backend/recording_downloads.gd game/backend/menu_snapshot_cache.gd",
    "Cover UTC week/day transitions, deadline/lease/receipt expiry, delayed arrivals, atomic ranking publication and current source/owner/block withdrawal. Preserve immutable historical contracts and old accepted outcomes.",
    "Before/at/after boundary cases, concurrent publication and skewed client clocks cannot double-award, reopen attempts, feature an invalid source or expose stale private data. Expired credentials cannot restore an older account state. Current reader sees a complete ranking generation.", "AUD-F08 AUD-F12")

task("REL-01", "Reliability and resilience", "Prepare and validate the agreed database recovery configuration", "P1", "M", "SRE/database owner", "FND-02 SCL-01",
    "backend/deploy/gcp/staging.py backend/deploy/gcp/update.py backend/bmt_backend/readiness.py backend/bmt_backend/config.py",
    "Prepare regional HA/PITR, backup retention, storage growth/caps and disk/backup alerts against approved RPO/RTO and budget. Define instance/zone, destructive-error and region-loss cases separately, including the fallback when service is unavailable.",
    "Reviewed configuration and an authorized isolated exercise demonstrate the agreed recovery objectives. A liveness probe stays independent of SQL; readiness fails boundedly for read-only/full/incompatible storage. Fixed disk exhaustion cannot silently destroy availability. No billable/configuration application without authorization.", "AUD-F06")
task("REL-02", "Reliability and resilience", "Enforce complete restore and privacy replay before reopening traffic", "P1", "L", "SRE + backend/privacy", "REL-01 DB-04 SEC-02",
    "backend/deploy/backup.sh backend/deploy/restore.sh backend/deploy/object_archive.py backend/bmt_backend/privacy.py backend/bmt_backend/erasure_journal.py backend/bmt_backend/cost_archives.py",
    "Make restore acceptance a mandatory gate for the matching image/schema, SQL, individual blobs, pending bytes, packs and archive keys. Replay the independent erasure ledger and verify protected references before API/worker startup.",
    "Restore into an isolated empty target from old and current accepted formats; all authoritative oracles and blob hashes pass. An account erased after backup stays inaccessible, including encrypted archives. Missing ledger/object/key or incomplete backup blocks reopening. Record actual restore time and recovered-point distance.", "AUD-F02 AUD-F06")
task("REL-03", "Reliability and resilience", "Exercise crash and dependency-failure boundaries", "P1", "L", "Backend + SRE/test engineer", "COR-02 REL-02",
    "backend/bmt_backend/worker_lifecycle.py backend/bmt_backend/publication_storage.py backend/bmt_backend/packed_storage.py backend/bmt_backend/worker.py backend/bmt_backend/run_signals.py",
    "Kill API, worker and packer before/after each acknowledgement and publication boundary; interrupt object upload, SQL commit/finalization, lease renewal and notifications. Include OOM, cancelled request and old-worker completion.",
    "Every acknowledged attempt is durable or has a recoverable terminal result; no duplicate economic effect or stale publish occurs. Leases and cleanup recover without manual data edits, queues drain within agreed bounds, and the remaining service stays within its declared degraded behavior.", "AUD-F03 AUD-F04 AUD-F06")
task("REL-04", "Reliability and resilience", "Run recovery drills and close every incident action", "P2", "M", "SRE/on-call owner", "REL-03 OBS-02",
    "backend/deploy/README.md backend/deploy/gcp/README.md backend/bmt_backend/operations.py backend/bmt_backend/studio_incidents.py",
    "Produce and exercise playbooks for failed submissions, stuck cohorts, full queues/disks, object outage, database failover, bad deployment, corrupt archive and lost worker role. Schedule repeat drills after storage/schema changes.",
    "A second operator resolves each selected incident using the playbook, without hidden credentials or destructive guesswork. Detection, escalation, containment, reconciliation and recovery times are captured; all material drill failures have an owner and verified resolution.", "AUD-F06 AUD-F11")

task("SEC-01", "Security", "Close known trajectory and clean-race trust gaps under an agreed policy", "P1", "L", "Backend/game security + owner", "FND-02 COR-01",
    "backend/bmt_backend/trajectory_verifier.py backend/bmt_backend/verifier.py backend/bmt_backend/economy.py game/backend/race_proof.gd",
    "Choose and implement independent checks appropriate to public competition and reward integrity. Retain the cheap trajectory pass, but prevent the known fabricated/nonphysical and incident-claim manipulations from earning authoritative outcomes. Compare selective/stronger validation options against measured cost and false positives.",
    "The retained synthetic nonphysical race and incident-tampering corpus no longer obtains an unjustified accepted score/clean bonus. Legitimate all-car/rewind/circuit corpora pass with a declared false-positive budget and cost/latency evidence. Attestation alone does not satisfy the proof gate; accepting these known exploits keeps Security below 10/10.", "AUD-F01")
task("SEC-02", "Security", "Finish authentication, deletion and least-privilege acceptance", "P1", "M", "Security + backend/SRE", "FND-01 TST-01",
    "backend/bmt_backend/auth.py backend/bmt_backend/security.py backend/bmt_backend/privacy.py backend/bmt_backend/database_privileges.py backend/bmt_backend/studio_identity.py game/backend/session_vault.gd",
    "Require a fresh identity challenge for irreversible deletion, bound to that account/action, with safe lost-reply recovery. Verify token rotation/revocation, named MFA staff, all effective workload grants and secret isolation; use the already implemented privilege checks.",
    "A normal stolen bearer alone cannot delete an account; stale/replayed step-up proof fails while the same committed deletion remains recoverable. API/worker/admin roles cannot read or mutate forbidden state through table/column/function/schema grants. Production has no development bypass or simulated paid entitlement path.", "AUD-F06 AUD-F08 AUD-F09")
task("SEC-03", "Security", "Validate the real edge and bound financial abuse", "P1", "M", "Security/SRE + backend", "OBS-01 SCL-02 TST-01",
    "backend/bmt_backend/client_address.py backend/bmt_backend/http_server.py backend/bmt_backend/middleware.py backend/bmt_backend/discovery_guard.py backend/deploy/gcp/staging.py",
    "Validate trusted-proxy identity and direct-service bypass, IPv6/64 and shared-NAT fairness, pre-header/body/decompression bounds, upload/storage quotas and distributed expensive reads. Prepare bounded aggregate exposure controls and cost alarms.",
    "Spoofed headers cannot choose quota identity; legitimate shared-network users retain the agreed service budget. Incomplete headers/bodies, oversized compressed data and many actors cannot exhaust all healthy slots or create unbounded retained bytes/jobs. Repeat source HTTP/grant repairs on the deployed candidate; no live attack without separate authorization.", "AUD-F04 AUD-F09")
task("SEC-04", "Security", "Enforce supply-chain and secret hygiene on every release", "P1", "M", "Security + release engineer", "FND-01 TST-01",
    "backend/requirements.lock backend/Dockerfile backend/deploy/lock_dependencies.py backend/deploy/GODOT_PROVENANCE.md scripts",
    "Generate an SBOM and provenance for pinned Python/OS/native/Godot/platform inputs; scan dependencies, container and release artifacts, not just source imports. Add scoped secret/history scanning, signed immutable release verification and a recurring patch/revocation process.",
    "Every deployed artifact is attributable to reviewed inputs and exact hashes. No exposed valid secret or unmitigated reachable critical/high vulnerability remains; exceptions have compensating controls, accountable owners and expiry. The custom Uvicorn/h11 boundary has upgrade regressions. Rotation/revocation is demonstrated without credential disclosure.", "AUD-F08 AUD-F09")

task("ARC-01", "Software architecture", "Document domain authority and trigger ownership", "P2", "S", "Backend/domain lead", "FND-01",
    "backend/bmt_backend/app.py backend/bmt_backend/race_acceptance.py backend/bmt_backend/migrations backend/bmt_backend/commerce.py backend/bmt_backend/privacy.py",
    "Produce a domain dependency map covering account authority, race acceptance, competition, progression, commerce, content, privacy and analytics. Assign every important table/trigger/write and external side effect to an owner and transaction boundary.",
    "A reviewer can follow each public operation to its atomic authority writes, asynchronous projections and cleanup without reverse-engineering triggers. No overlapping service owns the same balance/recipient/score truth. Keep the modular monolith; no speculative service/database split.", "AUD-F05 AUD-F07")
task("ARC-02", "Software architecture", "Separate player billing from the private Studio router", "P1", "M", "Backend/commerce", "ARC-01 COR-01",
    "backend/bmt_backend/app.py backend/bmt_backend/studio_finance.py backend/bmt_backend/commerce.py backend/bmt_backend/workloads.py",
    "Move account-binding/verification into a clearly owned player billing API and keep reports/admin controls private. Align caller authentication and database authority with each operation, and keep store enablement explicitly gated.",
    "Default production public routing exposes only intended player billing paths with player authorization; private Studio reports/monitor controls still return 404 there. Real production-role integration tests replace legacy-opt-in routing as the proof of availability. No store is enabled before durable settlement passes.", "AUD-F07")
task("ARC-03", "Software architecture", "Give worker roles explicit minimal entry points", "P2", "M", "Backend + SRE", "FND-01 ARC-01 SCL-01",
    "backend/bmt_backend/service_worker.py backend/bmt_backend/worker.py backend/bmt_backend/publication_worker.py backend/bmt_backend/world_ranking_worker.py backend/bmt_backend/packed_storage.py",
    "Make each role's dependencies, credentials, pool budget, startup checks and durable job contract explicit. Support running the same code/image in separate allocations when profiling proves contention; remove unnecessary HTTP/admin initialization only where measured.",
    "Each role can start/stop/recover independently under intended credentials and bounded resources. It neither imports a new service dependency nor acquires another role's secrets. Shared-supervisor and separate-allocation modes preserve the same correctness/job compatibility.", "AUD-F03 AUD-F08")
task("ARC-04", "Software architecture", "Version and test every public/job/storage contract", "P1", "M", "Backend + client/release", "FND-01",
    "backend/schemas backend/bmt_backend/contracts.py backend/bmt_backend/app.py backend/bmt_backend/job_contracts.py game/backend/backend_client.gd",
    "Maintain one effective route/capability catalogue plus schemas for client bodies/outcomes, durable jobs, pinned verifier/content and packed/archive formats. Define supported client versions, downgrade behavior and authority checks at cache boundaries.",
    "Current and supported older clients have executable consumer contracts; incompatible versions fail explicitly before destructive work. Every admitted job has a compatible worker or a safe recoverable refusal. Accepted immutable data remains readable through configuration rollback and tested release overlap.", "AUD-F08 AUD-F10")

task("MNT-01", "Maintainability", "Replace competing current runbooks with one canonical entry", "P2", "S", "Backend/release owner", "FND-01",
    "backend/README.md backend/deploy/README.md backend/deploy/gcp/README.md docs/README.md",
    "Publish the current architecture, setup, release/migration, restore/privacy and troubleshooting entry points. Mark historical schema/version/deployment notes as historical links instead of mutually competing current instructions.",
    "A new maintainer reaches the right schema/artifact/commands from one index. The generic restore path cannot omit erasure replay. All commands match current role/config defaults and preserve retained owner data.", "AUD-F06 AUD-F08")
task("MNT-02", "Maintainability", "Retire compatibility debt only from proven usage", "P3", "M", "Backend + client owner", "ARC-04 OBS-01",
    "backend/bmt_backend/tracks.py backend/bmt_backend/discovery.py backend/bmt_backend/load_fixtures.py backend/tests/legacy_authoring_fixture.py backend/tests/legacy_validation_fixture.py",
    "Inventory legacy endpoints, fixtures, duplicate adapters and feature flags. Set a supported-client window and migration/deprecation plan; remove only unused runtime paths after evidence confirms consumers can migrate.",
    "Every retained compatibility branch has a named consumer or historical-data requirement. Removed paths have replacement contracts and regression evidence. Historical immutable tracks/boards/receipts and original failing evidence are preserved; no player files are deleted.", "AUD-F08 AUD-F10")
task("MNT-03", "Maintainability", "Standardize critical interfaces and database error handling", "P2", "M", "Backend lead", "ARC-01 TST-01",
    "backend/pyproject.toml backend/bmt_backend/db.py backend/bmt_backend/app.py backend/bmt_backend/provider_proofs.py backend/bmt_backend/race_acceptance.py",
    "Enforce lint/type checks at public/domain boundaries and consistent retry/error/transaction conventions. Refactor duplicate high-risk glue revealed by profiling/review; avoid a broad cosmetic rewrite of working domain code.",
    "CI catches contract/type/lint drift on touched critical code. Errors expose stable non-sensitive codes and retry semantics; external I/O does not hold authority locks unnecessarily. No new catch-all converts failed economic work into success.", "AUD-F07 AUD-F08")
task("MNT-04", "Maintainability", "Prove maintainers can change and diagnose a vertical slice", "P2", "S", "Backend lead + second reviewer", "MNT-01 MNT-03",
    "backend/README.md backend/tests backend/deploy/README.md docs/README.md",
    "Document ownership/review rules and a worked feature change including schema, client contract, trigger effects, telemetry, retention/privacy and rollback. Run clean-checkout onboarding and one independent debugging exercise.",
    "A second maintainer completes setup, targeted tests, a migration rehearsal and diagnosis using documented commands without hidden local state or owner credentials. The review checklist identifies economic/authority/retention effects before implementation.", "AUD-F08 AUD-F11")

task("TST-01", "Testing", "Establish enforced production-shaped CI foundations", "P1", "M", "Test/release engineer", "FND-01",
    "backend/pyproject.toml backend/requirements.lock backend/Dockerfile backend/tests backend/deploy/test_operations.py",
    "Create or integrate an enforced CI pipeline using the pinned shipping Python and PostgreSQL versions, isolated schemas and actual workload roles. Pin the matching Godot verifier inputs; keep SQLite as fast smoke coverage, not isolation proof.",
    "Clean checkout builds and runs deterministic lint/unit/contract/PostgreSQL/privilege/migration checks without production credentials or services. Required jobs cannot be bypassed silently and failed/skipped critical tests block promotion. Existing external CI, if any, is reconciled instead of duplicated.", "AUD-F08 AUD-F10")
task("TST-02", "Testing", "Turn the audit findings into mandatory security and correctness regressions", "P1", "L", "Test + backend/security", "TST-01 FND-03 ARC-04 SEC-01 SEC-02 SEC-03 COR-03 COR-04",
    "backend/tests docs/evidence/backend-comprehensive-audit-2026-10-26/test_audit_probes.py backend/schemas",
    "Convert confirmed purchase, load-protocol, proof/incident and deletion findings into production-path regressions. Add ownership/authorization matrix, malformed/oversized payload fuzzing and property/oracle tests for rewards/ranks/attempts.",
    "Original finding/control probes are retained; corrected production-path tests pass without weakened invariants or insecure legacy opt-in. Every audited P1 has at least one meaningful prevention/recovery test and a source fix or demonstrated mitigation.", "AUD-F01 AUD-F07 AUD-F09 AUD-F10")
task("TST-03", "Testing", "Automate sustained load and fault regression evidence", "P1", "L", "Performance/test + SRE", "TST-01 FND-03 COR-01 COR-02 REL-03",
    "backend/bmt_backend/loadtest.py backend/LOAD_TESTING.md backend/tests backend/load_budgets.json",
    "Provide scheduled bounded open-loop load, soak and fault jobs on approved isolated resources, including a full daily workload cycle on the final capacity candidate after shorter stages pass. Compare equivalent datasets/limits and report scheduled latency, offered load, dropped arrivals, queue drain, physical growth and costs.",
    "A known overload intentionally fails gates and then demonstrates recovery. A normal reference workload meets them reproducibly with complete logs/percentiles and exact economic oracles. Generator saturation and FakeVerifier usage cannot masquerade as backend capacity.", "AUD-F03 AUD-F05 AUD-F10")
task("TST-04", "Testing", "Complete actual provider and exported-client acceptance", "P1", "L", "Platform/client QA + commerce/security", "COR-03 SEC-02 ARC-04 CST-02",
    "game/platform game/backend/session_vault.gd game/backend/backend_client.gd backend/bmt_backend/provider_proofs.py backend/bmt_backend/studio_providers.py",
    "Test exported Android clients on target hardware with Google identity, secure token storage, licensed provider sandbox purchases, pending/refund/completion, account deletion and offline/restart recovery. Keep sandbox payments separate from real charges.",
    "End-to-end receipts match backend authority and once-only effects through client loss/reinstall and provider delay. Release artifact has no dev key/simulation entry or token leakage. Hardware/provider evidence is actually captured; scripted adapters alone do not close this task. Use separately authorized devices/accounts/provider actions.", "AUD-F07 AUD-F08")

task("OBS-01", "Observability", "Measure complete endpoint and confirmation distributions cheaply", "P1", "M", "Backend/client + SRE", "FND-01",
    "backend/bmt_backend/http_costs.py backend/bmt_backend/observability.py backend/bmt_backend/operations.py backend/bmt_backend/worker.py game/backend/network_health.gd",
    "Extend existing bounded summaries to cover upload ACK, queue wait, object/decode/checker, SQL commit and client confirmation. Keep unsampled route/role/version counters and suitable tail distributions, with sampled diagnostic traces and bounded labels.",
    "Report P50/P95/P99, eligible errors/timeouts, bytes and arrivals/drain per journey/stage at declared sample sizes. Match counts across retries/batches without exposing player IDs, raw paths, proofs or tokens. Metrics collection cost is measured and loses no required financial/security evidence.", "AUD-F11")
task("OBS-02", "Observability", "Build dashboards and actionable SLO/resource alerts", "P1", "M", "SRE/on-call owner", "OBS-01 FND-02",
    "backend/bmt_backend/operations.py backend/bmt_backend/studio_incidents.py backend/bmt_backend/studio_alarms.py backend/deploy/gcp",
    "Version dashboards/alerts for gameplay SLO burns, confirmation age/failures, role health, DB/pool/disk/WAL, storage/GC lag, purchase completion and auth/abuse anomalies. Inventory actual existing provider policies before creating new ones.",
    "Every paging condition has severity, owner and runbook; test notifications reach the intended operator. Legitimate throttling at the certified load counts against availability rather than being relabeled away. Expected abusive rejection and insufficient samples are separated transparently.", "AUD-F03 AUD-F06 AUD-F09 AUD-F11")
task("OBS-03", "Observability", "Reconcile infrastructure cost with activity and retained growth", "P1", "M", "SRE + finance/privacy owner", "OBS-01 FND-02",
    "backend/bmt_backend/http_costs.py backend/bmt_backend/studio_finance.py backend/bmt_backend/studio_reporting.py backend/deploy/gcp/cost_profile.py",
    "Use an approved billing export/read path and aggregate game activity to report total/component cost per DAU, MAU, session and 1,000 races, plus retained bytes. Include provider request logs, inactive floors, backups and soft-deleted/version copies.",
    "A full billing cycle reconciles provider totals within 10% or documented billing/attribution lag. Price assumptions/credits/tax are explicit; business revenue and simulated purchases are not inferred from catalogue prices. Cost anomalies and budget alerts notify an owner; budgets are never represented as a provider hard cap.", "AUD-F02 AUD-F11")
task("OBS-04", "Observability", "Prove telemetry and alerts survive the incident they describe", "P2", "M", "SRE + test engineer", "OBS-01 OBS-02 OBS-03 TST-03",
    "backend/bmt_backend/observability.py backend/bmt_backend/http_costs.py backend/bmt_backend/operations.py backend/bmt_backend/studio_watchdog.py",
    "Exercise alert/counter conservation during overload, missing worker role, DB outage, log loss, restart and sampling. Build a single trace from a client's saved attempt to its final durable receipt using privacy-safe diagnostic identifiers.",
    "Operators detect missing/stale telemetry instead of reading a false green dashboard. One synthetic incident is detected, localized and explained using the retained evidence; recovery clears the alert. Label/cardinality/log-volume bounds hold under hostile inputs.", "AUD-F11")

task("OPS-01", "Operational readiness", "Build one repeatable production release candidate", "P1", "M", "Release/SRE + backend", "FND-01 ARC-04 DB-04 SEC-02 SEC-04",
    "backend/deploy/gcp/update.py backend/deploy/gcp/staging.py backend/deploy/stage_verifier.py backend/Dockerfile backend/bmt_backend/readiness.py",
    "Package the exact API/worker/static verifier/schema/grant/client capability manifest and tested configuration. Validate public/private routes, named staff/MFA, disabled development/simulation flags and pinned old cohorts; retain operator access and ownership guards.",
    "The same frozen candidate passes isolated smoke and production-role checks; all targets have compatible rather than blindly identical images. Reproducible provenance and release notes identify migrations/read compatibility and every remaining gate. Preparation does not deploy it.", "AUD-F08")
task("OPS-02", "Operational readiness", "Rehearse promotion, drain and compatible rollback", "P1", "L", "Release/SRE + test engineer", "OPS-01 COR-03 REL-02 SEC-03 TST-02",
    "backend/deploy/gcp/update.py backend/bmt_backend/worker_lifecycle.py backend/bmt_backend/readiness.py backend/deploy/README.md",
    "Test old/new overlap, cohort draining, queue preservation, canary/promotion and abort/rollback with the exact candidate. Separate additive migration/read compatibility from configuration rollback; practice a failed migration and stale worker completion.",
    "Promotion/rollback preserves every acknowledged attempt, reward, purchase and protected object. Old readers are never redeployed over incompatible authoritative formats. A failed canary stops promotion with a concrete recovery path and bounded downtime; live rollout remains an explicit authorized step.", "AUD-F04 AUD-F06 AUD-F08")
task("OPS-03", "Operational readiness", "Operate maintenance and spend controls as owned schedules", "P1", "M", "SRE + backend/privacy owner", "CST-03 OBS-02 REL-04 DB-03",
    "backend/bmt_backend/cost_maintenance.py backend/bmt_backend/maintenance.py backend/bmt_backend/discovery_worker.py backend/bmt_backend/product_worker.py backend/deploy/gcp",
    "Version the actual backup, erasure, retention/GC/compaction, daily/weekly generation, provider reconciliation and artifact-retention schedules/roles. Define job freshness deadlines, backlog recovery, configuration caps and approved spend escalation.",
    "Every enabled recurring function has an observed successful run, failure alert and retry/runbook. No cleanup races live references/backups or deletes retained owner tracks. Missed jobs catch up at certified load without starving gameplay; stale policies cannot silently increase allocated spend.", "AUD-F02 AUD-F03 AUD-F06 AUD-F11")
task("OPS-04", "Operational readiness", "Complete staged launch acceptance and a 30-day operating review", "P1", "L", "Owner + independent backend/SRE reviewer", "CST-04 SCL-04 LAT-04 DB-04 COR-04 REL-04 SEC-01 SEC-02 SEC-03 SEC-04 ARC-04 MNT-04 TST-02 TST-04 OBS-04 OPS-02 OPS-03",
    "docs/BACKEND_COMPREHENSIVE_AUDIT_2026_10_26.md docs/BACKEND_EXCELLENCE_BACKLOG_2026_10_26.md backend/deploy/README.md",
    "Promote only an authorized passed candidate, launch within the certified capacity and repeat the ladder as demand grows. Collect 30 days of eligible gameplay SLOs, billing, retention, security/provider events and completed recovery drills; independently reassess all twelve areas.",
    "All area gates and blockers are satisfied with linked evidence on the deployed release. No unresolved reachable P0/P1, fabricated capacity claim, missing provider/device acceptance or untested restore remains. A smaller deployment can earn readiness only for its declared envelope; million-DAU readiness requires the full million-DAU certification, not a projected score.", "AUD-F01 AUD-F02 AUD-F03 AUD-F04 AUD-F05 AUD-F06 AUD-F07 AUD-F08 AUD-F09 AUD-F10 AUD-F11 AUD-F12")

AREAS = [
    ("Cost efficiency", "6/10", "CST", "Observed provider invoices and retained growth meet the approved per-scale unit-cost budgets with all mandatory recovery/security costs included; optimizations show net savings and preserve the player experience."),
    ("Scalability", "5/10", "SCL", "The declared population/history and peak arrival mix pass open-loop hot-board/rollover/surge tests, with stable queue/pool/background freshness and safe recovery; no claimed scale exceeds measured capacity."),
    ("Player responsiveness", "6/10", "LAT", "Each important journey meets its approved P95/P99 across defined regional/device/cold/cache cohorts; ordinary local navigation and local results remain immediate and independent of optional backend work."),
    ("Database efficiency", "6/10", "DB", "Critical PostgreSQL plans, trigger/lock/WAL/pool cost and maintenance growth are bounded and within SLO/cost budgets at certified peak and one-year history, with exact rankings and safe migrations."),
    ("Correctness and consistency", "7/10", "COR", "Independent oracles stay exact through concurrency, duplicates, expiry, lost responses, crashes and provider reordering; all acknowledged state is durable and no unauthorized or duplicated economic effect occurs."),
    ("Reliability and resilience", "5/10", "REL", "Authorized failover/restore/fault drills meet the accepted availability/RPO/RTO; current objects, packs, pending bytes, purchases and erasure state recover without manual player-data repair."),
    ("Security", "6/10", "SEC", "Known competitive/incident/deletion/edge weaknesses are closed, production auth/MFA/least privilege is demonstrated, and no unmitigated reachable critical/high security finding remains on the released artifacts."),
    ("Software architecture", "8/10", "ARC", "Authority, public/private interfaces, durable jobs and data ownership are explicit and executable as contracts; the managed modular design remains simple and measured scaling needs do not force unrelated dependencies."),
    ("Maintainability", "6/10", "MNT", "One current runbook, supported compatibility policy, checked interfaces and independent onboarding/change/incident exercises make maintenance repeatable without hidden state or speculative rewrites."),
    ("Testing", "7/10", "TST", "Enforced production-role PostgreSQL, contract/oracle, adversarial, sustained-load/fault and real-provider/exported-device gates cover the actual shipping behavior; no critical skip or synthetic substitute masks a gap."),
    ("Observability", "6/10", "OBS", "Privacy-safe bounded metrics explain endpoint and complete-confirmation tails, errors, queues and costs; operators prove alert delivery and incident diagnosis even during failures, within a measured telemetry budget."),
    ("Operational readiness", "4/10", "OPS", "The exact deployed release passes promotion/rollback, recovery, maintenance, provider/device and capacity gates, then demonstrates the agreed SLO/unit-cost behavior in a 30-day operating review."),
]

INTRO = """# Backend task list: evidence required for 10/10 in every audited area

26 October 2026. Planning deliverable based on the [completed backend audit](BACKEND_COMPREHENSIVE_AUDIT_2026_10_26.md). Requirements BXL01 concrete tasks, BXL02 all twelve areas, BXL03 dependencies and acceptance, BXL04 evidence and scope.

**There are 51 concrete tasks: three shared prerequisites and four tasks for each of the twelve areas. All are Planned.** This document authorizes no implementation, deployment, live mutation, purchase or billable load test. Existing local fixes should be validated and released coherently rather than implemented twice.

Here, **10/10 means independently demonstrated readiness for an explicitly declared workload, data age and recovery/security policy**. Completing code or passing a local unit suite does not automatically raise a score. The same evidence can close gates in several areas; work is implemented and estimated once. Scores remain those of the audit until reassessment. There is no claim of zero risk or unlimited capacity.

## Proposed acceptance targets

These are concrete starting gates for FND-02, not previously accepted service promises or spending authorization. Amend and approve them before infrastructure sizing or retention changes. Choosing a cheaper scope cannot silently weaken existing rewards, purchases, competitive rules, privacy or retained-content promises.

| Gate | Proposed target and measurement boundary |
|---|---|
| Workload | 2 sessions/day, 5 races/session, 30 active minutes/player/day, DAU/MAU 0.20; validate both observed traffic and the audit's 60/150-call, 0.5/5-MiB sensitivity mixes. Include server events and one-year retained/protected history. |
| Capacity ladder | 1k / 10k / 100k / 1m DAU. At 1m DAU the lean/reference peak is 3,472 / 8,681 HTTP RPS plus 579 accepted races/s at 5x peak. Seeded account count alone does not establish this capacity. |
| Server reads | P95 <=200 ms, P99 <=500 ms for ordinary healthy-state reads at the certified peak; first join/ticket exceptions get explicit budgets, not hidden exclusions. |
| Upload and confirmation | Durable upload ACK P95 <=500 ms/P99 <=1 s after body receipt; ordinary complete verification/result/reward P95 <=2 s/P99 <=5 s after ACK. Local results render immediately. |
| Player journeys | Regional machine portion of saved login P95 <=500 ms/P99 <=1 s, excluding interactive identity. Define real Europe/NA/Asia network/device journey targets from LAT-01; do not copy server-only limits into worldwide cellular promises. |
| Availability | Proposed 99.95% eligible gameplay success over a rolling 30 days, including legitimate demand within the certified peak. Count backend overload/throttling of that legitimate demand; separately report abusive rejection and user/provider interaction. |
| Recovery | Proposed process/zone loss: RPO 0 acknowledged authority writes, RTO <=5 min; destructive/PITR recovery: RPO <=5 min, RTO <=60 min. Decide and cost region-loss objectives explicitly; document any unsupported failure scope. Prove results on the actual candidate. |
| Cost | Starting validation envelopes from the audit's lean upper scenario: <=EUR500 / 800 / 1,800 / 7,500 per modeled month at 1k / 10k / 100k / 1m DAU, respectively, before tax/labor and under the declared activity/history. Include HA, backup, objects, delivery, logging and idle floors. These are unvalidated targets, not price quotes or capacity claims. |
| Unit economics at 1m | The proposed EUR7,500 ceiling means <=EUR0.0075/DAU-month, <=EUR0.0015/MAU-month, <=EUR0.025/1,000 races and <=EUR0.000125/session under that activity model. Reconcile measured behavior rather than cutting promised features to hit an assumption. |
| Integrity | Exact once-only economic effects and independent PB/rank/attempt oracles. The known fabricated trajectory, incident claim and bearer-only deletion cases cannot remain exploitable if the affected categories are scored 10/10. Policy changes need an explicit owner decision. |
| Budgeted validation | Proposed 10-min warmup +30-min steady +15-min 5x peak, then a 2-hour soak and separate bounded 5-min 10x step. Set maximum duration/spend and an abort condition before any authorized cloud run. |

## Recommended execution order

The dependency graph in [tasks.json](evidence/backend-excellence-backlog-2026-10-26/tasks.json) is authoritative; the following waves are a practical delivery order, not permission to apply live changes.

1. **Make evidence trustworthy (dependency levels 1-2):** Freeze the baseline, agree targets and establish current contracts, load protocol, CI, measurements and runbooks.
2. **Measure and define the fixes (levels 3-4):** Profile journeys/SQL/worker/cost, specify authority oracles and retention, validate auth/supply chain, then prepare billing/role boundaries and recovery configuration.
3. **Complete authority and resource changes (levels 5-7):** Finish durable commerce, hot-board/migration fixes, efficient navigation/completion, pool/queue/scaling/edge work and coherent restore, then validate archives and fault regressions.
4. **Certify and rehearse operation (levels 8-10):** Run recovery and release drills, sustained fault/load jobs, scale certification, operating schedules, telemetry diagnosis, actual cost reconciliation and international/device latency acceptance.
5. **Earn the reassessment (level 11):** OPS-04: release only within the certified envelope, collect 30 days of operating evidence and independently rescore every area. Retain an explicit smaller-scale rating until larger-scale gates actually pass.

The following ready groups are computed from the actual dependencies. Tasks in a group need no other task from that group; finish their prerequisite groups first. This is sequencing guidance, not a request to start concurrent agents.

<!-- DEPENDENCY_LEVELS -->

P1 means a required commercial-readiness/capacity gate; P2 is an important measured improvement; P3 is bounded cleanup. Effort S/M/L is relative implementation effort, not an elapsed schedule or a sum of independent estimates. Owner labels describe required roles; one engineer may fill several. External access, policy decisions and operating observation are separate dependencies.

## Shared prerequisites

"""


def render_task(row):
    dependency = ", ".join(row["dependencies"]) or "None"
    sources = ", ".join("`"+s+"`" for s in row["sources"])
    return (f"### [ ] {row['id']} — {row['title']}\n\n"
        f"**{row['priority']} · {row['effort']} · Owner: {row['owner']} · Status: Planned**\n\n"
        f"**Deliver:** {row['change']}\n\n**Done when:** {row['acceptance']}\n\n"
        f"**Depends on:** {dependency}. **Primary targets:** {sources}.\n\n")


def main():
    assert len(TASKS)==51 and len({t["id"] for t in TASKS})==51
    known={t["id"] for t in TASKS}
    assert all(set(t["dependencies"])<=known and t["id"] not in t["dependencies"] for t in TASKS)
    assert all(t["status"]=="Planned" for t in TASKS)
    done, levels = set(), []
    while len(done)<len(TASKS):
        ready=sorted(t["id"] for t in TASKS if t["id"] not in done and set(t["dependencies"])<=done)
        assert ready, "Dependency cycle"
        levels.append(ready)
        done.update(ready)
    missing=sorted({s for t in TASKS for s in t["sources"] if (ROOT/s)!=DOC and not (ROOT/s).exists()})
    assert not missing, missing
    assert AUDIT.is_file()
    counts=Counter(t["area"] for t in TASKS)
    assert counts["Foundation"]==3 and all(counts[a[0]]==4 for a in AREAS)
    output={"schema":"bmt-backend-excellence-backlog-v1","date":"2026-10-26",
        "basis_audit":AUDIT.relative_to(ROOT).as_posix(),"basis_audit_sha256":hashlib.sha256(AUDIT.read_bytes()).hexdigest(),
        "scope":"Planning only; no task executed, infrastructure created or live setting changed",
        "task_count":len(TASKS),"area_task_counts":dict(counts),"dependency_levels":levels,
        "areas":[dict(name=a,baseline_score=s,prefix=p,ten_of_ten_gate=g) for a,s,p,g in AREAS],"tasks":TASKS}
    (OUT/"tasks.json").write_bytes((json.dumps(output,indent=2)+"\n").encode("utf-8"))
    fields=["id","area","title","priority","effort","owner","status","dependencies","sources","change","acceptance","audit_findings"]
    with (OUT/"tasks.csv").open("w",encoding="utf-8",newline="") as stream:
        writer=csv.DictWriter(stream,fieldnames=fields,lineterminator="\n")
        writer.writeheader()
        for t in TASKS:
            writer.writerow({k:" | ".join(t[k]) if isinstance(t[k],list) else t[k] for k in fields})
    dependency_table="| Dependency level | Ready task IDs |\n|---:|---|\n"+"".join(
        f"| {i+1} | {', '.join(group)} |\n" for i,group in enumerate(levels))
    document=INTRO.replace("<!-- DEPENDENCY_LEVELS -->",dependency_table)+"".join(render_task(t) for t in TASKS if t["area"]=="Foundation")
    for area,score,prefix,gate in AREAS:
        document+=f"## {area}: {score} to 10/10\n\n**10/10 acceptance gate:** {gate}\n\n"
        document+="".join(render_task(t) for t in TASKS if t["area"]==area)
    document+="""## Evidence needed to close a task

Keep each task's record with requirement/task ID, exact source and release hashes, changed files, commands and raw outcomes, independent invariant/oracle results, measurements and fixture/load limits, remaining acceptance and rollback. Link the proof from the task tracker. Status should progress Planned -> In progress -> Implemented locally -> Validated on the candidate -> Deployed/observed when applicable -> Done. A local-only deliverable can finish earlier; a deployment/device/provider/billing task cannot.

For each category reassessment, cite its four tasks and all shared prerequisite evidence. Reuse evidence rather than duplicate infrastructure or count the same optimization twice. Record failed tests and rejected proposals; do not remove assertions or reclassify legitimate backend errors merely to pass a gate. Keep any accepted limitation visible in the affected score.

## Scope and remaining decisions

This task produces only this checklist, a machine-readable task/dependency catalogue and an importable CSV. The audit remains the historical assessment. No runtime code, database, cloud resource, retention policy, verification policy, payments, deployment or owner process was changed. No phone attachment check, device test or APK build occurred. No actual provider/billing/load verification is claimed by generating this list.

FND-02 records the owner decisions needed during execution: final cost/SLO/RPO/RTO and region-loss scope, protected-history retention, competition/clean-bonus verification, and provider reversal/notification semantics. No blanket permission question is needed to make this concrete plan. Separate authorization is required later for billable environments, cloud changes, live rollout and real provider/account/device actions where applicable.

Artifacts: [task catalogue and dependency graph](evidence/backend-excellence-backlog-2026-10-26/tasks.json), [CSV backlog](evidence/backend-excellence-backlog-2026-10-26/tasks.csv), [generator and structural validation](evidence/backend-excellence-backlog-2026-10-26/build_backlog.py). The generator validates exactly 51 unique Planned tasks, twelve groups of four, three prerequisites, existing source targets and an acyclic dependency graph. This structural check is not a backend test or a claim that any task is complete.
"""
    DOC.write_bytes(document.encode("utf-8"))
    assert all((ROOT/s).exists() for t in TASKS for s in t["sources"])
    checks={"task_count":len(TASKS),"category_count":len(AREAS),"area_task_counts":dict(counts),
        "unique_ids":True,"all_dependencies_exist":True,"dependency_graph_acyclic":True,
        "dependency_levels":len(levels),"source_targets_exist":True,"all_statuses_planned":True,
        "audit_unchanged":hashlib.sha256(AUDIT.read_bytes()).hexdigest()==output["basis_audit_sha256"],
        "document":DOC.relative_to(ROOT).as_posix(),"document_sha256":hashlib.sha256(DOC.read_bytes()).hexdigest(),
        "commands_executed":[".tools/backend-venv/Scripts/python.exe docs/evidence/backend-excellence-backlog-2026-10-26/build_backlog.py"],
        "initial_generator_issue":"Initial source-path check included the not-yet-created generated document. Deferred that one self-reference check until after generation; no backend test or application source changed."}
    (OUT/"validation.json").write_bytes((json.dumps(checks,indent=2)+"\n").encode("utf-8"))
    patch=[]
    for path in sorted([DOC,*[p for p in OUT.iterdir() if p.is_file() and p.name!="scoped-change.patch"]]):
        name=path.relative_to(ROOT).as_posix()
        patch.extend([f"diff --git a/{name} b/{name}\n","new file mode 100644\n"])
        patch.extend(difflib.unified_diff([],path.read_text(encoding="utf-8").splitlines(keepends=True),
            fromfile="/dev/null",tofile="b/"+name))
    (OUT/"scoped-change.patch").write_bytes("".join(patch).encode("utf-8"))
    checked=subprocess.run(["git","apply","--check","--reverse",str(OUT/"scoped-change.patch")],
        cwd=ROOT,capture_output=True,text=True)
    assert checked.returncode==0,checked.stderr
    checks["scoped_patch_reverse_check"]="passed"
    print(json.dumps(checks,indent=2))


if __name__=="__main__":
    main()
