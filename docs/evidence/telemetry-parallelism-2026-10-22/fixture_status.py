"""Read-only fixture ownership check; never print connection credentials."""
import json
from pathlib import Path

from sqlalchemy import create_engine, text
from sqlalchemy.engine import make_url

lines = Path("/task/db.env").read_text().splitlines()
raw = next(line.split("=", 1)[1].strip() for line in lines if line.startswith("BMT_TEST_DATABASE_URL="))
url = make_url(raw).set(host="127.0.0.1", port=5432)
engine = create_engine(url, hide_parameters=True)
try:
    with engine.connect() as db:
        clients = db.scalar(text("SELECT COUNT(*) FROM pg_stat_activity WHERE datname=current_database() "
            "AND backend_type='client backend' AND pid<>pg_backend_pid()"))
        owned = db.scalar(text("SELECT COUNT(*) FROM pg_namespace WHERE nspname LIKE 'bmt_load_%' "
            "OR nspname LIKE 'telemetry_resume_%' OR nspname LIKE 'telemetry_migration_%'"))
        result = {"other_fixture_clients": clients, "remaining_generated_task_schemas": owned}
        Path("/evidence/fixture-status.json").write_text(json.dumps(result, indent=2) + "\n")
        print(json.dumps(result))
finally:
    engine.dispose()
