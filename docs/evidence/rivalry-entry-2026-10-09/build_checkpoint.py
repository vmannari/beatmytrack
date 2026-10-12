"""Retain only this entry fix in a reverse-checkable mixed-workspace patch."""
from pathlib import Path
import difflib
import shutil

root = Path.cwd()
evidence = root / "docs/evidence/rivalry-entry-2026-10-09"
base = evidence / "checkpoint-base"
base.mkdir(exist_ok=True)
app = (root / "game/core/app.gd").read_text(encoding="utf-8")
reversals = [
    ('\tif destination == "rivalry":\n\t\t_rivalry(column)\n\telif destination == "garage":', '\tif destination == "garage":'),
    ('\tif not rivalry.model.sample: rivalry.refresh()\n\t_navigate_menu_page("rivalry")', '\t_navigate_menu_page("rivalry")\n\tif not rivalry.model.sample: rivalry.refresh()'),
    ('\t# Swipe previews must follow the same membership state as the visible page.\n\tfor neighbor: Dictionary in menu_neighbors.values():\n\t\tif neighbor.screen == "rivalry": _rivalry(neighbor.content)\n\tif returning_menu_neighbor.get("screen","") == "rivalry" and is_instance_valid(returning_menu_neighbor.get("content")):\n\t\t_rivalry(returning_menu_neighbor.content)\n', ''),
]
for after, before in reversals:
    assert app.count(after) == 1, after
    app = app.replace(after, before, 1)
(base / "game__core__app.gd").write_text(app, encoding="utf-8", newline="\n")
page = (root / "game/ui/weekly_rivalry_page.gd").read_text(encoding="utf-8")
condition = '\t# An unresolved membership is not a confirmed invitation to join.\n\tif model.tracks.is_empty() and signed_in and error.is_empty() and (busy or model.received_msec == 0): _loading(body)\n\telif model.tracks.is_empty(): _empty(body)'
assert page.count(condition) == 1
page = page.replace(condition, '\tif model.tracks.is_empty(): _empty(body)', 1)
start = page.index("func _loading(")
end = page.index("func _empty(", start)
page = page[:start] + page[end:]
(base / "game__ui__weekly_rivalry_page.gd").write_text(page, encoding="utf-8", newline="\n")
for name in ["DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]:
    current = (root / name).read_text(encoding="utf-8")
    own = next(paragraph for paragraph in current.split("\n\n") if paragraph.startswith("2026-10-09 WR01-WR03/WR08/TD08/B05/"))
    (base / name.replace("/", "__")).write_text(current.replace(own+"\n\n", "", 1), encoding="utf-8", newline="\n")
name = "docs/WEEKLY_RIVALRY.md"
current = (root / name).read_text(encoding="utf-8")
heading = "\n## Immediate rivalry page on entry, 2026-10-09\n"
assert current.count(heading) == 1
(base / name.replace("/", "__")).write_text(current.split(heading)[0].rstrip()+"\n", encoding="utf-8", newline="\n")
files = ["game/core/app.gd", "game/ui/weekly_rivalry_page.gd", "game/tests/test_rivalry_entry.gd", "game/tests/test_rivalry_entry.gd.uid", "docs/WEEKLY_RIVALRY.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]
patch = ""
for name in files:
    old_path = base / name.replace("/", "__")
    old = old_path.read_text(encoding="utf-8") if old_path.exists() else ""
    current = (root / name).read_text(encoding="utf-8")
    patch += "".join(difflib.unified_diff(old.splitlines(keepends=True), current.splitlines(keepends=True), fromfile="a/"+name if old_path.exists() else "/dev/null", tofile="b/"+name))
(evidence / "scoped-change.patch").write_text(patch, encoding="utf-8", newline="\n")
logs = {
    "entry-graphical.log": "TestScript-16268/test-script.log",
    "automatic-flow.log": "TestScript-24464/test-script.log",
    "app.log": "TestApp-41036/app-tests.log",
    "weekly-rivalry.log": "TestScript-17436/test-script.log",
    "menu-swipes.log": "TestScript-4620/test-script.log",
    "doctor.log": "Doctor-20200/adb-devices.log",
    "entry-initial-fixture-error.log": "TestScript-19024/test-script.log",
    "entry-initial-sandbox-error.log": "TestScript-41652/test-script.log",
}
for dest, src in logs.items():
    candidate = root / "build/logs" / src
    if candidate.is_file(): shutil.copyfile(candidate, evidence / dest)
parsers = [p for p in (root / "build/logs").glob("TestScript-*/test-script.log") if "SCRIPT_PARSE: 388 scripts, 0 failures" in p.read_text(encoding="utf-8", errors="replace")]
if parsers: shutil.copyfile(max(parsers, key=lambda p: p.stat().st_mtime), evidence / "script-parse.log")
print("Scoped checkpoint: %d files; evidence logs retained." % len(files))
