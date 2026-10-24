"""Build a reviewable patch against exact task-start source without staging."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
RUNTIME = "game/ui/garage_cleanliness.gd"
NEW = [
    "game/tests/test_garage_cleanliness_match.gd",
    "game/tests/test_garage_cleanliness_match.gd.uid",
    "docs/GARAGE_CLEANLINESS_MATCH_2026_10_24.md",
    "docs/evidence/garage-cleanliness-match-2026-10-24/run_validation.ps1",
    "docs/evidence/garage-cleanliness-match-2026-10-24/checkpoint.py",
    "docs/evidence/garage-cleanliness-match-2026-10-24/doc-prefixes.json",
]


def read(path):
    data = path.read_bytes()
    return data.decode("utf-16" if data.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig").replace("\r\n", "\n")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


prefixes = json.loads(read(OUT / "doc-prefixes.json"))
before = {RUNTIME: read(OUT / "before" / RUNTIME)}
for name, prefix in prefixes.items():
    current = read(ROOT / name)
    assert current.count(prefix) == 1, name
    before[name] = current.replace(prefix, "", 1)
patch = []
for name in [*before, *NEW]:
    old, current = before.get(name, ""), read(ROOT / name)
    if old == current:
        continue
    patch.append(f"diff --git a/{name} b/{name}\n")
    if name not in before:
        patch.append("new file mode 100644\n")
    patch.extend(difflib.unified_diff(old.splitlines(True), current.splitlines(True), fromfile=f"a/{name}" if name in before else "/dev/null", tofile=f"b/{name}"))
(OUT / "checkpoint.patch").write_text("".join(patch), encoding="utf-8", newline="\n")
result = subprocess.run(["git", "apply", "--reverse", "--check", str(OUT / "checkpoint.patch")], cwd=ROOT, capture_output=True, text=True)
assert result.returncode == 0, result.stderr
validation = []
for receipt in sorted(OUT.glob("*/command.json")):
    item = json.loads(read(receipt))
    item["name"] = receipt.parent.name
    item["results"] = [line for line in read(receipt.parent / "console.log").splitlines() if re.search(r"\d+ (?:checks|scripts), \d+ failures", line)]
    validation.append(item)
report = {
    "date": "2026-10-24",
    "requirements": ["CCM01", "CCM02", "R01", "Q01"],
    "engine": read(ROOT / "godot-version.txt").strip(),
    "changed_files": [RUNTIME, *prefixes, *NEW],
    "source_sha256": {name: sha(ROOT / name) for name in [RUNTIME, *prefixes, *NEW]},
    "before_sha256": {RUNTIME: sha(OUT / "before" / RUNTIME)},
    "checkpoint_reverse_check": "passed",
    "checkpoint_sha256": sha(OUT / "checkpoint.patch"),
    "checkpoint_scope": "One runtime checker against its exact task-start source, new regression and exact added documentation prefixes. No staging or commit; concurrent work excluded.",
    "validation": validation,
    "focused_cases": {p.parent.name: json.loads(read(p)) for p in sorted(OUT.glob("test_garage_cleanliness_match-*/report.json"))},
    "native_capture_sha256": {str(p.relative_to(ROOT)).replace("\\", "/"): sha(p) for p in sorted(OUT.glob("test_garage_cleanliness_match-*/*.png"))},
    "limits": [
        "Bounded five-view 16x16 exterior sampling with 15 local footprint buckets; no new rays, draw calls or GPU readback.",
        "Classification still estimates exterior residue; not exact visible pixels for every livery, light or device.",
        "Initial local-only tolerance and Formula snow-footprint corrections retained; no existing assertions weakened.",
        "Initial sandbox certificate-store failure resolved by approved isolated native execution.",
        "Client restart and owner acceptance of the reported actual condition remain.",
        "No phone/tablet attachment check or device test, APK, owner-process restart, live mutation or deployment.",
    ],
}
(OUT / "report.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8", newline="\n")
print(json.dumps({"checkpoint_reverse_check": "passed", "validation": {row["name"]: row["results"] for row in validation}}, indent=2))
