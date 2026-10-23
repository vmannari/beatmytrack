"""Assemble this task's local evidence and a reviewable source-only patch."""
import difflib
import hashlib
import json
import re
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
FOLDER = Path(__file__).parent


def read(path):
    return path.read_text(encoding="utf-8")


def write(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False)+"\n", encoding="utf-8")


def suite(name):
    tree = ET.parse(FOLDER/name).getroot()
    cases = tree.findall(".//testcase")
    failures = len(tree.findall(".//failure"))
    errors = len(tree.findall(".//error"))
    skipped = len(tree.findall(".//skipped"))
    return {"artifact":name,"passed":len(cases)-failures-errors-skipped,
        "failed":failures,"errors":errors,"skipped":skipped}


def diff(path, original, markers=None):
    lines = list(difflib.unified_diff(original.splitlines(True),read(ROOT/path).splitlines(True),
        fromfile="a/"+path,tofile="b/"+path,n=3))
    if markers and lines:
        headers, hunks, current = lines[:2], [], []
        for line in lines[2:]:
            if line.startswith("@@"):
                if current: hunks.append(current)
                current = []
            current.append(line)
        if current: hunks.append(current)
        lines = headers + [line for hunk in hunks if any(m in "".join(hunk) for m in markers) for line in hunk]
        if len(lines) == 2: lines = []
    return "".join(lines)


def without_discovery_role(source):
    lines = []
    for line in source.splitlines(True):
        if any(term in line for term in ('"discovery":', 'discovery = wait_file', 'assert discovery[', 'discovery_mode =')):
            continue
        if line.strip().startswith("wait_file(") and "discovery.ready" in line:
            continue
        line = line.replace(', "discovery"','').replace('"discovery.ready", ','')
        line = line.replace('"discovery_fail", "discovery_exit_zero", ','')
        lines.append(line)
    return "".join(lines)


