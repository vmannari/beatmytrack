"""Create/remove only this task's disposable WSL PostgreSQL fixture."""
import argparse
import json
import secrets
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("action",choices=["create","cleanup"])
args = parser.parse_args()
root = Path(__file__).resolve().parents[3]
directory = root/"build/daily-standings-postgres-lab"
state_path = directory/"state.json"
docker = ["wsl.exe","-d","Ubuntu","--exec","docker"]


def call(arguments):
    result = subprocess.run(docker+arguments,capture_output=True,text=True,check=False)
    if result.returncode:
        raise RuntimeError("Owned PostgreSQL container command failed")
    return result.stdout.strip()


if args.action == "create":
    if state_path.exists(): raise SystemExit("An owned lab state already exists; inspect or clean it first.")
    directory.mkdir(parents=True,exist_ok=True)
    password = secrets.token_hex(24)
    name = "bmt-daily-standings-"+secrets.token_hex(4)
    env_path = directory/"postgres.env"
    env_path.write_text("POSTGRES_DB=bmt_daily_standings\nPOSTGRES_USER=daily_lab\nPOSTGRES_PASSWORD="+password+"\n",encoding="utf-8")
    assert root.drive.lower() == "c:"
    linux_path = "/mnt/c/"+env_path.relative_to(Path("C:/")).as_posix()
    identifier = call(["run","--detach","--rm","--pull=never","--name",name,
        "--label","bmt.task=daily-standings-2026-10-28","--cpus=1","--memory=512m",
        "--env-file",linux_path,"--publish","127.0.0.1::5432","postgres:17"])
    port = call(["port",name,"5432/tcp"]).split(":")[-1]
    url = "postgresql+psycopg://daily_lab:"+password+"@127.0.0.1:"+port+"/bmt_daily_standings"
    state_path.write_text(json.dumps({"name":name,"id":identifier,"url":url}),encoding="utf-8")
    print("Created disposable loopback PostgreSQL lab; credentials remain in the private build folder.")
else:
    if not state_path.exists(): raise SystemExit("Owned lab is already removed.")
    state = json.loads(state_path.read_text())
    assert state["name"].startswith("bmt-daily-standings-")
    metadata = call(["inspect","--format",'{{.Id}}|{{index .Config.Labels "bmt.task"}}|{{.Image}}',state["name"]]).split("|")
    assert metadata[0] == state["id"] and metadata[1] == "daily-standings-2026-10-28"
    count = call(["exec",state["name"],"psql","-U","daily_lab","-d","bmt_daily_standings","-Atc",
        "SELECT count(*) FROM pg_namespace WHERE nspname LIKE 'bmt_load_%'"])
    call(["stop","--time","10",state["name"]])
    assert not call(["ps","-a","--filter","id="+state["id"],"--format","{{.ID}}"])
    for filename in ("postgres.env","state.json"):
        path = directory/filename
        assert path.resolve().parent == directory.resolve() and directory.resolve().is_relative_to((root/"build").resolve())
        path.unlink()
    receipt = {"container":state["name"],"image_id":metadata[2],"schema_count_after_tests":int(count),
        "stopped":True,"removed":True,"private_local_files_removed":True}
    (Path(__file__).parent/"postgres-lab.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
    print("Removed the owned container and private fixture credentials.")
