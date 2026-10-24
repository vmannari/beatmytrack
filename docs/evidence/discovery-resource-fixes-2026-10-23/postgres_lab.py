"""Owned PostgreSQL acceptance of resource guards; never reads live settings."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[3]
FOLDER = Path(__file__).parent


def docker(*args, check=True):
    return subprocess.run(["wsl", "-d", "Ubuntu", "--", "docker", *args], capture_output=True,
                          text=True, check=check, timeout=30)


def main():
    owner = uuid.uuid4().hex
    name = "bmt-resource-fixes-" + owner[:12]
    created = False
    result = 1
    try:
        docker("run", "--pull=never", "-d", "--name", name, "--label", "bmt.resource.owner="+owner,
            "--memory=2g", "--cpus=2", "--shm-size=256m", "-p", "127.0.0.1::5432",
            "-e", "POSTGRES_HOST_AUTH_METHOD=trust", "-e", "POSTGRES_USER=bmt_discovery",
            "-e", "POSTGRES_DB=bmt_discovery_lab", "postgres:17-bookworm",
            "-c", "max_connections=32", "-c", "shared_buffers=128MB")
        created = True
        for _ in range(100):
            if docker("exec", name, "pg_isready", "-U", "bmt_discovery", check=False).returncode == 0:
                break
            time.sleep(.1)
        else:
            raise RuntimeError("Owned PostgreSQL did not become ready")
        port = int(docker("port", name, "5432/tcp").stdout.strip().rsplit(":", 1)[1])
        endpoint = f"postgresql+psycopg://bmt_discovery@127.0.0.1:{port}/bmt_discovery_lab"
        env = dict(os.environ, PYTHONPATH=str(ROOT/"backend"), PYTHONUTF8="1",
                   BMT_DISCOVERY_TEST_DATABASE_URL=endpoint)
        (FOLDER/"postgres-environment.json").write_text(json.dumps({"image":"postgres:17-bookworm",
            "owner":owner,"container":name,"loopback_port":port,"cpu_limit":2,"memory_limit":"2GiB",
            "shared_buffers":"128MB","fsync":"on","scope":"Fresh labelled local container and generated schemas"},indent=2)+"\n")
        files = ["backend/tests/test_discovery_resources.py", "backend/tests/test_discovery_v3.py",
                 "backend/tests/test_discovery_projection.py", "backend/tests/test_discovery_hardening.py"]
        receiver_only = "--receiver-only" in sys.argv
        if "--resources-only" in sys.argv or receiver_only:
            files = files[:1]
        receipt = "receiver-postgres" if receiver_only else "postgres"
        command = [sys.executable, "-m", "pytest", *files, "-q", "--tb=short", "-k",
                   "postgres and receiver" if receiver_only else "postgres",
                   "--junitxml="+str(FOLDER/(receipt+".xml"))]
        with (FOLDER/(receipt+".log")).open("w", encoding="utf-8") as log:
            result = subprocess.run(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT).returncode
        print((FOLDER/(receipt+".log")).read_text(encoding="utf-8")[-9000:], flush=True)
        if result == 0 and not receiver_only:
            with (FOLDER/"profile.log").open("w", encoding="utf-8") as log:
                result = subprocess.run([sys.executable, str(FOLDER/"profile.py")], cwd=ROOT,
                    env=env, stdout=log, stderr=subprocess.STDOUT).returncode
            print((FOLDER/"profile.log").read_text(encoding="utf-8")[-6000:], flush=True)
    finally:
        if created:
            inspected = json.loads(docker("inspect", name).stdout)[0]
            if inspected["Config"]["Labels"].get("bmt.resource.owner") != owner:
                raise RuntimeError("Refusing cleanup: container ownership differs")
            docker("rm", "-f", name)
            print("Owned resource-fixes PostgreSQL removed", flush=True)
    return result


if __name__ == "__main__":
    raise SystemExit(main())
