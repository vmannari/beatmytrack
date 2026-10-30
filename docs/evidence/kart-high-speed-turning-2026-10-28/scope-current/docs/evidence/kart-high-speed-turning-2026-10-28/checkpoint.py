"""Build and check a task-only patch without changing the main Git index."""
from pathlib import Path
import difflib
import hashlib
import json
import os
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
MEMO = "KART-HIGH-SPEED-TURNING-20261028"
FILES = [
    "game/resources/cars/kart.tres",
    "game/tests/test_kart.gd",
    "game/tests/test_kart_high_speed_turning.gd",
    "game/tests/fixtures/kart_high_speed_turning_before.tres",
    "backend/tests/fixtures/verified_oval.json",
    "docs/KART_HIGH_SPEED_TURNING_2026_10_28.md", "docs/KART.md",
    "AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md",
    "docs/evidence/kart-high-speed-turning-2026-10-28/verify_canonical.py",
    "docs/evidence/kart-high-speed-turning-2026-10-28/summarize.py",
    "docs/evidence/kart-high-speed-turning-2026-10-28/checkpoint.py",
]

patch = []
hashes = {}
for relative in FILES:
    current = (ROOT / relative).read_text(encoding="utf-8")
    saved = OUT / "before" / relative
    previous = saved.read_text(encoding="utf-8") if saved.exists() else ""
    # Retain concurrent edits in shared documents/tests/fixture as the patch base.
    if relative in {"AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md", "docs/KART.md"}:
        previous, count = re.subn(
            rf"<!-- {MEMO} -->.*?<!-- /{MEMO} -->\n\n", "", current, flags=re.S)
        assert count == 1, (relative, count)
    elif relative == "backend/tests/fixtures/verified_oval.json":
        old = json.loads(previous)["expected_manifest"]["vehicles"]["kart"]
        new = json.loads(current)["expected_manifest"]["vehicles"]["kart"]
        previous = current.replace(new["config_hash"], old["config_hash"]).replace(
            '"handling_version": "kart-6"', '"handling_version": "kart-5"')
        assert previous != current
    elif relative == "game/tests/test_kart.gd":
        previous = current.replace(
            'check(kart.version == "kart-6","current cornering tune retains a separate handling identity")',
            'check(kart.version == "kart-5","higher speed has a separate handling identity")')
        assert previous != current
    hashes[relative] = hashlib.sha256((ROOT / relative).read_bytes()).hexdigest()
    for name, contents in [("scope-base", previous), ("scope-current", current)]:
        if not contents:
            continue
        target = OUT / name / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(contents, encoding="utf-8", newline="\n")
    patch.extend(difflib.unified_diff(
        previous.splitlines(True), current.splitlines(True),
        fromfile="a/"+relative if previous else "/dev/null", tofile="b/"+relative))

patch_path = OUT / "task.patch"
patch_path.write_text("".join(patch), encoding="utf-8", newline="\n")
reverse = subprocess.run(["git", "apply", "--reverse", "--check", str(patch_path)],
                         cwd=ROOT, capture_output=True, text=True)
environment = dict(os.environ, GIT_CEILING_DIRECTORIES=str(OUT))
forward = subprocess.run(["git", "apply", "--check", str(patch_path)],
                         cwd=OUT / "scope-base", env=environment, capture_output=True, text=True)
receipt = {"source_hashes": hashes, "reverse_apply_check": reverse.returncode,
           "forward_apply_check": forward.returncode,
           "diagnostics": {"reverse": reverse.stderr, "forward": forward.stderr},
           "main_index_used": False}
(OUT / "checkpoint.json").write_text(json.dumps(receipt, indent=2)+"\n")
print(json.dumps({key: value for key, value in receipt.items() if key != "source_hashes"}))
assert reverse.returncode == forward.returncode == 0
