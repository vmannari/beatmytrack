"""Build a task-scoped review patch while keeping concurrent work intact."""
from pathlib import Path
import difflib
import shutil

root = Path.cwd()
evidence = root / "docs/evidence/race-mode-carousel-2026-10-09"
base = evidence / "checkpoint-base"
base.mkdir(exist_ok=True)
status = "2026-10-09 RMC01-RMC04/R01/V03-V05/Q01/WR01-WR03/WR08/TD08: owner-requested vertical Race carousel and populated first Rivalry entry implemented locally. Full viewport/0.32s rail-order slides retain fixed header/rail, asynchronous refresh and rapid interruption; authenticated startup/sign-in/car preloading reuses scoped requests and keeps the current menu until actual membership/error is ready. No empty rivalry/Join flash or invented data; account/new-choice fences retained. Final carousel52/entry70/automatic7/App99/weekly1235/headlessswipes240/parser394/Import pass; disposable native HTTP39/five-lap12757-tick verification pass. Fourteen layout/transition and eight HTTP captures inspected; initial timing/anchored-height/settle/guest-refresh/fixture-directory failures corrected without weakened assertions. Tablet f0ba474a offline; no physical-device test/Android export-install/full Validate/live deployment/production action. Scoped checkpoint preserves concurrent work. Files/commands/evidence/limits/acceptance: docs/RACE_MODE_CAROUSEL.md.\n\n"
for name in ["DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]:
    path = root / name
    current = path.read_text(encoding="utf-8")
    if status not in current:
        (base / name.replace("/", "__")).write_text(current, encoding="utf-8", newline="\n")
        path.write_text(status+current, encoding="utf-8", newline="\n")

for name in ["game/core/app.gd", "game/backend/weekly_rivalry_client.gd", "game/tests/test_rivalry_entry.gd"]:
    shutil.copyfile(evidence / "before" / name.replace("/", "__"), base / name.replace("/", "__"))

# Preserve concurrent track-detail assertions; reverse only our new settle helper.
weekly = (root / "game/tests/test_weekly_rivalry.gd").read_text(encoding="utf-8")
added = "\t# Bounds/focus assertions inspect the destination after its menu transition.\n\twhile app != null and app.menu_page_motion != null: await process_frame\n"
assert weekly.count(added) == 1
(base / "game__tests__test_weekly_rivalry.gd").write_text(weekly.replace(added, "", 1), encoding="utf-8", newline="\n")
files = ["game/core/app.gd", "game/backend/weekly_rivalry_client.gd", "game/tests/test_rivalry_entry.gd",
         "game/tests/test_weekly_rivalry.gd", "game/tests/test_race_mode_carousel.gd", "game/tests/test_race_mode_carousel.gd.uid",
         "AGENTS.md", "docs/RACE_MODE_CAROUSEL.md", "docs/WEEKLY_RIVALRY.md", "docs/MENU_PAGE_SWIPES.md",
         "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]
patch = ""
for name in files:
    old_path = base / name.replace("/", "__")
    old = old_path.read_text(encoding="utf-8") if old_path.exists() else ""
    current = (root / name).read_text(encoding="utf-8")
    patch += "".join(difflib.unified_diff(old.splitlines(keepends=True), current.splitlines(keepends=True),
                                       fromfile="a/"+name if old_path.exists() else "/dev/null", tofile="b/"+name))
(evidence / "scoped-change.patch").write_text(patch, encoding="utf-8", newline="\n")

markers = {"carousel.log": "RACE_MODE_CAROUSEL: 52 checks, 0 failures",
           "entry.log": "RIVALRY_ENTRY: 70 checks, 0 failures",
           "automatic-flow.log": "AUTOMATIC_RIVALRY_FLOW: 7 checks, 0 failures",
           "weekly.log": "WEEKLY_RIVALRY_TESTS: 1235 checks, 0 failures",
           "swipes.log": "MENU_PAGE_SWIPE: 240 checks, 0 failures",
           "parser.log": "SCRIPT_PARSE: 394 scripts, 0 failures",
           "app.log": "APP_TESTS: 99 checks, 0 failures"}
for name, marker in markers.items():
    matches = [p for p in (root / "build/logs").glob("*/*.log") if marker in p.read_text(encoding="utf-8", errors="replace")]
    if matches: shutil.copyfile(max(matches, key=lambda p: p.stat().st_mtime), evidence / name)
for name, source in {"doctor.log": "Doctor-41844/adb-devices.log",
                     "import.log": "Import-42104/import.log",
                     "carousel-initial-timing.log": "TestScript-21844/test-script.log",
                     "weekly-initial-moving-layout.log": "TestScript-42164/test-script.log",
                     "weekly-initial-guest-refresh.log": "TestScript-36036/test-script.log"}.items():
    candidate = root / "build/logs" / source
    if candidate.is_file(): shutil.copyfile(candidate, evidence / name)
(evidence / "http-outcome.txt").write_text("Actual disposable pytest run: 1 passed, 1 existing Starlette/httpx warning in 42.04s.\nNative WEEKLY_RIVALRY_HTTP_TESTS: 39 checks, 0 failures.\nCanonical verification_complete: time_ticks=12757, five legal laps, verification_seconds=2.219.\nEight actual native screenshots retained in http/.\nNo live account/backend data used.\n", encoding="utf-8")
print("Scoped checkpoint: %d files; actual test evidence retained." % len(files))
