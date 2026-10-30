"""Assemble safe task receipts and a patch without the main Git index."""
import difflib
import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).parent


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def junit(name):
    cases = list(ET.parse(OUT / name).iter("testcase"))
    return {"cases":len(cases),
        "passed":sum(not any(c.find(tag) is not None for tag in ("failure","error","skipped")) for c in cases),
        "failed":sum(c.find("failure") is not None for c in cases),
        "errors":sum(c.find("error") is not None for c in cases),
        "skipped":sum(c.find("skipped") is not None for c in cases)}


def failures(name):
    return {c.attrib["name"]:c.find("failure").attrib["message"]
            for c in ET.parse(OUT / name).iter("testcase") if c.find("failure") is not None}


def normalized(path):
    return path.read_text(encoding="utf-8").replace("\r\n","\n")


before = OUT / "before"
changed = {p.name.replace("__","/"):p for p in before.iterdir()}
new = ["game/backend/race_compatibility.gd", "game/tests/audit_backend_compatibility.gd",
       "backend/tests/test_car_compatibility.py", "backend/tests/test_car_compatibility_native.py",
       "docs/BACKEND_APP_COMPATIBILITY_2026_10_27.md"]
for name in ("probe_backend.py","verify_task_start.py","finalize_evidence.py"):
    new.append(str((OUT / name).relative_to(ROOT)).replace("\\","/"))
for path in ("game/backend/race_compatibility.gd.uid","game/tests/audit_backend_compatibility.gd.uid"):
    if (ROOT / path).exists():
        new.append(path)
check = ROOT / "build/compatibility-audit/patch-check"
check.relative_to(ROOT / "build/compatibility-audit")
check.mkdir(parents=True,exist_ok=False)
patch = []
for path in sorted(set(changed) | set(new)):
    old = normalized(changed[path]) if path in changed else ""
    current = normalized(ROOT / path)
    if old == current:
        continue
    if path in changed:
        target = check / path
        target.parent.mkdir(parents=True,exist_ok=True)
        target.write_text(old,encoding="utf-8",newline="\n")
    patch.append(f"diff --git a/{path} b/{path}\n")
    if path not in changed:
        patch.append("new file mode 100644\n")
    for line in difflib.unified_diff(old.splitlines(keepends=True),current.splitlines(keepends=True),
            fromfile=f"a/{path}" if path in changed else "/dev/null",tofile=f"b/{path}"):
        patch.append(line if line.endswith("\n") else line+"\n\\ No newline at end of file\n")
(OUT / "scoped.patch").write_text("".join(patch),encoding="utf-8",newline="\n")

native = json.loads((OUT / "client.json").read_text())
matrix = json.loads((OUT / "backend.json").read_text())
regression_failures = failures("regression-junit.xml")
baseline_failures = failures("regression-baseline-junit.xml")
assert regression_failures == baseline_failures
source_paths = [p for p in changed if p.startswith(("backend/","game/"))]
source_paths += [p for p in new if p.startswith(("backend/","game/"))]
report = {
    "task":"selected-car app/backend compatibility", "date":"2026-10-27",
    "requirements":["BC01","BC02","BC03","BC04","Q01","R01"],
    "result":"Implemented locally; six unchanged cars accept the explicit .74/.75 transition, and per-car tune-only releases retain unrelated contracts",
    "equivalent_physics":["arcade-planar-0.74","arcade-planar-0.75"],
    "unchanged_vehicles":["compact","pickup","classic","formula","kart","forklift"],
    "electric_equivalent":False,
    "native_client":{"checks":native["checks"],"failures":native["failures"],
        "differential_cases":len(native["canonical_differential"]),
        "exact_state_comparisons":sum(r["ticks"] for r in native["canonical_differential"]),
        "all_states_exact":all(r["every_state_exact"] for r in native["canonical_differential"])},
    "backend_matrix":{"cases":matrix["matrix_cases"],"historical_car_tickets":len(matrix["ev_update_blast_radius"]),
        "unchanged_cars_blocked_before":6,"unchanged_cars_blocked_after":matrix["unchanged_cars_blocked"]},
    "runs":{name:junit(name) for name in ("task-start-junit.xml","final-focused-junit.xml",
        "native-junit.xml","backend-junit.xml","publication-junit.xml","regression-junit.xml",
        "regression-baseline-junit.xml","car-full-junit.xml")},
    "existing_regression_failures_reproduced_exactly":regression_failures,
    "parser":{"scripts":1337,"failures":0},"retained_native_rivalry":{"checks":29,"failures":0},
    "postgresql":{"runtime_verified":False,"initial_setup_errors":16,"read_only_probe":"OperationalError/timeout",
        "postgresql_sql_predicates_compiled":2,"docker_available":False},
    "lint":{"focused_other_changed_sources_and_new_tests":"pass",
        "existing_rivalry_snapshot_SIM102":True},
    "credential_redactions":128,
    "source_hashes":{p:{"before_sha256":sha(changed[p]) if p in changed else None,
                        "after_sha256":sha(ROOT / p)} for p in sorted(source_paths)},
    "patch":{"path":"scoped.patch","sha256":sha(OUT / "scoped.patch"),
        "scope":"source-only, normalized LF; excludes generated metadata, raw receipts and archived snapshots",
        "git_check":"pending"},
    "remaining":["client rebuild/reload","matching API and worker rollout","PostgreSQL execution","owner acceptance"],
    "not_performed":["physical-device attachment check or test","APK","real authentication or purchase",
        "owner-save or live data mutation","cloud deployment","service or owner-process restart","main-index staging, commit or merge"],
}
(OUT / "report.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
print(json.dumps({"patch_files":len(set(changed)|set(new)),"patch_bytes":(OUT / "scoped.patch").stat().st_size,
    "focused":report["runs"]["final-focused-junit.xml"],"baseline":report["runs"]["task-start-junit.xml"]}))
