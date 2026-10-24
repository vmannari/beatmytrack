"""Collect actual verification and a checkpoint relative to this correction's start."""
import difflib
import hashlib
import json
import re
from pathlib import Path

EVIDENCE = Path(__file__).resolve().parent
ROOT = EVIDENCE.parents[2]
RELATIVE_EVIDENCE = EVIDENCE.relative_to(ROOT).as_posix()


def read_log(path):
    raw = path.read_bytes()
    return raw.decode("utf-16" if raw.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig")


runs = []
for mode in ("headless", "gl_compatibility", "mobile", "before", "regression", "parser"):
    raw = json.loads((EVIDENCE / f"results-{mode}.json").read_text(encoding="utf-8-sig"))
    for run in raw if isinstance(raw, list) else [raw]:
        log = read_log(Path(run["log"]))
        run["outcomes"] = [dict(label=label, count=int(count), unit=unit, failures=int(failures)) for label, count, unit, failures in re.findall(r"([A-Z_]+): (\d+) (checks|scripts), (\d+) failures", log)]
        run["native_background_samples"] = re.findall(r"PODIUM_BACKGROUND: (.+)", log)
        run["log"] = Path(run["log"]).relative_to(ROOT).as_posix()
        runs.append(run)
assert all(run["exit_code"] == 0 for run in runs), "A required correction check failed"
parser_count = next(outcome["count"] for run in runs for outcome in run["outcomes"] if outcome["label"] == "SCRIPT_PARSE")

marker = "RIVALRY-PODIUM-BACKGROUND-20261024"
status = f"2026-10-24 RPB01-RPB02/R01/Q01: Owner clarifies reference podium background and selected-only track highlighting. Podium-only dark medal walls, localized floor lighting, faint perspective seams and metallic rims replace the rejected flat-fill interpretation; other panels stay flat. Unselected tracks retain neutral normal/hover/pressed states. Actual native cars, contact shadows, cosmetics, raised winner, footer alignment and six-unit track padding remain. Focused196headless/210Compatibility/210desktopMobile, Weekly1145/cars199/parser{parser_count} pass. Initial stage/footer inset failure is retained and fixed without lowering thresholds. Native before/after, hidden-car lighting checks, commands, hashes and task-only checkpoint: docs/RIVALRY_PODIUM_BACKGROUND_2026_10_24.md and {RELATIVE_EVIDENCE}/report.json. Reload and owner/device appearance/cost acceptance remain. No attachment check/device test, APK, live mutation, purchase, deployment or owner-process restart; concurrent work preserved."
trackers = ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]
for relative in trackers:
    path = ROOT / relative
    original = path.read_text(encoding="utf-8")
    if f"<!-- {marker} -->" in original:
        continue
    baseline = EVIDENCE / "before-trackers" / path.name
    baseline.parent.mkdir(parents=True, exist_ok=True)
    baseline.write_bytes(path.read_bytes())
    heading = "## Rivalry podium background correction override (2026-10-24)\n" if relative == "AGENTS.md" else ""
    path.write_text(f"<!-- {marker} -->\n{heading}{status}\n<!-- /{marker} -->\n\n"+original, encoding="utf-8", newline="\n")

document = ROOT / "docs/RIVALRY_PODIUM_BACKGROUND_2026_10_24.md"
summary = f"Final checks: 196 headless, 210 Compatibility and 210 desktop Mobile focused checks pass. The existing full Weekly Rivalry interaction suite passes 1145 checks, native car checks pass 199, and all {parser_count} project scripts parse. Compatibility's settled draw count is 155 versus 529 while all three native car views are forced live; the three new stage quads account for the previous task's 152-to-155 change. This is a desktop work count, not device performance certification.\n"
body = document.read_text(encoding="utf-8")
if "Final checks:" not in body:
    document.write_text(body+"\n"+summary, encoding="utf-8", newline="\n")

sources = [
    "game/ui/weekly_rivalry_page.gd",
    "game/ui/rivalry_podium_backdrop.gd",
    "game/ui/rivalry_podium_backdrop.gdshader",
    "game/tests/test_rivalry_view_polish.gd",
    "docs/RIVALRY_PODIUM_BACKGROUND_2026_10_24.md",
    RELATIVE_EVIDENCE+"/run_checks.ps1",
    RELATIVE_EVIDENCE+"/build_report.py",
] + trackers
hashes = {}
patch = []
for relative in sources:
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
    requirements=["RPB01", "RPB02", "R01", "Q01"],
    direction="Reference podium stage backgrounds: medal-tinted dark walls, localized floor light, faint perspective floor, metallic rims. Track highlighting follows selection only; all other panels retain their flat style.",
    engine="4.7.2.stable.official.ed1daf0bf",
    tests=runs,
    source_sha256=hashes,
    task_start_sha256={path.name:hashlib.sha256(path.read_bytes()).hexdigest() for path in (EVIDENCE / "before").glob("*.gd")},
    captures=[path.relative_to(ROOT).as_posix() for path in sorted(EVIDENCE.glob("**/*.png"))],
    initial_failure="Initial native stage inset extended behind the footer; retained in initial-stage-inset-failure.log and corrected with a container-managed holder. No assertion threshold lowered.",
    preserved=["All prior geometry, footer wrapping/alignment and live-score checks", "Actual cars, appearances, contact shadows, render targets and one-shot rendering", "Six-unit track right padding and keyboard focus behavior", "Concurrent work and owner processes"],
    remaining_acceptance=["Client page reload", "Owner reference appearance/feel acceptance", "Physical-device appearance and cost acceptance"],
    boundaries=["No phone/tablet attachment check or physical-device test", "Mobile means desktop Vulkan", "No APK, live backend/account mutation, purchase, deployment or owner-process restart"],
    prior_known_failure="The previously documented broader detail-count assertion was reproduced on task-start code in the prior task. This follow-up does not change detail-count code or tests.",
)
(EVIDENCE / "report.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
print(json.dumps({"runs":len(runs),"all_exits_zero":True,"parser_scripts":parser_count,"source_files":len(sources)}, indent=2))
