"""Retain this copy-only change independently of earlier cleanliness work."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
FILES = ["game/ui/garage_cleanliness.gd", "game/tests/test_garage_clean_customisation.gd", "game/tests/test_garage_wash_easier.gd", "game/tests/test_garage_cleanliness_match.gd"]
NEW = ["docs/GARAGE_CLEANLINESS_LABELS_2026_10_24.md"] + [f"docs/evidence/garage-cleanliness-labels-2026-10-24/{name}" for name in ["run_validation.ps1", "checkpoint.py", "doc-prefixes.json"]]
REPLACEMENTS = {"Certified mud magnet": "There is a car under there. Maybe.", "Grubby but proud": "I can tell the color now", "Needs a rinse": "OK in the dark", "Clean enough for company": "Clean for most people."}


def read(path):
    data = path.read_bytes()
    return data.decode("utf-16" if data.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig").replace("\r\n", "\n")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


before = {name: read(OUT / "before" / name) for name in FILES}
expected = before[FILES[0]]
for old, new in REPLACEMENTS.items():
    expected = expected.replace('"' + old + '"', '"' + new + '"')
assert read(ROOT / FILES[0]) == expected, "Runtime grading code changed beyond requested labels"
prefixes = json.loads(read(OUT / "doc-prefixes.json"))
for name, prefix in prefixes.items():
    current = read(ROOT / name)
    assert current.count(prefix) == 1
    before[name] = current.replace(prefix, "", 1)
patch = []
for name in [*before, *NEW]:
    old, current = before.get(name, ""), read(ROOT / name)
    patch.append(f"diff --git a/{name} b/{name}\n")
    if name not in before:
        patch.append("new file mode 100644\n")
    patch.extend(difflib.unified_diff(old.splitlines(True), current.splitlines(True), fromfile=f"a/{name}" if name in before else "/dev/null", tofile=f"b/{name}"))
(OUT / "checkpoint.patch").write_text("".join(patch), encoding="utf-8", newline="\n")
check = subprocess.run(["git", "apply", "--reverse", "--check", str(OUT / "checkpoint.patch")], cwd=ROOT, capture_output=True, text=True)
assert check.returncode == 0, check.stderr
validation = []
for receipt in sorted(OUT.glob("*/command.json")):
    row = json.loads(read(receipt))
    row["name"] = receipt.parent.name
    row["results"] = [line for line in read(receipt.parent / "console.log").splitlines() if re.search(r"\d+ checks, \d+ failures", line)]
    validation.append(row)
report = {"date": "2026-10-24", "requirements": ["GCL01", "R01", "Q01"], "labels_dirtiest_first": [*REPLACEMENTS.values(), "Shiny. For now."], "runtime_labels_only_check": "passed", "checkpoint_reverse_check": "passed", "changed_files": [*FILES, *prefixes, *NEW], "source_sha256": {name: sha(ROOT / name) for name in [*FILES, *prefixes, *NEW]}, "before_sha256": {name: sha(OUT / "before" / name) for name in FILES}, "checkpoint_sha256": sha(OUT / "checkpoint.patch"), "validation": validation, "capture_sha256": {str(path.relative_to(ROOT)).replace("\\", "/"): sha(path) for path in sorted(OUT.glob("*/*.png"))}, "limitations": ["Sniny interpreted as Shiny spelling typo.", "Client reload and owner/device appearance acceptance remain.", "No device attachment check or physical-device test, APK, owner-process restart, live mutation or deployment.", "Patch excludes preceding grading changes and concurrent work; no staging or commit."]}
(OUT / "report.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8", newline="\n")
print(json.dumps({"runtime_labels_only_check": "passed", "checkpoint_reverse_check": "passed", "validation": {row["name"]: row["results"] for row in validation}}, indent=2))
