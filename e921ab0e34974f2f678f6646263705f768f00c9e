"""Run the new regression against exact task-start sources in a disposable copy."""
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parents[3]
stage = ROOT / "build/compatibility-audit/task-start-v1"
stage.relative_to(ROOT / "build/compatibility-audit")
if stage.exists() and "--reuse" not in sys.argv:
    raise SystemExit("Use a fresh absent stage; existing files are never overwritten")
if not stage.exists():
    shutil.copytree(ROOT / "backend/bmt_backend",stage / "bmt_backend",
                    ignore=shutil.ignore_patterns("__pycache__","*.pyc"))
    for source in (Path(__file__).parent / "before").glob("backend__bmt_backend__*.py"):
        shutil.copyfile(source,stage / "bmt_backend" / source.name.split("__")[-1])
for source in (Path(__file__).parent / "before").glob("backend__bmt_backend__*.py"):
    assert source.read_bytes() == (stage / "bmt_backend" / source.name.split("__")[-1]).read_bytes()
sys.path[:0] = [str(stage), str(ROOT / "backend/tests")]
import bmt_backend  # noqa: E402
import pytest  # noqa: E402

assert Path(bmt_backend.__file__).is_relative_to(stage)
raise SystemExit(pytest.main([str(ROOT / "backend/tests/test_car_compatibility.py"),
    "-k","not postgres","-q","--basetemp",str(ROOT / "build/compatibility-audit/pytest-task-start"),
    "--junitxml",str(Path(__file__).parent / "task-start-junit.xml")]))
