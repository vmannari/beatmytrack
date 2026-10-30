"""Scope the reference-popup review patch around concurrent shared App work."""
from pathlib import Path
import difflib
import hashlib
import json
import re

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[2]
REL = BASE.relative_to(ROOT).as_posix()
TAG = "RIVALRY-SUMMARY-REFERENCE-20261026"
BLOCK = f"""<!-- {TAG} -->
## Rivalry results popup follows supplied reference (2026-10-26)
RSR01-RSR04/R01/Q01: Gold-framed sheet replaces centered laurels with large left award/player banner, actual oversized rank, original trophy/checkers, actual player/runner-up comparison and lead badge. Final position, contested wins and validated PB count occupy three cards; the tiny native car uses event vehicle/local cosmetics. View results/close/Escape dismiss; the reference's explicit Continue calls the existing scoped acknowledgement/enrollment once. Busy/stale guards, operation-key reuse, failed retry on unchanged main results and successful next-week return pass. This supersedes only the earlier popup-only dismissal requirement. Final1437Compatibility/1437desktopMobile, retained weekly layout3012/rollover38/parser1281 pass; task-start popup6checks/3expected failures, initial spacing1344/14fail and subsequent corrected runs are retained. Weekly page/share/art/model/adapter and profile studio factory remain exact; concurrent App/header-profile work is excluded from the review patch. Sources, commands, native views, limits and checkpoint: docs/RIVALRY_SUMMARY_REFERENCE_2026_10_26.md and docs/evidence/rivalry-summary-reference-2026-10-26/report.json. Reload and owner/device appearance/touch/translation acceptance remain; a rapid-resize retained header-car artifact behind the scrim is outside this popup pass. No attachment/device test, APK, auth/purchase, owner-save/live mutation, deployment or owner-process restart; no staging/commit. Concurrent changes preserved.
<!-- /{TAG} -->

"""


def read(path):
    return path.read_bytes().decode("utf-8-sig")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def body(text):
    start = text.index("func _maybe_rivalry_summary() -> void:")
    end = text.index("func _share_rivalry_results() -> void:", start)
    return text[start:end]


def remove_block(text):
    return re.sub(rf"<!-- {TAG} -->.*?<!-- /{TAG} -->\n\n?", "", text, count=1, flags=re.S)


for name in ["AGENTS.md", "DEVELOPMENT_STATUS.md"]:
    path = ROOT / name
    current = path.read_bytes()
    if f"<!-- {TAG} -->".encode() not in current:
        path.write_bytes(BLOCK.encode() + current)
    else:
        path.write_bytes(BLOCK.encode() + remove_block(current.decode("utf-8-sig")).encode())

modified = ["game/core/app.gd", "game/ui/rivalry_summary_dialog.gd", "game/tests/test_rivalry_summary_popup.gd"]
added = ["game/ui/rivalry_summary_banner.gd", "docs/RIVALRY_SUMMARY_REFERENCE_2026_10_26.md"]
if (ROOT / "game/ui/rivalry_summary_banner.gd.uid").exists(): added.append("game/ui/rivalry_summary_banner.gd.uid")
unchanged = {}
for path in (BASE / "before").iterdir():
    if path.name in ["app.gd", "rivalry_summary_dialog.gd", "test_rivalry_summary_popup.gd", "profile_car.gd"]: continue
    area = "backend" if path.name == "weekly_rivalry_client.gd" else "race" if path.name == "weekly_rivalry.gd" else "ui"
    current = ROOT / "game" / area / path.name
    unchanged[current.relative_to(ROOT).as_posix()] = current.read_bytes() == path.read_bytes()
assert all(unchanged.values()), unchanged
profile = ROOT / "game/ui/profile_car.gd"
profile_before = BASE / "before/profile_car.gd"
factory = "static func make_preview("
assert read(profile).split(factory,1)[1] == read(profile_before).split(factory,1)[1]

