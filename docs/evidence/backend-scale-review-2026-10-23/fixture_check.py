"""Read-only check before restoring the test container's original stopped state."""
import json
from pathlib import Path

from sqlalchemy import create_engine, text
from sqlalchemy.engine import make_url

lines = Path("/task/db.env").read_text().splitlines()
raw = next(line.split("=", 1)[1].strip() for line in lines if line.startswith("BMT_TEST_DATABASE_URL="))
engine = create_engine(make_url(raw).set(host="127.0.0.1", port=5432), hide_parameters=True)
try:
    with engine.connect() as db:
        result = {"other_clients": db.scalar(text("SELECT COUNT(*) FROM pg_stat_activity "
            "WHERE datname=current_database() AND backend_type='client backend' AND pid<>pg_backend_pid()")),
            "remaining_review_schemas": db.scalar(text("SELECT COUNT(*) FROM pg_namespace WHERE nspname LIKE 'bmt_scale_review_%'"))}
    Path("/evidence/fixture-check.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result))
    assert result == {"other_clients": 0, "remaining_review_schemas": 0}
finally:
    engine.dispose()
