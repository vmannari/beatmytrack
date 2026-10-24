"""Build this task's reviewable patch without concurrent P1/discovery edits."""
import ast
import difflib
import hashlib
import json
from pathlib import Path
import subprocess
import xml.etree.ElementTree as ET

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def read(path):
    return path.read_text(encoding="utf-8-sig").replace("\r\n", "\n")


def function(source, name):
    node = next(item for item in ast.parse(source).body if isinstance(item, ast.FunctionDef) and item.name == name)
    return "".join(source.splitlines(keepends=True)[node.lineno - 1:node.end_lineno])


sources = {}


def existing(target, snapshot, *, narrow=None):
    old, actual = read(HERE / snapshot), read(ROOT / target)
    if target == "backend/bmt_backend/rivalry.py":
        # The concurrent P1 fix adds this import. Carry it on both sides as
        # prerequisite context, rather than including its unrelated mutation.
        old = old.replace("case, func, or_,", "case, func, literal_column, or_,")
    after = narrow(old, actual) if narrow else actual
    sources[target] = (old, after)


def telemetry_only(old, actual):
    start = actual.index("        # A telemetry tree")
    end = actual.index("        self.discovery_parsers", start)
    return old.replace("        self.telemetry_parsers = asyncio.Semaphore(1)\n", actual[start:end])


def config_only(old, actual):
    after = old.replace('    studio_business_cohorts: bool = False\n',
                        '    studio_business_cohorts: bool = False\n'
                        '    studio_analysis_database_url: str = ""\n'
                        '    studio_analysis_statement_timeout_ms: int = 5000\n')
    after = after.replace('    upload_concurrency: int = 2\n',
                          '    upload_concurrency: int = 2\n    telemetry_http_concurrency: int = 4\n')
    start = actual.index('        if (self.studio_analysis_database_url')
    end = actual.index('        if (not 50 <= self.telemetry_client_backlog', start)
    after = after.replace('        if (not 50 <= self.telemetry_client_backlog',
                          actual[start:end] + '        if (not 50 <= self.telemetry_client_backlog')
    after = after.replace('"upload_concurrency", "edge_limit_per_minute"',
                          '"upload_concurrency", "telemetry_http_concurrency", "edge_limit_per_minute"')
    marker = '            raise ValueError("Invalid pool overflow or upload concurrency")\n'
    after = after.replace(marker, marker + '        if self.telemetry_http_concurrency > 16:\n'
                          '            raise ValueError("Telemetry HTTP concurrency cannot exceed 16 bounded request trees")\n')
    return after


def skill_only(old, actual):
    after = old.replace(function(old, "skill_score"), function(actual, "skill_score"))
    after = after.replace("import case, ", "import ").replace("    BoardTimeCount,\n", "")
    return after


existing("backend/bmt_backend/config.py", "root/before/config.py", narrow=config_only)
existing("backend/bmt_backend/queueing.py", "root/before/queueing.py")
existing("backend/bmt_backend/middleware.py", "root/before/middleware.py", narrow=telemetry_only)
existing("backend/bmt_backend/rivalry.py", "ranks/before/rivalry.py", narrow=skill_only)
for name in ("economy_models.py", "runs.py"):
    existing("backend/bmt_backend/" + name, "ranks/before/" + name)
for name in ("maintenance.py", "network_health.py", "race_statistics.py", "studio_analysis.py",
             "studio_platform_models.py", "telemetry_erasure.py", "telemetry_processing.py", "track_models.py"):
    existing("backend/bmt_backend/" + name, "retention/before/backend/bmt_backend/" + name)
existing("backend/bmt_backend/app.py", "studio/before/app.py")
existing("backend/deploy/README.md", "root/before/deploy-README.md")
existing("backend/tests/test_product_analytics.py", "root/before/test_product_analytics.py")
for name in ("test_studio_platform.py", "test_studio_simulator.py"):
    existing("backend/tests/" + name, "studio/before/" + name)
for path in ("backend/bmt_backend/leaderboard_ranks.py", "backend/bmt_backend/studio_reporting.py",
             "backend/bmt_backend/migrations/versions/0055_bounded_rank_reads.py",
             "backend/bmt_backend/migrations/versions/0056_bounded_retention.py",
             "backend/tests/test_bounded_leaderboard_ranks.py", "backend/tests/test_bounded_retention.py",
             "backend/tests/test_scalability_admission.py", "backend/tests/test_studio_reporting.py"):
    sources[path] = ("", read(ROOT / path))

