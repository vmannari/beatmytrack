"""Assemble a review receipt without editing runtime sources or existing tests."""
import difflib
import hashlib
import json
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
findings = [
    {
        "id": "BSR2-F01", "priority": "P1", "status": "newly identified",
        "title": "Rivalry joining repeatedly scans closed groups under one skill-band reservation lock",
        "sources": ["backend/bmt_backend/rivalry.py:376", "backend/bmt_backend/rivalry.py:384",
                    "backend/bmt_backend/rivalry_models.py:11"],
        "growth": "O(G) closed/open group candidates per join; aggregate work across J growing enrollments is O(J^2/20) for a fixed band/car/week. LIMIT 100 bounds output, not candidate visits. The same week/contract/band OperationState lock serializes those joins.",
        "evidence": "The actual join() groups assignment returns one open group while PostgreSQL EXPLAIN ANALYZE removes 1000/10000/100000 closed groups. Shared buffer hits grow 23/223/2223. SQLite VM instructions grow about 5000/50000/500000.",
        "impact": "New-player placement and weekly rollover have concentrated bands. Adding API replicas does not remove the band reservation bottleneck, and a group's 20-member cap does not bound matching work.",
        "recommendation": "Index only open groups, ordered by week/contract/band/created_at/id, and redesign reservation around independently claimable groups with a bounded creation guard. Preserve exact capacity, unique membership and retry identities."
    },
    {
        "id": "BSR2-F02", "priority": "P1", "status": "newly identified",
        "title": "Creator achievement updates serialize accepted races across different tracks and boards",
        "sources": ["backend/bmt_backend/achievements.py:57", "backend/bmt_backend/achievements.py:198",
                    "backend/bmt_backend/worker.py:321", "backend/bmt_backend/economy.py:217"],
        "growth": "Constant per-result work, but every qualifying external race locks and rewrites (creator_id, creator) in achievement_states, even on different tracks/cars. The lock is held until the race's complete finalization transaction commits.",
        "evidence": "Actual achievements.capture_race with two different synthetic actor/track/board contexts produced two PostgreSQL lock waiters on one held creator state. Both completed after release and creator_plays was exactly two.",
        "impact": "A popular creator couples otherwise independent boards. The global verification counter fix does not remove this narrower critical section, and waiting finalizations retain their other transaction locks.",
        "recommendation": "Persist uniquely identified creator-achievement contributions transactionally, then coalesce them outside race finalization under bounded creator ownership. Retain exact once-only awards and deletion fences.",
        "qualification": "The lock probe exercises the actual achievement function on minimal synthetic accepted-result contexts, not a canonical verifier or an HTTP latency benchmark."
    },
    {
        "id": "BSR2-F03", "priority": "P1", "status": "original BSR-F07 partly fixed",
        "title": "Achievement and requested Trackside jobs still depend on an empty race queue",
        "sources": ["backend/bmt_backend/worker.py:101", "backend/bmt_backend/worker.py:360",
                    "backend/bmt_backend/achievements.py:245", "backend/bmt_backend/news.py:430"],
        "growth": "Scheduling starvation, not an asymptotic loop: achievements, requested news and ordinary lap backfill are selected only when no race is claimed. The reserved every-16-completions turn includes privacy and histograms only.",
        "evidence": "Executing the actual process_worker_job for 64 stubbed busy foreground completions invoked privacy four times and histograms four times, achievements/news zero times. Source inspection confirms their dispatch is inside the no-claimed-race branch.",
        "impact": "Continuous racing can prevent rarity, held-record/week achievement completion and requested news processing. Requested news has a ten-minute activity window and can expire before service.",
        "recommendation": "Reserve a measured fair share for all promised background classes, or give them independent bounded worker roles. Avoid a strict background priority chain in which one busy class can starve another."
    },
    {
        "id": "BSR2-F04", "priority": "P2", "status": "newly identified end-to-end capacity limit",
        "title": "Telemetry and discovery HTTP handlers each have one active slot per API process",
        "sources": ["backend/bmt_backend/middleware.py:134", "backend/bmt_backend/middleware.py:391",
                    "backend/bmt_backend/middleware.py:458", "backend/bmt_backend/middleware.py:470"],
        "growth": "One telemetry semaphore and one discovery semaphore are held through body parsing, authentication/endpoint SQL, object access and response serialization. Waiters time out after 100ms. Per-process throughput is therefore limited by full request duration, independently of parallel database projectors.",
        "evidence": "The existing test_telemetry_handler_budget_does_not_borrow_race_upload_slots passes and explicitly asserts that a second telemetry handler receives REQUEST_VALIDATION_BUSY while the first is held. Discovery uses the same lifetime and a separate one-slot semaphore.",
        "impact": "The earlier queue-drain benchmark is not ingress throughput. A slow discovery query can occupy the only discovery handler in that process while other users receive 503. This is per process, not a remaining database-global ProductState lock.",
        "recommendation": "Measure real HTTP ingress and memory, then expose separately reviewed handler budgets or process scaling. Keep JSON/live-tree memory and race-upload reservations bounded; do not simply remove the guards.",
        "qualification": "This is an intentional overload guard whose production capacity remains unqualified, not evidence that its memory protection should be removed."
    },
    {
        "id": "BSR2-F05", "priority": "P2", "status": "newly measured residual population work",
        "title": "Small leaderboard windows and Rivalry skill queries still perform population-dependent rank work",
        "sources": ["backend/bmt_backend/runs.py:494", "backend/bmt_backend/runs.py:509",
                    "backend/bmt_backend/runs.py:784", "backend/bmt_backend/rivalry.py:148"],
        "growth": "Around-me sums O(U) tick frequencies and counts an O(B) tied-player prefix in the worst case, despite returning only radius*2+1 rows. Rivalry skill_score scans frequencies for up to 20 comparable boards. U is bounded by the tick domain; tied-player ordinal counts still grow with board population.",
        "evidence": "Actual around_me on 1000/10000/100000 tied players and only one distinct tick executed about 5200/50200/500200 SQLite VM instructions. Actual skill_score with distinct tick values executed about 18500/185000/1850000 instructions. These are operation probes, not PostgreSQL latency predictions.",
        "impact": "Repeated personalized rank reads and Monday matchmaking can be expensive even though reward percentile calculation and histogram payloads were repaired.",
        "recommendation": "Reuse maintained prefix statistics for strict rank/percentile reads where populations match. Separately define whether absolute position within ties is required; preserve exact tie semantics and cursor stability rather than substituting an ordinary B-tree COUNT as a constant-cost rank."
    },
    {
        "id": "BSR2-F06", "priority": "P2", "status": "newly reproduced",
        "title": "Telemetry cleanup does not propagate race/network cleanup backlog into its busy-drain decision",
        "sources": ["backend/bmt_backend/telemetry_processing.py:265", "backend/bmt_backend/telemetry_processing.py:274",
                    "backend/bmt_backend/race_statistics.py:203", "backend/bmt_backend/product_worker.py:75"],
        "growth": "race_statistics.cleanup and network_health.cleanup delete bounded rows but return no progress signal. The maintenance more flag excludes their work, so an isolated remaining backlog falls back to one chunk per minute.",
        "evidence": "With 1001 expired RaceStatisticsReceipt rows and no unrelated backlog, the first actual maintenance call removed 500 but returned more=false; a call one second later removed nothing, leaving 501.",
        "impact": "When this stage alone keeps maintenance active, the default receipt cleanup ceiling is 720000 rows/day. The illustrative 20 races/day for one million DAU creates 20 million race packages/day. Other maintenance backlogs can incidentally accelerate it, but are not a reliable drain contract.",
        "recommendation": "Return bounded progress/backlog indicators from each cleanup helper and schedule immediate further chunks while any expiry class has work. Test each retention stage independently."
    },
    {
        "id": "BSR2-F07", "priority": "P2", "status": "newly reproduced",
        "title": "Person retention repeatedly sweeps active historical profiles instead of selecting expiry candidates",
        "sources": ["backend/bmt_backend/telemetry_erasure.py:82", "backend/bmt_backend/telemetry_processing.py:231",
                    "backend/bmt_backend/telemetry_processing.py:274"],
        "growth": "A first_at older than the fact floor enables maintenance; its keyset cursor then walks every AnalysisPerson, 16 per chunk, even if each still has recent AnalysisDay activity. Once the cursor reaches the end, the same condition restarts the sweep after the idle minute. Each pass is bounded, but a cycle still does O(P) person reads and per-old-person guard/activity lookups.",
        "evidence": "128 old-cohort profiles with current activity caused nine actual maintenance calls for a complete sweep, zero deletions, and a new busy sweep 61 seconds later.",
        "impact": "At large observed-player populations this creates continuous low-yield SQL and ownership traffic. Small chunks alone do not make lifetime-population work cheap.",
        "recommendation": "Maintain an indexed last-activity/expiry deadline through normal actor projection, then keyset only genuine expiry candidates. Preserve first-cohort semantics and recheck under player ownership; plan a bounded one-time legacy backfill."
    },
    {
        "id": "BSR2-F08", "priority": "P2", "status": "original BSR-F09 still open",
        "title": "Identity expiration still deletes the whole eligible backlog in one transaction",
        "sources": ["backend/bmt_backend/maintenance.py:189", "backend/bmt_backend/maintenance.py:199",
                    "backend/bmt_backend/identity_models.py:98"],
        "growth": "Unbounded DELETEs for browser logins, rate buckets, login challenges and session families; family deletion cascades to tokens. Expiry indexes help locate rows but do not bound the number deleted or the transaction's WAL/vacuum burden.",
        "impact": "A delayed cleanup can produce a large write transaction on the gameplay database.",
        "recommendation": "Use indexed, bounded transactions with resumable progress and sufficient drain throughput, accounting for token cascades as well as family count.",
        "evidence": "Source and existing expiration regression inspected; no production backlog or cleanup job was executed."
    },
    {
        "id": "BSR2-F09", "priority": "P2", "status": "newly measured capacity-scaling tradeoff",
        "title": "Queue admission preflight now counts all occupied reservations",
        "sources": ["backend/bmt_backend/migrations/versions/0047_queue_capacity_slots.py:65",
                    "backend/bmt_backend/queueing.py:14", "backend/bmt_backend/queueing.py:56"],
        "growth": "queue_capacity is now a COUNT(*) view over queue_reservations. Preflight/admit reads therefore do O(K) work in occupied slots, rather than a constant row read. The allocator also ranges over the configured slot domain; its cost was not separately benchmarked.",
        "evidence": "PostgreSQL EXPLAIN ANALYZE for the actual QueueCapacity.pending selection scans 1000/10000/100000 reservations. Local observations were approximately 0.109/1.046/8.715ms; these are not production latency forecasts.",
        "impact": "Cheap at the default 128 slots. Raising the backlog allowance by orders of magnitude can make every admission more expensive, particularly during outage recovery. This does not invalidate the successful removal of the global exclusive counter lock.",
        "recommendation": "Keep reservation/unique-slot ownership as the hard capacity fence, and remove population COUNT preflights from the hot path or replace them with bounded/sharded conservative metadata. Revalidate full-capacity and retry semantics before changing it.",
        "qualification": "The synthetic ledger is for query cost only; it is not a full simulated job/owner workload."
    },
    {
        "id": "BSR2-F10", "priority": "P2", "status": "residual reporting volume, related to original BSR-F08",
        "title": "Studio behaviour reports still aggregate per-player day/session facts on the transactional database",
        "sources": ["backend/bmt_backend/studio_analysis.py:279", "backend/bmt_backend/studio_analysis.py:311",
                    "backend/bmt_backend/studio_analysis.py:325", "backend/bmt_backend/studio_analysis.py:361"],
        "growth": "COUNT DISTINCT/SUM on the requested AnalysisDay range, session aggregates, and cohort joins still visit matching per-player facts. Returning a few daily rows and using at most six SQL statements does not bound work per statement. A 28-day view at one million DAU can cover at least tens of millions of player-day rows before build/mode dimensions.",
        "impact": "The original player catalogue and finance lifetime scans are fixed, but broad analytics can still compete with gameplay IO/CPU. This is O(window facts), not proof of a quadratic query or a scan of every registered account.",
        "recommendation": "Move broad analytical reads to a reporting replica/store or prepared rollups with explicitly preserved distinct/cohort semantics; retain direct transactional support lookups.",
        "evidence": "Current SQL reviewed and test_behaviour_tabs_match_combined_exact_report_without_other_analyses passes for all four views; no production-cardinality report benchmark was performed."
    }
]

