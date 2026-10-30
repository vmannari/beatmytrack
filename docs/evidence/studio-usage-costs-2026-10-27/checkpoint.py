"""Create/check a task-only binary-inclusive patch without changing the main index."""
import hashlib
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
TASK = ROOT / "build/studio-usage-costs-2026-10-27"
EXISTING = ["backend/bmt_backend/app.py", "backend/bmt_backend/admin.py", "backend/bmt_backend/config.py",
    "backend/bmt_backend/studio_settings.py", "backend/bmt_backend/studio_governance.py",
    "backend/bmt_backend/admin_ui/app.js", "backend/bmt_backend/admin_ui/index.html",
    "AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md", "backend/README.md"]
NEW = ["backend/bmt_backend/studio_usage.py", "backend/bmt_backend/studio_usage_cloud.py",
    "backend/bmt_backend/admin_ui/usage.js", "backend/bmt_backend/admin_ui/usage.css",
    "backend/tests/test_studio_usage.py", "scripts/test_studio_usage_console.py",
    "scripts/test_studio_usage_postgres.py", "scripts/studio_usage_cloud_preview.py",
    "docs/STUDIO_USAGE_COSTS_2026_10_27.md"]
DOCUMENTS = {"AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md", "backend/README.md"}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def call(args):
    return subprocess.run(args,cwd=ROOT,capture_output=True,check=False)


def main():
    # Shared documents can receive concurrent inserts; remove only our exact
    # marked block to construct their review baseline. Runtime baselines are
    # the preserved pre-edit files, audited separately during implementation.
    before, after = TASK/"checkpoint-before", TASK/"checkpoint-after"
    for name in EXISTING:
        target=before/name
        target.parent.mkdir(parents=True,exist_ok=True)
        if name in DOCUMENTS:
            content=(ROOT/name).read_text(encoding="utf-8")
            start=content.index("<!-- STUDIO-USAGE-COSTS-20261027 -->")
            end=content.index("<!-- /STUDIO-USAGE-COSTS-20261027 -->",start)+len("<!-- /STUDIO-USAGE-COSTS-20261027 -->")
            if content[end:end+2]=="\n\n":
                end+=2
            target.write_text(content[:start]+content[end:],encoding="utf-8",newline="\n")
        else:
            target.write_bytes((TASK/"base"/name).read_bytes())
    files=EXISTING+NEW
    cloud=json.loads((OUT/"cloud-preview.json").read_text())
    report={"requirements":["UC01","UC02","UC03","UC04","UC05"],
        "created_at_utc":datetime.now(timezone.utc).isoformat(),"status":"implemented_locally; activation awaits owner authorization",
        "files":{name:sha(ROOT/name) for name in files},
        "validation":{"broad_regression":{"passed":88,"deselected":1,"evidence":"postgres.xml"},
            "final_postgresql":{"passed":20,"evidence":"postgres-final.xml"},
            "final_focused":{"passed":31,"deselected_postgres":2,"evidence":"focused-final.xml"},
            "saved_location_dates":{"passed":2,"evidence":"saved-view.xml"},
            "browser":{"passed":9,"page_errors":0,"widths":[1440,390],"evidence":"browser.json"},
            "native_download":{"failed":1,"same_task_start_failure":True,"evidence":"native-baseline.xml"},
            "lint":"new files and changed admin/configuration integrations pass; same baseline app.py I001 retained"},
        "cloud":{"scope":cloud["scope"],"captured_at":cloud["captured_at"],"provider_errors":cloud["provider_errors"],
            "resource_rows":len(cloud["resources"]),"endpoint_rows":len(cloud["cloud"].get("endpoints",{}).get("rows",[])),
            "billing_discovery":cloud["billing_discovery"],"runtime_identity_coverage":"operator preflight only; workload IAM acceptance pending"},
        "boundaries":{"source_population":"original global totals preserved; Ville alone eligible for cost-per-active-player",
            "cost_method":"partial identifiable request-based API allocation by observed client request share; all other charges unallocated",
            "billing_query_max_bytes":100000000,"collection_min_interval_seconds":60,
            "warning_percent":75,"critical_percent":90,"stale_seconds":600,
            "detailed_export_created":False,"deployment":False,"private_player_rows_read_by_cloud_preview":False,
            "schema_change":False,"physical_device_check_or_test":False,"main_index_staging_commit_merge":False,
            "owner_process_restart":False},
        "pending":["private Studio rollout and runtime read permissions","detailed billing export and dataset/query read permissions",
            "actual Ville stable binding and billing calibration","owner acceptance"],
        "checkpoint":{"patch":"scoped-change.patch","checks":"checkpoint-checks.json","binary_inclusive":True}}
    (OUT/"report.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    # A separate receipt can be included without a patch-hash/self-hash cycle.
    commands={"forward":"git apply --check --directory=<captured task baseline> scoped-change.patch",
        "reverse":"git apply --check --reverse scoped-change.patch","results":"checkpoint-verification.json"}
    (OUT/"checkpoint-checks.json").write_text(json.dumps(commands,indent=2)+"\n",encoding="utf-8")
    excluded={"scoped-change.patch","checkpoint-verification.json","checkpoint-errors.txt"}
    files += [p.relative_to(ROOT).as_posix() for p in OUT.iterdir() if p.is_file() and p.name not in excluded]
    for name in files:
        target=after/name
        target.parent.mkdir(parents=True,exist_ok=True)
        target.write_bytes((ROOT/name).read_bytes())
    old,new=before.relative_to(ROOT).as_posix(),after.relative_to(ROOT).as_posix()
    diff=call(["git","diff","--no-index","--binary","--",old,new])
    if diff.returncode not in (0,1):
        raise RuntimeError("Could not construct task-only patch")
    patch=diff.stdout
    for prefix in (old,new):
        for side in ("a/","b/"):
            patch=patch.replace((side+prefix+"/").encode(),side.encode())
    patch_path=OUT/"scoped-change.patch"
    patch_path.write_bytes(patch)
    forward=call(["git","apply","--check","--directory="+old,str(patch_path.relative_to(ROOT))])
    reverse=call(["git","apply","--check","--reverse",str(patch_path.relative_to(ROOT))])
    receipt={"forward_check":forward.returncode==0,"reverse_check":reverse.returncode==0,
        "main_index_changed_by_script":False,"patch_bytes":len(patch),"patch_sha256":sha(patch_path)}
    # Keep the receipt stable in the patch: its external hash/size receipt is a
    # sibling file, avoiding recursive inclusion of its own changing checksum.
    (OUT/"checkpoint-verification.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
    if forward.returncode or reverse.returncode:
        (OUT/"checkpoint-errors.txt").write_bytes(forward.stderr+reverse.stderr)
        raise RuntimeError("Task-only patch checks failed; inspect checkpoint-errors.txt")
    print(json.dumps({"scoped_files":len(files),"patch_bytes":len(patch),"forward_check":True,"reverse_check":True}))


if __name__=="__main__":
    main()
