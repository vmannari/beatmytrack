"""Retain a task-only source patch and actual validation receipt."""
import difflib
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
existing = ["backend/bmt_backend/" + name for name in (
    "telemetry_processing.py", "telemetry_erasure.py", "maintenance.py", "race_statistics.py",
    "network_health.py", "studio_platform_models.py", "studio_analysis.py", "track_models.py")]
added = ["backend/bmt_backend/migrations/versions/0056_bounded_retention.py",
         "backend/tests/test_bounded_retention.py"]
patch = []


def retention_projection(original, current):
    # The Studio reporting agent owns the endpoint below this projector. Build
    # exactly our narrow projector/legacy-cleanup edits against the task start.
    edited = original.replace("case, cast, delete, func", "case, cast, func")
    edited = edited.replace("active_events, client_first = {}, {}", "active_events, client_first, latest_days = {}, {}, {}")
    edited = edited.replace("        key = event.occurred_at // DAY, event.player_id, digest(context)\n",
        "        key = event.occurred_at // DAY, event.player_id, digest(context)\n"
        "        latest_days[event.player_id] = max(latest_days.get(event.player_id, key[0]), key[0])\n")
    edited = edited.replace("                first_at=event.occurred_at,\n",
        "                first_at=event.occurred_at,\n                last_day=event.occurred_at // DAY,\n")
    edited = edited.replace("    for identity, row in people.items():\n",
        "    for identity, row in people.items():\n"
        "        if identity in latest_days and row.last_day is not None:\n"
        "            row.last_day = max(row.last_day, latest_days[identity])\n")
    first, last = "def cleanup(session, at, limit, fact_days):", "def sums(model, names=COUNTERS):"
    edited = edited[:edited.index(first)] + current[current.index(first):current.index(last)] + edited[edited.index(last):]
    return edited


for name in existing + added:
    old = (HERE / "before" / name).read_text() if name in existing else ""
    current = (ROOT / name).read_text()
    new = retention_projection(old, current) if name.endswith("/studio_analysis.py") else current
    patch += difflib.unified_diff(old.splitlines(keepends=True), new.splitlines(keepends=True),
        fromfile="a/" + name if old else "/dev/null", tofile="b/" + name, n=2)
(HERE / "task-only.patch").write_text("".join(patch))
report = {
    "requirement_ids": ["BSR2-F06", "BSR2-F07", "BSR2-F08"],
    "implementation": {
        "BSR2-F06": "Race receipt/day and network-day cleanup signal progress into maintenance.more; isolated backlogs immediately retain a draining turn.",
        "BSR2-F07": "AnalysisPerson.last_day expiry index replaces recurring first-cohort sweeps. New projections advance the latest fact day, legacy NULLs upgrade once in bounded actor-fenced batches, due candidates recheck latest indexed day after acquiring ownership. First cohort and exact retention floor remain unchanged.",
        "BSR2-F08": "Each identity class deletes at most1000 selected keys per transaction. Expired families lock before bounded token deletion and only empty families are removed, preventing unbounded rotation-history cascades. Busy expired families still reportmore. CLI drains up to100 batches by default, accepts1-1000 batches, and explicitly returnsmore/budget_exhausted."},
    "changed_files": existing + added,
    "source_sha256": {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in existing + added},
    "validation": [
        {"command": ".tools/backend-secure-venv/Scripts/python.exe -m pytest backend/tests/test_bounded_retention.py -q -k 'not postgres'", "result": "Initial10passed, then11passed after CLI test; finalfocused+legacymaintenance12passed before added migration test.", "receipt": "focused-sqlite.txt"},
        {"command": ".tools/backend-secure-venv/Scripts/python.exe -m pytest backend/tests/test_bounded_retention.py -q -k 'expiry_migration and not postgres'", "result": "1passed,21deselected; populated0056 downgrade/upgrade preserves cohort and lazily initializes deadline.", "receipt": "migration-sqlite.txt"},
        {"command": ".tools/backend-secure-venv/Scripts/python.exe -m pytest backend/tests/test_bounded_retention.py backend/tests/test_maintenance.py backend/tests/test_telemetry_parallel.py backend/tests/test_studio_platform.py backend/tests/test_network_health.py backend/tests/test_race_statistics.py -q -k 'not postgres'", "result": "98passed,1failed,21deselected. Failure in pre-existing overview/publications contract fixture; root replay against archived original HEAD reproduces identical KeyError; see root/original-overview-fixture.xml. Assertion retained."},
        {"command": ".tools/backend-secure-venv/Scripts/python.exe -m ruff check <10 owned source/test paths>", "result": "All checks passed."},
        {"command": "git diff --check -- <10 owned source/test paths>", "result": "Passed; only existing CRLF normalization notices."},
        {"command": ".tools/backend-secure-venv/Scripts/python.exe docs/evidence/backend-scale-other-fixes-2026-10-23/retention/probe.py", "result": "1000/10000/100000 retained active old-cohort people each require approximately100 SQLiteVM instructions, no expiry backlog; both existence probes use covering ix_analysis_person_expiry.", "receipt": "probe.json"},
        {"command": ".tools/backend-secure-venv/Scripts/python.exe -m bmt_backend.maintenance --help", "result": "CLI exposes --identity-batches and bounded1000-row-per-class help."},
        {"command": "Coordinated disposable PostgreSQL run: tests/test_bounded_retention.py -k postgres", "result": "Root coordinates10 cases, including locked-family backlog, locked-actor retry, actual EXPLAIN for10000 current people and populated0056 migration. See root receipts for final result."}],
    "objective_review": [
        "Split NULL/due existence checks so the optimizer can stop at each expiry-index prefix rather than combining a population bitmap.",
        "Retained active people no longer trigger old-cohort maintenance. Legacy deadline work is one-time and bounded, without a historical migration rewrite.",
        "Family lock order matches refresh: parent before token. Child deletion budget applies to all selected families together, not once per family. Empty-parent recheck makes the remaining cascade zero.",
        "A single1000-row/hour CLI pass would under-drain a million-player workload; default finite100-transaction drain and explicit backlog/budget flags avoid that hidden ceiling."],
    "remaining_acceptance": [
        "Matching0056 schema/API/worker rollout and representative PostgreSQL migration duration/index/storage acceptance are required; no live changes performed.",
        "LegacyNULL deadline backfill and identity cleanup service rate must be measured against actual retained population, session rotations and scheduled runtime; followmore/budget_exhausted with another budgeted job.",
        "Synthetic local query-work and correctness checks do not certify millionDAU/500millionaccounts cloud capacity."],
    "checkpoint": "task-only.patch excludes the concurrent Studio reporting endpoint changes; no shared-workspace commit, deployment or live account mutation."}
(HERE / "report.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps({"files": len(existing) + len(added), "patch_lines": len(patch), "report": str(HERE / "report.json")}))
