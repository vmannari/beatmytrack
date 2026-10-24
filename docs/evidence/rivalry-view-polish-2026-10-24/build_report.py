"""Assemble actual native test outcomes and a task-only checkpoint."""
import difflib
import hashlib
import json
import re
from pathlib import Path

EVIDENCE = Path(__file__).resolve().parent
ROOT = EVIDENCE.parents[2]
marker = "WEEKLY-RIVALRY-POLISH-20261024"
status = "2026-10-24 WRP01-WRP06/R01/Q01: Reference-led Weekly Rivalry keeps flat gold/silver-blue/bronze podiums after the owner removes gradients. Winner rises8 units; larger fitted native cars, compact non-wrapping footer scores/PTS, actual position/gap header, aligned standings and six-unit track right padding retain existing data/interaction/car bounds. Focused142headless/145Compatibility/145desktopMobile, cars135/199, Weekly1124/1145, profiles2176/App141/parser1102 pass. Broader detail321 retains one stale more-driver-label assertion, reproduced with all three task-start runtime sources reloaded only in the isolated process's memory. Initial footer/scrollbar/fixture/sandbox corrections are retained. Native views, commands, hashes and task-only checkpoint: docs/WEEKLY_RIVALRY_POLISH_2026_10_24.md and docs/evidence/rivalry-view-polish-2026-10-24/report.json. Client reload and owner/device appearance/cost acceptance remain. No attachment check/device test, APK, live mutation, purchase, deployment or owner-process restart. Concurrent work preserved."
trackers = ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]
for relative in trackers:
    path = ROOT / relative
    original = path.read_text(encoding="utf-8")
    if f"<!-- {marker} -->" in original:
        continue
    backup = EVIDENCE / "before-trackers" / path.name
    backup.parent.mkdir(parents=True, exist_ok=True)
    backup.write_bytes(path.read_bytes())
    heading = "## Weekly Rivalry reference polish override (2026-10-24)\n" if relative == "AGENTS.md" else ""
    block = f"<!-- {marker} -->\n{heading}{status}\n<!-- /{marker} -->\n\n"
    path.write_text(block+original, encoding="utf-8", newline="\n")
SOURCES = [
    "game/ui/weekly_rivalry_page.gd",
    "game/ui/menu_style.gd",
    "game/ui/race_mode_rail.gd",
    "game/tests/test_weekly_rivalry.gd",
    "game/tests/test_rivalry_view_polish.gd",
    "game/tests/probe_rivalry_detail_polish.gd",
    "docs/WEEKLY_RIVALRY_POLISH_2026_10_24.md",
] + trackers
def read_log(path):
    data = path.read_bytes()
    return data.decode("utf-16" if data.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig")

results = []
for mode in ("headless", "gl_compatibility", "mobile", "before", "parser", "supplemental"):
    path = EVIDENCE / f"results-{mode}.json"
    data = json.loads(path.read_text(encoding="utf-8-sig"))
    for entry in data if isinstance(data, list) else [data]:
        log = read_log(Path(entry["log"]))
        matches = re.findall(r"([A-Z_]+): (\d+) (checks|scripts), (\d+) failures", log)
        entry["outcomes"] = [dict(label=label, count=int(count), unit=unit, failures=int(failures)) for label, count, unit, failures in matches]
        entry["log"] = str(Path(entry["log"]).relative_to(ROOT)).replace("\\", "/")
        results.append(entry)
baseline_log = EVIDENCE / "detail-baseline-probe.log"
results.append(dict(test="probe_rivalry_detail_polish", mode="task_start_runtime_in_memory", exit_code=1, log=str(baseline_log.relative_to(ROOT)).replace("\\", "/"), outcomes=[dict(label="RIVALRY_TRACK_DETAIL_TESTS", count=321, unit="checks", failures=1)], command="scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/probe_rivalry_detail_polish.gd -TestArgument --baseline", baseline_reload_confirmed="TASK_START_UI_RELOADED_IN_MEMORY" in read_log(baseline_log)))

hashes = {}
patch = []
for relative in SOURCES:
    path = ROOT / relative
    content = path.read_bytes()
    hashes[relative] = hashlib.sha256(content).hexdigest()
    baseline = EVIDENCE / ("before-trackers" if relative in trackers else "before") / path.name
    old = baseline.read_text(encoding="utf-8") if baseline.exists() else ""
    new = path.read_text(encoding="utf-8")
    patch.append(f"diff --git a/{relative} b/{relative}\n")
    patch.extend(difflib.unified_diff(old.splitlines(keepends=True), new.splitlines(keepends=True), fromfile=f"a/{relative}" if baseline.exists() else "/dev/null", tofile=f"b/{relative}"))
    target = EVIDENCE / "final" / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(content)
(EVIDENCE / "task-only.patch").write_text("".join(patch), encoding="utf-8", newline="\n")
report = dict(
    date="2026-10-24",
    requirements=["WRP01", "WRP02", "WRP03", "WRP04", "WRP05", "WRP06", "R01"],
    final_direction="Flat gold, cool silver-blue and bronze podiums; no added gradients; compact aligned footers and raised winner; six-unit track right padding.",
    engine="4.7.2.stable.official.ed1daf0bf",
    tests=results,
    source_sha256=hashes,
    baseline_sha256={path.name:hashlib.sha256(path.read_bytes()).hexdigest() for path in (EVIDENCE / "before").glob("*.gd")},
    captures=[str(path.relative_to(ROOT)).replace("\\", "/") for path in sorted(EVIDENCE.glob("**/*.png")) if "retained-hub-evidence" not in str(path)],
    corrections=["Footer points/PTS originally wrapped vertically; explicit non-wrapping labels and reserved score width fix the geometry.", "Gradient helper/shader removed following owner direction; medal palette retained as flat fills.", "Scrollbar header gutter now follows its real inherited width.", "Overview summary container is limited to overview; detail header keeps the original simpler hierarchy.", "Fixture self identity and track ordering corrected without changing shipping data.", "Initial PowerShell execution policy and sandbox certificate restrictions are retained in the task notes."],
    remaining_acceptance=["Client page reload", "Owner appearance/feel acceptance", "Physical-device appearance and cost acceptance"],
    retained_failure="Track-detail suite: 321 checks, one stale more-driver label assertion; reproduced with exact task-start copies of all three edited runtime scripts reloaded only into the isolated process's memory.",
    boundaries=["No device attachment check or physical-device test", "Mobile means desktop Vulkan", "No APK, live backend/account mutation, purchase, deployment or owner-process restart", "Concurrent work preserved"],
)
(EVIDENCE / "report.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
print(json.dumps({"runs":len(results), "outcomes":[entry["outcomes"] for entry in results], "all_exits_zero":all(entry["exit_code"] == 0 for entry in results)}, indent=2))
