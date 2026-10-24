"""Lint, hash and retain a scoped patch while preserving concurrent work."""
import ast
import difflib
import hashlib
import json
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
EXISTING = ["backend/bmt_backend/"+name+".py" for name in (
    "app", "config", "middleware", "storage", "gcs_storage", "object_models", "maintenance", "rivalry", "challenges",
    "service_worker", "database_privileges", "economy", "economy_models", "track_models", "discovery_v3", "tracks",
    "privacy", "worker", "studio_finance")]
EXISTING += ["backend/deploy/gcp/staging.py", "backend/deploy/object_archive.py", "backend/deploy/.env.example",
    "game/export_presets.cfg", "backend/schemas/discovery-query-v3.schema.json", "backend/schemas/discovery-page-v3.schema.json"]
EXISTING += ["game/backend/"+name+".gd" for name in
    ("backend_client", "cloud_tracks", "weekly_rivalry_client", "challenges_client", "discovery_windows")]
NEW = ["backend/bmt_backend/"+name+".py" for name in
    ("cost_archives", "cost_maintenance", "ghost_http", "ghost_wire", "http_costs", "immutable_payloads", "object_garbage",
     "pack_io", "packed_storage", "preview_wire")]
NEW += ["backend/bmt_backend/migrations/versions/0065_packed_objects.py", "backend/bmt_backend/migrations/versions/0066_cost_archives.py",
    "backend/deploy/compose.cost.yaml", "backend/deploy/gcp/cost_profile.py", "backend/tools/bundle_official_content.py",
    "backend/schemas/packed-ghost-v1.schema.json"]
NEW += ["backend/tests/test_"+name+".py" for name in
    ("cost_archives", "cost_http", "cost_maintenance", "cost_transport", "packed_storage")]
NEW += ["game/backend/"+name+".gd" for name in
    ("bundled_tracks", "ghost_wire", "preview_dictionary", "recording_cache", "recording_downloads")]
NEW += ["game/tests/test_cost_downloads.gd", "game/tests/test_cost_downloads_http.gd",
        "docs/COST_OPTIMISATION_IMPLEMENTATION_2026_10_24.md"]
NEW += [str(path.relative_to(ROOT)).replace("\\", "/") for path in sorted((ROOT / "game/resources/cloud_tracks").glob("*.json"))]
NEW += [str(path.relative_to(ROOT)).replace("\\", "/") for path in sorted(HERE.glob("*.py"))]
LATE_DOCS = ["AGENTS.md", "DEVELOPMENT_STATUS.md", "backend/deploy/README.md", "docs/README.md"]


def selected_before(name):
    path = HERE / "checkpoint-before" / name
    if path.exists():
        return path.read_bytes()
    path = HERE / "before" / name
    if path.exists():
        return path.read_bytes()
    status = json.loads((HERE / "baseline.json").read_text())["git_status"]
    assert not any(line[3:] == name for line in status.splitlines()), "Uncaptured dirty baseline: "+name
    data = subprocess.check_output(["git", "show", "HEAD:"+name], cwd=ROOT)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return data


def scoped_lines(name, before, after):
    if name not in ("backend/bmt_backend/discovery_v3.py", "game/backend/discovery_windows.gd"):
        return before
    # Produce the base that contains the unrelated concurrent changes, so the
    # reverse-checkable patch removes only this task's preview protocol edits.
    base = []
    for tag, i, j, a, b in difflib.SequenceMatcher(None, before, after, autojunk=False).get_opcodes():
        old, new = before[i:j], after[a:b]
        joined = "".join(old+new)
        owned = (any(marker in joined for marker in ("typing import Annotated", "preview_cache", "known_previews", "compact_previews"))
                 if name.endswith("discovery_v3.py") else "Daily picks & more" not in joined)
        base.extend(old if tag == "equal" or owned else new)
    return base


def xml_summary(path):
    suite = ET.parse(path).getroot().find("testsuite")
    return {key: suite.attrib[key] for key in ("tests", "failures", "errors", "skipped", "time")}


