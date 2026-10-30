"""Read-only aggregate table counts; no private rows or record hashes are read/exported."""
import json

from sqlalchemy import inspect, text

from bmt_backend.config import Settings
from bmt_backend.db import make_engine

baseline = __BASELINE__
settings = Settings.from_env()
engine = make_engine(settings.database_url, settings)
with engine.connect() as db:
    db.execute(text("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY"))
    names = sorted(baseline["tables"]) if baseline else sorted(set(inspect(db).get_table_names())-{"alembic_version"})
    tables = {name:db.scalar(text('SELECT count(*) FROM "'+name+'"')) for name in names}
    result = {"schema":db.scalar(text("SELECT version_num FROM alembic_version")),"tables":tables,
        "pending":{name:db.scalar(text("SELECT count(*) FROM "+name+" WHERE status IN ('queued','verifying','validating')"))
                   for name in ("runs","publication_intents","track_validations")},
        "invalid_indexes":db.scalar(text("SELECT count(*) FROM pg_index WHERE NOT indisvalid")),
        "private_rows_exported":False,"private_record_hashes_exported":False}
    if baseline:
        assert tables == baseline["tables"], [name for name in tables if tables[name] != baseline["tables"][name]]
print("RELEASE_RESULT="+json.dumps(result))
engine.dispose()