def main():
    million = json.loads(read(FOLDER/"scale-million-results.json"))
    final_scale = json.loads(read(FOLDER/"scale-results.json"))
    million_level = million["levels"][-1]
    burst_before = million["levels"][0]["projection_burst"]
    burst_after = final_scale["levels"][0]["projection_burst"]
    backend_count = suite("postgres.xml")["passed"]
    entry = ("2026-10-22 DSI01-DSI04/DRR01-DRR13/R01/Q01: Discovery v3 replaces complete matching catalogues "
        "with twenty-item keyset pages, retained changed-row epochs, current authority checks and uniform bounded Random. "
        "Transactional receipts, sixteen independent partitions, coalesced exact seven-day pairs, expiry/erasure, worker health "
        "and reserved busy-partition scheduling serve a bounded native window with scoped caches and exact revision anchors. "
        f"Final SQLite/PostgreSQL{backend_count}pass/1SQLite-lock skip, security/migration/staging60, native80headless/83Compatibility/83desktopMobile, "
        "legacy paging269/list233/challenge68, real native HTTP safety/privacy and parser934 pass. "
        "A local synthetic million-track probe has warm-page median60.73ms; a two-character miss returns503. "
        f"The same10k receipt burst improves261.4 to{burst_after['receipts_per_second']}/s before daemon sleeps; neither is cloud/DAU certification. "
        "An older publication fixture's null-root failure reproduces with task-original Cloud; assertions remain. "
        "Actual commands, initial corrections, SQL plans, native views, risk dispositions and task-only checkpoint: "
        "docs/evidence/discovery-indexed-2026-10-22/report.json. Migration/API/worker/client rollout, old-client update, "
        "representative migration/load/storage and owner/device acceptance remain; no phone attachment check/device test, APK, "
        "live backend/account/queue mutation or deployment.\n\n")
    agent_entry = "## Indexed discovery and bounded browsing override (2026-10-22)\n"+entry
    for filename,prefix in (("AGENTS.md",agent_entry),("DEVELOPMENT_STATUS.md",entry),("docs/PHASE_0_PLAN.md",entry)):
        path = ROOT/filename
        value = read(path)
        pattern = (r"\A## Indexed discovery and bounded browsing override \(2026-10-22\)\n2026-10-22 DSI01-DSI04.*?\n\n"
            if filename == "AGENTS.md" else r"\A2026-10-22 DSI01-DSI04.*?\n\n")
        while re.match(pattern,value,flags=re.S):
            value = re.sub(pattern,"",value,count=1,flags=re.S)
        path.write_text(prefix+value,encoding="utf-8")

    originals = {
        name: FOLDER/"before"/name.replace("/","__") for name in (
        "backend/bmt_backend/discovery.py","backend/bmt_backend/app.py","backend/bmt_backend/privacy.py",
        "backend/bmt_backend/migrations/env.py","backend/bmt_backend/track_models.py",
        "backend/tests/test_discovery_paging.py","backend/tests/test_attack_resistance.py",
        "backend/tests/test_community_safety.py","game/backend/backend_client.gd","game/backend/cloud_tracks.gd",
        "game/ui/track_browser.gd","game/ui/track_search_drawer.gd","game/ui/challenge_create.gd")}
    originals.update({
        "backend/deploy/gcp/staging.py":FOLDER/"before/staging.py",
        "backend/tests/test_gcp_staging.py":FOLDER/"before/test_gcp_staging.py",
        "backend/tests/test_community_safety_http.py":FOLDER/"before/test_community_safety_http.py",
        "game/tests/test_community_safety_http.gd":FOLDER/"before/test_community_safety_http.gd"})
    new_files = ["backend/bmt_backend/"+name+".py" for name in (
        "discovery_models","discovery_projection","discovery_v3","discovery_worker","discovery_erasure")]
    new_files += ["backend/bmt_backend/migrations/versions/0050_discovery_indexed.py",
        "backend/tests/test_discovery_v3.py","backend/tests/test_discovery_projection.py",
        "game/backend/discovery_windows.gd","game/tests/test_discovery_windows.gd"]
    new_files += ["backend/schemas/discovery-"+name+"-v3.schema.json" for name in ("query","page","random")]
    new_files += [name+".uid" for name in ("game/backend/discovery_windows.gd","game/tests/test_discovery_windows.gd") if (ROOT/(name+".uid")).exists()]
    patches = []
    for name,base in originals.items():
        markers = (["discovery_erasure"] if name.endswith("/privacy.py") else
            ["discovery_models"] if name.endswith("/migrations/env.py") else None)
        patches.append(diff(name,read(base),markers))
    auxiliary = ["backend/bmt_backend/middleware.py","backend/bmt_backend/security.py"]
    for name in auxiliary:
        previous = subprocess.check_output(["git","show","HEAD:"+name],cwd=ROOT).decode("utf-8")
        patches.append(diff(name,previous))
    role_files = ["backend/bmt_backend/service_worker.py","backend/tests/test_service_worker.py","backend/tests/service_worker_probe.py"]
    for name in role_files:
        patches.append(diff(name,without_discovery_role(read(ROOT/name))))
    for name,prefix in (("AGENTS.md",agent_entry),("DEVELOPMENT_STATUS.md",entry),("docs/PHASE_0_PLAN.md",entry)):
        patches.append(diff(name,read(ROOT/name).replace(prefix,"",1)))
    readme = read(ROOT/"backend/README.md")
    before_readme = re.sub(r"Local discovery redesign \(2026-10-22\):.*?(?=Local Studio performance update)","",readme,flags=re.S)
    patches.append(diff("backend/README.md",before_readme))
    for name in new_files:
        patches.append("".join(difflib.unified_diff([],read(ROOT/name).splitlines(True),fromfile="/dev/null",tofile="b/"+name,n=3)))
    (FOLDER/"task-source.patch").write_text("".join(patches),encoding="utf-8",newline="\n")
    changed = sorted({*originals,*new_files,*auxiliary,*role_files,"backend/README.md","AGENTS.md","DEVELOPMENT_STATUS.md","docs/PHASE_0_PLAN.md"})
    write(FOLDER/"source-checkpoint.json",{"kind":"Task-only patch against captured or explicitly reconstructed baselines; no mixed-tree commit",
        "patch":"task-source.patch","files":{name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in changed},
        "scope_notes":["Only discovery imports/calls selected from shared privacy and migration-env diffs.",
            "Supervisor/test baselines reverse only discovery-role additions; pre-existing publication changes are retained.",
            "Unrelated shared workspace changes remain uncommitted and outside this patch.",
            "Original complete snapshots and previous failed test outputs are retained under before/ and history/."]})

    mitigations = [
        ("DRR01","Epoch-vector cursors freeze rank keys, filters, version IDs and candidate page spans. Current removals shorten pages after selection; they cannot backfill across cached pages or reweave recommendations."),
        ("DRR02","Store one current row plus actual changes, shared across queries. Retain retired rows for cursor TTL plus margin; bounded cleanup."),
        ("DRR03","Indexed per-partition LIMIT, bounded global merge, SQL/monotonic work deadlines including collection inserts; explicit retry on exhaustion."),
        ("DRR04","Complete small eligible set or uniform dense-slot rejection; no nearest-UUID or top-N bias; explicit 503 after4096 trials."),
        ("DRR05","Transactional triggers cover source writers. Pending flags survive late lower-sequence commits; idempotent pair ledger, bounded backfill/source audit and explicit counter repair."),
        ("DRR06","Pair last_at is event-time maximum. Expiry reads the latest durable row under its partition lock; replay/refresh cannot decrement an obsolete timer."),
        ("DRR07","Sixteen independently locked partitions, bounded batches and 60s rank coalescing. Main race transaction only appends receipts. Busy-partition scheduling removes sixteen-way empty polling."),
        ("DRR08","Current hide, account, block and revision-state checks before delivery. Frozen bounded block collections change new-view identity immediately after block/unblock. Actor-bound HMAC cursors, scoped caches, deletion fences and bounded erasure."),
        ("DRR09","At most13 payload pages/260 cards plus nearby placeholders; rebase scroll and grid columns, reload prior cursors, exact revision anchors, busy/expiry retry states."),
        ("DRR10","Initial local favourites/raced IDs become typed indexed expiring collection members; later pages send only a cursor. Device-local semantics remain."),
        ("DRR11","Three-official/one-community two-stream phase, explicit unique tie keys, rated/unrated boolean seek, 18-decimal integer score, expanded Unicode keys and BIGINT rating sum."),
        ("DRR12","Explicit v3 contract and scoped disk namespace. V2 always426, no overload fallback. Independent supervised process, backfill readiness/freshness gates, full connection budget and coordinated-release runbook."),
        ("DRR13","Actual SQLite/PostgreSQL/native correctness, million-track read plans/buffers and timed pages, sparse Random and hot receipt/pair/WAL probe; remaining capacity dimensions are explicit.")]
    report = {"title":"Indexed discovery implementation and risk dispositions","date":"2026-10-22",
        "status":"Implemented and locally verified; not deployed",
        "requirements":{"DSI01":"Remove complete matching-catalogue construction from shipping discovery.",
            "DSI02":"Address frozen paging, uniform Random, projection consistency, privacy and bounded state risks.",
            "DSI03":"Integrate bounded browser/search/publication selection without global totals or offsets.",
            "DSI04":"Measure representative local scale and document explicit release/capacity limits.",
            "R01":"Preserve identities, safety, legacy-server client operation and concurrent work.",
            "Q01":"Record actual commands, results, baseline failures and remaining acceptance."},
        "risk_dispositions":[{"id":identity,"implementation":detail} for identity,detail in mitigations],
        "contracts":{"page_size":20,"partitions":16,"cursor_lifetime_seconds":1800,"rank_coalescing_seconds":60,
            "work_budget_seconds":1.5,"new_view_stale_threshold_seconds":120,"random_trials":4096,
            "client_payload_pages":13,"client_cards":260,"client_extent_max":300,
            "anchor":"Selected immutable revision begins a forward window. Refresh returns to ordinary feed; no global ordinal or pre-anchor page is promised.",
            "old_clients":"Existing v2 server endpoints return426. New client still supports a v2 server before coordinated rollout.",
            "scope":"Discovery only. This does not certify the rest of the backend for500million accounts."},
        "verification":{"backend":suite("postgres.xml"),"security_migration_staging":suite("backend-safety-complete.xml"),
            "retired_v2_and_sqlite":suite("backend-scheduler-final.xml"),"native_safety_http":suite("community-http.xml"),
            "native_privacy_http":suite("privacy-http.xml"),"native":{"headless":80,"compatibility":83,"desktop_mobile":83,
                "legacy_paging":269,"free_race_list":233,"challenge_discovery":68,"parser_scripts":934},
            "linux_supervisor":{"passed":14,"artifact":"linux-service-final.log","scope":"Real isolated Linux signals, priorities, child exits and cleanup"},
            "skip_reason":"SQLite cannot prove PostgreSQL SKIP LOCKED independence; the PostgreSQL variant runs and passes.",
            "lint":"See ruff-final.log","checkpoint":"source-checkpoint.json",
            "native_views":[renderer+"-window-"+view+".png" for renderer in ("gl_compatibility","mobile") for view in ("list","gallery","compact")]},
        "measurements":{"scope":million["scope"],"million_track_level":{k:v for k,v in million_level.items() if k!="plans"},
            "final_100001_level":{k:v for k,v in final_scale["levels"][0].items() if k!="plans"},
            "burst_before":burst_before,"burst_after":burst_after,
            "plans":["scale-million-results.json","scale-results.json"],
            "notes":["Million-row measurements precede final frozen-membership, worker-priority, Unicode-width and scoped reopening-cache edits. Current code repeats all reader query classes at100001 tracks.",
                "Fixtures seed source and projection explicitly; seed time is excluded from reads and does not measure resumable-worker backfill throughput.",
                "Median/max come from25 successive local TestClient pages, not concurrent HTTPS p95/p99.",
                "16 Random picks per level are a reachability check, not a statistical distribution certification.",
                "The 1.5s work budget is not a hard end-to-end latency promise; the million-row two-character miss returns503 after2550.982ms including planning/rollback/HTTP overhead."]},
        "initial_corrections":["PostgreSQL JSON comparisons require jsonb for distinctness.",
            "Stats due times derive from receipt creation, not delayed processing.","Boolean keyset comparisons require explicit transitions between rated/unrated rows.",
            "Duplicate Retry-After headers removed without changing existing middleware defaults.",
            "Shared telemetry migration/import startup errors resolved in the concurrent work; no foreign code reverted.",
            "Linux child probe initially imported the image-installed package; PYTHONPATH=/src verifies mounted source.",
            "Scale fixture timeout separated from shipping request deadlines; Decimal report field serialized as integer.",
            "Fresh legacy-schema forward migration test replaces unsupported full-head downgrade.",
            "Search drawer suppresses unrelated local results and false empty text when global search is busy.",
            "Late audit adds name/score/recommended hide-revisit identity/order tests. Candidate selection now precedes current delivery checks; bounded block snapshots identify new views after unblock. Removed slots show availability rather than perpetual loading.",
            "Native fixture waits for resize, tests a non-divisor grid, and models actual anchor cursors. Compact capture settles the page and uses logical viewport scale.",
            "An empty CheckScript argument ran the isolated App until the bounded launcher timeout; corrected to test_script_parse.gd and934scripts pass."],
        "known_baseline_failure":{"test":"game/tests/test_publication_discovery.gd",
            "finding":"Old fixture overrides App._ready without constructing root_ui, then calls the newer publication-confirmation path. Null add_child in App._own_dialog3466 reproduces with task-original Cloud.",
            "artifacts":["native-publication_discovery-regression.log","publication-baseline-corrected.log"],
            "disposition":"Preserved assertions and current App. V3 exact publication-revision handoff is independently covered by the new native test."},
        "remaining_acceptance":["Backup and representative-copy migration timing: widening existing rating_sum can rewrite/lock track_versions. New projection indexes start empty; index/WAL/disk and rollback backup need release capacity.",
            "Apply0050 and all matching current migrations, deploy matching API/supervisor/worker and client, let source/backfill catch up, inspect logged partition lag and canary before traffic. No live rollout performed.",
            "No generic sublinear guarantee for arbitrary combinations/short substrings. Budget exhaustion is a retry response, and selective Random may also retry.",
            "Measure production concurrent p95/p99, API/worker peak RSS, database connection saturation, skew, WAL/vacuum/cleanup, backlog and failure recovery. The local burst excludes daemon sleeps and verification/HTTP.",
            "Measure large recent-pair and changed-history populations separately. Catalogues, accounts, active sessions, revisions and seven-day distinct pairs are independent dimensions;500million accounts and140million pairs were not instantiated.",
            "Bounded metadata audit sweeps128 tracks/partition/minute, so complete reconciliation time grows with catalogue size. Journal is the normal freshness authority; explicit derived-counter repair may need offline time for huge ledgers.",
            "Future ranking/collation/protocol changes require a new compatible version or expiry/drain policy. No permanent old-client whole-catalogue fallback.",
            "Owner workflow and physical-device acceptance remain; no phone attachment check, phone test or APK action."],
        "commands":[
            ".tools/backend-secure-venv/Scripts/python.exe docs/evidence/discovery-indexed-2026-10-22/postgres_lab.py --scale",
            ".tools/backend-secure-venv/Scripts/python.exe docs/evidence/discovery-indexed-2026-10-22/postgres_lab.py --scale --small",
            "PYTHONPATH=backend python -m pytest backend/tests/test_attack_resistance.py backend/tests/test_community_safety.py backend/tests/test_gcp_staging.py -q --tb=short -k 'not postgres'",
            "PYTHONPATH=backend python -m pytest backend/tests/test_community_safety_http.py backend/tests/test_privacy_http.py (run separately; see XML/logs)",
            "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_discovery_windows.gd [-Graphical -RenderingMethod gl_compatibility|mobile] -CommandTimeoutSeconds120",
            "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds120",
            "wsl -d Ubuntu -- docker run --rm --network none --memory=512m --cpus=1 -e PYTHONPATH=/src --entrypoint python -v '/mnt/c/Codes/Godot/Beat my track/backend:/src:ro' -w /src bmt-full-20261018:86d38519ffb5ac1f -m pytest tests/test_service_worker.py -q --tb=short -p no:cacheprovider"],
        "safety":{"live_access":False,"live_account_or_queue_mutation":False,"deployment":False,"phone_test":False,
            "databases":"Generated schemas in labelled disposable loopback PostgreSQL17 container and temporary SQLite; ownership checked before container removal.",
            "workspace":"Concurrent telemetry, queue, histogram, Studio, Rivalry and game changes retained."}}
    write(FOLDER/"report.json",report)
    print("Report and task-source.patch written; source files:",len(changed))


if __name__ == "__main__": main()
