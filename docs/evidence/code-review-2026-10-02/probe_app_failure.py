"""Capture a stalled app test directly after validating the exact engine pin."""

import os
import subprocess
import sys
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "backend"))
from bmt_backend.verifier import GodotVerifier

binary = "C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe"
verifier = GodotVerifier(SimpleNamespace(godot_bin=binary, game_project=ROOT / "game", verifier_timeout_seconds=90))
verifier._check_engine()
env = {**os.environ, "BMT_API_URL": ""}
with (Path(__file__).parent / "app-direct.log").open("wb") as output:
    process = subprocess.Popen([binary, "--headless", "--path", str(ROOT / "game"), "--script", "res://tests/test_app.gd"],
                               env=env, stdout=output, stderr=subprocess.STDOUT)
    try:
        code = process.wait(timeout=20)
        print("app_direct_exit=" + str(code))
    except subprocess.TimeoutExpired:
        subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"], capture_output=True)
        process.wait(timeout=10)
        print("app_direct_timeout_seconds=20; created process tree stopped")
