"""Measure bounded diagnostic writes/reads in a newly owned local SQLite database.

Synthetic observations exercise SQL budgets, not renderer or phone performance.
No real user, production service or provider is accessed.
"""
import json
import secrets
import statistics
import sys
import time
from pathlib import Path
from uuid import uuid4

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "backend"))
sys.path.insert(0, str(ROOT / "backend/tests"))


def main():
    from conftest import TestIdentity
    from fastapi.testclient import TestClient
    from sqlalchemy import event, func, select
    from test_race_statistics import package

    from bmt_backend.app import create_app
    from bmt_backend.config import Settings
    from bmt_backend.migrate import upgrade
    from bmt_backend.product_analytics import project_pending
    from bmt_backend.race_statistics_models import RaceStatisticsDay, RaceStatisticsReceipt
    from bmt_backend.track_models import Track, TrackVersion, now

    folder = ROOT / "build" / ("studio-statistics-profile-" + uuid4().hex[:8])
    folder.mkdir(parents=True)
    analyst = secrets.token_urlsafe(32)
    settings = Settings(database_url="sqlite:///" + (folder / "database.sqlite").as_posix(),
        object_dir=str(folder / "objects"), admin_analyst_key=analyst,
        telemetry_enabled=True, client_quality_enabled=True, google_client_ids=("fixture",),
        rate_limit_per_minute=10000, write_limit_per_minute=10000)
    app = create_app(settings, identity_verifier=TestIdentity())
    upgrade(app.state.engine)
    with TestClient(app) as client:
        challenge = client.post("/v1/auth/google/challenge").json()
        token = secrets.token_urlsafe(32)
        app.state.identity_verifier.claims[token] = {"sub": "owned-profile-fixture", "nonce": challenge["nonce"]}
        signed = client.post("/v1/auth/google", json={"id_token": token,
            "challenge_id": challenge["challenge_id"], "display_name": "Diagnostic fixture"}).json()
        headers = {"Authorization": "Bearer " + signed["access_token"]}
        with app.state.session_factory() as session:
            track = Track(owner_id=signed["player"]["id"])
            session.add(track); session.flush()
            version = TrackVersion(track_id=track.id, number=1, name="Owned diagnostic fixture",
                state="published", content_hash="a" * 64, manifest={},
                discovery={"theme": "pine", "points": [[0, 0], [200, 0], [200, 200], [0, 0]]})
            session.add(version); session.commit(); version_id = version.id
        at = now()
        observations = []
        for index in range(100):
            props = package(version_id, cells=[[i, 0, 1, i % 2] for i in range(128)],
                segments=[[0, 128, 64]], position_samples=128)
            observations.append({"id": props["race_id"], "name": "race_statistics", "occurred_at": at,
                "session_id": str(uuid4()), "seq": index, "monotonic_ms": index, "properties": props})
        durations, packet_bytes = [], []
        for offset in range(0, 100, 10):
            body = {"schema": "bmt-product-events-v1", "purpose_policy": "bmt-product-telemetry-v1",
                "build_id": "owned-fixture", "platform": "android", "events": observations[offset:offset + 10]}
            packet_bytes.append(len(json.dumps(body, separators=(",", ":")).encode()))
            before = time.perf_counter()
            response = client.post("/v1/telemetry/batches", headers=headers, json=body)
            durations.append((time.perf_counter() - before) * 1000)
            assert response.status_code == 200 and all(item["status"] == "accepted" for item in response.json()["events"])

        statements = []
        def capture(_connection, _cursor, statement, _parameters, _context, _many):
            statements.append(statement)
        event.listen(app.state.engine, "before_cursor_execute", capture)
        try:
            before = time.perf_counter()
            project_pending(app.state.session_factory, limit=100)
            project_ms = (time.perf_counter() - before) * 1000
            projection_statements = list(statements); statements.clear()
            before = time.perf_counter()
            response = client.get("/v1/admin/race-statistics", params={"track_version_id": version_id},
                headers={"Authorization": "Bearer " + analyst})
            report_ms = (time.perf_counter() - before) * 1000
            report_statements = list(statements)
        finally:
            event.remove(app.state.engine, "before_cursor_execute", capture)
        result = response.json()
        assert response.status_code == 200 and result["totals"]["races"] == 100
        assert len(result["cells"]) == 128 and result["cells"][0]["samples"] == 100
        assert not any(" runs " in sql or "personal_bests" in sql or "product_events" in sql for sql in report_statements)
        with app.state.session_factory() as session:
            assert session.scalar(select(func.count()).select_from(RaceStatisticsReceipt)) == 100
            assert session.scalar(select(func.count()).select_from(RaceStatisticsDay)) == 1
        evidence = {
            "owned_local_fixture": True, "production_writes": 0, "database": "SQLite",
            "packages": 100, "cells_per_package": 128, "prepared_rows_written": 1,
            "maximum_batch_bytes": max(packet_bytes), "events_per_ingress_batch": 10,
            "ingress_median_ms": round(statistics.median(durations), 3),
            "project_100_events_ms": round(project_ms, 3),
            "diagnostic_projection_selects": sum(sql.lstrip().upper().startswith("SELECT") and "race_statistics_days.frame_buckets" in sql for sql in projection_statements),
            "diagnostic_cleanup_selects": sum(sql.lstrip().upper().startswith("SELECT") and "race_statistics_days" in sql and "race_statistics_days.frame_buckets" not in sql for sql in projection_statements),
            "diagnostic_projection_inserts": sum(sql.lstrip().upper().startswith("INSERT") and "race_statistics_days" in sql for sql in projection_statements),
            "prepared_report_ms": round(report_ms, 3), "prepared_report_bytes": len(response.content),
            "prepared_report_selects": sum(sql.lstrip().upper().startswith("SELECT") for sql in report_statements),
            "limitation": "Desktop wall time including local API/auth/middleware; not phone, PostgreSQL throughput or load acceptance.",
        }
        assert evidence["diagnostic_projection_selects"] == evidence["diagnostic_projection_inserts"] == 1
    app.state.engine.dispose()
    output = ROOT / "docs/evidence/studio-monitor-revision-2026-10-12"
    output.mkdir(parents=True, exist_ok=True)
    (output / "diagnostic-compute.json").write_text(json.dumps(evidence, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(evidence, indent=2))


if __name__ == "__main__":
    main()
