"""Retain this area's reviewable source delta and actual validation receipts."""

import difflib
import hashlib
import json
from pathlib import Path
import subprocess


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
FILES = (
    "backend/bmt_backend/app.py",
    "backend/bmt_backend/studio_analysis.py",
    "backend/bmt_backend/studio_reporting.py",
    "backend/tests/test_studio_platform.py",
    "backend/tests/test_studio_simulator.py",
    "backend/tests/test_studio_reporting.py",
)


def main():
    patch = []
    for relative in FILES:
        current = (ROOT / relative).read_text(encoding="utf-8")
        before = HERE / "before" / Path(relative).name
        original = before.read_text(encoding="utf-8") if before.exists() else ""
        if relative.endswith("studio_analysis.py"):
            # Retention owns the projector/cleanup changes in the shared file.
            # This checkpoint isolates only this area's import and report reader.
            old_prefix, separator, _old_reader = original.partition("def sums(")
            _new_prefix, _separator, new_reader = current.partition("def sums(")
            current = old_prefix.replace("from .studio_queries import read_snapshot\n", "") + separator + new_reader
        patch.append(f"diff --git a/{relative} b/{relative}\n")
        if not before.exists():
            patch.append("new file mode 100644\n")
        patch.extend(difflib.unified_diff(
            original.splitlines(keepends=True), current.splitlines(keepends=True),
            fromfile=f"a/{relative}" if before.exists() else "/dev/null", tofile=f"b/{relative}",
        ))
    (HERE / "task-only.patch").write_text("".join(patch), encoding="utf-8")
    report = {
        "requirement": "BSR2-F10",
        "status": "Implemented locally; infrastructure provisioning and rollout remain",
        "result": "Exact arbitrary-window Studio behaviour analyses require isolated physical reporting storage; analytical facts never fall back to primary",
        "implementation": [
            "Dedicated lazy PostgreSQL engine, one report slot per API process, one pooled connection, no overflow, 100 ms pool wait",
            "Server read-only repeatable-read snapshot and one total SQL budget, default 5000 ms, apportioned across statements",
            "Primary constant metadata probe returns inserted WAL position, system identifier, database and schema; standby must match identity and replay through the fence before report snapshot opens",
            "At most 250 ms bounded standby catch-up; unavailable/unconfigured/busy/permission-denied/mismatched readers return 503 and Retry-After, without changing primary readiness",
            "Last replayed transaction age is nullable coverage, not a stale-data admission heuristic; quiet caught-up replicas remain available",
            "Original exact distinct, cohort, population, dimension and journey SQL retained; explicit test-only engine injection preserves fixtures",
        ],
        "design_review_and_refinements": [
            "Summing fixed daily distinct counts cannot preserve exact distinct users across arbitrary overlapping windows/dimensions; isolate the unchanged exact reports instead",
            "Replica wall-clock transaction age does not establish replication lag; a matching primary inserted-WAL fence establishes request-start completeness",
            "Inserted WAL position covers already acknowledged asynchronous commits; current write position alone is insufficient under synchronous_commit=off",
            "Numeric WAL positions alone do not authenticate a physical cluster; require matching system identifier, database and schema",
            "The fence must be checked before opening the repeatable-read snapshot, so an earlier snapshot cannot retain an erased contribution",
        ],
        "changed_files": list(FILES),
        "config_dependencies_owned_by_root": {
            "studio_analysis_database_url": "required dedicated PostgreSQL hot-standby URL; empty means reports return actionable 503",
            "studio_analysis_statement_timeout_ms": "default 5000; total SQL budget as well as per-statement ceiling",
        },
        "least_privilege_additions": [
            "GRANT EXECUTE ON FUNCTION pg_catalog.pg_control_system() TO <api_role>, <analysis_reader_role>",
            "Analysis reader requires CONNECT to the replica database, USAGE on the matching schema, and SELECT on studio_analysis_state, studio_analysis_people, studio_analysis_days, studio_analysis_sessions and product_state",
            "Missing monitoring-function privilege fails closed with 503; no live grants were issued",
        ],
        "validation": [
            {
                "coordinated_by": "Root final combined validation after source freeze",
                "result": "63 passed, 5 deselected across reporting/platform/performance/simulator SQLite tests",
                "receipt": "../root/final-studio.xml",
            },
            {
                "command": "PYTHONPATH=backend .tools/backend-secure-venv/Scripts/python.exe -m pytest backend/tests/test_studio_reporting.py backend/tests/test_studio_platform.py backend/tests/test_studio_performance.py backend/tests/test_studio_simulator.py -k 'not postgres' -q --junitxml docs/evidence/backend-scale-other-fixes-2026-10-23/studio/sqlite-final.xml",
                "result": "60 passed, 5 deselected before final cluster-identity-only refinement; exact report mathematics and wired request path passed",
                "receipt": "sqlite-final.xml",
            },
            {
                "command": "PYTHONPATH=backend .tools/backend-secure-venv/Scripts/python.exe -m pytest backend/tests/test_studio_reporting.py -k 'not postgres' -q --junitxml docs/evidence/backend-scale-other-fixes-2026-10-23/studio/reporting-final.xml",
                "result": "15 passed, 3 deselected after final identity/quiet-replica refinements; PostgreSQL selection is covered by root's combined run and physical fixture",
                "receipt": "reporting-final.xml",
            },
            {
                "command": "wsl -d Ubuntu -- bash '/mnt/c/Codes/Godot/Beat my track/docs/evidence/backend-scale-other-fixes-2026-10-23/studio/run_physical_replica.sh'",
                "result": json.loads((HERE / "physical_replica_result.json").read_text()),
                "receipt": "physical_replica_result.json",
            },
            {
                "command": ".tools/backend-secure-venv/Scripts/python.exe -m ruff check backend/bmt_backend/studio_reporting.py backend/tests/test_studio_reporting.py backend/bmt_backend/studio_analysis.py backend/bmt_backend/app.py backend/tests/test_studio_platform.py backend/tests/test_studio_simulator.py",
                "result": "All checks passed",
            },
            {
                "command": "git apply --check --reverse --ignore-space-change docs/evidence/backend-scale-other-fixes-2026-10-23/studio/task-only.patch",
                "result": "Passed; whitespace option accounts for the shared files' mixed CRLF/LF line endings",
            },
        ],
        "retained_initial_corrections": [
            "First SQLite pass: 3 failures and 57 passes; overlapping shared-file atomic patches lost endpoint routing, caught by no-fallback/separate-engine/busy assertions; restored reader hunks after projector edits completed",
            "Initial physical fixture standby exited because its tmpfs data directory had mode 0755; corrected to 0700 and made readiness a hard precondition",
            "Physical HTTP fixture initially tried creating object storage under a read-only source mount; moved synthetic objects into its temporary container filesystem",
            "Independent review removed the quiet-replica timestamp rejection and added cluster/database/schema authentication plus explicit monitoring-function grants",
        ],
        "limits_and_remaining_acceptance": [
            "Analytical CPU remains O(retained matching facts); this change isolates gameplay storage and bounds query work rather than making arbitrary exact aggregates constant-cost",
            "Provision a matching physical standby, apply explicit grants and set the reporting URL before matching API rollout; otherwise the behaviour tab deliberately returns 503",
            "Capacity is bounded per API process; size replica connections and API process count together",
            "The physical probe verifies correctness, privacy visibility, real cancellation and isolation on tiny disposable fixtures; it does not certify million-DAU or 500-million-account report latency, memory or deployment behaviour",
            "Representative high-cardinality report/load acceptance remains; no live backend, account, queue, deployment or device action occurred",
        ],
        "checkpoint": {
            "head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
            "patch": "task-only.patch",
            "source_sha256": {relative: hashlib.sha256((ROOT / relative).read_bytes()).hexdigest() for relative in FILES},
            "note": "studio_analysis.py hash includes the concurrent retention projector; this area's patch excludes those separately owned hunks. Root owns the combined config/README/checkpoint.",
        },
    }
    (HERE / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"report": str(HERE / "report.json"), "files": len(FILES)}))


if __name__ == "__main__":
    main()
