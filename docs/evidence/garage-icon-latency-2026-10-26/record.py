"""Record further icon latency changes, controls, and a scoped review patch."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import subprocess

EVIDENCE = Path(__file__).resolve().parent
ROOT = EVIDENCE.parents[2]
EXISTING = ["game/ui/garage_paint_icons.gd","game/ui/rivalry_victory_car.gd","game/vehicle/car_visual.gd",
            "game/tests/test_garage_paint_icon_performance.gd","game/tests/test_garage_paint_list.gd",
            "AGENTS.md","DEVELOPMENT_STATUS.md"]
NEW = ["game/tests/test_icon_latency_model_control.gd","game/tests/test_icon_latency_model_control.gd.uid",
       "docs/GARAGE_ICON_LATENCY_2026_10_26.md"]
NEW += ["docs/evidence/garage-icon-latency-2026-10-26/"+name for name in ("run.ps1","record.py","review.html")]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def log_text(path):
    raw = path.read_bytes()
    return raw.decode("utf-16" if raw.startswith(b"\xff\xfe") else "utf-8-sig",errors="replace")


patch, sources = [], []
for name in EXISTING+NEW:
    target, before = ROOT/name,EVIDENCE/"before"/name
    original = before.read_text(encoding="utf-8") if before.exists() else ""
    current = target.read_text(encoding="utf-8")
    checkpoint_base = None
    if name in ["AGENTS.md","DEVELOPMENT_STATUS.md"]:
        original, removed = re.subn(r"<!-- GARAGE-ICON-LATENCY-20261026 -->[\s\S]*?<!-- /GARAGE-ICON-LATENCY-20261026 -->\n\n","",current,count=1)
        assert removed==1
        checkpoint_base = EVIDENCE/"checkpoint-base"/name
    elif name=="game/vehicle/car_visual.gd":
        # Preserve concurrent Garage template integration in the review base.
        original = current
        for added, prior in [
            ("var cache_rest_pose: bool = true\n",""),
            ("var build_budget_us: int = 4000\n",""),
            (">= build_budget_us:",">= 4000:"),
            ('if cache_rest_pose: preload("res://vehicle/prepared_car_cache.gd").remember(self)',
             'preload("res://vehicle/prepared_car_cache.gd").remember(self)')]:
            assert original.count(added)==1
            original = original.replace(added,prior,1)
        checkpoint_base = EVIDENCE/"checkpoint-base"/name
    if checkpoint_base:
        checkpoint_base.parent.mkdir(parents=True,exist_ok=True)
        checkpoint_base.write_text(original,encoding="utf-8",newline="\n")
    if original!=current:
        patch.append(f"diff --git a/{name} b/{name}\n")
        patch.extend(difflib.unified_diff(original.splitlines(True),current.splitlines(True),
                     fromfile=f"a/{name}" if before.exists() else "/dev/null",tofile=f"b/{name}"))
    sources.append({"path":name,"sha256":sha(target),"before_sha256":sha(before) if before.exists() else None,
                    "checkpoint_base_sha256":sha(checkpoint_base) if checkpoint_base else None})
checkpoint = EVIDENCE/"task-only.patch"
checkpoint.write_text("".join(patch),encoding="utf-8",newline="\n")
reverse = subprocess.run(["git","apply","--check","--reverse",str(checkpoint)],cwd=ROOT,capture_output=True,text=True)
runs = []
for path in sorted(EVIDENCE.rglob("command.json")):
    log = path.with_name("console.log")
    content = log_text(log)
    runs.append({"directory":path.parent.relative_to(EVIDENCE).as_posix(),
                 **json.loads(path.read_text(encoding="utf-8-sig")),
                 "summary":re.findall(r"(?:GARAGE_PAINT_ICON_PERFORMANCE|GARAGE_PAINT_LIST|SCRIPT_PARSE|RACING_MODEL_TESTS)[: ]+[^\r\n]+",content),
                 "failures":re.findall(r"^FAIL:[^\r\n]+",content,re.M),
                 "script_errors":re.findall(r"^SCRIPT ERROR:[^\r\n]+",content,re.M),"log_sha256":sha(log)})
by_name = {run["directory"]:run for run in runs}
expected = {"test_garage_paint_icon_performance-"+mode for mode in ["gl_compatibility","mobile"]}
expected |= {"test_garage_paint_list-"+mode for mode in ["headless","gl_compatibility","mobile"]}
expected |= {"test_script_parse-headless","import-headless","test_racing_car_models-headless","test_icon_latency_model_control-headless"}
missing = sorted(expected-by_name.keys())
known_models = ["test_racing_car_models-headless","test_icon_latency_model_control-headless"]
model_control = {"same_failures":False}
if all(name in by_name for name in known_models):
    actual, control = [by_name[name] for name in known_models]
    model_control = {"same_failures":sorted(actual["failures"])==sorted(control["failures"]) and len(actual["failures"])==4,
                     "messages":actual["failures"]}
metrics = [{"path":p.relative_to(EVIDENCE).as_posix(),"sha256":sha(p),"data":json.loads(p.read_text())}
           for p in sorted(EVIDENCE.rglob("metrics.json"))]
report = {
    "date":"2026-10-26","requirements":["GIL01","GIL02","GIL03","GIL04","R01","Q01"],
    "engine":(ROOT/"godot-version.txt").read_text().strip(),"sources":sources,"runs":runs,"missing_final_runs":missing,
    "metrics":metrics,"broader_model_control":model_control,
    "architecture":{"read_batch":8,"queued_write_limit":8,"write_batch":8,"gpu_images":24,"disk_images":196,
                    "icon_build_soft_interval_us":16000,"other_model_interval_default_us":4000,
                    "snapshot":"only icon studio opts out of the unused simplified rest-pose snapshot",
                    "readiness":"partial icon geometry remains unrendered until model completion",
                    "preserved":"exact customisation cache identity, accepted appearance, economy/save/account and main-camera behavior"},
    "captures":[{"path":p.relative_to(EVIDENCE).as_posix(),"sha256":sha(p)} for p in sorted(EVIDENCE.rglob("*.png"))],
    "checkpoint":{"path":"task-only.patch","sha256":sha(checkpoint),"reverse_check_exit":reverse.returncode,"stderr":reverse.stderr},
    "remaining_acceptance":["reload","owner scrolling/appearance review","physical-device cold/warm frame-time and memory review"],
    "limits":["Windows Compatibility/Vulkan Mobile; shader state and concurrent processes affect timings",
              "soft construction interval is not a frame-time guarantee; initial driver/unsliced work remains",
              "first icon can take extra elapsed time while construction yields",
              "four broader model fixture failures reproduce with task-start constructor and remain",
              "no physical-device attachment check/test, APK, real authentication/purchase or owner-save/live mutation",
              "no deployment, merge, staging, commit or owner-process restart; concurrent work preserved"]}
(EVIDENCE/"report.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
print(json.dumps({"runs":[{"name":run["directory"],"exit":run["exit_code"],"summary":run["summary"]} for run in runs],
                  "missing_final_runs":missing,"broader_model_control":model_control,
                  "checkpoint_reverse_exit":reverse.returncode,"checkpoint_error":reverse.stderr},indent=2))
failed = any(run["exit_code"]!=0 for run in runs if not run["directory"].startswith(("before/","initial/")) and run["directory"] not in known_models)
raise SystemExit(reverse.returncode or int(bool(missing) or failed or not model_control["same_failures"]))
