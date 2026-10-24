"""Explicit-only reproduction of existing native publication assertions."""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path[:0] = [str(ROOT / "backend"), str(ROOT / "backend/tests")]
from test_cloud_client import run_client


def test_task_start_cloud_publication(tmp_path):
    run_client(tmp_path, str(Path(__file__).with_name("baseline_cloud.gd")),
               extra_env={"BMT_SCALE_TASK_BEFORE": str(Path(__file__).with_name("before") / "game/backend")})
