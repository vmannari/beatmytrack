"""Network-health receipt, projection and PostgreSQL query acceptance in an owned database."""
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
    name = "bmt-network-health-pg-" + secrets.token_hex(4)
    label = "network-health-" + secrets.token_hex(8)
    password = secrets.token_urlsafe(24)
    with socket.socket() as reservation:
        reservation.bind(("127.0.0.1", 0))
        port = reservation.getsockname()[1]

    def call(*arguments):
        return subprocess.run([*docker, *arguments], capture_output=True, text=True, timeout=30, check=False)

    if call("image", "inspect", "postgres:17").returncode:
        raise RuntimeError("Existing PostgreSQL 17 image unavailable; no image pulled")
    started = call("run", "-d", "--rm", "--name", name, "--label", "bmt.task=" + label,
        "-p", f"127.0.0.1:{port}:5432", "-e", "POSTGRES_USER=network_test",
        "-e", "POSTGRES_DB=network_test", "-e", "POSTGRES_PASSWORD=" + password, "postgres:17")
    if started.returncode:
        raise RuntimeError("Owned PostgreSQL could not start; no existing service changed")
    try:
        for _ in range(30):
            if call("exec", name, "pg_isready", "-U", "network_test").returncode == 0:
                break
            time.sleep(.5)
        else:
            raise RuntimeError("Owned PostgreSQL did not become ready")
        env = dict(os.environ)
        env["BMT_TEST_DATABASE_URL"] = f"postgresql+psycopg://network_test:{password}@127.0.0.1:{port}/network_test"
        result = subprocess.run([sys.executable, "-m", "pytest", "tests/test_network_health.py",
            "tests/test_network_health_postgres.py", "tests/test_product_analytics.py", "tests/test_client_quality.py",
            "-q", "--tb=short", "--show-capture=no"], cwd=ROOT / "backend", env=env,
            capture_output=True, text=True, timeout=300, check=False)
        output = (result.stdout + result.stderr).replace(password, "[REDACTED]")
        evidence = ROOT / "docs/evidence/network-health-2026-10-13"
        evidence.mkdir(parents=True, exist_ok=True)
        (evidence / "postgres-tests.log").write_text(output, encoding="utf-8")
        print(output[-6000:])
        return result.returncode
    finally:
        owned = call("inspect", name, "--format", "{{json .Config.Labels}}")
        if owned.returncode or json.loads(owned.stdout).get("bmt.task") != label:
            raise RuntimeError("Owned database label changed; leaving it untouched")
        if call("stop", name).returncode:
            raise RuntimeError("Owned database cleanup failed")
        print("Owned PostgreSQL removed")


if __name__ == "__main__":
    raise SystemExit(main())
