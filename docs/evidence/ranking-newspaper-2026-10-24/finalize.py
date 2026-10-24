"""Record this task's exact sources, real receipts and reversible review patch."""
import difflib
import hashlib
import json
import re
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
BEFORE = HERE / "before"
MARKER = "<!-- RANKING-NEWSPAPER-20261024 -->"
CHECKPOINT = (
    "2026-10-24 RNP01-RNP03/R01/G01/Q01: Remove World Ranking/Circuit buttons "
    "from Weekly Rivalry. Garage newspaper prints bounded published rankings with "
    "scope/paging/Near me/details/Circuit controls in its footer. Completed Circuit "
    "overview shows earned/net points and up/down/unchanged/new-entry movement "
    "above standings, with publication-week/account/safety fences. Focused45headless/"
    "50Compatibility/50desktopMobile, ranking25/news70/native stories868/"
    "Rivalry1115/awards64/App141/parser1085 pass. Initial clipping, sandbox "
    "certificate/userdata, concurrent Desert parser and unsupported headless GPU "
    "probe interruptions are retained; broader native story shutdown reports4 "
    "ObjectDB/1resource. Commands, native views, hashes and scoped checkpoint: "
    "docs/WORLD_RANKING_NEWSPAPER_2026_10_24.md and "
    "docs/evidence/ranking-newspaper-2026-10-24/report.json. Client restart and "
    "owner/device acceptance remain. No phone/tablet attachment check/device "
    "test, APK, live mutation or deployment. Concurrent work and owner processes preserved."
)

for name in ("AGENTS.md", "DEVELOPMENT_STATUS.md"):
    target = ROOT / name
    data = target.read_bytes()
    if MARKER.encode() not in data:
        saved = BEFORE / name
        if not saved.exists():
            saved.write_bytes(data)
        prefix = MARKER + "\n"
        if name == "AGENTS.md":
            prefix += "## World Ranking newspaper and Rivalry layout override (2026-10-24)\n"
        prefix += CHECKPOINT + "\n<!-- /RANKING-NEWSPAPER-20261024 -->\n\n"
        # Read again immediately before writing to preserve other tasks' updates.
        latest = target.read_bytes()
        if latest != data:
            saved.write_bytes(latest)
        target.write_bytes(prefix.encode("utf-8") + latest)

FILES = [
    "game/ui/garage_news_menu.gd",
    "game/ui/garage_news_ranking.gd",
    "game/ui/weekly_rivalry_page.gd",
    "game/ui/weekly_rivalry_finale.gd",
    "game/ui/world_ranking_week_summary.gd",
    "game/tests/test_ranking_newspaper.gd",
    "docs/WORLD_RANKING_NEWSPAPER_2026_10_24.md",
    "docs/evidence/ranking-newspaper-2026-10-24/run_validation.ps1",
    "docs/evidence/ranking-newspaper-2026-10-24/finalize.py",
    "AGENTS.md",
    "DEVELOPMENT_STATUS.md",
]
pieces = []
for name in FILES:
    old = BEFORE / name.replace("/", "__")
    old_lines = old.read_text(encoding="utf-8-sig").splitlines(True) if old.exists() else []
    new_lines = (ROOT / name).read_text(encoding="utf-8-sig").splitlines(True)
    pieces.extend(difflib.unified_diff(old_lines, new_lines,
        fromfile="a/" + name if old.exists() else "/dev/null", tofile="b/" + name))
(HERE / "scoped-change.patch").write_text("".join(pieces), encoding="utf-8", newline="\n")

tests = []
for script, mode, expected, pattern in [
    ("test_ranking_newspaper", "headless", 45, r"RANKING NEWSPAPER: (\d+) checks, (\d+) failures"),
    ("test_ranking_newspaper", "gl_compatibility", 50, r"RANKING NEWSPAPER: (\d+) checks, (\d+) failures"),
    ("test_ranking_newspaper", "mobile", 50, r"RANKING NEWSPAPER: (\d+) checks, (\d+) failures"),
    ("test_world_ranking", "headless", 25, r"WORLD_RANKING checks=(\d+) failures=(\d+)"),
    ("test_garage_news", "headless", 70, r"GARAGE NEWS: (\d+) checks, (\d+) failures"),
    ("test_garage_news_native", "gl_compatibility", 868, r"GARAGE NEWS NATIVE: (\d+) checks, (\d+) failures"),
    ("test_rivalry_awards", "headless", 64, r"RIVALRY_AWARDS: (\d+) checks, (\d+) failures"),
    ("test_weekly_rivalry", "headless", 1115, r"WEEKLY_RIVALRY_TESTS: (\d+) checks, (\d+) failures"),
    ("test_app", "headless", 141, r"APP_TESTS: (\d+) checks, (\d+) failures"),
    ("test_script_parse", "headless", 1085, r"SCRIPT_PARSE: (\d+) scripts, (\d+) failures"),
]:
    name = script + "-" + mode
    log = HERE / (name + ".log")
    match = re.search(pattern, log.read_text(encoding="utf-8"))
    assert match and tuple(map(int, match.groups())) == (expected, 0), name
    command = json.loads((HERE / (name + "-command.json")).read_text(encoding="utf-8-sig"))
    assert command["exit_code"] == 0, name
    tests.append({"test": script, "mode": mode, "checks": expected, "failures": 0,
                  "log": log.relative_to(ROOT).as_posix(), "command": command})

captures = []
for mode in ("gl_compatibility", "mobile"):
    for path in sorted((HERE / mode).glob("*.png")):
        captures.append({"path": path.relative_to(ROOT).as_posix(),
                         "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
report = {
    "task": "World Ranking newspaper and Weekly Rivalry layout",
    "date": "2026-10-24",
    "generated_utc": datetime.now(timezone.utc).isoformat(),
    "requirements": ["RNP01", "RNP02", "RNP03", "R01", "G01", "Q01"],
    "engine": (ROOT / "godot-version.txt").read_text().strip(),
    "tests": tests,
    "sources": [{"path": name, "sha256": hashlib.sha256((ROOT/name).read_bytes()).hexdigest()}
                for name in FILES],
    "captures": captures,
    "checkpoint": "docs/evidence/ranking-newspaper-2026-10-24/scoped-change.patch",
    "retained_limits": [
        "Initial native layout iterations exposed offscreen ranking rows and clipped movement; final assertions require visible content.",
        "Initial scripts/dev.ps1 attempt was blocked by execution policy, then default user:// log permissions; isolated APPDATA is used.",
        "The strict dev runner terminates on the sandbox certificate-store diagnostic. Direct pinned-engine offline fixture runs retain that diagnostic and complete their assertions.",
        "Initial concurrent Desert wind-envelope parser error is retained; that task's sources were not edited.",
        "Existing native newspaper headless GPU probe failed to sample a Dummy texture and was interrupted through its own exec session. Its graphical replacement passed868 checks.",
        "Existing native story fixture exits0 but reports4 retained ObjectDB instances and1 resource at shutdown; no clean-shutdown claim.",
        "No phone/tablet attachment check or physical-device test, APK/export/install, backend mutation or deployment.",
        "Client restart and owner/device visual/flow acceptance remain. Desktop Mobile is not a device-performance test.",
        "Concurrent work and owner processes were preserved; scoped patch only, no shared-workspace commit.",
    ],
}
(HERE / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"tests": len(tests), "checks": sum(t["checks"] for t in tests),
                  "sources": len(FILES), "captures": len(captures), "report": str(HERE / "report.json")}))
