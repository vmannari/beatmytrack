"""Record the empty-week UI correction without including concurrent work."""
from pathlib import Path
import difflib
import hashlib
import json
import re

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[2]
REL = BASE.relative_to(ROOT).as_posix()
TAG = "RIVALRY-EMPTY-WEEK-20261026"


def read(path):
    return path.read_bytes().decode("utf-8-sig")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


logs = {}
for path in sorted(BASE.glob("*.log")):
    data = path.read_bytes()
    value = data.decode("utf-16" if data.startswith((b"\xff\xfe",b"\xfe\xff")) else "utf-8-sig")
    summaries = re.findall(r"[^\r\n]*\d+ (?:checks|scripts), \d+ failures[^\r\n]*",value)
    logs[path.name] = {"summary":summaries[-1] if summaries else None,"sha256":sha(path)}
for name in ["popup-compatibility.log","popup-mobile.log","parser.log"]:
    assert logs[name]["summary"] and ", 0 failures" in logs[name]["summary"],name

block = f"""<!-- {TAG} -->
## Rivalry popup for a week without races (2026-10-26)
REW01-REW02/R01/Q01: A null rank with zero completed races uses muted No races completed copy in place of the oversized dash, diagonal divider and finish flag/checkers. Ranked banners, real data, comparison/cards, small missing-value position and both actions retain the accepted reference. Runtime scope is the popup and banner helper; existing snapshot/account/dismissal/Continue guards remain. Native popup1517Compatibility/1517desktopMobile and parser1299 pass, including six award states/four sizes, empty-versus-ranked assertions, resize, modal input, stale scope and rollover failure/retry/success. Sources, actual commands, matched native views, hashes and scoped checkpoint: docs/RIVALRY_EMPTY_WEEK_2026_10_26.md and docs/evidence/rivalry-empty-week-2026-10-26/report.json. Reload and owner/device appearance/touch/translation acceptance remain; new copy has English fallback. No attachment/device test, APK, auth/purchase, owner-save/live mutation, deployment or owner-process restart; no staging/commit. Concurrent work preserved.
<!-- /{TAG} -->

"""


def without_block(value):
    return re.sub(rf"<!-- {TAG} -->.*?<!-- /{TAG} -->\n\n?","",value,count=1,flags=re.S)


for name in ["AGENTS.md","DEVELOPMENT_STATUS.md"]:
    path = ROOT / name
    path.write_bytes(block.encode()+without_block(read(path)).encode())

modified = ["game/ui/rivalry_summary_dialog.gd","game/ui/rivalry_summary_banner.gd","game/tests/test_rivalry_summary_popup.gd"]
doc = "docs/RIVALRY_EMPTY_WEEK_2026_10_26.md"
unchanged = {}
for name in ["game/ui/weekly_rivalry_page.gd","game/core/app.gd","game/race/weekly_rivalry.gd","game/backend/weekly_rivalry_client.gd"]:
    unchanged[name] = (ROOT/name).read_bytes() == (BASE/"before"/Path(name).name).read_bytes()
commands = ["powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_summary_popup.gd -Graphical",
            "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_summary_popup.gd -Graphical -RenderingMethod mobile",
            "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd",
            "git apply --reverse --check "+REL+"/change.patch",
            "git diff --check -- "+" ".join(modified+[doc,"AGENTS.md","DEVELOPMENT_STATUS.md"])]
report = {"requirements":["REW01","REW02","R01","Q01"],"engine":read(ROOT/"godot-version.txt").strip(),
          "changed_files":modified+[doc,"AGENTS.md","DEVELOPMENT_STATUS.md"],"commands":commands,"logs":logs,
          "source_sha256":{name:sha(ROOT/name) for name in modified+[doc]},
          "task_start_sha256":{p.name:sha(p) for p in sorted((BASE/"before").iterdir())},
          "untouched_sources_equal_task_start":unchanged,
          "images":{p.relative_to(BASE).as_posix():sha(p) for p in sorted((BASE/"ui").rglob("*.png"))},
          "environment":"APPDATA=<workspace>/build/rivalry-empty-week/userdata; unique disposable fixtures; BMT_API_URL disabled",
          "limitations":["English fallback for the new message; reload and owner/device appearance/touch/translation acceptance remain.",
                         "No physical-device test or attachment check, APK, real auth/purchase, owner-save/live mutation, deployment, owner-process restart, staging or commit."]}
(BASE/"report.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8",newline="\n")
patch = []
for name in modified:
    patch.extend(difflib.unified_diff(read(BASE/"before"/Path(name).name).splitlines(True),read(ROOT/name).splitlines(True),fromfile="a/"+name,tofile="b/"+name))
for name in ["AGENTS.md","DEVELOPMENT_STATUS.md"]:
    value = read(ROOT/name)
    patch.extend(difflib.unified_diff(without_block(value).splitlines(True),value.splitlines(True),fromfile="a/"+name,tofile="b/"+name))
for name in [doc,REL+"/report.json",REL+"/checkpoint.py"]:
    patch.extend(difflib.unified_diff([],read(ROOT/name).splitlines(True),fromfile="/dev/null",tofile="b/"+name))
(BASE/"change.patch").write_text("".join(patch),encoding="utf-8",newline="\n")
print(json.dumps({"unchanged":unchanged,"results":logs},indent=2))
