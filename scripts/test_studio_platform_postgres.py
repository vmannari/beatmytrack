"""Owned disposable PostgreSQL acceptance; never uses an existing project database."""

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
    docker = (
        json.loads(config.read_text())["docker"] if config.is_file() else ["docker"]
    )
    name = "bmt-platform-" + secrets.token_hex(4)
    label = "studio-platform-" + secrets.token_hex(8)
    password = secrets.token_urlsafe(24)
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        port = sock.getsockname()[1]

    def call(*args):
        return subprocess.run(
            [*docker, *args], capture_output=True, text=True, check=False, timeout=30
        )

    start = call(
        "run",
        "-d",
        "--rm",
        "--name",
        name,
        "--label",
        "bmt.task=" + label,
        "-p",
        f"127.0.0.1:{port}:5432",
        "-e",
        "POSTGRES_USER=studio_test",
        "-e",
        "POSTGRES_DB=studio_test",
        "-e",
        "POSTGRES_PASSWORD=" + password,
        "postgres:17",
    )
    if start.returncode:
        raise RuntimeError(
            "Owned PostgreSQL could not start; no existing service changed"
        )
    try:
        for _ in range(30):
            if call("exec", name, "pg_isready", "-U", "studio_test").returncode == 0:
                break
            time.sleep(0.5)
        else:
            raise RuntimeError("Owned PostgreSQL readiness timed out")
        env = dict(os.environ)
        env["BMT_TEST_DATABASE_URL"] = (
            f"postgresql+psycopg://studio_test:{password}@127.0.0.1:{port}/studio_test"
        )
        destination = ROOT / "docs/evidence/studio-platform-2026-10-16"
        destination.mkdir(parents=True, exist_ok=True)
        result = subprocess.run(
            [
                sys.executable,
                "-m",
                "pytest",
                "tests/test_studio_platform_postgres.py",
                "tests/test_earned_coins.py",
                "tests/test_race_statistics_postgres.py",
                "tests/test_network_health_postgres.py",
                "-q",
                "--tb=short",
                "--junitxml=" + str(destination / "postgres.xml"),
            ],
            cwd=ROOT / "backend",
            env=env,
            capture_output=True,
            text=True,
            check=False,
            timeout=600,
        )
        output = (result.stdout + result.stderr).replace(password, "[REDACTED]")
        (destination / "postgres.log").write_text(output, encoding="utf-8")
        print(output[-7000:])
        return result.returncode
    finally:
        checked = call("inspect", name, "--format", "{{json .Config.Labels}}")
        if (
            checked.returncode == 0
            and json.loads(checked.stdout).get("bmt.task") == label
        ):
            print("Owned PostgreSQL removed:", call("stop", name).returncode == 0)
        else:
            raise RuntimeError("Database ownership changed; leaving it untouched")


if __name__ == "__main__":
    raise SystemExit(main())
