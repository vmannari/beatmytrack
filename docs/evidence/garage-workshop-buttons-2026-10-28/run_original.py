import hashlib
from pathlib import Path
import subprocess
import sys

EVIDENCE = Path(__file__).resolve().parent
ROOT = next(p for p in EVIDENCE.parents if (p / "godot-version.txt").exists())
target = ROOT / "game/ui/garage_page.gd"
current = target.read_bytes()
original = (EVIDENCE / "garage_page.before.gd.txt").read_bytes()
(EVIDENCE / "garage_page.final.before-control.gd.txt").write_bytes(current)
try:
    target.write_bytes(original)
    result = subprocess.run([sys.executable, str(EVIDENCE / "run_checks.py"),
                             "original-clean", "_garage_workshop_clean_before.gd", "headless"], cwd=ROOT)
finally:
    if target.read_bytes() != original:
        raise RuntimeError("Garage source changed during control; final source preserved in evidence, no concurrent edits overwritten")
    target.write_bytes(current)
print("RESTORED_GARAGE_SHA256", hashlib.sha256(target.read_bytes()).hexdigest())
sys.exit(result.returncode)
