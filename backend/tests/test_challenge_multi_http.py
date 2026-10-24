"""Actual native 3x3 results, retries and track changes against disposable HTTP."""
import pytest
from test_challenges_http import prepare
from test_cloud_client import run_client


@pytest.mark.godot
def test_native_three_track_race_and_retry(tmp_path):
    run_client(tmp_path, "res://tests/test_challenge_multi_http.gd", prepare=prepare)
