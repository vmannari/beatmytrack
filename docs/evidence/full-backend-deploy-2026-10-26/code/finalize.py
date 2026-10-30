"""Retain the completed full release evidence without private resource metadata."""
import difflib
import hashlib
import json
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WORK = Path(__file__).resolve().parent
OUT = ROOT/"docs/evidence/full-backend-deploy-2026-10-26"
state = json.loads((WORK/"state.private.json").read_text())
assert state.get("complete")


def sha(data):
    return hashlib.sha256(data).hexdigest()


def decode(path):
    data = path.read_bytes()
    return data.decode("utf-16" if data.startswith((b"\xff\xfe",b"\xfe\xff")) else "utf-8")


for name in ("deploy.py","aggregate_counts.py","rehearse.py","install.py","Dockerfile",".dockerignore","finalize.py"):
    target = OUT/"code"/name;target.parent.mkdir(exist_ok=True)
    shutil.copyfile(WORK/name,target)
stages = ("inspect","build-stage","build-stage-r2","test-stage","preflight-stage","rehearse-stage","recheck-stage",
          "push-stage","maintenance-build-stage","quiesce-stage","quiesce-stage-r2","stop-worker-stage",
          "aggregate-snapshot-stage","backup-stage","migrate-stage","canary-stage","start-targets-stage",
          "promote-stage","smoke-stage","authority-stage","discovery-stage","finish-stage")
for name in stages:
    path = WORK/(name+".log")
    if path.exists():
        (OUT/(name+".log")).write_text(decode(path),encoding="utf-8",newline="\n")

existing = ["backend/bmt_backend/database_privileges.py","backend/tests/test_public_website.py",
            "AGENTS.md","DEVELOPMENT_STATUS.md","backend/deploy/README.md"]
new = ["docs/FULL_BACKEND_DEPLOY_2026_10_26.md"]
chunks,sources = [],{}
for name in existing+new:
    path = ROOT/name
    after = path.read_text()
    before = ""
    if name == "backend/bmt_backend/database_privileges.py":
        line = '    "bmt_reward_player_revision", "bmt_reward_move_personal_bests", "bmt_reward_move_lap_personal_bests",\n'
        assert after.count(line) == 1
        before = after.replace(line,"")
    elif name == "backend/tests/test_public_website.py":
        before = after.replace("def test_public_site_does_not_add_admin_service_routes(tmp_path):",
                               "def test_public_site_does_not_add_admin_service_routes():")
        before = before.replace('    app = create_app(Settings(environment="test", workload_role="admin",\n'
            '                              database_url="sqlite://", object_dir=str(tmp_path / "objects")))',
            '    app = create_app(Settings(environment="test", workload_role="admin"))')
        assert before != after
    elif name in existing:
        start = after.index("<!-- FULL-BACKEND-DEPLOY-20261026 -->")
        end = after.index("<!-- /FULL-BACKEND-DEPLOY-20261026 -->")+len("<!-- /FULL-BACKEND-DEPLOY-20261026 -->\n\n")
        before = after[:start]+after[end:]
    sources[name] = sha(path.read_bytes())
    chunks.append(f"diff --git a/{name} b/{name}\n")
    if name in new:
        chunks.append("new file mode 100644\n")
    chunks.extend(difflib.unified_diff(before.splitlines(keepends=True),after.splitlines(keepends=True),
        fromfile="/dev/null" if name in new else "a/"+name,tofile="b/"+name))
patch = OUT/"checkpoint.patch"
patch.write_text("".join(chunks),encoding="utf-8",newline="\n")
checked = subprocess.run(["git","apply","--reverse","--check","--ignore-space-change",str(patch)],
                         cwd=ROOT,capture_output=True,text=True)
(OUT/"checkpoint-check.log").write_text(checked.stdout+checked.stderr,encoding="utf-8")
assert checked.returncode == 0,checked.stderr

review = {"rejected_action":"Export cloud-side fingerprints derived from private database records to local artifacts",
          "execution_started":False,"reason":"Deployment authorization did not specifically authorize sensitive derived-data egress",
          "alternative":"Managed backup on the existing Cloud SQL instance and aggregate SQL counts only",
          "private_record_hashes_exported":False,"deployment_completed_with_alternative":True}
report = {"requirements":["FBD01","FBD02","FBD03","FBD04","FBD05","R01","Q01"],
          "release":json.loads((OUT/"rollout.json").read_text()),"sources":sources,
          "validation":{"original_exact_image":{"passed":520,"skipped":18,"fixture_failure":1,"deselected":3},
                        "corrected_website_module":{"passed":4,"remaining_failures":0},
                        "managed_backup_id":state["backup_id"],"original_tables_compared":len(state["data_before"]["tables"]),
                        "original_row_counts_unchanged":sum(state["data_before"]["tables"].values()),
                        "private_record_content_comparison_performed":False,
                        "native_storage_smoke":json.loads((OUT/"native-storage-smoke.json").read_text()),
                        "synthetic_migration":json.loads((OUT/"synthetic-migration.json").read_text())},
          "automatic_approval_review":review,
          "limits":{"physical_device_tested":False,"interactive_game_sign_in_tested":False,"purchase_tested":False,
                    "local_pc_backend_updated":False,"owner_game_restarted":False,"production_capacity_or_cost_measured":False},
          "checkpoint":{"path":str(patch.relative_to(ROOT)).replace("\\","/"),"sha256":sha(patch.read_bytes()),
                        "reverse_apply_check":checked.returncode}}
report["evidence_hashes"] = {path.relative_to(OUT).as_posix():sha(path.read_bytes()) for path in sorted(OUT.rglob("*"))
                             if path.is_file() and path.name != "report.json"}
(OUT/"report.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
print(json.dumps({"complete":True,"schema":report["release"]["schema_target"],"targets":report["release"]["targets"],
                  "checkpoint_reverse_check":checked.returncode,"evidence_files":len(report["evidence_hashes"])}))
