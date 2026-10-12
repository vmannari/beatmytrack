"""Retain this standings correction without concurrent presentation changes."""
from pathlib import Path
import difflib
import shutil

root = Path.cwd()
evidence = root / "docs/evidence/standings-stability-2026-10-09"
base = evidence / "checkpoint-base"
base.mkdir(exist_ok=True)
status = "2026-10-09 RMC02/RMC04/R01/WR02/WR08/V03-V05/Q01: owner-reported standings movement reproduced as outgoing anchored-size changes and reset scroll during refresh/return. Fixed departing geometry, offscreen initial layout/reveal and scoped transient remembered scroll seeded before first draw; different championships retain independent player reveal. Final graphical stability50/carousel42/weekly1235/App99/headlessentry66/parser395/Import pass; six native captures inspected. Baseline six failures and subpixel/case-isolation fixture corrections retained; no invariant weakened. Concurrent compact podium/track-row edits preserved. Tablet f0ba474a offline; no physical-device test/export/install/full Validate/live race/backend or production action. Files/actual commands/evidence/scoped checkpoint/acceptance: docs/RACE_MODE_CAROUSEL.md (Standings row stability correction).\n\n"
for name in ["DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]:
    path = root / name
    current = path.read_text(encoding="utf-8")
    if status not in current:
        (base / name.replace("/", "__")).write_text(current, encoding="utf-8", newline="\n")
        path.write_text(status+current, encoding="utf-8", newline="\n")
shutil.copyfile(evidence / "before/game__core__app.gd", base / "game__core__app.gd")
page = (root / "game/ui/weekly_rivalry_page.gd").read_text(encoding="utf-8")
reversals = [
    ('var standings_identity: String = ""\nvar standings_scroll_offset: int = -1\nvar standings_scroll: ScrollContainer\nvar standings_ready: bool = false\n', ''),
    ('\tif standings_scroll == null: standings_ready = true\n', ''),
    ('\tstandings_scroll = scroll\n', ''),
    ("\tif standings_scroll_offset >= 0:\n\t\t# Seed the real range before its first draw, rather than painting at zero\n\t\t# and restoring the remembered rows a few frames later.\n\t\tscroll.get_v_scroll_bar().max_value = rows.get_combined_minimum_size().y\n\t\tscroll.scroll_vertical = standings_scroll_offset\n", ''),
    ('\t\tif standings_scroll_offset < 0: scroll.ensure_control_visible(player)\n\t\tstandings_ready = true\n', '\t\tscroll.ensure_control_visible(player)\n'),
]
for after, before in reversals:
    assert page.count(after) == 1, after
    page = page.replace(after, before, 1)
(base / "game__ui__weekly_rivalry_page.gd").write_text(page, encoding="utf-8", newline="\n")
files = ["game/core/app.gd", "game/ui/weekly_rivalry_page.gd", "game/tests/test_standings_stability.gd",
         "game/tests/test_standings_stability.gd.uid", "docs/RACE_MODE_CAROUSEL.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]
patch = ""
for name in files:
    before_path = base / name.replace("/", "__")
    before = before_path.read_text(encoding="utf-8") if before_path.exists() else ""
    after = (root / name).read_text(encoding="utf-8")
    patch += "".join(difflib.unified_diff(before.splitlines(keepends=True), after.splitlines(keepends=True),
                                       fromfile="a/"+name if before_path.exists() else "/dev/null", tofile="b/"+name))
(evidence / "scoped-change.patch").write_text(patch, encoding="utf-8", newline="\n")
markers = {"stability.log": "STANDINGS_STABILITY: 50 checks, 0 failures",
           "carousel.log": "RACE_MODE_CAROUSEL: 42 checks, 0 failures",
           "weekly.log": "WEEKLY_RIVALRY_TESTS: 1235 checks, 0 failures",
           "entry.log": "RIVALRY_ENTRY: 66 checks, 0 failures",
           "app.log": "APP_TESTS: 99 checks, 0 failures",
           "parser.log": "SCRIPT_PARSE: 395 scripts, 0 failures"}
for name, marker in markers.items():
    matches = [p for p in (root / "build/logs").glob("*/*.log") if marker in p.read_text(encoding="utf-8", errors="replace")]
    if matches: shutil.copyfile(max(matches, key=lambda p: p.stat().st_mtime), evidence / name)
for name, path in {"baseline-six-failures.log": "TestScript-32996/test-script.log",
                   "initial-fixture.log": "TestScript-42728/test-script.log",
                   "subpixel-fixture.log": "TestScript-11904/test-script.log",
                   "doctor.log": "Doctor-37960/adb-devices.log"}.items():
    candidate = root / "build/logs" / path
    if candidate.is_file(): shutil.copyfile(candidate, evidence / name)
print("Scoped checkpoint: %d files; concurrent presentation changes preserved." % len(files))