previous = {
    "BSR-F01": {"status": "fixed in current source", "basis": "Reward ranks read a root and at most 30 Fenwick prefix nodes; current exactness and bounded-read regressions pass."},
    "BSR-F02": {"status": "fixed in current source", "basis": "Independent transactional queue slots remove the global exclusive counter; PostgreSQL held-completion cases pass. See new BSR2-F09 before increasing backlog capacity."},
    "BSR-F03": {"status": "fixed in current source", "basis": "Large histogram own maps replaced by compact frequencies and indexed personal markers; immutable buffers, bounded 128-entry/128MiB cache and requested-board scheduling are present."},
    "BSR-F04": {"status": "fixed architecture with remaining query/load qualification", "basis": "V3 keyset pages and incremental seven-day popularity replace full catalogue vectors; v2 requires an update. Rare/small substring matches can still hit a deadline/503, already documented by the discovery task."},
    "BSR-F05": {"status": "fixed in current source", "basis": "Disk-backed immutable scan manifests perform one directory pass and direct page seeks. First preparation remains O(objects) and consumes manifest disk space, outside DB locks."},
    "BSR-F06": {"status": "fixed in current source", "basis": "Independent telemetry intake/actor/shared/fold ownership; new PostgreSQL held-global-row ingress and parallel worker tests pass. See HTTP/retention findings for other limits."},
    "BSR-F07": {"status": "partly fixed", "basis": "Histogram demand now has a reserved turn, and discovery/publication/product have separate processes; achievements and requested news still starve, BSR2-F03."},
    "BSR-F08": {"status": "original catalogue/finance queries fixed", "basis": "Page summaries replace lifetime account classifications; global wallet totals and unused purchase counts removed. Current Studio performance regressions pass. Separate volume-heavy behaviour reporting remains, BSR2-F10."},
    "BSR-F09": {"status": "still open", "basis": "Unbounded identity cleanup, BSR2-F08."},
    "BSR-F10": {"status": "fixed in current source", "basis": "Migration 0044 and ProductState.processed_events use BIGINT; ProductMetric and new partial accumulators also use BIGINT."},
    "BSR-F11": {"status": "still an unqualified deployment/capacity gate", "basis": "Checked-in staging still permits only two API/two worker instances with a small SQL/pool budget. Not a defect in a deliberately disposable template; no live configuration inspected and no production design/load/restore qualification established."},
    "BSR-F12": {"status": "still open as a delivery-capacity consideration", "basis": "Cold track documents still read/parse immutable objects and serialize via API; conditional reads retain authoritative visibility and origin revalidation. Any delivery offload must preserve blocking, revocation and erasure."}
}

