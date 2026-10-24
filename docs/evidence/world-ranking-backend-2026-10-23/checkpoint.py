"""Validate and package only the ranking backend assessment files."""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
subprocess.run([sys.executable, str(OUT / "assess.py")], cwd=ROOT, check=True)
command = [str(ROOT / ".tools/backend-venv/Scripts/python.exe"), "-m", "ruff", "check",
           *[str(OUT / name) for name in ("probe.py", "assess.py", "checkpoint.py")]]
result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, check=False)
(OUT / "lint.log").write_text(result.stdout + result.stderr)
assert result.returncode == 0, result.stdout + result.stderr
sources = [ROOT / "docs/WORLD_RANKING_BACKEND_2026_10_23.md",
           *[OUT / name for name in ("probe.py", "assess.py", "checkpoint.py")]]
patch = []
for path in sources:
    relative = path.relative_to(ROOT).as_posix()
    lines = path.read_text(encoding="utf-8").splitlines()
    patch.extend([f"diff --git a/{relative} b/{relative}", "new file mode 100644",
                  "--- /dev/null", f"+++ b/{relative}", f"@@ -0,0 +1,{len(lines)} @@"])
    patch.extend("+" + line for line in lines)
(OUT / "task-only.patch").write_bytes(("\n".join(patch) + "\n").encode("utf-8"))
command = ["git", "apply", "--reverse", "--check", "--whitespace=error-all", str(OUT / "task-only.patch")]
result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, check=False)
(OUT / "patch-check.log").write_text(result.stdout + result.stderr)
assert result.returncode == 0, result.stdout + result.stderr
manifest = {
    "source_files": {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources},
    "evidence": {p.relative_to(OUT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                 for p in OUT.iterdir() if p.is_file() and p.name != "checkpoint.json"},
    "validation": {"full_history_sql_probes": 3, "score_bounds": "passed", "lint": "passed",
                   "source_fingerprints": "passed", "task_patch_reverse_check": "passed"},
    "checkpoint_command": "python docs/evidence/world-ranking-backend-2026-10-23/checkpoint.py",
    "scope": "Documentation and offline assessment only. No runtime or deployed service changes.",
}
(OUT / "checkpoint.json").write_text(json.dumps(manifest, indent=2))
print(json.dumps(manifest["validation"]))
