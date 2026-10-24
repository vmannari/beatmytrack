"""Create and remove only this task's labelled loopback PostgreSQL container."""
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
    parser.add_argument("--include-product", action="store_true")
    args = parser.parse_args()
    configured = ROOT / ".tools/gcp-staging/config.json"
    docker = json.loads(configured.read_text())["docker"] if configured.is_file() else ["docker"]
    name, label = "bmt-config-"+secrets.token_hex(6), "game-config-"+secrets.token_hex(12)
    password = secrets.token_urlsafe(24)
    destination = ROOT / "docs/evidence/game-configuration-2026-10-24"
    destination.mkdir(parents=True, exist_ok=True)
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        port = sock.getsockname()[1]
    def call(*args):
        return subprocess.run([*docker, *args], check=False, capture_output=True, text=True, timeout=45)
    started = call("run", "-d", "--rm", "--name", name, "--label", "bmt.task="+label,
        "-p", f"127.0.0.1:{port}:5432", "-e", "POSTGRES_USER=config_test", "-e", "POSTGRES_DB=config_test",
        "-e", "POSTGRES_PASSWORD="+password, "postgres:17")
    if started.returncode:
        raise RuntimeError("Owned PostgreSQL fixture could not start; existing containers unchanged")
    try:
        for _ in range(40):
            if call("exec", name, "pg_isready", "-U", "config_test").returncode == 0:
                break
            time.sleep(0.25)
        else:
            raise RuntimeError("Owned PostgreSQL fixture did not become ready")
        environment = dict(os.environ, BMT_CONFIG_TEST_PG_URL=f"postgresql+psycopg://config_test:{password}@127.0.0.1:{port}/config_test")
        selection = ["tests/test_game_config_postgres.py"]
        suffix = "-with-product" if args.include_product else ""
        if args.include_product:
            environment["BMT_TEST_DATABASE_URL"] = environment["BMT_CONFIG_TEST_PG_URL"]
            selection.append("tests/test_product_analytics.py::test_postgres_duplicate_ingestion_and_parallel_projection_are_one_effect")
        result = subprocess.run([sys.executable, "-m", "pytest", *selection, "-q", "--tb=short",
            "--junitxml="+str(destination / ("postgres"+suffix+".xml"))], cwd=ROOT / "backend", env=environment,
            check=False, capture_output=True, text=True, timeout=240)
        output = (result.stdout+result.stderr).replace(password, "[REDACTED]")
        (destination / ("postgres"+suffix+".log")).write_text(output, encoding="utf-8")
        print(output[-6000:])
        return result.returncode
    finally:
        receipt = call("inspect", name, "--format", "{{json .Config.Labels}}")
        if receipt.returncode == 0 and json.loads(receipt.stdout).get("bmt.task") == label:
            call("rm", "-f", name)


if __name__ == "__main__":
    raise SystemExit(main())
