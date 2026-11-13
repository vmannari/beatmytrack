"""Reviewable authored delta against task-start copies; never changes Git state."""
import difflib
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
BEFORE = OUT / "before"
EXCLUDED = {"game/vehicle/visual_geometry.gd"}
NEW = [
    "game/vehicle/super_rally_model.gd",
    "game/vehicle/super_rally_model.gd.uid",
    "game/tests/test_super_rally_design.gd",
    "game/tests/test_super_rally_design.gd.uid",
    "game/tests/test_super_rally_c3_kits.gd",
    "game/tests/test_super_rally_c3_kits.gd.uid",
    "game/tests/review_super_rally_design.gd",
    "game/tests/review_super_rally_design.gd.uid",
    *[p.relative_to(ROOT).as_posix() for p in
      (ROOT / "game/tests/fixtures/super_rally_design_before").rglob("*") if p.is_file()],
]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


parts = []
receipt = []
for before in sorted(BEFORE.rglob("*")):
    if not before.is_file():
        continue
    relative = before.relative_to(BEFORE).as_posix()
    if relative in EXCLUDED or not relative.startswith(("game/", "scripts/")):
        continue
    current = ROOT / relative
    if not current.exists() or before.suffix not in (".gd", ".json", ".ps1", ".py", ".tres"):
        continue
    old = before.read_text(encoding="utf-8-sig")
    new = current.read_text(encoding="utf-8-sig")
    if old == new:
        continue
    parts.extend(difflib.unified_diff(old.splitlines(True), new.splitlines(True),
                 "a/" + relative, "b/" + relative))
    receipt.append({"path": relative, "before_sha256": sha(before), "after_sha256": sha(current)})
for relative in sorted(NEW):
    current = ROOT / relative
    if not current.exists():
        continue
    new = current.read_text(encoding="utf-8-sig")
    parts.extend(difflib.unified_diff([], new.splitlines(True), "/dev/null", "b/" + relative))
    receipt.append({"path": relative, "before_sha256": None, "after_sha256": sha(current)})
patch = OUT / "source-only.patch"
patch.write_text("".join(parts), encoding="utf-8", newline="\n")
result = subprocess.run(["git", "apply", "--check", "--reverse", str(patch)], cwd=ROOT,
                        capture_output=True, text=True)
(OUT / "checkpoint-check.log").write_text(result.stdout + result.stderr, encoding="utf-8")
(OUT / "source-receipt.json").write_text(json.dumps({
    "files": receipt, "file_count": len(receipt), "excluded_concurrent": sorted(EXCLUDED),
    "reverse_check_exit_code": result.returncode,
    "camera_baseline": "See camera-baseline-provenance.json",
    "scope": "Authored source only; binaries, generated identities, documentation and existing faster-car/backend changes excluded.",
}, indent=2), encoding="utf-8")
print("SOURCE_CHECKPOINT:", len(receipt), "files; reverse check", result.returncode)
raise SystemExit(result.returncode)
