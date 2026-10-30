"""Record local tutorial correction evidence and verify an isolated task-only patch."""
from pathlib import Path
import difflib
import hashlib
import html
import json
import re
import shutil
import subprocess
import uuid

E = Path(__file__).resolve().parent
ROOT = E.parents[2]
RUNTIME = ["game/tutorial/tutorial_controller.gd", "game/tutorial/tutorial_overlay.gd"]
TEST = "game/tests/test_first_play_tutorial.gd"
TRACKERS = ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md", "docs/README.md"]
ADDED = ["docs/TUTORIAL_STOP_TOUCH_2026_10_25.md", str((E/"finalize.py").relative_to(ROOT)).replace("\\", "/")]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def lf(data):
    return data.decode("utf-8").replace("\r\n", "\n")


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False)+"\n", encoding="utf-8")


focused = {}
for mode, folder in [("headless", "final-headless"), ("gl_compatibility", "gl_compatibility"), ("mobile", "mobile-confirmation")]:
    focused[mode] = json.loads((E/folder/"test-report.json").read_text(encoding="utf-8"))
    assert focused[mode]["failures"] == 0, (mode, focused[mode])
counts = "/".join(str(r["checks"]) for r in focused.values())
summary = (
    "2026-10-25 TST01-TST02/R01/G01/Q01: Tutorial floor circles now use the car's canonical world conversion; "
    "a stable stop completes without a presentation-sampled brake prerequisite. Touch instructions and actual "
    "saved-control outlines remain visible from the first frame and after keyboard/gamepad events, across all "
    "three methods and handedness. Native target-center/control-border checks, 120Hz/30Hz stopping regressions "
    f"and real five-lap flow pass: focused{counts} headless/Compatibility/desktopMobile, controls407/App141/parser1120. "
    "Initial fixture/focus failures, displaced-circle failures and two Mobile race diagnostics stalled at two laps "
    "remain recorded; added state diagnostics retain the five-lap assertion and two subsequent full runs pass. "
    "Earlier diagnostic stalls remain unexplained. Commands, native views, hashes and isolated Git-checked patch: "
    "docs/TUTORIAL_STOP_TOUCH_2026_10_25.md and docs/evidence/tutorial-stop-touch-2026-10-25/report.json. "
    "Client reload and owner/device touch acceptance remain. No attachment/device test, APK, live mutation, "
    "purchase, deployment or owner-process restart; concurrent work preserved."
)
marker = "TUTORIAL-STOP-TOUCH-20261025"
for name in TRACKERS:
    path = ROOT/name
    raw = path.read_bytes()
    if name == "docs/README.md":
        old = next(line for line in (E/"before"/name).read_bytes().splitlines(keepends=True) if line.startswith(b"| First-play tutorial |"))
        current = next(line for line in raw.splitlines(keepends=True) if line.startswith(b"| First-play tutorial |"))
        base = raw.replace(current, old, 1)
        row = b"| First-play tutorial | [Stopping fix and touch controls](TUTORIAL_STOP_TOUCH_2026_10_25.md), [original lesson](FIRST_PLAY_TUTORIAL_2026_10_24.md) | [Tutorial controller](../game/tutorial/tutorial_controller.gd), [Settings Help](../game/ui/settings_page.gd) |\n"
        updated = base.replace(old, row, 1)
    else:
        expression = rb"<!-- "+marker.encode()+rb" -->.*?<!-- /"+marker.encode()+rb" -->\r?\n\r?\n"
        base = re.sub(expression, b"", raw, flags=re.S)
        title = "## Tutorial stopping and touch controls override (2026-10-25)\n" if name == "AGENTS.md" else ""
        block = f"<!-- {marker} -->\n{title}{summary}\n<!-- /{marker} -->\n\n"
        updated = block.encode()+base
    target = E/"checkpoint-base"/name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(base)
    path.write_bytes(updated)

