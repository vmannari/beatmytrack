"""Summarize actual receipts and hash the reviewable local deliverable."""
import hashlib
import json
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent


def read(name):
    return json.loads((OUT / name).read_text(encoding="utf-8"))


def suite(path):
    root = ET.parse(path).getroot()
    rows = root.findall("testsuite") if root.tag == "testsuites" else [root]
    return {"file":path.name,"tests":sum(int(row.get("tests",0)) for row in rows),
        "failures":sum(int(row.get("failures",0)) for row in rows),
        "errors":sum(int(row.get("errors",0)) for row in rows),
        "skipped":sum(int(row.get("skipped",0)) for row in rows),
        "skips":[{"test":case.get("name"),"reason":case.find("skipped").get("message","")}
                 for row in rows for case in row.findall("testcase") if case.find("skipped") is not None]}


checkpoint = read("checkpoint.json")
assert checkpoint["reverse_check_exit_code"] == 0
for entry in checkpoint["files"]:
    assert hashlib.sha256((ROOT / entry["path"]).read_bytes()).hexdigest() == entry["after_sha256"], entry["path"]
scale = read("scale-1000000.json")
retention = read("career-retention-1000000.json")
assert scale["players"] == 1000000 and scale["award_rows"] == 26000000
assert retention["retained_rows"] == 2000001
artifacts = [{"path":p.relative_to(OUT).as_posix(),"bytes":p.stat().st_size,
    "sha256":hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(OUT.rglob("*"))
    if p.is_file() and p.name != "report.json" and "__pycache__" not in p.parts]
frozen = []
for path in sorted(OUT.glob("postgres-*.xml")):
    token = path.stem.removeprefix("postgres-")
    backend = ROOT / "build" / ("world-ranking-frozen-"+token) / "backend"
    if not backend.is_dir(): continue
    hashes = {}
    for source in checkpoint["files"]:
        if source["path"].startswith("backend/"):
            candidate = backend / source["path"].removeprefix("backend/")
            if candidate.is_file(): hashes[source["path"]] = hashlib.sha256(candidate.read_bytes()).hexdigest()
    frozen.append({"receipt":path.name,"backend":str(backend),"ranking_source_sha256":hashes})
report = {
    "task":"World Ranking implementation","date":"2026-10-23",
    "requirements":["WRI01","WRI02","WRI03","WRI04","WRI05","WRI06","WRI07","WRI08","R01","G01","Q01"],
    "status":"Implemented and locally validated; production rollout and owner/device acceptance remain",
    "implementation":"../../WORLD_RANKING_IMPLEMENTATION_2026_10_23.md",
    "rules":{"policy":"compact-circuit-v1","car":"compact","tracks":5,"world_best":12,
        "rolling_weeks":26,"season_weeks":13,"season_best":6,"prestige_field":1000,
        "season_qualifying_weeks":6,"free_official_resumes":3,"launch_default":0,"migration":"0059_world_ranking"},
    "boundaries":{"worker_connections":1,"batch_players":2000,"work_mem_per_node_mib":16,
        "parallel_database_workers":0,"statement_seconds":30,"lock_timeout_ms":500,"lease_seconds":120,
        "pause_ms":25,"yield_queue_age_seconds":30,"hot_public_generations":2,"award_buffer_weeks":28,
        "page_rows":50,"around_rows":9,"profile_results":26,"native_cache_entries":8,
        "native_pending_profiles":4,"native_page_history":8,"native_rows_built_per_frame":10},
    "validation":{"junit":[suite(p) for p in sorted(OUT.glob("*.xml"))],
        "native_regressions":read("native-regressions.json"),
        "focused_native":{"headless":{"checks":25,"failures":0,"file":"native-headless.log"},
            "compatibility":{"checks":26,"failures":0,"file":"native-gl_compatibility.log"},
            "compatibility_390x844":{"checks":26,"failures":0,"file":"native-gl_compatibility-390x844.log"},
            "desktop_mobile_430x932":{"checks":26,"failures":0,"file":"native-mobile-430x932.log"}},
        "script_parser":{"scripts":1041,"failures":0,"file":"parser.log"},
        "ruff":"All selected changed backend modules and ranking tests passed",
        "scale_earlier_iteration":"scale-100000.json","scale_final":scale,"career_retention_final":retention},
    "retained_failures":[
        {"test":"test_rivalry_track_detail","assertions":1,"control":"original-detail-control-process.log",
         "reason":"Fourteen entrants expose remaining six; same failure with task-original shared sources"},
        {"test":"test_resume_recovery_budget","assertions":3,"control":"original-test_resume_recovery_budget-process.log",
         "reason":"Publication retry identities/deferred restart; same failures with task-original shared sources"}],
    "initial_corrections":[
        "Migration generation: static string FK types and fresh-schema Rivalry column guard",
        "PostgreSQL SQL points numerator required explicit BigInteger binding",
        "Million-player member DISTINCT exceeded 30s; replaced by bounded previous/current indexed streams",
        "Backlog guard placement corrected before the final scale run",
        "Career retention now advances player keys, verified separately with 3000001 interleaved rows",
        "Windows sandbox certificate/userdata diagnostics; canonical check passed with normal runtime access and isolated native userdata",
        "Native Garage trophy fixture required garage_mode; final assertions remain unchanged",
        "PowerShell/Python source encoding correction restored App punctuation; unrelated status-file encoding was restored",
        "Schema contract test uses existing standard-library JSON support; no new dependency installed"],
    "source_provenance":{"checkpoint":checkpoint,"frozen_runs":frozen,
        "original_control":"Task-original shared client sources, with current unchanged assets in an isolated copied project",
        "reconstructed_bases":["game/race/weekly_rivalry.gd","game/ui/weekly_rivalry_finale.gd"],
        "shared_workspace":"Concurrent modifications retained; no Git index changes or commit"},
    "commands":[
        "python docs/evidence/world-ranking-implementation-2026-10-23/run_postgres.py tests/test_world_ranking.py tests/test_world_ranking_service.py tests/test_service_worker.py tests/test_rivalry.py tests/test_resumes.py tests/test_rivalry_planning.py tests/test_community_safety.py tests/test_privacy.py tests/test_maintenance.py -k 'not canonical_three_rewinds'",
        "$env:BMT_RANKING_SCALE_PLAYERS='1000000'; python docs/evidence/world-ranking-implementation-2026-10-23/run_postgres.py tests/test_world_ranking_scale.py -k postgres",
        "$env:BMT_RANKING_SCALE_PLAYERS='1000000'; python docs/evidence/world-ranking-implementation-2026-10-23/run_postgres.py tests/test_world_ranking_scale.py -k career_retention",
        "python docs/evidence/world-ranking-implementation-2026-10-23/run_native_regressions.py",
        "python docs/evidence/world-ranking-implementation-2026-10-23/run_original_control.py",
        "python docs/evidence/world-ranking-implementation-2026-10-23/run_original_control.py test_resume_recovery_budget",
        "python docs/evidence/world-ranking-implementation-2026-10-23/run_native.py gl_compatibility 390x844",
        "python docs/evidence/world-ranking-implementation-2026-10-23/run_native.py mobile 430x932",
        "Pinned Godot 4.7.2: --headless --path game --script res://tests/test_script_parse.gd",
        "python docs/evidence/world-ranking-implementation-2026-10-23/build_checkpoint.py",
        "git apply --reverse --check --whitespace=nowarn docs/evidence/world-ranking-implementation-2026-10-23/checkpoint.patch"],
    "remaining":["Matching migration/API/worker/client rollout and deliberate future-Monday launch",
        "Representative staging shadow/restore/correction and production capacity calibration",
        "Owner acceptance and sustained physical-device layout/performance validation"],
    "limits":["Synthetic frozen verified times and historical awards; API race verification uses FakeVerifier",
        "One-CPU local database and in-process HTTP; no cloud/network/DAU/FPS certification",
        "Full pipeline seed starts at frozen input classification; live admission/freeze tested separately on both engines",
        "Final career cursor optimization additionally verified on one million players with three generations",
        "No phone/tablet attachment check, physical-device test, APK, deployment, purchase or live account/backend mutation",
        "Correction branches need temporary additional storage; cold sporting archives grow with weekly participation"],
    "artifacts":artifacts,
}
(OUT / "report.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
print(json.dumps({"report":"report.json","source_files":len(checkpoint["files"]),"artifacts":len(artifacts),
                  "scale_players":scale["players"],"scale_seconds":scale["seconds"]}))
