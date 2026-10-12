"""Studio/admin acceptance using one owned disposable PostgreSQL container."""

import argparse
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
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "docs/evidence/backend-studio-2026-10-11")
    args = parser.parse_args()
    config = ROOT / ".tools/gcp-staging/config.json"
    docker = json.loads(config.read_text())["docker"] if config.is_file() else ["docker"]
    name = "bmt-studio-pg-" + secrets.token_hex(4)
    label = "backend-studio-" + secrets.token_hex(8)
    password = secrets.token_urlsafe(24)
    with socket.socket() as reservation:
        reservation.bind(("127.0.0.1", 0))
        port = reservation.getsockname()[1]

    def call(*args):
        return subprocess.run([*docker, *args], capture_output=True, text=True, check=False, timeout=30)

    started = call("run", "-d", "--rm", "--name", name, "--label", "bmt.task=" + label,
        "-p", f"127.0.0.1:{port}:5432", "-e", "POSTGRES_USER=studio_test", "-e",
        "POSTGRES_DB=studio_test", "-e", "POSTGRES_PASSWORD=" + password, "postgres:17")
    if started.returncode:
        raise RuntimeError("Owned PostgreSQL could not start; no existing service was replaced")
    try:
        for _attempt in range(30):
            if call("exec", name, "pg_isready", "-U", "studio_test").returncode == 0:
                break
            time.sleep(0.5)
        else:
            raise RuntimeError("Owned database did not become ready")
        env = dict(os.environ)
        env["BMT_TEST_DATABASE_URL"] = f"postgresql+psycopg://studio_test:{password}@127.0.0.1:{port}/studio_test"
        command = [sys.executable, "-m", "pytest", "tests/test_studio.py", "tests/test_admin.py",
            "tests/test_admin_support.py", "tests/test_store_admin.py", "-q", "--tb=short"]
        tested = subprocess.run(command, cwd=ROOT / "backend", env=env,
            capture_output=True, text=True, check=False)
        output = tested.stdout + tested.stderr
        output = output.replace(password, "[REDACTED]")
        evidence = args.output
        evidence.mkdir(parents=True, exist_ok=True)
        (evidence / "postgres.log").write_text(output, encoding="utf-8")
        print(output[-5000:])
    finally:
        checked = call("inspect", name, "--format", "{{json .Config.Labels}}")
        if checked.returncode == 0 and json.loads(checked.stdout).get("bmt.task") == label:
            removed = call("stop", name)
            print("Owned PostgreSQL removed:", removed.returncode == 0)
        else:
            raise RuntimeError("Database ownership changed; leaving it untouched")
    return tested.returncode


if __name__ == "__main__":
    raise SystemExit(main())
