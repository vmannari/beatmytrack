"""Record only this task's source delta, preserving the shared dirty workspace."""
import difflib
import hashlib
import json
import shutil
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
BEFORE = HERE / "before"
BUILD = ROOT / "build/telemetry-parallelism-2026-10-22"


def sha(value):
    return hashlib.sha256(value).hexdigest()


review = json.loads((ROOT / "docs/evidence/telemetry-parallelism-plan-2026-10-22/plan-review.json").read_text())
path = ROOT / "backend/tests/test_product_analytics.py"
current = path.read_bytes()
old = current.replace(
    b"        from bmt_backend.telemetry_queue_models import TelemetryCredit\n"
    b"        assert session.scalar(select(func.sum(TelemetryCredit.capacity - TelemetryCredit.free))) == 2\n",
    b"        assert session.get(ProductState, 1).pending_clients == 2\n")
assert sha(old) == review["reviewed_source_sha256"]["backend/tests/test_product_analytics.py"]
(BEFORE / "tests__test_product_analytics.py").write_bytes(old)

counter_patch = (ROOT / "docs/evidence/telemetry-counter-bigint-2026-10-22/task-only.patch").read_text()
section = counter_patch.split("+++ b/backend/tests/test_telemetry_counter.py\n", 1)[1]
original_counter = "".join(line[1:] for line in section.splitlines(keepends=True)
                           if line.startswith("+") and not line.startswith("+++"))
(BEFORE / "tests__test_telemetry_counter.py").write_text(original_counter, encoding="utf-8", newline="\n")

owned = {}
for before in BEFORE.iterdir():
    name = before.name
    if name == "backend_README.md":
        target = "backend/README.md"
    elif name.startswith("tests__"):
        target = "backend/tests/" + name.removeprefix("tests__")
    else:
        target = "backend/bmt_backend/" + name.replace("__", "/")
    owned[target] = before
for name in ("telemetry_queue_models.py", "telemetry_queue.py", "telemetry_projection.py",
             "telemetry_processing.py", "telemetry_erasure.py", "migrations/versions/0051_telemetry_parallel.py"):
    owned["backend/bmt_backend/" + name] = None
owned["backend/tests/test_telemetry_parallel.py"] = None
patch, fingerprints, changed = [], {}, []
for target, baseline in sorted(owned.items()):
    current = (ROOT / target).read_bytes()
    before = baseline.read_bytes() if baseline is not None else b""
    fingerprints[target] = {"before": sha(before) if baseline else None, "after": sha(current)}
    if before == current:
        continue
    changed.append(target)
    patch.append(f"diff --git a/{target} b/{target}\n")
    if baseline is None:
        patch.append("new file mode 100644\n")
    patch.extend(difflib.unified_diff(before.decode("utf-8-sig").replace("\r\n", "\n").splitlines(keepends=True),
        current.decode("utf-8-sig").replace("\r\n", "\n").splitlines(keepends=True),
        fromfile="a/" + target if baseline else "/dev/null", tofile="b/" + target))
(HERE / "task-only.patch").write_text("".join(patch), encoding="utf-8", newline="\n")
(HERE / "source-sha256.json").write_text(json.dumps(fingerprints, indent=2) + "\n")
for name in ("verified-sqlite.xml", "causal-sqlite.xml", "final-expiry.xml", "baseline-operator.xml",
             "broad.xml", "final-sqlite.xml", "domains-initial.xml", "corrected.xml", "initial.xml", "optimized.xml", "product.xml"):
    if (BUILD / name).exists():
        shutil.copyfile(BUILD / name, HERE / name)

receipts = {}
for filename in ("verified-sqlite.xml", "causal-sqlite.xml", "final-expiry.xml", "verified-postgres.xml",
                 "causal-postgres.xml", "postgres-recovery-http.xml", "original-lock.xml", "baseline-operator.xml",
                 "broad.xml", "final-sqlite.xml", "postgres-37-pass-2-fail.xml"):
    tree = ET.parse(HERE / filename)
    suites = tree.findall(".//testsuite")
    receipts[filename] = {field: sum(int(suite.get(field, "0")) for suite in suites)
                          for field in ("tests", "failures", "errors", "skipped")}
    properties = {row.get("name"): row.get("value") for row in tree.findall(".//property")}
    if properties:
        receipts[filename]["properties"] = properties
