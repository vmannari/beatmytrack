"""Owned local PostgreSQL acceptance and cost profile; never uses live settings."""
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
    return subprocess.run(["wsl", "-d", "Ubuntu", "--", "docker", *args],
                          capture_output=True, text=True, check=check)


def main():
    owner = uuid.uuid4().hex
    name = "bmt-discovery-hardening-" + owner[:10]
    created = False
    result = 1
    try:
        docker("run", "-d", "--name", name, "--label", "bmt.discovery.owner="+owner,
            "--memory=2g", "--cpus=2", "--shm-size=256m", "-p", "127.0.0.1::5432",
            "-e", "POSTGRES_HOST_AUTH_METHOD=trust", "-e", "POSTGRES_USER=bmt_discovery",
            "-e", "POSTGRES_DB=bmt_discovery_lab", "postgres:17-bookworm",
            "-c", "max_connections=32", "-c", "shared_buffers=128MB")
        created = True
        for _ in range(150):
            if docker("exec", name, "pg_isready", "-U", "bmt_discovery", check=False).returncode == 0:
                break
            time.sleep(.2)
        else:
            raise RuntimeError("Owned PostgreSQL did not become ready")
        port = int(docker("port", name, "5432/tcp").stdout.strip().rsplit(":", 1)[1])
        endpoint = f"postgresql+psycopg://bmt_discovery@127.0.0.1:{port}/bmt_discovery_lab"
        env = dict(os.environ, PYTHONPATH=str(ROOT/"backend"), PYTHONUTF8="1",
                   BMT_DISCOVERY_TEST_DATABASE_URL=endpoint)
        (FOLDER/"postgres-environment.json").write_text(json.dumps({"image":"postgres:17-bookworm",
            "owner":owner,"container":name,"loopback_port":port,"cpu_limit":2,"memory_limit":"2GiB",
            "shared_buffers":"128MB","fsync":"on","scope":"Fresh labelled local container and generated schemas"},indent=2)+"\n")
        cost_only = '--cost-only' in sys.argv
        guarded = '--guarded-small' in sys.argv
        prefix = 'guarded' if guarded else 'expiry' if cost_only else 'postgres'
        test_files = ["backend/tests/test_discovery_projection.py", "backend/tests/test_discovery_hardening.py"]
        if guarded:test_files=["backend/tests/test_discovery_hardening.py"]
        elif not cost_only:test_files.insert(0,"backend/tests/test_discovery_v3.py")
        command = [sys.executable, "-m", "pytest", *test_files, "-q", "--tb=short",
            "--junitxml="+str(FOLDER/(prefix+".xml"))]
        if '--focused-expiry' in sys.argv:
            command += ['-k','compact_expiry']
        with (FOLDER/(prefix+".log")).open("w",encoding="utf-8") as log:
            result = subprocess.run(command,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT).returncode
        print((FOLDER/(prefix+".log")).read_text(encoding="utf-8")[-6000:],flush=True)
        if result == 0:
            log_name = 'profile-guarded.log' if guarded else 'pair-cost.log' if cost_only else 'profile.log'
            script = 'pair_cost.py' if cost_only else 'profile.py'
            arguments = ['--small','--guarded'] if guarded else sys.argv[1:]
            with (FOLDER/log_name).open("w",encoding="utf-8") as log:
                result = subprocess.run([sys.executable,str(FOLDER/script),*arguments],
                    cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT).returncode
            print((FOLDER/log_name).read_text(encoding="utf-8")[-6000:],flush=True)
    finally:
        if created:
            inspected = json.loads(docker("inspect",name).stdout)[0]
            if inspected["Config"]["Labels"].get("bmt.discovery.owner") != owner:
                raise RuntimeError("Refusing cleanup: container ownership differs")
            docker("rm","-f",name)
            print("Owned PostgreSQL container removed",flush=True)
    return result


if __name__ == "__main__":
    raise SystemExit(main())
