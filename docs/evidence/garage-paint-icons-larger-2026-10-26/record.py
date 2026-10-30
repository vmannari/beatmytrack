"""Record the paint-row icon correction and a scoped reverse-checked patch."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import subprocess

EVIDENCE = Path(__file__).resolve().parent
ROOT = EVIDENCE.parents[2]
EXISTING = ["game/ui/garage_part_option.gd", "game/ui/garage_paint_icons.gd",
            "game/tests/test_garage_paint_list.gd", "game/tests/test_customisation_carousel.gd",
            "AGENTS.md", "DEVELOPMENT_STATUS.md"]
NEW = ["docs/GARAGE_PAINT_ICONS_LARGER_2026_10_26.md"]
NEW += ["docs/evidence/garage-paint-icons-larger-2026-10-26/"+name for name in ("run.ps1","record.py","review.html")]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def log_text(path):
    raw = path.read_bytes()
    return raw.decode("utf-16" if raw.startswith(b"\xff\xfe") else "utf-8-sig",errors="replace")


patch, sources = [], []
for name in EXISTING+NEW:
    target, before = ROOT/name, EVIDENCE/"before"/name
    original = before.read_text(encoding="utf-8") if before.exists() else ""
    current = target.read_text(encoding="utf-8")
    checkpoint_base = None
    if name in ["AGENTS.md","DEVELOPMENT_STATUS.md"]:
        original, removed = re.subn(r"<!-- GARAGE-PAINT-ICONS-LARGER-20261026 -->[\s\S]*?<!-- /GARAGE-PAINT-ICONS-LARGER-20261026 -->\n\n","",current,count=1)
        assert removed==1
        checkpoint_base = EVIDENCE/"checkpoint-base"/name
        checkpoint_base.parent.mkdir(parents=True,exist_ok=True)
        checkpoint_base.write_text(original,encoding="utf-8",newline="\n")
    if original != current:
        patch.append(f"diff --git a/{name} b/{name}\n")
        patch.extend(difflib.unified_diff(original.splitlines(True),current.splitlines(True),
                     fromfile=f"a/{name}" if before.exists() else "/dev/null",tofile=f"b/{name}"))
    sources.append({"path":name,"sha256":sha(target),"before_sha256":sha(before) if before.exists() else None,
                    "checkpoint_base_sha256":sha(checkpoint_base) if checkpoint_base else None})
checkpoint = EVIDENCE/"task-only.patch"
checkpoint.write_text("".join(patch),encoding="utf-8",newline="\n")
reverse = subprocess.run(["git","apply","--check","--reverse",str(checkpoint)],cwd=ROOT,capture_output=True,text=True)
runs = []
for path in sorted(EVIDENCE.glob("*/command.json")):
    log = path.with_name("console.log")
    content = log_text(log)
    runs.append({"directory":path.parent.relative_to(EVIDENCE).as_posix(),
                 **json.loads(path.read_text(encoding="utf-8-sig")),
                 "summary":re.findall(r"(?:GARAGE_PAINT_LIST|CUSTOMISATION_CAROUSEL|SCRIPT_PARSE):[^\r\n]+",content),
                 "failures":re.findall(r"^FAIL:[^\r\n]+",content,re.M),"log_sha256":sha(log)})
expected = {"test_garage_paint_list-"+mode for mode in ["headless","gl_compatibility","mobile"]}
expected |= {"test_customisation_carousel-headless","test_script_parse-headless"}
missing = sorted(expected-{run["directory"] for run in runs})
before_source = "docs/evidence/garage-paint-framing-2026-10-26/test_garage_paint_framing-gl_compatibility/paint-app-1720.png"
report = {
    "date":"2026-10-26","requirements":["GPI01","GPI02","GPI03","R01","Q01"],
    "engine":(ROOT/"godot-version.txt").read_text().strip(),"sources":sources,"runs":runs,"missing_runs":missing,
    "behavior":{"paint_row_numbers":"hidden without layout space", "Parts_row_numbers":"visible and covered by retained assertion",
                "display_sizes_before":[[64,40],[56,36]],"display_sizes_after":[[112,76],[96,72]],
                "render_pixels_before":[176,112],"render_pixels_after":[224,152],"cache_version":2,
                "row_height":100,"cache_bound":24,"active_studio_bound":1,
                "preserved":"profile presentation, all49 paints/seven cars, labels/prices/states/count/purchases, save/account/compare and main camera"},
    "before_capture":{"source":before_source,"source_sha256":sha(ROOT/before_source),
                      "copy":"before/previous-native-paint-rows.png","copy_sha256":sha(EVIDENCE/"before/previous-native-paint-rows.png"),
                      "provenance":"previous native capture of the preceding numbered row UI; not a new baseline run"},
    "initial_attempts":[{"command":json.loads(p.read_text(encoding="utf-8-sig")),
                         "path":p.relative_to(EVIDENCE).as_posix(),
                         "log_sha256":sha(p.with_name(p.name.replace("command.json","console.log")))}
                        for p in sorted((EVIDENCE/"initial").glob("*-command.json"))],
    "captures":[{"path":p.relative_to(EVIDENCE).as_posix(),"sha256":sha(p)} for p in sorted(EVIDENCE.rglob("*.png"))],
    "checkpoint":{"path":"task-only.patch","sha256":sha(checkpoint),"reverse_check_exit":reverse.returncode,"stderr":reverse.stderr},
    "remaining_acceptance":["reload","owner visual/touch review","physical-device appearance/performance"],
    "limits":["Windows Compatibility and Vulkan Mobile with synthetic mouse/touch",
              "no physical-device attachment check or device test","no APK","no real authentication/purchase or live mutation",
              "no deployment, merge, staging, commit or owner-process restart","concurrent changes preserved and excluded"]}
(EVIDENCE/"report.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
print(json.dumps({"runs":[{"name":run["directory"],"exit":run["exit_code"],"summary":run["summary"]} for run in runs],
                  "missing_runs":missing,"checkpoint_reverse_exit":reverse.returncode,"checkpoint_error":reverse.stderr},indent=2))
raise SystemExit(reverse.returncode or int(bool(missing) or any(run["exit_code"]!=0 for run in runs)))
