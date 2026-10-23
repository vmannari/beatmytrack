"""Own disposable database: concurrent schema migrations must not share a DB."""
import os
import sys
import uuid

import pytest
from sqlalchemy import create_engine, text
from sqlalchemy.engine import make_url

url = make_url(os.environ["BMT_TEST_DATABASE_URL"])
assert url.host == "127.0.0.1" and url.port == 5432
name = "histogram_followup_20261022_" + uuid.uuid4().hex[:12]
admin = create_engine(url, isolation_level="AUTOCOMMIT", hide_parameters=True)
created = False
try:
    with admin.connect() as db:
        db.execute(text('CREATE DATABASE "' + name + '"'))
        created = True
    os.environ["BMT_TEST_DATABASE_URL"] = url.set(database=name).render_as_string(hide_password=False)
    result = pytest.main(sys.argv[1:])
finally:
    if created:
        assert name.startswith("histogram_followup_20261022_") and len(name) == 40
        with admin.connect() as db:
            db.execute(text('DROP DATABASE "' + name + '" WITH (FORCE)'))
    admin.dispose()
raise SystemExit(result)