logs = {}
for path in sorted(BASE.glob("*.log")):
    raw = path.read_bytes()
    text = raw.decode("utf-16" if raw.startswith((b"\xff\xfe",b"\xfe\xff")) else "utf-8-sig")
    summaries = re.findall(r"[^\r\n]*\d+ (?:checks|scripts), \d+ failures[^\r\n]*", text)
    logs[path.name] = {"sha256":sha(path), "summary":summaries[-1] if summaries else None,
                       "findings":re.findall(r"^FAIL: (.*)$", text, re.M)}
for name in ["final-compatibility.log", "final-mobile.log", "weekly-layout.log", "week-completion.log", "parser.log"]:
    assert logs[name]["summary"] and ", 0 failures" in logs[name]["summary"], name

commands = [
    "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_summary_popup.gd -Graphical",
    "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_summary_popup.gd -Graphical -RenderingMethod mobile",
    "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_summary_popup.gd -TestArgument '--reference-before'",
]
for script in ["test_rivalry_finale_layout.gd", "test_rivalry_week_completion.gd", "test_script_parse.gd"]:
    commands.append("powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/" + script)
commands.extend(["git apply --reverse --check " + REL + "/change.patch", "git diff --check -- " + " ".join(modified + added + ["AGENTS.md", "DEVELOPMENT_STATUS.md"])])
report = {
    "requirements":["RSR01","RSR02","RSR03","RSR04","R01","Q01"],
    "engine":read(ROOT / "godot-version.txt").strip(),
    "changed_files":modified + added + ["AGENTS.md","DEVELOPMENT_STATUS.md"],
    "source_sha256":{name:sha(ROOT / name) for name in modified + added},
    "before_sha256":{p.name:sha(p) for p in sorted((BASE / "before").iterdir())},
    "unchanged_task_start_sources":unchanged,
    "concurrent_profile":{"before_sha256":sha(profile_before),"current_sha256":sha(profile),"studio_factory_and_presentation_methods_exact":True,"header_picture_changes":"Concurrent work preserved and excluded."},
    "images":{p.relative_to(BASE).as_posix():sha(p) for p in sorted((BASE / "ui").rglob("*.png"))},
    "logs":logs,
    "commands":commands,
    "environment":"APPDATA=<workspace>/build/rivalry-summary-reference/userdata; local delayed fixture; tests disable BMT_API_URL",
    "behavior":"Dismissal is read-only. Only the explicit Continue action invokes the existing scoped acknowledgement/enrollment; failure retries on the unchanged weekly page with the same operation key.",
    "limitations":["No physical-device test or attachment check, APK, real auth/purchase, owner-save/live database mutation, deployment, owner-process restart, staging or commit.",
                   "Reload and owner/device appearance/touch/translation acceptance remain; uncatalogued phrases have English fallback.",
                   "Rapid-resize capture contains an enlarged retained header-car image behind the scrim. Shared profile/header rendering is outside the popup geometry pass."]
}
(BASE / "report.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8",newline="\n")
patch = []
for name in modified:
    current = read(ROOT / name)
    before = read(BASE / "before" / Path(name).name)
    if name == "game/core/app.gd": before = current.replace(body(current),body(before),1)
    patch.extend(difflib.unified_diff(before.splitlines(True),current.splitlines(True),fromfile="a/"+name,tofile="b/"+name))
for name in ["AGENTS.md","DEVELOPMENT_STATUS.md"]:
    current = read(ROOT / name)
    patch.extend(difflib.unified_diff(remove_block(current).splitlines(True),current.splitlines(True),fromfile="a/"+name,tofile="b/"+name))
for name in added + [REL+"/report.json",REL+"/checkpoint.py"]:
    patch.extend(difflib.unified_diff([],read(ROOT / name).splitlines(True),fromfile="/dev/null",tofile="b/"+name))
(BASE / "change.patch").write_text("".join(patch),encoding="utf-8",newline="\n")
print(json.dumps({"unchanged_sources":unchanged,"native_images":len(report["images"]),"final_popup":logs["final-compatibility.log"]["summary"]},indent=2))
