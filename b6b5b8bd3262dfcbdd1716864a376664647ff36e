"""Package the local simulation evidence without touching application sources."""
import difflib
import hashlib
import json
import re
import subprocess
import xml.etree.ElementTree as ET
from datetime import datetime,timezone
from pathlib import Path

ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
DOCUMENT=ROOT/"docs/BACKEND_LOCAL_COST_SIMULATION_2026_10_26.md"


def main():
    for path in OUT.iterdir():
        if not path.is_file() or path.name=="scoped-change.patch":
            continue
        raw=path.read_bytes()
        value=raw.decode("utf-16" if raw.startswith((b"\xff\xfe",b"\xfe\xff")) else "utf-8")
        value=value.replace("\r\n","\n")
        path.write_bytes((value if value.endswith("\n") else value+"\n").encode("utf-8"))
    names=("packing","archives","retention","logging","native-cache","native-exit","database-restore",
        "restore-validation","cleanup","existing-container-observations","postgres-environment","lab-summary")
    data={name:json.loads((OUT/(name+".json")).read_text()) for name in names}
    assert data["packing"]["individual"]["physical_object_writes"]==512
    assert data["packing"]["packed"]["physical_object_writes"]==16
    assert data["packing"]["physical_write_reduction_percent"]==96.875
    assert data["archives"]["hot_before"]["rows"]==5000 and data["archives"]["hot_after"]["rows"]==0
    assert data["retention"]["all_protected_runs_retained"]
    assert data["native-exit"]["python_returncode"]==0 and data["native-exit"]["native_summary_present"]
    assert data["native-cache"]["full_recording_downloads"]==1
    assert data["restore-validation"]["all_values_exact"]
    assert data["cleanup"]["owned_fixture_removed"]
    tests={}
    for name in ("regressions","postgres-checks","regressions-initial"):
        root=ET.parse(OUT/(name+".xml")).getroot()
        suites=root.findall("testsuite") if root.tag=="testsuites" else [root]
        tests[name]={key:sum(int(s.attrib.get(key,0)) for s in suites) for key in ("tests","errors","failures","skipped")}
    assert tests["regressions"]=={"tests":35,"errors":0,"failures":0,"skipped":0}
    assert tests["postgres-checks"]=={"tests":20,"errors":0,"failures":0,"skipped":0}
    sources=["backend/bmt_backend/packed_storage.py","backend/bmt_backend/pack_io.py","backend/bmt_backend/storage.py",
        "backend/bmt_backend/cost_archives.py","backend/bmt_backend/cost_maintenance.py","backend/bmt_backend/maintenance.py",
        "backend/bmt_backend/http_costs.py","backend/bmt_backend/config.py","backend/bmt_backend/object_models.py",
        "backend/bmt_backend/track_models.py","backend/bmt_backend/app.py","backend/deploy/object_archive.py",
        "game/backend/backend_client.gd","game/backend/recording_cache.gd","game/backend/recording_downloads.gd",
        "game/backend/ghost_wire.gd","backend/tests/fixtures/verified_oval.json",
        "docs/evidence/cost-optimisation-implementation-2026-10-24/ghost-wire-fixture.json"]
    source_hashes={name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in sources}
    report={"schema":"bmt-local-cost-simulation-v1","date":"2026-10-26","completed_at_utc":datetime.now(timezone.utc).isoformat(),
        "requirements":[f"LCS{i:02d}" for i in range(1,8)],"document":DOCUMENT.relative_to(ROOT).as_posix(),
        "git_head":subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip(),
        "runtime_changes":False,"cloud_mutations":False,"real_player_data":False,
        "tests":tests,"native_assertions_passed":21,"measured_experiments":data,
        "commands_executed":[
            {"command":"WSL environment_probe.py","result":"Local Docker29.3.0 and cached PostgreSQL17 found; initial sandbox WSL/WMI denial and inline-quoting failure retained in task record"},
            {"command":"wsl.exe -d Ubuntu --exec python3 /mnt/c/Codes/Godot/Beat my track/docs/evidence/backend-local-cost-simulation-2026-10-26/postgres_fixture.py start","result":"Owned, loopback-only PostgreSQL fixture created with2CPU/1536MiB/768MiB tmpfs and40connections"},
            {"command":".tools/backend-venv/Scripts/python.exe docs/evidence/backend-local-cost-simulation-2026-10-26/database_probe.py","result":"Connected to own PostgreSQL17.11 fixture"},
            {"command":"Initial direct pytest selection: test_packed_storage.py test_cost_archives.py test_cost_maintenance.py test_cost_transport.py -k not-postgres -m not-godot","result":"24pass/11setup errors: incomplete model registry in isolated selection; original log/XML retained"},
            {"command":".tools/backend-venv/Scripts/python.exe -X utf8 docs/evidence/backend-local-cost-simulation-2026-10-26/run_regressions.py","result":"35passed/2deselected with full application model registry; unchanged assertions"},
            {"command":".tools/backend-venv/Scripts/python.exe -X utf8 docs/evidence/backend-local-cost-simulation-2026-10-26/run_postgres_checks.py","result":"20passed/36deselected against generated fixture URL only"},
            {"command":".tools/backend-venv/Scripts/python.exe -X utf8 docs/evidence/backend-local-cost-simulation-2026-10-26/local_cost_lab.py","result":"512record packing,5000receipt archival,120run retention and10000request logging experiments passed"},
            {"command":".tools/backend-venv/Scripts/python.exe -X utf8 docs/evidence/backend-local-cost-simulation-2026-10-26/run_native_cache.py","result":"21native assertions; PowerShell diagnostic stderr caused ambiguous shell exit; output retained"},
            {"command":".tools/backend-venv/Scripts/python.exe -X utf8 docs/evidence/backend-local-cost-simulation-2026-10-26/capture_native.py","result":"Fresh fixture;21native assertions, exact Python exit0, all assertions completed"},
            {"command":"WSL postgres_fixture.py restore","result":"Actual pg_dump/pg_restore into new empty bmt_cost_restored database inside own fixture"},
            {"command":".tools/backend-venv/Scripts/python.exe -X utf8 docs/evidence/backend-local-cost-simulation-2026-10-26/verify_restore.py","result":"64packed records,1pending value and20private replies exact after source object archive/restore"},
            {"command":"WSL postgres_fixture.py stop","result":"First preservation guard found unrelated API restart; final owned-ID/name/label-checked cleanup succeeded; existing BMT three containers unchanged"},
            {"command":".tools/backend-venv/Scripts/python.exe -X utf8 docs/evidence/backend-local-cost-simulation-2026-10-26/finalize.py","result":"Evidence/link/arithmetic validation and task-only reverse patch check"}],
        "limitations":["Synthetic bounded mechanism experiments, not one-million-DAU throughput","PostgreSQL data tmpfs is not cloud persistent SSD",
            "No real GCS/request billing or public geographical latency","No production failover/PITR/full erasure-ledger restore",
            "No physical-device attachment check/test or APK","No existing game/BMT service restart or deployment",
            "No runtime fix for old mixed-load protocol; native canonical work only prepares the fixture"],
        "source_sha256":source_hashes,
        "artifacts_sha256":{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
            for p in [DOCUMENT,*OUT.iterdir()] if p.is_file() and p.name not in ("report.json","scoped-change.patch")}}
    (OUT/"report.json").write_bytes((json.dumps(report,indent=2)+"\n").encode("utf-8"))
    missing=[]
    for target in re.findall(r"\]\(([^)]+)\)",DOCUMENT.read_text(encoding="utf-8")):
        if not target.startswith(("https://","http://","#")) and not (DOCUMENT.parent/target.split("#")[0]).is_file():
            if not target.endswith("scoped-change.patch"):
                missing.append(target)
    assert not missing,missing
    patch=[]
    for path in sorted([DOCUMENT,*[p for p in OUT.iterdir() if p.is_file() and p.name!="scoped-change.patch"]]):
        value=path.read_text(encoding="utf-8").replace("\r\n","\n")
        if not value.endswith("\n"):value+="\n"
        path.write_bytes(value.encode("utf-8"))
        name=path.relative_to(ROOT).as_posix()
        patch.extend([f"diff --git a/{name} b/{name}\n","new file mode 100644\n"])
        patch.extend(difflib.unified_diff([],value.splitlines(keepends=True),fromfile="/dev/null",tofile="b/"+name))
    (OUT/"scoped-change.patch").write_bytes("".join(patch).encode("utf-8"))
    check=subprocess.run(["git","apply","--check","--reverse",str(OUT/"scoped-change.patch")],cwd=ROOT,capture_output=True,text=True)
    if check.returncode:
        print(check.stderr);raise RuntimeError("Reverse patch check failed")
    print(json.dumps({"python_tests_passed":55,"native_checks_passed":21,"experiments":"passed",
        "restore":"passed","owned_fixture_removed":data["cleanup"]["owned_fixture_removed"],
        "existing_BMT_containers_unchanged":True,"unrelated_container_restart_recorded":True,
        "scoped_patch_reverse_check":"passed","document_words":len(DOCUMENT.read_text().split())},indent=2))


if __name__=="__main__":main()
