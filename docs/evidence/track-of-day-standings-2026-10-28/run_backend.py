"""Run owned tests with connection credentials redacted from all emitted output."""
import argparse
import json
import os
import re
import subprocess
import sys
import uuid
from pathlib import Path

from sqlalchemy.engine import make_url

parser = argparse.ArgumentParser()
parser.add_argument("--postgres", action="store_true")
parser.add_argument("tests", nargs=argparse.REMAINDER)
args = parser.parse_args()
root = Path(__file__).resolve().parents[3]
env = os.environ.copy()
secret = ""
if args.postgres:
    state = json.loads((root/"build/daily-standings-postgres-lab/state.json").read_text())
    url = make_url(state["url"])
    assert url.host == "127.0.0.1" and url.database == "bmt_daily_standings"
    assert state["name"].startswith("bmt-daily-standings-")
    env["BMT_DAILY_STANDINGS_POSTGRES"] = "1"
    env["BMT_DAILY_STANDINGS_DATABASE_URL"] = state["url"]
    secret = url.password
tests = args.tests[1:] if args.tests[:1] == ["--"] else args.tests
command = [sys.executable,"-m","pytest",*tests,"-q","--disable-warnings","--tb=short",
           "--basetemp="+str(root/"build"/("daily-standings-pytest-"+uuid.uuid4().hex[:10]))]
result = subprocess.run(command,cwd=root/"backend",env=env,text=True,capture_output=True)
output = result.stdout+result.stderr
if secret: output = output.replace(secret,"[redacted]")
output = re.sub(r"(password=)[^\s,'\"]+",r"\1[redacted]",output)
logs = Path(__file__).resolve().parent/"logs"
logs.mkdir(exist_ok=True)
log = logs/("backend-"+("postgres-" if args.postgres else "sqlite-")+uuid.uuid4().hex[:8]+".log")
log.write_text(output,encoding="utf-8")
print(output)
print("Sanitized log:",log.name)
raise SystemExit(result.returncode)
