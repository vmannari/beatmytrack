"""Run Studio regressions on a newly owned, bounded synthetic PostgreSQL server."""
import argparse
import json
import os
import secrets
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/studio-usage-costs-2026-10-27"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--focused", action="store_true")
    args = parser.parse_args()
    config = json.loads((ROOT / ".tools/gcp-staging/config.json").read_text(encoding="utf-8-sig"))
    docker = config["docker"]
    def call(*args):
        return subprocess.run([*docker,*args],capture_output=True,text=True,check=False,timeout=30)
    label, password = secrets.token_hex(16), secrets.token_hex(24)
    name = "bmt-usage-" + label[:10]
    image = call("image","inspect","postgres:17-bookworm")
    if image.returncode:
        raise RuntimeError("Cached PostgreSQL image unavailable; no pull or existing service mutation")
    started = call("run","--detach","--pull=never","--name",name,"--label","bmt.usage="+label,
        "--cpus=2","--memory=1536m","--pids-limit=128","--shm-size=256m",
        "--publish","127.0.0.1::5432","--tmpfs","/var/lib/postgresql/data:rw,size=768m",
        "--env","POSTGRES_PASSWORD="+password,"--env","POSTGRES_DB=studio_usage",
        json.loads(image.stdout)[0]["Id"],"postgres","-c","max_connections=40","-c","shared_buffers=64MB")
    if started.returncode:
        raise RuntimeError("Owned fixture could not start")
    identity = started.stdout.strip()
    exit_code = 1
    try:
        details = json.loads(call("inspect",identity).stdout)[0]
        ports = details["NetworkSettings"]["Ports"]["5432/tcp"]
        assert len(ports)==1 and ports[0]["HostIp"]=="127.0.0.1"
        port=ports[0]["HostPort"]
        for _ in range(80):
            if call("exec",identity,"pg_isready","-U","postgres","-d","studio_usage").returncode==0:
                break
            time.sleep(.25)
        else:
            raise RuntimeError("Owned fixture readiness timeout")
        env=os.environ.copy()
        env["BMT_TEST_DATABASE_URL"]=f"postgresql+psycopg://postgres:{password}@127.0.0.1:{port}/studio_usage"
        env["BMT_LIMITED_TEST_DATABASE_URL"]=env["BMT_TEST_DATABASE_URL"]
        OUT.mkdir(parents=True,exist_ok=True)
        selection = ["tests/test_studio_usage.py::test_postgres_ville_aggregation_and_database_connection_limit",
            "tests/test_studio_usage.py::test_retained_read_only_snapshot_with_explicit_admin_workload",
            "tests/test_studio_shared_reporting.py"] if args.focused else ["tests/test_studio_usage.py","tests/test_studio.py",
                "tests/test_studio_shared_reporting.py","tests/test_studio_platform.py","tests/test_public_website.py",
                "--deselect=tests/test_studio.py::test_postgres_snapshot_is_read_only_and_does_not_mix_worker_completion"]
        stem="postgres-final" if args.focused else "postgres"
        result=subprocess.run([sys.executable,"-m","pytest",*selection,
            "-q","--disable-warnings","--maxfail=3","--junitxml="+str(OUT/(stem+".xml"))],
            cwd=ROOT/"backend",env=env,capture_output=True,text=True,check=False,timeout=240)
        (OUT/(stem+".log")).write_text(result.stdout+result.stderr,encoding="utf-8")
        print(result.stdout[-6000:])
        exit_code=result.returncode
    finally:
        details=json.loads(call("inspect",identity).stdout)[0]
        if details["Config"]["Labels"].get("bmt.usage")!=label or details["Name"]!="/"+name:
            raise RuntimeError("Fixture ownership mismatch; refuse cleanup")
        cleaned=call("rm","--force",identity)
        (OUT/"postgres-environment.json").write_text(json.dumps({"synthetic_only":True,"cpus":2,"memory_mib":1536,
            "max_connections":40,"bound_to":"127.0.0.1","cached_image":True,
            "owned_fixture_removed":cleaned.returncode==0,"test_exit_code":exit_code},indent=2))
    raise SystemExit(exit_code)


if __name__=="__main__":
    main()
