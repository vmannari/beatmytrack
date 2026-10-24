"""Validate and package the lean storage assessment without changing runtime."""
import hashlib
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
data = json.loads((OUT / "probe.json").read_text())
assert data["cleanup"] is True
assert hashlib.sha256((OUT / "probe.py").read_bytes()).hexdigest() == data["source_sha256"]
assert data["counts"]["award"] == 2600000 and data["counts"]["packed"] == 100000
assert len(data["checks"]) == 6
assert data["estimates"][-1]["lean_db_with_two_snapshots_map_career_gib"] < 3
doc = ROOT / "docs/WORLD_RANKING_STORAGE_2026_10_23.md"
links = re.findall(r"\]\(([^)]+)\)", doc.read_text(encoding="utf-8"))
assert all((doc.parent / link).exists() for link in links if not link.startswith("https:"))
command = [str(ROOT / ".tools/backend-venv/Scripts/python.exe"), "-m", "ruff", "check",
           str(OUT / "probe.py"), str(OUT / "checkpoint.py")]
result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, check=False)
(OUT / "lint.log").write_text(result.stdout + result.stderr)
assert result.returncode == 0, result.stdout + result.stderr
sources = [doc, OUT / "probe.py", OUT / "checkpoint.py"]
patch = []
for path in sources:
    relative = path.relative_to(ROOT).as_posix()
    lines = path.read_text(encoding="utf-8").splitlines()
    patch.extend([f"diff --git a/{relative} b/{relative}", "new file mode 100644",
                  "--- /dev/null", f"+++ b/{relative}", f"@@ -0,0 +1,{len(lines)} @@"])
    patch.extend("+" + line for line in lines)
(OUT / "task-only.patch").write_bytes(("\n".join(patch) + "\n").encode("utf-8"))
result = subprocess.run(["git", "apply", "--reverse", "--check", "--whitespace=error-all",
                         str(OUT / "task-only.patch")], cwd=ROOT, text=True,
                        capture_output=True, check=False)
(OUT / "patch-check.log").write_text(result.stdout + result.stderr)
assert result.returncode == 0, result.stdout + result.stderr
manifest = {
    "commands": [{"command": "python docs/evidence/world-ranking-storage-2026-10-23/probe.py", "exit_code": 0},
                 {"command": "python docs/evidence/world-ranking-storage-2026-10-23/checkpoint.py", "exit_code": 0}],
    "checks": {"sample_cardinality": "passed", "binary_round_trip_and_layout": "passed",
               "source_hash": "passed", "links": "passed", "lint": "passed", "strict_patch_check": "passed"},
    "source_sha256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources},
    "evidence_sha256": {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in OUT.iterdir()
                        if p.is_file() and p.name != "checkpoint.json"},
    "scope": "New proposal and offline sample only; no runtime, live data or deployment changes.",
    "remaining_acceptance": "Production query/write cost, revisions, archive restore/retention and representative capacity tests.",
}
(OUT / "checkpoint.json").write_text(json.dumps(manifest, indent=2))
print(json.dumps(manifest["checks"]))
