"""Ensure archive/restart subprocesses inherit the same reviewed source tree."""
import os
import sys
from pathlib import Path

import pytest

root = Path(__file__).resolve().parents[3]
os.environ["PYTHONPATH"] = str(root / "backend")
sys.path.insert(0, str(root / "backend"))
os.chdir(root / "backend")
raise SystemExit(pytest.main(sys.argv[1:]))
