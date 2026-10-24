"""Read-only check before restoring the fixture's originally stopped state."""
import json
from pathlib import Path

from sqlalchemy import create_engine, text
from sqlalchemy.engine import make_url

raw = next(line.split("=", 1)[1].strip() for line in Path("/task/db.env").read_text().splitlines()
           if line.startswith("BMT_TEST_DATABASE_URL="))
engine = create_engine(make_url(raw).set(host="127.0.0.1", port=5432), hide_parameters=True)
try:
    with engine.connect() as connection:
        result = {"other_clients": connection.scalar(text("SELECT COUNT(*) FROM pg_stat_activity "
            "WHERE datname=current_database() AND backend_type='client backend' AND pid<>pg_backend_pid()")),
            "remaining_domain_test_schemas": connection.scalar(text(
                "SELECT COUNT(*) FROM pg_namespace WHERE nspname LIKE 'test_domains_%'"))}
    Path("/evidence/fixture-check.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result))
finally:
    engine.dispose()