benchmark = json.loads((HERE / "benchmark.json").read_text())
report = {
    "date": "2026-10-22",
    "scope": "Local implementation of the user-approved telemetry parallelism plan. No live deployment, account mutation or device test.",
    "requirements": {
        "TPP01": "Independent receipt acceptance and analytical ownership; no global row held through projection",
        "TPP02": "Parallel PostgreSQL actor/entity processing with transactional ownership, exact effects and erasure fences",
        "TPP03": "Existing immutable acknowledgements and conflicts, consent, late-arrival window and exact global client capacity",
        "TPP04": "Preserved historical baseline, BIGINT partials/totals, retryable expansion, documented cutover and measured limits"
    },
    "changed_files": changed,
    "architecture": [
        "256 SHA256 logical player partitions; separate intake, actor ownership and terminal progress rows. No account enumeration or per-account ownership rows.",
        "64 shared capacity-credit buckets; reserve only actual new client receipts, distinguish contention from exhaustion, and return credits atomically once after actor/derived completion or erasure cancellation.",
        "Transactional derived work for semantic publication, race, network and quality keys. Bounded race maps retain the original algorithm and one ordered reducer per context.",
        "Bulk actor batches claim up to 16 independent owners in service mode; the bounded offline diagnostic claims up to 256. Additive corrections go into the claimed leader's partial namespace, separately from shared-reducer metrics.",
        "Each touched actor records the metric owner/revision for its previous batch. A subsequent batch waits for that fold, preventing a late negative restatement from preceding the original contribution.",
        "Independent repeatable-read incremental folds preserve existing totals and atomically advance per-owner checkpoints. No reconstruction from retired raw history.",
        "Fixed-size intake/completion/fold metadata captured in one MVCC UNION snapshot supports a conservative completeness barrier without requiring the whole queue to empty.",
        "Private erasure and bounded retention share analytical/entity guards. Publication erasure also fences retained owned versions with no existing fact; session expiry rechecks last_at after acquiring ownership.",
        "Separate worker roles, fair stage rotation, owner failure backoff, busy draining and bounded maintenance. Pending expiry chunks drain continuously instead of being limited to one chunk per minute."
    ],
    "implementation_refinements": [
        "Quality and network facts use semantic keyed reducers rather than duplicating their fact tables as shard partials; this preserves existing prepared readers and removes cross-owner first-row races.",
        "Prepared totals remain cumulative snapshots and can include newer provisional contributions. Protocol-2 coverage explicitly calls the committed intake/fold barrier a lower bound and exposes counts_include_provisional_tail; it does not claim immutable complete-generation snapshots.",
        "An indexed keyset cursor bounds person-retention candidate reads before activity checks; it avoids the old unbounded NOT EXISTS search through an entire active cohort. Its scan/drain rate remains a representative-load acceptance item.",
        "The new protocol is activated by matching binaries after an operational drain/fence of old writers, not by a mixed-binary rolling feature flag. Legacy binaries do not understand the fence; all old roles must be stopped before activation."
    ],
    "review_and_corrections": [
        "Kept the original PostgreSQL 500-player query assertion (<60). Initial per-partition implementation generated about 8900 statements; batching reduced it through 78 and 62 to 59. Recorded final timings are test observations, not an HTTP latency claim.",
        "Found a real CREATE INDEX CONCURRENTLY/advisory-lock waiter deadlock. Migration acquisition now commits between nonblocking advisory-lock attempts. Two separate migrating processes pass the regression.",
        "Added resumable expansion after concurrent-index interruption, including invalid-index replacement, idempotent fixed-row seeding and preservation of existing rows.",
        "Initial SQLite UNION ordering and static-migration empty-string default errors were corrected; receipts retain those failed attempts.",
        "Kept the existing backlog assertion by changing its source from the intentionally stale reporting summary to the exact occupied-credit ledger. No invariant was removed.",
        "Isolated the earlier BIGINT migration test at revisions 0043/0044 so later deliberately irreversible migrations do not invalidate its safe downgrade checks. Overflow refusal and preservation assertions remain.",
        "A single-process threaded throughput diagnostic exposed GIL/test-harness effects and was retained separately. The final diagnostic uses one or four separate initialized Python processes with the same 2-CPU/1-GiB container limit."
    ],
    "test_receipts": receipts,
    "known_failure": {
        "test": "test_race_statistics.py::test_operator_queue_counts_explicit_publication_work_and_oldest_age",
        "outcome": "Existing Studio overview response lacks publications; KeyError reproduced with task-start telemetry sources. Assertion preserved. Excluded explicitly from the final 125-case relevant SQLite run.",
        "evidence": ["baseline-operator.xml", "broad.xml", "final-sqlite.xml"]
    },
    "transient_test_failure": "The initial CPU-capped broader PostgreSQL run passed 37 cases and failed two concurrent HTTP checks at the existing one-slot telemetry parser's 100ms admission timeout. Both original tests passed on standalone rerun; no middleware limit or assertion was changed.",
    "original_reproduction": "Task-start telemetry sources block ingestion while ProductState(1) is held. Final PostgreSQL regression holds both that row and the actor owner, yet ingress completes and another actor partition progresses.",
    "benchmark": benchmark,
    "capacity_assessment": "Four processes delivered 1.14x uniform and 1.34x hot-context throughput in the short 2-CPU diagnostic; the proposed >=3x scaling gate is NOT established. These are 4000-event queue drains with 1000 players and no HTTP producer or gameplay, not a million-DAU qualification.",
    "remaining_acceptance": [
        "Production-like sustained HTTP ingestion at declared batch sizes and DAU/peak assumptions; scheduled p95/p99 latency, freshness and recovery headroom",
        "Representative account/history cardinalities and query plans, backlog size, retained-state growth, maintenance drain rate, WAL/IO/CPU/memory and multi-process scaling with measured resource headroom",
        "Concurrent gameplay latency and skew, including a popular shared semantic key; one key intentionally retains one reducer",
        "Backup/restore rehearsal and explicit migration maintenance window: widening the prepared ProductMetric value still requires a PostgreSQL table rewrite and sufficient timeout/disk budget",
        "Operator-authorized deployment with old writers drained/fenced, capacity reconciliation and matching API/worker/simulator artifacts. Roll back concurrency with one new-protocol worker; legacy binary downgrade is refused."
    ],
    "commands": [
        "Windows venv python -m pytest tests/test_telemetry_parallel.py tests/test_telemetry_counter.py tests/test_product_analytics.py tests/test_privacy.py tests/test_studio_simulator.py tests/test_race_statistics.py tests/test_client_quality.py tests/test_network_health.py -k 'not postgres and not operator_queue_counts_explicit_publication_work_and_oldest_age' -q --tb=short --junitxml=../build/telemetry-parallelism-2026-10-22/verified-sqlite.xml (cwd backend)",
        "Windows venv python -m pytest tests/test_telemetry_parallel.py tests/test_product_analytics.py -k 'not postgres' -q --tb=short --junitxml=../build/telemetry-parallelism-2026-10-22/causal-sqlite.xml (cwd backend)",
        "Windows venv python -m pytest tests/test_product_analytics.py tests/test_privacy.py -k 'cleanup or retirement or erasure or delete or retained' -q --tb=short --junitxml=../build/telemetry-parallelism-2026-10-22/final-expiry.xml (cwd backend)",
        "WSL Docker cached bmt-full-20261018:86d38519ffb5ac1f runtime, --cpus=2 --memory=1024m --pids-limit=128 --network container:bmt-backend-test, source/fixture-env read-only, PYTHONPATH=/task/backend, PYTHONDONTWRITEBYTECODE=1; python /evidence/run_postgres.py tests/test_telemetry_parallel.py tests/test_telemetry_counter.py tests/test_product_analytics.py tests/test_studio_platform_postgres.py (verified-postgres.xml)",
        "Same Docker command, python /evidence/run_postgres.py tests/test_telemetry_parallel.py tests/test_product_analytics.py tests/test_studio_platform_postgres.py (causal-postgres.xml)",
        "Same Docker command, python /evidence/run_postgres.py tests/test_race_statistics_postgres.py tests/test_network_health_postgres.py tests/test_telemetry_parallel.py::test_postgres_expansion_resumes_after_interrupted_concurrent_index (postgres-recovery-http.xml)",
        "Same Docker command with preserved baseline source mounted as /task/backend, python /evidence/run_postgres.py /evidence/test_original_lock.py (original-lock.xml)",
        "Same Docker command, python /evidence/benchmark.py; four owned generated schemas, all dropped in finally blocks (benchmark.json)",
        "Windows venv python -m ruff check all changed runtime/migration/test Python files: passed",
        "Read-only rg/Get-Content source review, exact task-start byte snapshots and SHA256 fingerprints; task-only unified patch generated without staging unrelated work"
    ],
    "checkpoint": "task-only.patch; before/ and source-sha256.json preserve exact inputs and final source fingerprints",
    "fixture_cleanup": "Read-only check found zero other fixture clients and zero remaining generated task schemas; bmt-backend-test was stopped to restore its original state. Other containers and application databases were not changed.",
    "device_status": "No device test or attachment check; backend-only change. No APK, deployment or live data mutation."
}
(HERE / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"changed_files": len(changed), "receipts": receipts}))
