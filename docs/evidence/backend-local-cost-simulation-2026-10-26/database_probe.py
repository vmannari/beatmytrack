"""Connect only to this lab's generated loopback PostgreSQL fixture."""
import json
from pathlib import Path

from sqlalchemy import create_engine,text

ROOT=Path(__file__).resolve().parents[3]


def fixture_url():
    state=json.loads((ROOT/"build/backend-local-cost-simulation-2026-10-26/private-fixture.json").read_text())
    if not state["name"].startswith("bmt-local-cost-") or not 1024<=state["port"]<=65535:
        raise ValueError("Invalid owned local fixture")
    return f"postgresql+psycopg://postgres:{state['password']}@127.0.0.1:{state['port']}/bmt_cost_lab"


if __name__=="__main__":
    engine=create_engine(fixture_url(),hide_parameters=True,connect_args={"connect_timeout":3})
    with engine.connect() as db:
        version=db.scalar(text("SELECT version()"))
        assert version.startswith("PostgreSQL 17.")
        print(json.dumps({"database":"synthetic fixture","version":version,"loopback_connection":"passed"}))
    engine.dispose()