def main():
    files = EXISTING + NEW + [name for name in LATE_DOCS if (HERE / "checkpoint-before" / name).exists()]
    python = [name for name in files if name.endswith(".py")]
    lint = subprocess.run([sys.executable, "-m", "ruff", "check", *python], cwd=ROOT, capture_output=True, text=True, check=False)
    (HERE / "ruff.txt").write_text(lint.stdout+lint.stderr, encoding="utf-8")
    for name in python:
        ast.parse((ROOT / name).read_text(encoding="utf-8"), filename=name)
    if lint.returncode:
        print(lint.stdout+lint.stderr)
        raise SystemExit(lint.returncode)
    patch, hashes, excluded = [], {}, []
    for name in files:
        path = ROOT / name
        after = path.read_text(encoding="utf-8").splitlines(True)
        if name in NEW:
            before, source = [], "/dev/null"
        else:
            original = selected_before(name).decode("utf-8").splitlines(True)
            before, source = scoped_lines(name, original, after), "a/"+name
            if before != original:
                excluded.append(name)
        diff = [line if line.endswith("\n") else line+"\n\\ No newline at end of file\n"
                for line in difflib.unified_diff(before, after, fromfile=source, tofile="b/"+name)]
        if diff:
            patch.extend(["diff --git a/"+name+" b/"+name+"\n", *diff])
            hashes[name] = {"sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "bytes": path.stat().st_size}
    patch_path = HERE / "scoped-change.patch"
    patch_path.write_text("".join(patch), encoding="utf-8", newline="\n")
    checked = subprocess.run(["git", "apply", "--reverse", "--check", str(patch_path)], cwd=ROOT, capture_output=True, text=True, check=False)
    (HERE / "checkpoint-check.txt").write_text(checked.stdout+checked.stderr+"exit="+str(checked.returncode)+"\n", encoding="utf-8")
    native = json.loads((HERE / "native-checks.json").read_text())
    report = {"requirements": [f"DCOI{index:02d}" for index in range(1, 11)], "sources": hashes,
        "baseline": "baseline.json, before/, checkpoint-before/ for documentation captured immediately before this task's edit",
        "concurrent_hunks_excluded": excluded, "reverse_patch_check": checked.returncode,
        "validation": {path.name: xml_summary(path) for path in sorted(HERE.glob("*.xml"))},
        "native": [{"name": row["name"], "passed": row["passed"], "seconds": row["seconds"],
                    "results": [line for line in row["output"].splitlines() if re.search(r'\d+ checks|\d+ failures', line)]} for row in native],
        "ghost_wire": json.loads((HERE / "ghost-wire-benchmark.json").read_text()),
        "linux_supervisor": json.loads((HERE / "linux-supervisor.json").read_text()),
        "commands": [
            ".tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_cost_archives.py backend/tests/test_cost_transport.py backend/tests/test_cost_maintenance.py backend/tests/test_packed_storage.py backend/tests/test_storage.py backend/tests/test_s3_storage.py backend/tests/test_gcs_storage.py backend/tests/test_earned_coins.py backend/tests/test_privacy.py backend/tests/test_priority_scaling.py backend/tests/test_bounded_retention.py backend/tests/test_race_acceptance_sql.py backend/tests/test_gcp_staging.py backend/tests/test_cloud_setup.py backend/tests/test_service_worker.py -k 'not postgres' -m 'not godot' -q --tb=short --junitxml=docs/evidence/cost-optimisation-implementation-2026-10-24/final-backend-regression.xml",
            ".tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_cost_http.py -q -s --tb=short --junitxml=docs/evidence/cost-optimisation-implementation-2026-10-24/native-http.xml",
            ".tools/backend-venv/Scripts/python.exe docs/evidence/cost-optimisation-implementation-2026-10-24/native_checks.py",
            "wsl.exe -d Ubuntu -- python3 '/mnt/c/Codes/Godot/Beat my track/docs/evidence/cost-optimisation-implementation-2026-10-24/supervisor_probe.py'",
            ".tools/backend-venv/Scripts/python.exe docs/evidence/cost-optimisation-implementation-2026-10-24/finalize.py"],
        "limitations": ["No production PostgreSQL concurrency/capacity pass: local configured endpoint unavailable",
            "No player-day transfer or Google Cloud bill saving measured", "No million-DAU or response-time certification",
            "No phone/tablet attachment check or physical-device test performed", "No APK, purchase, live mutation or deployment",
            "Known existing0054 downgrade guard remains in initial domain results; assertions not weakened"],
        "rollout": "Matching migrations0065/0066, grants, API/worker/client readers, restore rehearsal and PostgreSQL calibration before enabling cost profile"}
    (HERE / "report.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
    print(json.dumps({"files": len(hashes), "ruff": lint.returncode, "reverse_patch_check": checked.returncode,
                      "native_suites_passed": sum(row["passed"] for row in native)}))
    raise SystemExit(checked.returncode)


if __name__ == "__main__":
    main()
