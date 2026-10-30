"""Initialize the full model registry, then run isolated existing cost checks."""
import os
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/"backend"))
import pytest
from bmt_backend.app import create_app
from bmt_backend.config import Settings


if __name__=="__main__":
    app=create_app(Settings(environment="test",database_url="sqlite://",
        object_dir=str(ROOT/"build/backend-local-cost-simulation-2026-10-26/model-registry")))
    app.state.engine.dispose()
    raise SystemExit(pytest.main([
        "backend/tests/test_packed_storage.py","backend/tests/test_cost_archives.py",
        "backend/tests/test_cost_maintenance.py","backend/tests/test_cost_transport.py",
        "-q","-k","not postgres","-m","not godot",
        "--junitxml=docs/evidence/backend-local-cost-simulation-2026-10-26/regressions.xml",
        "-o","cache_dir=build/backend-local-cost-simulation-2026-10-26/cache",
        "--basetemp=build/backend-local-cost-simulation-2026-10-26/test-final-temp"]))
