"""Record measured paint framing and a reverse-checkable task-only patch."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import subprocess

EVIDENCE = Path(__file__).resolve().parent
ROOT = EVIDENCE.parents[2]
EXISTING = ["game/ui/garage_customisation_camera.gd", "game/tests/test_customisation_carousel.gd",
            "AGENTS.md", "DEVELOPMENT_STATUS.md"]
NEW = ["game/tests/test_garage_paint_framing.gd", "game/tests/test_garage_paint_framing.gd.uid",
       "docs/GARAGE_PAINT_FRAMING_2026_10_26.md"]
NEW += ["docs/evidence/garage-paint-framing-2026-10-26/"+name
        for name in ("run.ps1", "record.py", "review.html")]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def log_text(path):
    data = path.read_bytes()
    return data.decode("utf-16" if data.startswith(b"\xff\xfe") else "utf-8-sig", errors="replace")


patch, sources = [], []
for name in EXISTING + NEW:
    target, before = ROOT/name, EVIDENCE/"before"/name
    original = before.read_text(encoding="utf-8") if before.exists() else ""
    current = target.read_text(encoding="utf-8")
    checkpoint_base = None
    if name in ["AGENTS.md","DEVELOPMENT_STATUS.md"]:
        # Preserve later concurrent tracker additions in the review base.
        original, removed = re.subn(r"<!-- GARAGE-PAINT-FRAMING-20261026 -->[\s\S]*?<!-- /GARAGE-PAINT-FRAMING-20261026 -->\n\n","",current,count=1)
        assert removed==1
        checkpoint_base = EVIDENCE/"checkpoint-base"/name
        checkpoint_base.parent.mkdir(parents=True,exist_ok=True)
        checkpoint_base.write_text(original,encoding="utf-8",newline="\n")
    if original != current:
        patch.append(f"diff --git a/{name} b/{name}\n")
        patch.extend(difflib.unified_diff(original.splitlines(True), current.splitlines(True),
                     fromfile=f"a/{name}" if before.exists() else "/dev/null", tofile=f"b/{name}"))
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
                 "summary":re.findall(r"(?:GARAGE_PAINT_FRAMING|CUSTOMISATION_CAROUSEL|GARAGE_PREVIEW_STABILITY|SCRIPT_PARSE):[^\r\n]+",content),
                 "failures":re.findall(r"^FAIL:[^\r\n]+",content,re.M),"log_sha256":sha(log)})
coverage = []
for path in sorted(EVIDENCE.rglob("coverage.json")):
    rows = json.loads(path.read_text(encoding="utf-8"))
    coverage.append({"path":path.relative_to(EVIDENCE).as_posix(),"sha256":sha(path),"samples":rows,
                     "minimum_height_fraction":min(row["height_fraction"] for row in rows)})
baseline = {row["label"]:row for row in json.loads((EVIDENCE/"before/gl_compatibility/coverage.json").read_text())}
comparison = []
for mode in ["gl_compatibility","mobile"]:
    rows = json.loads((EVIDENCE/f"test_garage_paint_framing-{mode}/coverage.json").read_text())
    for row in rows:
        old = baseline[row["label"]]
        comparison.append({"renderer":mode,"label":row["label"],"before_height_fraction":old["height_fraction"],
                           "after_height_fraction":row["height_fraction"],
                           "relative_height_gain":row["height_fraction"]/old["height_fraction"]-1})
initial_logs = [{"path":p.relative_to(EVIDENCE).as_posix(),"sha256":sha(p)} for p in sorted((EVIDENCE/"initial").rglob("*.log"))]
expected = {"test_garage_paint_framing-"+mode for mode in ["headless","gl_compatibility","mobile"]}
expected |= {"test_customisation_carousel-"+mode for mode in ["gl_compatibility","mobile"]}
expected |= {"test_garage_preview_stability-headless","test_script_parse-headless","import-headless"}
missing = sorted(expected-{run["directory"] for run in runs})
report = {
    "date":"2026-10-26","requirements":["GPF01","GPF02","GPF03","R01","Q01"],
    "engine":(ROOT/"godot-version.txt").read_text().strip(),"sources":sources,"runs":runs,"missing_final_runs":missing,
    "coverage":coverage,"comparison":comparison,"initial_logs":initial_logs,
    "initial_proposal_sources":[{"path":p.relative_to(EVIDENCE).as_posix(),"sha256":sha(p)}
                                for p in sorted((EVIDENCE/"initial").rglob("*.gd"))],
    "policy":{"paint_entry_minimum_elevation_degrees":30,"horizontal_direction":"retained",
              "fit":"cached corners of each visible mesh","paint_reserved_height":128,
              "Body_kits":"original low angle, whole bounds, padding and checks retained",
              "same_category":"selection keeps current camera/orbit/zoom", "leave":"exact preceding Garage transform and orbit restored"},
    "captures":[{"path":p.relative_to(EVIDENCE).as_posix(),"sha256":sha(p)} for p in sorted(EVIDENCE.rglob("*.png"))],
    "concurrent_dependency_hashes":[{"path":name,"sha256":sha(ROOT/name)} for name in
        ["game/ui/car_showroom.gd","game/ui/garage_page.gd","game/ui/garage_cached_thumbnail.gd","game/ui/garage_paint_transition.gd"]],
    "checkpoint":{"path":"task-only.patch","sha256":sha(checkpoint),"reverse_check_exit":reverse.returncode,"stderr":reverse.stderr},
    "remaining_acceptance":["client reload","owner visual/rotation review","physical-device touch/performance"],
    "limits":["Windows Compatibility and Vulkan Mobile", "projected mesh bounds, not segmented image pixels",
              "no physical-device attachment check or device test","no APK","no real authentication/purchase or live mutation",
              "no deployment, merge, staging, commit or owner-process restart","concurrent work preserved and excluded"]}
(EVIDENCE/"report.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
print(json.dumps({"runs":[{"name":run["directory"],"exit":run["exit_code"],"summary":run["summary"]} for run in runs],
                  "compact":[row for row in comparison if row["renderer"]=="gl_compatibility" and (row["label"].startswith("compact/") or row["label"].startswith("actual-app/"))],
                  "missing_final_runs":missing,"checkpoint_reverse_exit":reverse.returncode,"checkpoint_error":reverse.stderr},indent=2))
failed = any(run["exit_code"]!=0 for run in runs if not run["directory"].startswith(("before/","initial/")))
raise SystemExit(reverse.returncode or int(failed or bool(missing)))
