"""Owned disposable PostgreSQL 17 acceptance. No live service/env file is read."""
import json
import os
import hashlib
import shutil
from pathlib import Path
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[3]
FOLDER = Path(__file__).parent


def docker(*args, check=True):
    return subprocess.run(["wsl", "-d", "Ubuntu", "--", "docker", *args],
        capture_output=True, text=True, check=check)


def main():
    owner = uuid.uuid4().hex
    name = "bmt-discovery-v3-" + owner[:12]
    created = False
    result = 1
    try:
        docker("run", "-d", "--name", name, "--label", "bmt.discovery.owner=" + owner,
            "--memory=2g", "--cpus=2", "--shm-size=256m", "-p", "127.0.0.1::5432",
            "-e", "POSTGRES_HOST_AUTH_METHOD=trust", "-e", "POSTGRES_USER=bmt_discovery",
            "-e", "POSTGRES_DB=bmt_discovery_lab", "postgres:17-bookworm",
            "-c", "max_connections=32", "-c", "shared_buffers=128MB")
        created = True
        deadline = time.monotonic() + 40
        while time.monotonic() < deadline:
            ready = docker("exec", name, "pg_isready", "-U", "bmt_discovery", check=False)
            if ready.returncode == 0:
                break
            time.sleep(.2)
        else:
            raise RuntimeError("Owned PostgreSQL did not become ready")
        port = docker("port", name, "5432/tcp").stdout.strip().rsplit(":", 1)[1]
        endpoint = "postgresql+psycopg://bmt_discovery@127.0.0.1:" + port + "/bmt_discovery_lab"
        env = dict(os.environ, PYTHONPATH=str(ROOT / "backend"), PYTHONUTF8="1",
            BMT_DISCOVERY_TEST_DATABASE_URL=endpoint, BMT_TEST_DATABASE_URL=endpoint)
        history = FOLDER / 'history'
        history.mkdir(exist_ok=True)
        for filename in ('postgres.log', 'postgres.xml', 'postgres-environment.json', 'scale.log', 'scale-results.json'):
            previous = FOLDER / filename
            if previous.exists():
                suffix = hashlib.sha256(previous.read_bytes()).hexdigest()[:10]
                shutil.copyfile(previous, history / (previous.stem + '-' + suffix + previous.suffix))
        command = [sys.executable, "-m", "pytest", "backend/tests/test_discovery_v3.py",
            "backend/tests/test_discovery_projection.py", "-q", "--tb=short",
            "--junitxml=" + str(FOLDER / "postgres.xml")]
        with (FOLDER / "postgres.log").open("w", encoding="utf-8") as log:
            process = subprocess.run(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
        result = process.returncode
        print((FOLDER / "postgres.log").read_text(encoding="utf-8")[-12000:])
        if result == 0 and "--scale" in sys.argv:
            with (FOLDER / "scale.log").open("w", encoding="utf-8") as log:
                scaled = subprocess.run([sys.executable, str(FOLDER / "scale_probe.py"),
                        *(["--small"] if "--small" in sys.argv else [])],
                    cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
            print((FOLDER / "scale.log").read_text(encoding="utf-8")[-8000:])
            result = scaled.returncode
        (FOLDER / "postgres-environment.json").write_text(json.dumps({"image":"postgres:17-bookworm",
            "owner":owner, "loopback_port":int(port), "memory_limit":"2GiB", "cpu_limit":2,
            "shared_buffers":"128MB", "fsync":"on", "test_exit_code":result,
            "scope":"Fresh labelled container and isolated generated schemas; no live database."}, indent=2)+"\n")
    finally:
        if created:
            inspected = json.loads(docker("inspect", name).stdout)[0]
            if inspected["Config"]["Labels"].get("bmt.discovery.owner") != owner:
                raise RuntimeError("Refusing cleanup: container ownership differs")
            docker("rm", "-f", name)
            print("Owned PostgreSQL container removed")
    return result


if __name__ == "__main__":
    raise SystemExit(main())
