"""Build an isolated offline wheel and verify its local filter resources."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[2]
TASK = Path(__file__).resolve().parent
SOURCE = TASK / "wheel-source"
SOURCE.mkdir(exist_ok=True)
for name in ("pyproject.toml", "README.md"):
    shutil.copyfile(ROOT / "backend" / name, SOURCE / name)
shutil.copytree(ROOT / "backend/bmt_backend", SOURCE / "bmt_backend",
                ignore=shutil.ignore_patterns("__pycache__", "*.pyc"), dirs_exist_ok=True)
WHEELS = TASK / "wheels"
WHEELS.mkdir(exist_ok=True)
result = subprocess.run([sys.executable, "-m", "pip", "wheel", ".", "--no-deps", "--no-build-isolation",
                         "--no-index", "--wheel-dir", str(WHEELS)], cwd=SOURCE, capture_output=True, text=True)
(TASK / "wheel-build.log").write_text(result.stdout + result.stderr, encoding="utf-8")
if result.returncode:
    raise SystemExit(result.returncode)
wheel = next(WHEELS.glob("bmt_backend-*.whl"))
extracted = TASK / "wheel-installed"
extracted.mkdir(exist_ok=True)
with zipfile.ZipFile(wheel) as archive:
    prefix = "bmt_backend/name_filter_data/"
    paths = sorted(name for name in archive.namelist() if name.startswith(prefix))
    for name in paths:
        assert archive.read(name) == (ROOT / "backend" / name).read_bytes(), name
    assert len(paths) == 30, paths  # 26 dictionaries + license + source manifest + policy + attribution.
    archive.extractall(extracted)
script = """
import sys
sys.path.insert(0, sys.argv[1])
from bmt_backend.name_moderation import contains_profanity, POLICY_VERSION
assert contains_profanity('V1TTU circuit')
assert contains_profanity('f.u.c.k_Racer')
assert not contains_profanity('Scunthorpe Speedway')
assert not contains_profanity('Jasmine')
print(POLICY_VERSION)
"""
probe = subprocess.run([sys.executable, "-I", "-X", "utf8", "-c", script, str(extracted)],
                       cwd=extracted, check=True, capture_output=True, text=True)
report = {"wheel": wheel.name, "sha256": hashlib.sha256(wheel.read_bytes()).hexdigest(),
          "bundled_files_exact": len(paths), "isolated_import_and_checks": "pass", "policy": probe.stdout.strip()}
(TASK / "packaging.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps(report))
