"""Staging job: real storage, schema and native fixture checks without player writes."""
import hashlib
import json
import os
import re
import uuid
from dataclasses import replace
from pathlib import Path

from sqlalchemy import text

from .config import Settings
from .db import make_engine
from .gcs_storage import GCSBlobStore
from .migrate import SCHEMA_HEAD
from .storage import canonical_json
from .verifier import GodotVerifier


def check_comparison_route(app):
    """Reject a client/backend mismatch even when canonical replay still passes."""
    path = "/v1/track-versions/{version_id}/results-comparison"
    operation = app.openapi().get("paths", {}).get(path, {}).get("get", {})
    parameters = {item["name"] for item in operation.get("parameters", [])}
    if not {"version_id", "vehicle_id", "bins", "race_ticks", "lap_ticks"} <= parameters:
        raise RuntimeError("Results comparison API is missing or incompatible")


def check(settings, owner, fixture_path=Path("/opt/bmt/acceptance/verified_oval.json")):
    if settings.object_backend != "gcs" or not re.fullmatch(r"[0-9a-f]{32}", owner):
        raise ValueError("This diagnostic is restricted to explicitly owned GCS staging")
    engine = make_engine(settings.database_url, settings)
    verifier = GodotVerifier(settings)
    store = GCSBlobStore(replace(settings, gcs_prefix="bmt-contract/" + owner + "/" + uuid.uuid4().hex))
    keys = []
    try:
        from .app import create_app

        app = create_app(settings, verifier=verifier)
        try:
            check_comparison_route(app)
        finally:
            app.state.engine.dispose()
        with engine.connect() as connection:
            assert connection.execute(text("SELECT version_num FROM alembic_version")).scalar() == SCHEMA_HEAD
            role = connection.execute(text("SELECT rolsuper,rolcreatedb,rolcreaterole,rolreplication,rolbypassrls FROM pg_roles WHERE rolname=current_user")).one()
            if any(role):
                raise RuntimeError("Application database role is overprivileged")
            if (connection.execute(text("SELECT 1 FROM pg_roles WHERE rolname='cloudsqlsuperuser'")).scalar()
                    and connection.execute(text("SELECT pg_has_role(current_user,'cloudsqlsuperuser','MEMBER')")).scalar()):
                raise RuntimeError("Application role inherits Cloud SQL administration")
        fixture = json.loads(fixture_path.read_text())
        result = verifier.verify_canonical_diagnostic(fixture["document"], fixture["replay"], fixture["vehicle_id"], capture_ghost=False)
        # Same existing oval golden proof checked during image build; its saved
        # format names expected_manifest and keeps per-lap expectations in the checker.
        if (result["time_ticks"] != fixture["time_ticks"] or result["lap_ticks"] != [2634, 2532, 2531, 2530, 2530]
                or result["manifest"] != fixture["expected_manifest"]):
            raise RuntimeError("Canonical staging fixture differs from pinned proof")
        values = [{"staging_contract": "track", "document": fixture["document"]},
            {"staging_contract": "replay", "replay": fixture["replay"]}]
        for value in values:
            digest = hashlib.sha256(canonical_json(value)).hexdigest()
            keys.append(digest)  # Include uncertain publication in cleanup.
            if store.put_json(value) != digest or store.put_json(value) != digest or store.get_json(digest) != value:
                raise RuntimeError("Staging storage contract failed")
        rows, cursor = store.list_objects(None, 100)
        if cursor or {row["digest"] for row in rows} != set(keys):
            raise RuntimeError("Staging object listing differs from publications")
        return {"status": "passed", "schema": SCHEMA_HEAD, "storage_objects": len(keys),
            "results_comparison_route": True,
            "canonical_ticks": result["time_ticks"], "player_writes": 0}
    finally:
        try:
            for key in keys:
                store.delete(key)
        finally:
            verifier.close()
            engine.dispose()


def main():
    result = check(Settings.from_env(), os.environ.get("BMT_STAGING_OWNER", ""))
    print(json.dumps(result))


if __name__ == "__main__":
    main()
