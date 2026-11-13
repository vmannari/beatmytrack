"""Create/remove only this lab's labelled, synthetic, bounded local PostgreSQL."""
import argparse
import hashlib
import json
import secrets
import subprocess
import time
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
BUILD = ROOT / "build/backend-local-cost-simulation-2026-10-26"
STATE = BUILD / "private-fixture.json"
OUT = Path(__file__).resolve().parent
LABEL = "bmt.local-cost-simulation"


def docker(*args, check=True, timeout=25):
    result = subprocess.run(["docker", *args], capture_output=True, text=True, timeout=timeout)
    if check and result.returncode:
        raise RuntimeError("Local Docker operation failed: " + " ".join(args[:2]))
    return result


def inspected(identity):
    return json.loads(docker("inspect", identity).stdout)[0]


def owned(state):
    result = inspected(state["container"])
    if result["Config"]["Labels"].get(LABEL) != state["token"] or result["Name"] != "/"+state["name"]:
        raise RuntimeError("Fixture ownership differs; refuse all changes")
    return result


def start():
    BUILD.mkdir(parents=True, exist_ok=True)
    if STATE.exists():
        raise RuntimeError("Existing fixture state requires explicit owned cleanup before a new run")
    image = inspected("postgres:17-bookworm")
    token = uuid.uuid4().hex
    name = "bmt-local-cost-"+token[:12]
    password = secrets.token_hex(24)  # Invented fixture credential; never included in public evidence.
    before = docker("ps", "-q").stdout.splitlines()
    previous = {identity: {"id": inspected(identity)["Id"], "started_at": inspected(identity)["State"]["StartedAt"]} for identity in before}
    container = docker("run", "--detach", "--pull=never", "--name", name, "--label", LABEL+"="+token,
        "--cpus=2", "--memory=1536m", "--pids-limit=128", "--shm-size=256m",
        "--publish", "127.0.0.1::5432", "--tmpfs", "/var/lib/postgresql/data:rw,size=768m",
        "--env", "POSTGRES_PASSWORD="+password, "--env", "POSTGRES_DB=bmt_cost_lab",
        image["Id"], "postgres", "-c", "max_connections=40", "-c", "shared_buffers=64MB",
        "-c", "work_mem=4MB", "-c", "max_wal_size=256MB", "-c", "min_wal_size=32MB").stdout.strip()
    state = {"container":container,"name":name,"token":token,"password":password,"previous":previous}
    STATE.write_text(json.dumps(state),encoding="utf-8")
    for _ in range(60):
        ready = docker("exec",container,"pg_isready","-U","postgres","-d","bmt_cost_lab",check=False)
        if ready.returncode == 0:
            break
        time.sleep(.25)
    else:
        raise RuntimeError("Owned PostgreSQL did not become ready")
    details=owned(state)
    ports=details["NetworkSettings"]["Ports"]["5432/tcp"]
    assert len(ports)==1 and ports[0]["HostIp"]=="127.0.0.1"
    state["port"]=int(ports[0]["HostPort"])
    STATE.write_text(json.dumps(state),encoding="utf-8")
    record={"postgres_image_id":image["Id"],"container_name":name,"cpus":2,"memory_mib":1536,
        "data_tmpfs_mib":768,"max_connections":40,"bind_address":"127.0.0.1",
        "port":state["port"],"previous_running_container_count":len(previous),"data":"Synthetic fixture only; no cloud or player data copied"}
    (OUT/"postgres-environment.json").write_text(json.dumps(record,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(record))


def stop():
    state=json.loads(STATE.read_text(encoding="utf-8"))
    owned(state)
    preserved={}
    differences=[]
    for identity,row in state["previous"].items():
        response=docker("inspect",identity,check=False)
        current=json.loads(response.stdout)[0] if response.returncode==0 else None
        preserved[identity]=bool(current and current["Id"]==row["id"] and current["State"]["StartedAt"]==row["started_at"])
        if not preserved[identity]:
            differences.append({"name":current["Name"] if current else "original container no longer inspectable",
                "previous_started_at":row["started_at"],"current_started_at":current["State"]["StartedAt"] if current else None,
                "current_restart_count":current.get("RestartCount") if current else None,
                "current_oom_killed":current["State"].get("OOMKilled") if current else None})
    # A concurrent change elsewhere must be recorded, never repaired or used to
    # strand this task's resource. The ownership check above still fences removal.
    (OUT/"existing-container-observations.json").write_text(json.dumps({"checked":len(preserved),
        "unchanged":sum(preserved.values()),"differences":differences,
        "cause":"Not established; no lab mutation command targeted these containers"},indent=2)+"\n",encoding="utf-8")
    docker("rm","--force",state["container"])
    result={"owned_fixture_removed":True,"previous_container_count":len(preserved),
        "previous_containers_unchanged":all(preserved.values()),"existing_container_changes":len(differences),
        "synthetic_database_discarded":True,"cleanup_scope":"Only the container with this task's exact ID/name/ownership label"}
    (OUT/"cleanup.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    STATE.unlink()
    print(json.dumps(result))


def restore():
    state=json.loads(STATE.read_text(encoding="utf-8"))
    owned(state)
    existing=docker("exec",state["container"],"psql","-U","postgres","-d","postgres","-Atc",
        "SELECT datname FROM pg_database WHERE datname='bmt_cost_restored'").stdout.strip()
    if existing:
        raise RuntimeError("Restore target already exists; refuse overwrite")
    backup=subprocess.run(["docker","exec",state["container"],"pg_dump","-U","postgres","-d","bmt_cost_lab","-Fc"],
        capture_output=True,timeout=60)
    if backup.returncode:
        raise RuntimeError("Synthetic fixture backup failed")
    (BUILD/"synthetic-database.dump").write_bytes(backup.stdout)
    docker("exec",state["container"],"createdb","-U","postgres","bmt_cost_restored")
    restored=subprocess.run(["docker","exec","-i",state["container"],"pg_restore","-U","postgres",
        "-d","bmt_cost_restored","--exit-on-error","--single-transaction","--no-owner","--no-privileges"],
        input=backup.stdout,capture_output=True,timeout=60)
    if restored.returncode:
        raise RuntimeError("Synthetic restore failed; preserve fixture for diagnosis")
    result={"synthetic_pg_dump_bytes":len(backup.stdout),"sha256":hashlib.sha256(backup.stdout).hexdigest(),
        "restore_database":"bmt_cost_restored","new_empty_database":True,"restore_command_succeeded":True}
    (OUT/"database-restore.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(result))


if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action",choices=("start","restore","stop"))
    {"start":start,"restore":restore,"stop":stop}[parser.parse_args().action]()