# Select the exact completed run logs, keeping originals in build/logs as well.
logs = sorted((ROOT/"build/logs").glob("TestScript-*/test-script.log"), key=lambda p: p.stat().st_mtime, reverse=True)
selectors = {
    "final-headless": ("First-play tutorial: 165 checks, 0 failures", None),
    "gl_compatibility": ("First-play tutorial: 223 checks, 0 failures", "OpenGL API"),
    "mobile-confirmation": ("First-play tutorial: 223 checks, 0 failures", "Vulkan"),
    "control-layout": ("CONTROL_LAYOUT: 407 checks, 0 failures", None),
    "app": ("APP_TESTS: 141 checks, 0 failures", None),
    "parser": ("SCRIPT_PARSE: 1120 scripts, 0 failures", None),
}
log_manifest = {}
for name, (needle, extra) in selectors.items():
    source = next(p for p in logs if needle in p.read_text(encoding="utf-8", errors="replace") and (extra is None or extra in p.read_text(encoding="utf-8", errors="replace")))
    target = E/name/"test-script.log"
    target.parent.mkdir(exist_ok=True)
    shutil.copy2(source, target)
    log_manifest[name] = {"source": str(source.relative_to(ROOT)).replace("\\", "/"), "sha256": sha(target.read_bytes())}

files = RUNTIME+[TEST]+TRACKERS+ADDED
manifest = {}
patch = []
bases = {}
for name in files:
    after = (ROOT/name).read_bytes()
    before_path = E/("checkpoint-base" if name in TRACKERS else "before")/name
    before = before_path.read_bytes() if before_path.exists() else b""
    bases[name] = before
    manifest[name] = {"sha256": sha(after), "lf_sha256": sha(lf(after).encode()), "before_sha256": sha(before) if before else None}
    patch.extend(difflib.unified_diff(lf(before).splitlines(keepends=True), lf(after).splitlines(keepends=True), fromfile="a/"+name if before else "/dev/null", tofile="b/"+name))
patch_path = E/"task-only.patch"
patch_path.write_text("".join(patch), encoding="utf-8", newline="\n")
scratch = ROOT/"build"/("tutorial-stop-touch-checkpoint-"+uuid.uuid4().hex)
scratch.mkdir()
for name, before in bases.items():
    if before:
        target = scratch/name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(lf(before), encoding="utf-8", newline="\n")
for args in [["init", "--quiet"], ["config", "core.autocrlf", "false"], ["apply", "--check", str(patch_path)], ["apply", str(patch_path)]]:
    subprocess.run(["git", *args], cwd=scratch, check=True, capture_output=True)
assert all(sha((scratch/name).read_bytes()) == manifest[name]["lf_sha256"] for name in files)
report = {
    "task": "Tutorial stopping and touch controls", "date": "2026-10-25",
    "requirements": ["TST01", "TST02", "R01", "G01", "Q01"],
    "engine": (ROOT/"godot-version.txt").read_text().strip(), "focused": focused,
    "regressions": {"controls":407, "app":141, "parser":1120}, "logs":log_manifest,
    "retained_failures": ["initial-fixture-error.log", "reproduction/test-report.json", "marker-reproduction/test-report.json", "mobile-initial/test-report.json", "mobile-serial/test-report.json"],
    "notes": ["Initial reproduction: 132 checks/20 failures, including two delayed-focus action failures.", "Marker reproduction after controller fix: 147 checks/3 target-center failures.", "Two initial Mobile attempts: target/touch/stop checks passed; full-race diagnostic stopped at two laps. Cause was not captured. Additional paused-state logging leaves the five-lap assertion unchanged; two subsequent full Mobile runs pass in 12753 simulation ticks each. Earlier diagnostic stalls remain unexplained.", "Headless and Compatibility passed before the added failure-state logging; runtime fixes and assertions are identical.", "Native race hitch logs reflect batched diagnostic ticks, not device performance measurements.", "Older broad UI-suite failures remain in the original tutorial evidence; not rerun here.", "Desktop synthetic touches and renderers only; no physical touchscreen test, APK, deployment or owner-process restart."],
    "additional_mobile_pass": json.loads((E/"mobile-diagnostic/test-report.json").read_text(encoding="utf-8")),
    "files":manifest, "checkpoint":{"files":len(files), "patch_sha256":sha(patch_path.read_bytes()), "git_apply_check":True, "reconstructed_lf_hashes_match":True, "isolated_directory":str(scratch.relative_to(ROOT)).replace("\\", "/")},
}
commands = [
    "# Every command uses a workspace-local APPDATA, disposable fixture saves and an empty BMT_API_URL.",
    "# scripts/dev.ps1 selects the pinned engine; test processes require Windows certificate-store access.",
]
for mode, folder in [("headless", "final-headless"), ("gl_compatibility", "gl_compatibility"), ("mobile", "mobile-confirmation")]:
    graphics = "" if mode == "headless" else f" -Graphical -RenderingMethod {mode}"
    commands.append(f"powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_first_play_tutorial.gd{graphics} -TestArgument '--evidence-root=res://../docs/evidence/tutorial-stop-touch-2026-10-25/{folder}' -CommandTimeoutSeconds 300")
