"""Record native icon reuse/cache evidence and a reverse-checkable scoped patch."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import subprocess

EVIDENCE = Path(__file__).resolve().parent
ROOT = EVIDENCE.parents[2]
EXISTING = ["game/ui/garage_paint_icons.gd","game/ui/profile_car.gd","game/tests/test_garage_paint_list.gd",
            "AGENTS.md","DEVELOPMENT_STATUS.md"]
NEW = ["game/tests/test_garage_paint_icon_performance.gd","game/tests/test_garage_paint_icon_performance.gd.uid",
       "docs/GARAGE_PAINT_ICON_PERFORMANCE_2026_10_26.md"]
NEW += ["docs/evidence/garage-paint-icon-performance-2026-10-26/"+name for name in ("run.ps1","record.py","review.html")]


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
        original, removed = re.subn(r"<!-- GARAGE-PAINT-ICON-PERFORMANCE-20261026 -->[\s\S]*?<!-- /GARAGE-PAINT-ICON-PERFORMANCE-20261026 -->\n\n","",current,count=1)
        assert removed==1
        checkpoint_base = EVIDENCE/"checkpoint-base"/name
        checkpoint_base.parent.mkdir(parents=True,exist_ok=True)
        checkpoint_base.write_text(original,encoding="utf-8",newline="\n")
    elif name=="game/ui/profile_car.gd":
        # The header's independent 2D-picture work shares this file. Include
        # that work in the base so the patch contains only our repaint helper.
        original, removed = re.subn(r"\nstatic func repaint_preview\(view: Control, paint: Dictionary\) -> void:\n(?:\t[^\n]*\n)+","",current,count=1)
        assert removed==1
        checkpoint_base = EVIDENCE/"checkpoint-base"/name
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
                 "client_build":re.findall(r"Client build: ([^\r\n]+)",content),
                 "summary":re.findall(r"(?:GARAGE_PAINT_ICON_PERFORMANCE|GARAGE_PAINT_LIST|SCRIPT_PARSE):[^\r\n]+",content),
                 "failures":re.findall(r"^FAIL:[^\r\n]+",content,re.M),"log_sha256":sha(log)})
expected = {"test_garage_paint_icon_performance-"+mode for mode in ["gl_compatibility","mobile"]}
expected |= {"test_garage_paint_list-"+mode for mode in ["headless","gl_compatibility","mobile"]}
expected |= {"test_script_parse-headless","import-headless"}
missing = sorted(expected-{run["directory"] for run in runs})
metrics = [{"path":p.relative_to(EVIDENCE).as_posix(),"sha256":sha(p),"data":json.loads(p.read_text())}
           for p in sorted(EVIDENCE.rglob("metrics.json"))]
report = {
    "date":"2026-10-26","requirements":["GIP01","GIP02","GIP03","GIP04","R01","Q01"],
    "engine":(ROOT/"godot-version.txt").read_text().strip(),"sources":sources,"runs":runs,"missing_final_runs":missing,"metrics":metrics,
    "architecture":{"cold":"one attached reusable studio for the current vehicle/parts while visible",
                    "warm":"persistent PNGs with zero icon model constructions/renders in the benchmark",
                    "background":"tree-owned CPU file/decode/encode/eviction jobs; no scene or GPU access",
                    "identity":"version, build, renderer, vehicle, full paint/stickers, fitted parts",
                    "gpu_images":24,"disk_images":196,"compressed_file_bytes":262144,"icon_pixels":[224,152],
                    "idle":"viewport stopped; hidden/free releases studio and cancels jobs"},
    "captures":[{"path":p.relative_to(EVIDENCE).as_posix(),"sha256":sha(p)} for p in sorted(EVIDENCE.rglob("*.png"))],
    "checkpoint":{"path":"task-only.patch","sha256":sha(checkpoint),"reverse_check_exit":reverse.returncode,"stderr":reverse.stderr},
    "remaining_acceptance":["reload","owner appearance/scrolling review","physical-device cold/warm frame-time and memory review"],
    "limits":["Windows Compatibility/Vulkan Mobile diagnostics; final renderer benchmarks concurrent",
              "initial model construction/shader hitch remains; separate Garage world-entry cost not changed",
              "no physical-device attachment check or device test","no APK","no real authentication/purchase or owner-save/live mutation",
              "no deployment, merge, staging, commit or owner-process restart","concurrent work preserved and excluded"]}
(EVIDENCE/"report.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
print(json.dumps({"runs":[{"name":run["directory"],"exit":run["exit_code"],"summary":run["summary"]} for run in runs],
                  "missing_final_runs":missing,"checkpoint_reverse_exit":reverse.returncode,"checkpoint_error":reverse.stderr},indent=2))
failed = any(run["exit_code"]!=0 for run in runs if not run["directory"].startswith(("before/","initial/")))
raise SystemExit(reverse.returncode or int(bool(missing) or failed))
