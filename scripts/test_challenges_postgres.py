"""Verify challenge row locks on an owned disposable PostgreSQL service."""
import json
import os
import secrets
import socket
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    config = ROOT / ".tools/gcp-staging/config.json"
    docker = json.loads(config.read_text())["docker"] if config.is_file() else ["docker"]
    name = "bmt-challenges-pg-"+secrets.token_hex(4)
    label = "challenges-"+secrets.token_hex(8)
    password = secrets.token_urlsafe(24)
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        port = listener.getsockname()[1]

    def call(*args):
        return subprocess.run([*docker, *args], capture_output=True, text=True, check=False, timeout=30)

    if call("image", "inspect", "postgres:17").returncode:
        raise RuntimeError("A local PostgreSQL image is required; no dependency was downloaded")
    started = call("run", "-d", "--rm", "--name", name, "--label", "bmt.task="+label,
        "-p", f"127.0.0.1:{port}:5432", "-e", "POSTGRES_USER=challenges", "-e", "POSTGRES_DB=challenges",
        "-e", "POSTGRES_PASSWORD="+password, "postgres:17")
    if started.returncode:
        raise RuntimeError("Owned PostgreSQL could not start; no existing service was replaced")
    try:
        for _attempt in range(30):
            if call("exec", name, "pg_isready", "-U", "challenges").returncode == 0:
                break
            time.sleep(0.5)
        else:
            raise RuntimeError("Owned database did not become ready")
        env = dict(os.environ)
        env["BMT_TEST_DATABASE_URL"] = f"postgresql+psycopg://challenges:{password}@127.0.0.1:{port}/challenges"
        tested = subprocess.run([sys.executable, "-m", "pytest", "backend/tests/test_challenges.py",
            "-q", "--tb=short", "--junitxml=docs/evidence/challenges-2026-10-08/postgres.xml"],
            cwd=ROOT, env=env, capture_output=True, text=True, check=False, timeout=180)
        (ROOT / "docs/evidence/challenges-2026-10-08/postgres.log").write_text(tested.stdout+tested.stderr, encoding="utf-8")
        print(tested.stdout[-5000:])
        return tested.returncode
    finally:
        checked = call("inspect", name, "--format", "{{json .Config.Labels}}")
        if checked.returncode == 0 and json.loads(checked.stdout).get("bmt.task") == label:
            stopped = call("stop", name)
            print("Owned PostgreSQL removed:", stopped.returncode == 0)
        else:
            raise RuntimeError("Database ownership changed; leaving it untouched")


if __name__ == "__main__":
    raise SystemExit(main())