for script in ["test_control_layout.gd", "test_app.gd", "test_script_parse.gd"]:
    commands.append(f"powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/{script} -CommandTimeoutSeconds 300")
for folder in ["reproduction", "marker-reproduction"]:
    commands.append(f"powershell -NoProfile -ExecutionPolicy Bypass -Command \"& 'scripts/dev.ps1' TestScript -ScriptPath res://tests/test_first_play_tutorial.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--evidence-root=res://../docs/evidence/tutorial-stop-touch-2026-10-25/{folder}','--hall-only') -CommandTimeoutSeconds 300\"")
for folder in ["mobile", "mobile-serial", "mobile-diagnostic"]:
    commands.append(f"powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_first_play_tutorial.gd -Graphical -RenderingMethod mobile -TestArgument '--evidence-root=res://../docs/evidence/tutorial-stop-touch-2026-10-25/{folder}' -CommandTimeoutSeconds 300")
report["appdata_directories"] = ["build/tutorial-stop-touch-2026-10-25/"+name for name in ["userdata", "userdata-headless-final", "control-userdata", "app-userdata", "parser-userdata"]]
report["commands"] = commands
write_json(E/"report.json", report)
items = ["<!doctype html><meta charset='utf-8'><title>Tutorial stopping and touch controls</title><style>body{background:#101820;color:#eee;font:16px system-ui;max-width:1400px;margin:30px auto}img{width:100%}figure{display:inline-block;vertical-align:top;width:47%;margin:1%}a{color:#ffd25b}</style><h1>Tutorial stopping and touch controls</h1>", f"<p>Focused checks: {html.escape(counts)}; controls 407, App 141, parser 1120. <a href='report.json'>Report</a></p>"]
for folder, label in [("marker-reproduction", "Before: circle displaced from the stopped car"), ("gl_compatibility", "After: circle matches the actual stopping target"), ("mobile-confirmation", "Mobile renderer: aligned target")]:
    items.append(f"<figure><figcaption>{label}</figcaption><img src='{folder}/floor-target-2.png'></figure>")
for filename in ["highlight-buttons-0", "highlight-buttons-1", "highlight-buttons-2", "highlight-horizontal-1", "highlight-joystick-1", "highlight-joystick-2", "stopped-without-brake", "hall-ready"]:
    items.append(f"<figure><figcaption>{html.escape(filename)}</figcaption><img src='gl_compatibility/{filename}.png'></figure>")
(E/"report.html").write_text("\n".join(items), encoding="utf-8")
print(json.dumps({"focused":counts,"patch_files":len(files),"git_apply_check":True,"reconstructed_hashes_match":True}))