receipts = {}
for filename in ("regression.xml", "extended-regression.xml", "postgres-regression.xml"):
    tree = ET.parse(HERE / filename)
    suites = tree.findall(".//testsuite")
    receipts[filename] = {field: sum(int(suite.get(field, "0")) for suite in suites)
                          for field in ("tests", "failures", "errors", "skipped")}
    receipts[filename]["skips"] = [{"case": row.get("name"), "reason": row.find("skipped").get("message")}
                                  for row in tree.findall(".//testcase") if row.find("skipped") is not None]
sources = {entry.split(":")[0] for finding in findings for entry in finding["sources"]}
sources.update({"backend/bmt_backend/reward_ranks.py", "backend/bmt_backend/storage.py",
                "backend/bmt_backend/local_object_listing.py", "backend/bmt_backend/histogram_population.py",
                "backend/bmt_backend/histogram_snapshots.py", "backend/bmt_backend/discovery_v3.py",
                "backend/bmt_backend/discovery_projection.py", "backend/bmt_backend/telemetry_models.py",
                "backend/bmt_backend/telemetry_queue.py", "backend/bmt_backend/service_worker.py",
                "backend/deploy/gcp/staging.py", "backend/bmt_backend/race_acceptance.py"})
fingerprints = {source: hashlib.sha256((ROOT / source).read_bytes()).hexdigest() for source in sorted(sources)}
head = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, check=True, text=True, capture_output=True).stdout.strip()
report = {
    "title": "Second backend scalability review: repaired items and previously missed bottlenecks",
    "date": "2026-10-23", "source_head": head,
    "requirements": {"BSR2-01": "Reassess all original BSR-F01 through BSR-F12 against current source",
                     "BSR2-02": "Investigate newly missed growth, contention, retention and HTTP scheduling costs",
                     "BSR2-03": "Reproduce important findings and distinguish correctness/source evidence from production qualification"},
    "requested_scale": {"daily_players": 1000000, "registered_accounts": 500000000},
    "verdict": "The main original implementation problems have substantially improved. The new highest priorities are Rivalry matching growth, creator-wide accepted-result locking and remaining background starvation. The backend still has no demonstrated million-DAU/500-million-account capacity qualification.",
    "notation": {"G": "Rivalry groups in one week/contract/skill band", "J": "joins into that cohort",
                 "B": "players with a PB on a board", "U": "distinct tick values, bounded by the accepted tick domain",
                 "P": "retained observed-person profiles, not necessarily every registered account",
                 "K": "occupied verification reservations"},
    "original_findings": previous, "findings": findings,
    "assessment": {"worse_than_linear": "Rivalry matching can accumulate quadratic candidate work as joins create more full groups. The previous local-object quadratic prefix traversal is repaired.",
                   "important_distinction": "Indexed equality lookups, small competition fields, fixed tick-domain trees and bounded batches are useful. They do not prove a scalar aggregate, a page LIMIT, a handler semaphore or a global/shared row is cheap at the requested concurrency.",
                   "not_flags": ["The 20-driver by five-track standings loop remains small; it is not a 500-million-account nested loop.",
                                 "Discovery's nested event loops are capped at BATCH=128; no claim of an unbounded population-squared loop there.",
                                 "Histogram memory now grows with a bounded tick-frequency domain, not every driver mapping; cold frequency reads and refresh IO still require workload measurement.",
                                 "Remaining board/version/shared-context locks are narrower than the former database-global queue/telemetry locks. Their throughput is a skew/load acceptance item, not evidence that those repairs failed."]},
    "validation": {"receipts": receipts,
        "passing_cases": "97 passing SQLite cases in the first run plus 26 in the follow-up (including the corrected archive subprocess invocation); 9 PostgreSQL cases pass, 1 discovery case skips.",
        "initial_failure": "Initial local archive round-trip test failed because the test subprocess did not inherit PYTHONPATH and could not import bmt_backend. The exact test passed with the source path exported by run_sqlite.py; no existing test or runtime source changed.",
        "postgres_skip": "Discovery's fixture requires a separately owned database named bmt_discovery_lab. It was not supplied; its assertion was not bypassed. PostgreSQL queue/reward/telemetry/histogram checks ran in dedicated random schemas.",
        "probes": ["probe-results.json: actual-query SQLite VM work, independent cleanup, active-profile sweep, busy scheduler dispatch",
                   "postgres-plans.json: actual Rivalry query plans, exact pending-capacity COUNT plans, creator-achievement lock waiters"],
        "probe_corrections": "The first creator probe's minimal synthetic board omitted vehicle_id, so it did not reach the creator lock. The fixture was corrected; the final actual-function run confirms two PostgreSQL lock waiters and exact creator_plays=2 after release. Query-plan and other assertion failures were not treated as passes.",
        "qualification": "All data is synthetic and locally disposable. SQLite VM instruction counts are growth evidence, not PostgreSQL timings. PostgreSQL EXPLAIN and held-lock results are local observations, not sustained HTTP, canonical-verification or cloud capacity measurements."},
    "priority_order": ["BSR2-F01 Rivalry open-group indexing/reservation", "BSR2-F02 creator contribution outbox/coalescing",
                       "BSR2-F03 fair service for achievements and requested news", "BSR2-F06 and BSR2-F07 independent targeted retention",
                       "BSR2-F04 real HTTP ingress budgets", "BSR2-F05 ranks/skill and BSR2-F09 capacity preflights",
                       "BSR2-F08 identity expiry and BSR2-F10 isolated analytical reporting"],
    "remaining_capacity_acceptance": ["Representative total accounts, retained histories, hot creators/boards and Monday placement joins",
        "Sustained open-loop HTTP plus real canonical verification with scheduled p95/p99 latency and generator drops",
        "Worker service shares, pending-age/freshness and retention drain throughput at illustrative peak rates",
        "Measured database CPU/IO/locks, pool waits, WAL/vacuum, retained-state/index bytes, memory and content egress",
        "Explicit production topology, failover, restore and overload/recovery exercise; staging defaults and short synthetic tests do not certify it"],
    "commands": [
        "Read-only rg/Get-Content/current Git inspection; compared the original 2026-10-22 review with current runtime, triggers and tests",
        ".tools/backend-secure-venv/Scripts/python.exe docs/evidence/backend-scale-review-2026-10-23/probe.py",
        "cwd backend: ../.tools/backend-secure-venv/Scripts/python.exe -m pytest tests/test_reward_ranks.py tests/test_queue_capacity_slots.py tests/test_histogram_followup.py tests/test_discovery_v3.py tests/test_telemetry_parallel.py tests/test_local_object_listing.py tests/test_studio_catalogue.py tests/test_product_analytics.py::test_telemetry_handler_budget_does_not_borrow_race_upload_slots -k 'not postgres and not migration' -q --tb=short --junitxml=../docs/evidence/backend-scale-review-2026-10-23/regression.xml",
        ".tools/backend-secure-venv/Scripts/python.exe docs/evidence/backend-scale-review-2026-10-23/run_sqlite.py tests/test_local_object_listing.py::test_local_backup_round_trip_excludes_scan_artifacts tests/test_studio_performance.py tests/test_maintenance.py -k 'not postgres' -q --tb=short --junitxml=../docs/evidence/backend-scale-review-2026-10-23/extended-regression.xml",
        "WSL Docker cached bmt-full-20261018:86d38519ffb5ac1f, --cpus=2 --memory=1024m --pids-limit=128 --network container:bmt-backend-test; current backend and ignored fixture credentials mounted read-only, PYTHONPATH=/task/backend, PYTHONDONTWRITEBYTECODE=1; python /evidence/postgres_probe.py",
        "Same Docker runner: python /evidence/run_postgres.py tests/test_queue_capacity_slots.py::test_uncommitted_completion_does_not_block_another_player tests/test_reward_ranks.py::test_prefix_queries_are_bounded_and_do_not_read_players_or_pbs tests/test_reward_ranks.py::test_concurrent_pb_writers_keep_both_metric_prefixes_exact tests/test_telemetry_parallel.py::test_postgres_ingress_ignores_global_and_analytical_owner_locks tests/test_telemetry_parallel.py::test_postgres_parallel_workers_and_retry_have_exact_effects tests/test_histogram_followup.py::test_continuous_foreground_work_gets_reserved_histogram_turn tests/test_discovery_v3.py::test_cursor_tamper_scope_and_page_query_cost",
        ".tools/backend-secure-venv/Scripts/python.exe -m ruff check new evidence Python helpers; passed after import formatting and explicit trusted-source-query annotations"
    ],
    "scope": {"runtime_source_changes": False, "existing_test_changes": False, "live_environment_access": False,
              "live_player_account_or_queue_mutation": False, "deployment": False, "device_or_attachment_check": False,
              "changes": "Only docs/evidence/backend-scale-review-2026-10-23; unrelated evidence and workspace changes preserved",
              "test_fixture": "Dedicated bmt-backend-test was originally stopped; started for this review. Random schemas dropped in finally blocks; final fixture-check.json confirms zero other clients and zero review schemas. Container stopped afterward to restore its original state."},
    "reviewed_source_sha256": fingerprints,
    "checkpoint": "task-only.patch adds only this review's evidence; backend sources and existing assertions are unchanged"
}
(HERE / "review.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
patch = []
for path in sorted(HERE.iterdir()):
    if path.is_file() and path.name != "task-only.patch":
        relative = path.relative_to(ROOT).as_posix()
        patch.extend([f"diff --git a/{relative} b/{relative}\n", "new file mode 100644\n"])
        content = path.read_text(encoding="utf-8").splitlines()
        patch.extend(difflib.unified_diff([], [line + "\n" for line in content], fromfile="/dev/null", tofile="b/" + relative))
(HERE / "task-only.patch").write_text("".join(patch), encoding="utf-8", newline="\n")
print(json.dumps({"findings": len(findings), "previous_findings_reassessed": len(previous), "receipts": receipts}))
