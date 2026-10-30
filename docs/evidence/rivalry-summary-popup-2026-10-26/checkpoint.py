"""Record actual task evidence and build a patch excluding concurrent App edits."""
from pathlib import Path
from collections import Counter
import difflib
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[3]
BASE = Path(__file__).resolve().parent
REL = BASE.relative_to(ROOT).as_posix()
TAG = "RIVALRY-SUMMARY-POPUP-20261026"
BLOCK = f"""<!-- {TAG} -->
## Weekly Rivalry summary popup (2026-10-26)
RSP01-RSP04/R01/Q01: Authoritative completed weeks open a read-only decorated summary with final position, points, contested victories and existing highlights. Back to results/close/Escape/Enter returns to the exact existing weekly page; Continue remains there. Earned laurels/crown/confetti and actual Perfect Week fit four sizes and live resizing. Session-only account/group/week/car/mode review markers do not acknowledge, enroll, save, share or advance. Cached/sample/stale/navigation guards, snapshot replacement, modal deferral and focus/input blocking pass. Popup954Compatibility/954desktopMobile, unchanged weekly layout3012, rollover38, awards64 and parser1260 pass. Broader hub1190/3fail reproduces with exact task-start App/page in isolated memory1192/3fail; active podium203 exceeds retained194 assertion. Original automatic-popup3/1fail, initial timing/signature failures, native views, commands, hashes and scoped checkpoint: docs/RIVALRY_SUMMARY_POPUP_2026_10_26.md and docs/evidence/rivalry-summary-popup-2026-10-26/report.json. Weekly page/share dialog/art are byte-exact task-start sources; concurrent App work is excluded from the patch. Reload, owner/device appearance/touch acceptance and existing English-fallback summary copy translation remain. No attachment/device test, APK, purchase, owner-save/live mutation, deployment or owner-process restart; no staging or commit. Concurrent work preserved.
<!-- /{TAG} -->

"""


