"""Validate and package only this audit's documentation/evidence; no runtime writes."""
import csv
import difflib
import hashlib
import json
import re
import subprocess
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
DOCUMENT = ROOT / "docs/BACKEND_COMPREHENSIVE_AUDIT_2026_10_26.md"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    # PowerShell 5 redirects text as UTF-16; retain content with portable UTF-8 encoding.
    for path in OUT.glob("*.log"):
        raw = path.read_bytes()
        if raw.startswith((b"\xff\xfe", b"\xfe\xff")):
            path.write_text(raw.decode("utf-16"), encoding="utf-8")
    inventory = json.loads((OUT/"inventory.json").read_text(encoding="utf-8"))
    initial = json.loads((OUT/"inventory-start.json").read_text(encoding="utf-8"))
    first = {x["path"]: x for x in initial["files"] if "/build/" not in x["path"]}
    last = {x["path"]: x for x in inventory["files"]}
    drift = {"added": sorted(last.keys()-first.keys()), "removed": sorted(first.keys()-last.keys()),
        "changed": sorted(k for k in first.keys() & last.keys() if first[k]["sha256"] != last[k]["sha256"])}
    runtime = json.loads((OUT/"runtime-inventory.json").read_text(encoding="utf-8"))
    with (OUT/"endpoints.csv").open("w",newline="",encoding="utf-8") as stream:
        writer = csv.writer(stream)
        writer.writerow(["application", "methods", "path", "function", "source", "line"])
        for role in ("api", "admin"):
            for row in runtime[role]:
                writer.writerow([role,"|".join(row["methods"]),row["path"],row["function"],row["source"],row["line"]])
    with (OUT/"tables.csv").open("w",newline="",encoding="utf-8") as stream:
        writer=csv.writer(stream)
        writer.writerow(["table", "columns", "orm_index_names"])
        for table in runtime["tables"]:
            writer.writerow([table["name"],"|".join(table["columns"]),"|".join(i["name"] for i in table["indexes"])])
    # Make the new text artifacts portable and reverse-checkable, including
    # pytest's one-line XML files which otherwise have no final newline.
    for path in [DOCUMENT, *[p for p in OUT.iterdir() if p.is_file() and p.name!="scoped-change.patch"]]:
        value = path.read_text(encoding="utf-8").replace("\r\n", "\n")
        path.write_bytes((value if value.endswith("\n") else value+"\n").encode("utf-8"))
    source = DOCUMENT.read_text(encoding="utf-8")
    links, missing = [], []
    for target in re.findall(r"\]\(([^)]+)\)", source):
        if target.startswith(("http://","https://","#")):
            continue
        path = (DOCUMENT.parent/target.split("#")[0]).resolve()
        links.append(target)
        if not path.is_file():
            missing.append(target)
    assert not missing, missing
    assert all(f"## {letter}." in source for letter in "ABCDEFGHIJKL")
    assert all(f"AUD-F{i:02d}" in source for i in range(1,13))
    tests = {}
    for filename in ("focused-tests.xml","audit-probes.xml","initial-test-fixture-errors.xml"):
        tree=ET.parse(OUT/filename).getroot()
        suites=tree.findall("testsuite") if tree.tag=="testsuites" else [tree]
        tests[filename] = {key: sum(int(s.attrib.get(key,0)) for s in suites) for key in ("tests","errors","failures","skipped")}
    assert tests["focused-tests.xml"] == {"tests":135,"errors":0,"failures":0,"skipped":3}
    assert tests["audit-probes.xml"] == {"tests":5,"errors":0,"failures":0,"skipped":0}
    model=json.loads((OUT/"cost-model.json").read_text(encoding="utf-8"))
    for row in model["scenarios"]:
        total=row["total_eur_month"]
        assert abs(total-sum(row["components_eur_month"].values())) < 1e-7
        assert abs(row["cost_per_1000_races_eur"]-total/(row["dau"]*300)*1000) < 1e-9
        assert abs(row["monthly_cost_per_mau_eur"]-total/(row["dau"]/.2)) < 1e-9
        assert abs(row["cost_per_session_eur"]-total/(row["dau"]*60)) < 1e-9
    selected = [p for p in OUT.iterdir() if p.is_file() and p.name not in ("report.json","scoped-change.patch")]
    artifact_hashes={p.relative_to(ROOT).as_posix():sha(p) for p in selected}
    artifact_hashes[DOCUMENT.relative_to(ROOT).as_posix()]=sha(DOCUMENT)
    report={"schema":"bmt-comprehensive-backend-audit-v1","date":"2026-10-26",
        "finalized_at_utc":datetime.now(timezone.utc).isoformat(),"requirements":[f"AUD{i:02d}" for i in range(1,13)],
        "mode":"Audit only; new report/evidence and disposable local test artifacts",
        "document":DOCUMENT.relative_to(ROOT).as_posix(),"git_head":inventory["git_head"],
        "scope":{"current_source_files":len(inventory["files"]),"source_lines":sum(x["lines"] for x in inventory["files"]),
            "runtime_python_files":sum(x["path"].startswith("backend/bmt_backend/") and x["path"].endswith(".py") for x in inventory["files"]),
            "test_python_files":184,"api_route_records":len(runtime["api"]),"admin_route_records":len(runtime["admin"]),
            "orm_tables":len(runtime["tables"]),"initial_generated_build_copies_excluded":269,
            "manual_line_by_line_entire_backend":False},
        "source_drift":drift,"tests":tests,"local_report_links_checked":len(links),
        "findings":[{"id":f"AUD-F{i:02d}","severity":"P1" if i in (1,2,3,4,5,6,7,8,10) else "P2"} for i in range(1,13)],
        "commands_executed":[
            {"command":"Get-Content attachment Pasted text.txt, AGENTS.md, DEVELOPMENT_STATUS.md, docs/PHASE_0_PLAN.md; rg --files/rg and targeted source/runbook/evidence reads","outcome":"Request/guidance read; complete selected-source inventory with focused manual traces"},
            {"command":"git status --short; git rev-parse HEAD","outcome":"Existing extensive concurrent work preserved; no index/commit mutation"},
            {"command":".tools/backend-venv/Scripts/python.exe docs/evidence/backend-comprehensive-audit-2026-10-26/inventory.py","outcome":"Start/end inventories; final excludes generated build copies; no parsed Python syntax error"},
            {"command":".tools/backend-venv/Scripts/python.exe -X utf8 docs/evidence/backend-comprehensive-audit-2026-10-26/runtime_inventory.py","outcome":"Local metadata/router construction; no database connection/migration"},
            {"command":".tools/backend-venv/Scripts/python.exe -X utf8 docs/evidence/backend-comprehensive-audit-2026-10-26/cloud_read.py","outcome":"Initial sandbox CLI-profile failure; approved metadata/aggregate-only rerun succeeded"},
            {"command":".tools/backend-venv/Scripts/python.exe -X utf8 docs/evidence/backend-comprehensive-audit-2026-10-26/cloud_detail.py","outcome":"Revision/health/schema/latency histogram/jobs read; optional scheduler/alerts/log-exclusions reads unavailable"},
            {"command":".tools/backend-venv/Scripts/python.exe -X utf8 docs/evidence/backend-comprehensive-audit-2026-10-26/price_read.py; logging_price_read.py","outcome":"Public EUR catalogue reads; no billing records or secret values saved"},
            {"command":".tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_cost_http.py backend/tests/test_cost_archives.py backend/tests/test_packed_storage.py backend/tests/test_earned_coins.py backend/tests/test_race_acceptance_sql.py backend/tests/test_security_fixes.py backend/tests/test_http_server.py backend/tests/test_attack_resistance.py backend/tests/test_rivalry_concurrency.py backend/tests/test_track_of_day.py backend/tests/test_slot_gifts.py -q -m 'not postgres and not godot' -k 'not postgres' --junitxml=docs/evidence/backend-comprehensive-audit-2026-10-26/focused-tests.xml -o cache_dir=build/backend-comprehensive-audit-2026-10-26/pytest-cache --basetemp=build/backend-comprehensive-audit-2026-10-26/pytest-temp","outcome":"132 passed,3 skipped,61 deselected; initial filename/temporary-parent runner errors retained"},
            {"command":".tools/backend-venv/Scripts/python.exe -m pytest docs/evidence/backend-comprehensive-audit-2026-10-26/test_audit_probes.py -q -k 'not postgres' --junitxml=docs/evidence/backend-comprehensive-audit-2026-10-26/audit-probes.xml -o cache_dir=build/backend-comprehensive-audit-2026-10-26/probe-cache --basetemp=build/backend-comprehensive-audit-2026-10-26/probe-final-temp","outcome":"5 passed,1 deselected; finding confirmations, not clean-security certification"},
            {"command":".tools/backend-venv/Scripts/python.exe docs/evidence/backend-comprehensive-audit-2026-10-26/cost_model.py","outcome":"16 scenario variants recalculated; assertion/unit arithmetic verified"},
            {"command":".tools/backend-venv/Scripts/python.exe docs/evidence/backend-comprehensive-audit-2026-10-26/finalize.py","outcome":"Local links, tests, totals, routes/tables CSV and task-only patch prepared"}],
        "limitations":["No actual invoice, billing export or remaining credit balance","No full current PostgreSQL suite or capacity load",
            "No production load, provider purchase/authentication or cloud restore","No complete dependency/OS/native CVE/secret-history/organization-IAM audit",
            "No phone/tablet attachment check, physical-device test or APK","No runtime code/config/data/deployment/owner-process change",
            "One client source changed concurrently; runtime Python fingerprints stayed exact in selected start/end manifests"],
        "artifacts_sha256":artifact_hashes}
    (OUT/"report.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    patch=[]
    for path in sorted([DOCUMENT, *[p for p in OUT.iterdir() if p.is_file() and p.name!="scoped-change.patch"]]):
        name=path.relative_to(ROOT).as_posix()
        patch.extend([f"diff --git a/{name} b/{name}\n","new file mode 100644\n"])
        patch.extend(difflib.unified_diff([],path.read_text(encoding="utf-8").splitlines(keepends=True),fromfile="/dev/null",tofile="b/"+name))
    (OUT/"scoped-change.patch").write_text("".join(patch),encoding="utf-8",newline="\n")
    checked=subprocess.run(["git","apply","--check","--reverse",str(OUT/"scoped-change.patch")],cwd=ROOT,capture_output=True,text=True)
    if checked.returncode:
        print(checked.stderr)
        raise RuntimeError("Task-only reverse patch check failed")
    print(json.dumps({"local_links":len(links),"tests":tests,"source_drift":drift,
        "cost_variants":len(model["scenarios"]),"scoped_patch_reverse_check":"passed",
        "document_words":len(source.split()),"artifact_count":len(artifact_hashes)+2},indent=2))


if __name__=="__main__":
    main()
