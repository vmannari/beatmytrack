"""Record real card-refinement verification and its task-start checkpoint."""
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
    values = json.loads((EVIDENCE / f"results-{mode}.json").read_text(encoding="utf-8-sig"))
    for run in values if isinstance(values, list) else [values]:
        log = read_log(Path(run["log"]))
        run["outcomes"] = [dict(label=label, count=int(count), unit=unit, failures=int(failures)) for label, count, unit, failures in re.findall(r"([A-Z_]+): (\d+) (checks|scripts), (\d+) failures", log)]
        run["native_background_samples"] = re.findall(r"PODIUM_BACKGROUND: (.+)", log)
        run["log"] = Path(run["log"]).relative_to(ROOT).as_posix()
        runs.append(run)
assert all(run["exit_code"] == 0 for run in runs)
parser_count = next(outcome["count"] for run in runs for outcome in run["outcomes"] if outcome["label"] == "SCRIPT_PARSE")
backgrounds = {}
for name in ("rivalry_podium_backdrop.gd", "rivalry_podium_backdrop.gdshader"):
    before_hash = sha(EVIDENCE / "before" / name)
    current_hash = sha(ROOT / "game/ui" / name)
    assert before_hash == current_hash, f"Approved background changed: {name}"
    backgrounds[name] = dict(task_start_sha256=before_hash, final_sha256=current_hash, unchanged=True)

marker = "RIVALRY-CARD-REFINEMENT-20261024"
status = f"2026-10-24 RCF01-RCF03/R01/Q01: Owner accepts podium background and requests equal cards, refined names and smaller points. All three cards now share194-unit heights/top/bottom edges; integrated56-unit footers use larger28-unit flags, centered names, cleaner divider/padding and22-unit condensed points with11-unit PTS. Approved backdrop/shader hashes are exact; car/render/score/selection/padding contracts remain. Focused250headless/264Compatibility/264desktopMobile, Weekly1145/cars199/parser{parser_count} pass. Raised-winner assertions are replaced by the owner's equal-height contract; all other assertions remain. Native before/after, commands, hashes and task-only checkpoint: docs/RIVALRY_CARD_REFINEMENT_2026_10_24.md and {REL}/report.json. Reload and owner/device acceptance remain. No attachment/device test, APK, live mutation, purchase, deployment or owner-process restart; concurrent work preserved."
trackers = ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]
for relative in trackers:
    path = ROOT / relative
    original = path.read_text(encoding="utf-8")
    if f"<!-- {marker} -->" in original:
        continue
    backup = EVIDENCE / "before-trackers" / path.name
    backup.parent.mkdir(parents=True, exist_ok=True)
    backup.write_bytes(path.read_bytes())
    heading = "## Rivalry equal-height cards and footer refinement override (2026-10-24)\n" if relative == "AGENTS.md" else ""
    path.write_text(f"<!-- {marker} -->\n{heading}{status}\n<!-- /{marker} -->\n\n"+original, encoding="utf-8", newline="\n")

document = ROOT / "docs/RIVALRY_CARD_REFINEMENT_2026_10_24.md"
body = document.read_text(encoding="utf-8")
if "Final checks:" not in body:
    document.write_text(body+f"\nFinal checks: 250 headless, 264 Compatibility and 264 desktop Mobile focused checks pass; full Weekly Rivalry interaction1145, native cars199 and parser{parser_count} pass. Both approved background source hashes are unchanged.\n", encoding="utf-8", newline="\n")

sources = ["game/ui/weekly_rivalry_page.gd", "game/tests/test_rivalry_view_polish.gd", "game/tests/test_rivalry_custom_cars.gd", "game/tests/test_weekly_rivalry.gd", "docs/RIVALRY_CARD_REFINEMENT_2026_10_24.md", REL+"/run_checks.ps1", REL+"/build_report.py"]+trackers
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
    target = EVIDENCE / "final" / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(path.read_bytes())
(EVIDENCE / "task-only.patch").write_text("".join(patch), encoding="utf-8", newline="\n")
report = dict(date="2026-10-24", requirements=["RCF01", "RCF02", "RCF03", "R01", "Q01"], engine="4.7.2.stable.official.ed1daf0bf", tests=runs, source_sha256=hashes, approved_backgrounds=backgrounds, captures=[path.relative_to(ROOT).as_posix() for path in sorted(EVIDENCE.glob("**/*.png"))], superseded_requirement="The latest explicit equal-height request replaces the earlier raised/taller winner requirement; no other assertion is weakened.", remaining_acceptance=["Client page reload", "Owner appearance/feel acceptance", "Physical-device appearance and cost acceptance"], boundaries=["No phone/tablet attachment check or physical-device test", "Mobile means desktop Vulkan", "No APK, live backend/account mutation, purchase, deployment or owner-process restart", "Concurrent work preserved"])
(EVIDENCE / "report.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
print(json.dumps(dict(runs=len(runs), all_exits_zero=True, parser_scripts=parser_count, approved_backgrounds_unchanged=True), indent=2))