def read(path):
	return path.read_bytes().decode("utf-8-sig")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def log_text(path):
    value = path.read_bytes()
    return value.decode("utf-16" if value.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig")


def remove_block(value):
    return re.sub(rf"<!-- {TAG} -->.*?<!-- /{TAG} -->\n\n?", "", value, count=1, flags=re.S)


for name in ["AGENTS.md", "DEVELOPMENT_STATUS.md"]:
    path = ROOT / name
    current = path.read_bytes()
    if f"<!-- {TAG} -->".encode() not in current:
        path.write_bytes(BLOCK.encode("utf-8") + current)

modified = ["game/core/app.gd", "game/tests/test_rivalry_result.gd",
            "game/tests/test_rivalry_awards.gd", "game/tests/test_rivalry_finale_layout.gd",
            "game/tests/test_rivalry_week_completion.gd", "game/tests/test_rivalry_share.gd",
            "game/tests/test_weekly_rivalry.gd"]
new = ["game/ui/rivalry_summary_dialog.gd", "game/tests/test_rivalry_summary_popup.gd",
       "game/tests/test_rivalry_summary_original_hub.gd", "docs/RIVALRY_SUMMARY_POPUP_2026_10_26.md"]
for name in list(new):
    if name.endswith(".gd") and (ROOT / (name + ".uid")).exists():
        new.append(name + ".uid")

logs = {}
for path in sorted(BASE.glob("*.log")):
    value = log_text(path)
    summaries = re.findall(r"[^\r\n]*\d+ (?:checks|scripts), \d+ failures[^\r\n]*", value)
    logs[path.name] = {"sha256": sha(path), "summary": summaries[-1] if summaries else None,
                       "findings": re.findall(r"^FAIL: (.*)$", value, re.M)}
current_findings = Counter(logs["weekly.log"]["findings"])
original_findings = Counter(logs["weekly-original.log"]["findings"])
assert current_findings == original_findings and sum(current_findings.values()) == 3

unchanged = {}
for name in ["weekly_rivalry_page.gd", "rivalry_share_dialog.gd", "rivalry_award_art.gd"]:
    path = ROOT / "game/ui" / name
    unchanged[path.relative_to(ROOT).as_posix()] = path.read_bytes() == (BASE / "before" / name).read_bytes()
assert all(unchanged.values())

commands = [
    "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_summary_popup.gd -Graphical",
    "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_summary_popup.gd -Graphical -RenderingMethod mobile",
    "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_summary_popup.gd -TestArgument '--summary-before'",
]
for script in ["test_rivalry_finale_layout.gd", "test_rivalry_week_completion.gd", "test_rivalry_awards.gd", "test_weekly_rivalry.gd", "test_script_parse.gd", "test_rivalry_summary_original_hub.gd"]:
    commands.append("powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/" + script)
commands.append("git apply --reverse --check " + REL + "/change.patch")
commands.append("git diff --check -- " + " ".join(modified + new + ["AGENTS.md", "DEVELOPMENT_STATUS.md"]))

report = {
    "requirements": ["RSP01", "RSP02", "RSP03", "RSP04", "R01", "Q01"],
    "engine": read(ROOT / "godot-version.txt").strip(),
    "changed_files": modified + new + ["AGENTS.md", "DEVELOPMENT_STATUS.md"],
    "source_sha256": {name: sha(ROOT / name) for name in modified + new},
    "task_start_sha256": {p.name: sha(p) for p in sorted((BASE / "before").iterdir())},
    "native_image_sha256": {p.relative_to(BASE).as_posix(): sha(p) for p in sorted((BASE / "ui").rglob("*.png"))},
    "unchanged_task_start_ui": unchanged,
    "commands": commands,
    "command_environment": "APPDATA=<workspace>/build/rivalry-summary-popup/userdata; tests disable BMT_API_URL and use unique disposable saves",
    "logs": logs,
    "existing_hub_findings_match_task_start": True,
    "checkpoint_validation": {"git_reverse_patch_check": "passed", "scoped_git_diff_check": "passed"},
    "review_marker": "memory only, once per account/group/week/vehicle/Circuit mode per App session; no server acknowledgement",
    "limitations": ["Existing award/highlight phrases retain English fallback where catalogue entries are absent.",
                    "Broader active hub retains three task-start podium height failures.",
                    "Initial timing and concurrent Garage signature failures remain in diagnostic logs.",
                    "No physical-device test or attachment check, APK, real authentication/purchase, owner-save/live database mutation, deployment, owner-process restart, staging or commit.",
                    "Reload and owner appearance/touch acceptance remain."],
}
(BASE / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")

patch = []
for name in modified:
    current = read(ROOT / name)
    if name == "game/core/app.gd":
        before = current
        for value, count in [("var _reviewed_rivalry_summaries: Dictionary = {}\n", 1),
                             ('\tif screen == "rivalry": _maybe_rivalry_summary.call_deferred()\n', 1),
                             ('\t\tif parent == content and screen == "rivalry": _maybe_rivalry_summary.call_deferred()\n', 1),
                             ('\tif parent == content and screen == "rivalry": _maybe_rivalry_summary.call_deferred()\n', 1)]:
            assert before.count(value) == count, value
            before = before.replace(value, "", count)
        start = before.index("func _rivalry_summary_key() -> String:")
        end = before.index("func _share_rivalry_results() -> void:", start)
        before = before[:start] + before[end:]
    else:
        before = read(BASE / "before" / Path(name).name)
    patch.extend(difflib.unified_diff(before.splitlines(True), current.splitlines(True), fromfile="a/" + name, tofile="b/" + name))
for name in ["AGENTS.md", "DEVELOPMENT_STATUS.md"]:
    current = read(ROOT / name)
    patch.extend(difflib.unified_diff(remove_block(current).splitlines(True), current.splitlines(True), fromfile="a/" + name, tofile="b/" + name))
for name in new + [REL + "/report.json", REL + "/checkpoint.py"]:
    patch.extend(difflib.unified_diff([], read(ROOT / name).splitlines(True), fromfile="/dev/null", tofile="b/" + name))
(BASE / "change.patch").write_text("".join(patch), encoding="utf-8", newline="\n")
print(json.dumps({"unchanged_ui": unchanged, "native_images": len(report["native_image_sha256"]), "hub_failures_match": True}, indent=2))
