"""Verify the scoped source patch without staging files or changing the main index."""
import difflib
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).parent
names = ["game/ui/garage_page.gd", "game/ui/garage_wash_tool.gd", "game/tests/test_super_wash.gd",
         "docs/SUPER_WASH_LAYOUT_2026_10_29.md"]
fixture = ROOT / "tmp/super-wash-layout-checkpoint"
fixture.mkdir(parents=True, exist_ok=False)
patch = []
hashes = {}
for name in names:
    after = (ROOT/name).read_text(encoding="utf-8")
    previous = HERE/"before"/name
    before = previous.read_text(encoding="utf-8") if previous.exists() else ""
    patch.extend(difflib.unified_diff(before.splitlines(keepends=True), after.splitlines(keepends=True),
                                      fromfile="a/"+name if previous.exists() else "/dev/null", tofile="b/"+name))
    if previous.exists():
        target = fixture/name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(before, encoding="utf-8", newline="\n")
    hashes[name] = hashlib.sha256(after.encode("utf-8")).hexdigest()
review = HERE/"source-only.patch"
review.write_text("".join(patch), encoding="utf-8", newline="\n")
relative = str(review.relative_to(ROOT))
directory = str(fixture.relative_to(ROOT)).replace("\\", "/")
commands = [["git", "apply", "--check", "--reverse", relative],
            ["git", "apply", "--check", "--directory="+directory, relative],
            ["git", "apply", "--directory="+directory, relative],
            ["git", "apply", "--check", "--reverse", "--directory="+directory, relative]]
receipts = []
for command in commands:
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    receipts.append({"command": command, "exit": result.returncode, "stdout": result.stdout, "stderr": result.stderr})
    assert result.returncode == 0, receipts[-1]
for name in names:
    assert hashlib.sha256((fixture/name).read_text(encoding="utf-8").encode("utf-8")).hexdigest() == hashes[name]
logs = {}
for log in sorted(HERE.glob("*.log")):
    content = log.read_text(encoding="utf-8")
    assert "SCRIPT ERROR:" not in content and "FAIL:" not in content, log
    logs[log.name] = {"result": re.findall(r"(?:SUPER_WASH|Garage hose):[^\n]+", content),
                      "errors": [line for line in content.splitlines() if "ERROR:" in line]}
report = {"date": "2026-10-29", "requirements": ["SWL01", "SWL02", "R01", "Q01"],
          "source_sha256_lf": hashes, "validation_logs": logs, "checkpoint": receipts,
          "captures": {directory.name: len(list(directory.glob("*.png"))) for directory in HERE.glob("Windows-*")},
          "limitations": ["Sandbox Windows certificate-store error retained", "No physical-device query/test", "Reload and owner/device appearance/input acceptance remain"],
          "no_main_index_writes": True, "concurrent_work_preserved": True}
(HERE/"report.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
print("SUPER_WASH_LAYOUT_REVIEW: four-file source/doc patch; forward/reverse checks and fixture hashes pass")
