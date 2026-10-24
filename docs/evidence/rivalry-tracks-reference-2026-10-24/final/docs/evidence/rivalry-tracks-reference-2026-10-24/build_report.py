"""Collect actual track-panel verification and a task-start-only checkpoint."""
import difflib
import hashlib
import json
import re
from pathlib import Path

EVIDENCE = Path(__file__).resolve().parent
ROOT = EVIDENCE.parents[2]
REL = EVIDENCE.relative_to(ROOT).as_posix()


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_log(path):
    raw = path.read_bytes()
    return raw.decode("utf-16" if raw.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig")


runs = []
for mode in ("headless", "gl_compatibility", "mobile", "before", "regression", "parser"):
    raw = json.loads((EVIDENCE / f"results-{mode}.json").read_text(encoding="utf-8-sig"))
    for run in raw if isinstance(raw, list) else [raw]:
        log = read_log(Path(run["log"]))
        run["outcomes"] = [dict(label=label, count=int(count), unit=unit, failures=int(failures)) for label, count, unit, failures in re.findall(r"([A-Z_]+): (\d+) (checks|scripts), (\d+) failures", log)]
        run["log"] = Path(run["log"]).relative_to(ROOT).as_posix()
        runs.append(run)
assert all(run["exit_code"] == 0 for run in runs)
outcomes = {outcome["label"]:outcome["count"] for run in runs for outcome in run["outcomes"]}
parser_count = outcomes["SCRIPT_PARSE"]
backgrounds = {}
for name in ("rivalry_podium_backdrop.gd", "rivalry_podium_backdrop.gdshader"):
    old = sha(EVIDENCE / "before" / name)
    new = sha(ROOT / "game/ui" / name)
    assert old == new, f"Accepted background changed: {name}"
    backgrounds[name] = dict(task_start_sha256=old, final_sha256=new)
before_page = (EVIDENCE / "before/weekly_rivalry_page.gd").read_text(encoding="utf-8")
after_page = (ROOT / "game/ui/weekly_rivalry_page.gd").read_text(encoding="utf-8")
def podium(source):
    start = source.index("func _podium(")
    return source[start:source.index("\nfunc _track_time(", start)]
assert podium(before_page) == podium(after_page), "Accepted podium section changed"

marker = "RIVALRY-TRACKS-REFERENCE-20261024"
status = f"2026-10-24 RTR01-RTR03/R01/Q01: Owner's track reference adds numbered wider thumbnails, open divider rows, larger aligned place/time columns and verified lead/completion segments. Filled highlight exists only while pressed; hover/release/remembered selection remain neutral, with a small number-frame keyboard cue. Enlarged next-target badge sits between name/place and chooses the smallest verified gap to the immediately preceding driver, excluding unplayed/unavailable/pending results. Distinguishing nearest-position-vs-leader test passes. Focused352headless/372Compatibility/372desktopMobile, Weekly{outcomes['WEEKLY_RIVALRY_TESTS']}/verified-time{outcomes['RIVALRY_TRACK_TIME_TESTS']}/input{outcomes['RACE_MODE_INPUT']}/parser{parser_count} pass. Accepted podium section and backdrop hashes are exact. Native press/release/before/after, commands, hashes and task-only checkpoint: docs/RIVALRY_TRACKS_REFERENCE_2026_10_24.md and {REL}/report.json. Reload and owner/device appearance/cost acceptance remain; no attachment/device test, APK, live mutation, purchase, deployment or owner-process restart. Concurrent work preserved."
trackers = ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]
for relative in trackers:
    path = ROOT / relative
    original = path.read_text(encoding="utf-8")
    if f"<!-- {marker} -->" in original:
        continue
    backup = EVIDENCE / "before-trackers" / path.name
    backup.parent.mkdir(parents=True, exist_ok=True)
    backup.write_bytes(path.read_bytes())
    heading = "## Rivalry track reference and press-only feedback override (2026-10-24)\n" if relative == "AGENTS.md" else ""
    path.write_text(f"<!-- {marker} -->\n{heading}{status}\n<!-- /{marker} -->\n\n"+original, encoding="utf-8", newline="\n")

document = ROOT / "docs/RIVALRY_TRACKS_REFERENCE_2026_10_24.md"
body = document.read_text(encoding="utf-8")
if "Final checks:" not in body:
    document.write_text(body+f"\nFinal checks: 352 headless, 372 Compatibility and 372 desktop Mobile focused checks pass. Full Weekly Rivalry interactions{outcomes['WEEKLY_RIVALRY_TESTS']}, verified-time/receipt checks{outcomes['RIVALRY_TRACK_TIME_TESTS']}, actual parked-page/pointer input{outcomes['RACE_MODE_INPUT']} and parser{parser_count} pass. The accepted podium function and both background files are unchanged.\n", encoding="utf-8", newline="\n")

sources = ["game/ui/weekly_rivalry_page.gd", "game/ui/rivalry_track_accents.gd", "game/tests/test_rivalry_view_polish.gd", "docs/RIVALRY_TRACKS_REFERENCE_2026_10_24.md", REL+"/run_checks.ps1", REL+"/build_report.py"]+trackers
hashes = {}
patch = []
for relative in sources:
    path = ROOT / relative
    hashes[relative] = sha(path)
    baseline = EVIDENCE / ("before-trackers" if relative in trackers else "before") / path.name
    old = baseline.read_text(encoding="utf-8") if baseline.exists() else ""
    new = path.read_text(encoding="utf-8")
    patch.append(f"diff --git a/{relative} b/{relative}\n")
    patch.extend(difflib.unified_diff(old.splitlines(keepends=True), new.splitlines(keepends=True), fromfile=f"a/{relative}" if baseline.exists() else "/dev/null", tofile=f"b/{relative}"))
    destination = EVIDENCE / "final" / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(path.read_bytes())
(EVIDENCE / "task-only.patch").write_text("".join(patch), encoding="utf-8", newline="\n")
report = dict(date="2026-10-24", requirements=["RTR01", "RTR02", "RTR03", "R01", "Q01"], engine="4.7.2.stable.official.ed1daf0bf", tests=runs, source_sha256=hashes, accepted_backgrounds=backgrounds, podium_section_unchanged=True, captures=[path.relative_to(ROOT).as_posix() for path in sorted(EVIDENCE.glob("**/*.png"))], final_target_rule="Smallest positive verified gap to the immediately preceding driver among available non-pending tracks with an own verified time. No target if no known eligible position gap.", steering="Owner enlarged the initial target badge, moved it into the name/place gap and clarified nearest-position rather than race-leader selection. Initial passing layout logs are retained.", remaining_acceptance=["Client page reload", "Owner appearance/interaction acceptance", "Physical-device appearance and cost acceptance"], boundaries=["No phone/tablet attachment check or physical-device test", "Mobile means desktop Vulkan", "No APK, live backend/account mutation, purchase, deployment or owner-process restart", "Concurrent work preserved"])
(EVIDENCE / "report.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
print(json.dumps(dict(runs=len(runs), all_exits_zero=True, parser_scripts=parser_count, accepted_podium_unchanged=True), indent=2))