patch = []
for target, (before, after) in sorted(sources.items()):
    if before == after:
        continue
    patch.append(f"diff --git a/{target} b/{target}\n")
    if not before:
        patch.append("new file mode 100644\n")
    patch.extend(difflib.unified_diff(before.splitlines(keepends=True), after.splitlines(keepends=True),
                 fromfile="a/" + target if before else "/dev/null", tofile="b/" + target))
(HERE / "task-only.patch").write_bytes("".join(patch).encode("utf-8"))


def xml_summary(relative):
    path = HERE / relative
    if not path.exists():
        return {"receipt": relative, "pending": True}
    root = ET.parse(path).getroot()
    cases = list(root.iter("testcase"))
    skipped = sum(case.find("skipped") is not None for case in cases)
    failed = sum(case.find("failure") is not None for case in cases)
    errors = sum(case.find("error") is not None for case in cases)
    return {"receipt": relative,
            "phase": "original_HEAD_failure_reproduction" if "original-overview" in relative else "current_source_validation",
            "passed": len(cases) - skipped - failed - errors,
            "skipped": skipped, "failed": failed, "errors": errors}


report = {
    "task": "Fix the six other confirmed scalability finding areas (BSR2-F04 through F10)",
    "date": "2026-10-23",
    "status": "Implemented and validated locally; rollout and representative capacity acceptance remain",
    "source_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
    "scope": "Local source, tests, synthetic isolated databases and reviewable checkpoint; concurrent discovery/P1 work is preserved and excluded from this patch.",
    "requirements": {
        "BSR2-F04": "Bounded concurrent telemetry HTTP trees, separate race slots; preserve independently repaired small-discovery query pool.",
        "BSR2-F05": "Exact bounded time-prefix and compressed tie-order reads; index visible window keys before authority joins; retain artificial population isolation.",
        "BSR2-F06": "Propagate every diagnostic expiry backlog into immediate bounded maintenance retries.",
        "BSR2-F07": "Indexed last-activity expiry and one-time bounded legacy repair, preserving cohort dates and actor/privacy guards.",
        "BSR2-F08": "Bound identity deletes and token cascades; finite multi-transaction CLI drain with explicit unfinished-work receipts.",
        "BSR2-F09": "Remove full-reservation COUNTs; at most64 sampled indexed preflight probes before storage, exact transactional slot fence retained.",
        "BSR2-F10": "Exact broad analytics isolated on a read-only physical standby with dedicated pool/SQL budget, identity-bound inserted-WAL privacy fence and no primary fallback."
    },
    "changed_files": sorted(sources),
    "source_sha256": {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in sorted(sources)},
    "validation": [xml_summary(name) for name in (
        "root/admission-product.xml", "root/final-admission-ranks.xml", "root/final-studio.xml", "postgres-regression.xml",
        "root/postgres-core-44-passed.xml", "root/original-overview-fixture.xml")],
    "detailed_evidence": ["ranks/report.json", "ranks/probe.json", "retention/report.json",
                          "retention/probe.json", "studio/report.json", "studio/physical_replica_result.json"],
    "static_checks": {"ruff": "All26changedPython source/testfiles passed",
                      "whitespace": "Scoped gitdiff--check passed",
                      "checkpoint": "gitapply--reverse--check--ignore-whitespace passed"},
    "final_validation_summary": {"sqlite_final_admission_ranks": 114, "sqlite_final_studio": 63,
                                 "postgres_final": 46, "physical_standby_checks": 11,
                                 "note": "Separate validation runs; historical/partial runs are not added to these totals. Final SQLite selections are disjoint."},
    "root_commands": [
        ".tools/backend-secure-venv/Scripts/python.exe docs/evidence/backend-scale-review-2026-10-23/run_sqlite.py -q --tb=short tests/test_scalability_admission.py tests/test_queue_capacity_slots.py tests/test_product_analytics.py -k 'not postgres and not migration_preserves' --junitxml=../docs/evidence/backend-scale-other-fixes-2026-10-23/root/admission-product.xml",
        ".tools/backend-secure-venv/Scripts/python.exe docs/evidence/backend-scale-review-2026-10-23/run_sqlite.py -q --tb=short tests/test_scalability_admission.py tests/test_bounded_leaderboard_ranks.py tests/test_communication_boundary.py tests/test_review_followups.py tests/test_review_reliability.py -k 'not postgres' --junitxml=../docs/evidence/backend-scale-other-fixes-2026-10-23/root/final-admission-ranks.xml",
        ".tools/backend-secure-venv/Scripts/python.exe docs/evidence/backend-scale-review-2026-10-23/run_sqlite.py -q --tb=short tests/test_studio_reporting.py tests/test_studio_platform.py tests/test_studio_simulator.py tests/test_studio_performance.py -k 'not postgres' --junitxml=../docs/evidence/backend-scale-other-fixes-2026-10-23/root/final-studio.xml",
        "wsl -d Ubuntu -- docker run --rm --cpus=2 --memory=1024m --pids-limit=128 --network container:bmt-backend-test -v '/mnt/c/Codes/Godot/Beat my track/backend:/task/backend:ro' -v '/mnt/c/Codes/Godot/Beat my track/.tools/backend-postgres.env:/task/db.env:ro' -v '/mnt/c/Codes/Godot/Beat my track/docs/evidence/backend-scale-other-fixes-2026-10-23:/evidence' -e PYTHONPATH=/task/backend -e PYTHONDONTWRITEBYTECODE=1 -w /task/backend --entrypoint python bmt-full-20261018:86d38519ffb5ac1f /evidence/run_postgres.py tests/test_bounded_leaderboard_ranks.py tests/test_scalability_admission.py tests/test_queue_capacity_slots.py tests/test_bounded_retention.py tests/test_reward_ranks.py tests/test_rivalry.py::test_skill_uses_verified_comparable_percentiles_and_separates_placement -x",
        "git archive --format=zip --output=.tools/backend-scale-other-original.zip HEAD backend",
        "Original archived backend: python -m pytest -q --tb=short tests/test_race_statistics.py::test_operator_queue_counts_explicit_publication_work_and_oldest_age --junitxml=docs/evidence/backend-scale-other-fixes-2026-10-23/root/original-overview-fixture.xml",
        "git apply --reverse --check --ignore-whitespace docs/evidence/backend-scale-other-fixes-2026-10-23/task-only.patch"
    ],
    "objective_review_and_refinements": [
        "Rejected 32 UUID-prefix records per PB; compressed tree has N..2N-1 nodes, with public/test-only time contributions avoiding duplicate ordinary-player trees.",
        "Closed hidden-player neighbor scans with explicit visible leaves and an indexed limited subquery, including variable-length IDs and stale short cursors.",
        "Fixed PostgreSQL streaming-cursor option leakage caught during migration setup; seed SELECT is statement-scoped and its cursor closes.",
        "Restored no-upload backpressure after independent review found removing preflight COUNT could otherwise write blobs before a full-queue rejection.",
        "Split NULL/due expiry probes; actor and session-family locks recheck current state. Identity CLI drains finite committed batches instead of hiding a low hourly ceiling.",
        "Replica SQL work stays linear in matching analytical facts, but isolated from gameplay. A primary inserted-WAL fence, identity checks, read-only transaction and cumulative SQL deadline preserve exactness/privacy.",
        "Quiet replay timestamps indicate transaction inactivity; successful replay to the fresh fence determines availability.",
        "Shared-file endpoint overlap was caught by routing assertions and corrected without removing retention projector edits."
    ],
    "retained_failures": [
        "The unchanged race_statistics overview/publications assertion fails identically against archived original HEAD; its assertion remains. Receiptroot/original-overview-fixture.xml.",
        "Historical queue/reward round-trip fixtures cross separately irreversible0051 (and possibly undrained0054 creator effects); retained assertions are excluded from final runtime checks. New0055/0056 populated migration round trips run directly.",
        "Intermediate cursor, mixed-source and local fixture startup failures are recorded separately; final receipts determine completion."
    ],
    "remaining_acceptance": [
        "Apply matching0055/0056 schema and API/worker rollout only after representative migration/lock/storage rehearsal; no deployment included.",
        "Provision a matching physical reporting standby and documented least privileges; without it behaviour analytics returns503. General SQL scans remain linear on that replica.",
        "Queue probes can conservatively return503 near saturation. Withonefree slot, sample success ismin(64,capacity)/capacity. Actual slot allocation still depends on finite configured queue capacity.",
        "Measure arrival/drain rates, retention-backfill runtime, pool/CPU/memory and recovery under representative traffic; these tests do not certify1millionDAU/500millionaccounts.",
        "No phone attachment check, device test, APK, live backend/account/queue mutation or deployment was performed."
    ],
    "checkpoint": "task-only.patch; based on per-file pre-edit snapshots, excluding concurrent discovery/P1 hunks. Requires pre-existing0053/0054 migrations. No shared-workspace commit."
}
(HERE / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"files": len(sources), "patch_bytes": (HERE / "task-only.patch").stat().st_size,
                  "validation": report["validation"]}, indent=2))
