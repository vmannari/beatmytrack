"""Production receipt locks, prepared JSON updates and selected-failure index."""
# ruff: noqa: F811
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace

from sqlalchemy import func, select, text
from test_auth_postgres import google_request, postgres_auth  # noqa: F401
from test_network_health import failure, summary
from test_product_analytics import body, observed

from bmt_backend.network_models import NetworkHealthDay
from bmt_backend.product_analytics import project_pending
from bmt_backend.track_models import now


def test_postgres_network_duplicate_receipts_and_projection_are_exactly_once(postgres_auth):
    app, client = postgres_auth
    app.state.settings = replace(app.state.settings, telemetry_enabled=True, client_quality_enabled=True,
        admin_analyst_key="a" * 40)
    signed = client.post("/v1/auth/google", json=google_request(app, client, "network-postgres")).json()
    headers = {"Authorization": "Bearer " + signed["access_token"]}
    event = observed("network_summary", at=now(), properties=summary())
    with ThreadPoolExecutor(max_workers=4) as pool:
        results = list(pool.map(lambda _: client.post("/v1/telemetry/batches", headers=headers, json=body([event])), range(4)))
    assert sorted(response.json()["events"][0]["status"] for response in results) == ["accepted", "duplicate", "duplicate", "duplicate"]
    with ThreadPoolExecutor(max_workers=4) as pool:
        list(pool.map(lambda _: project_pending(app.state.session_factory), range(4)))
    with app.state.session_factory() as session:
        assert session.scalar(select(func.count()).select_from(NetworkHealthDay)) == 1
        row = session.scalar(select(NetworkHealthDay))
        assert row.counters["attempts"] == 3 and row.buckets["upload_age_buckets"][4] == 2
    fail = observed("network_failure", at=now(), properties=failure())
    assert client.post("/v1/telemetry/batches", headers=headers, json=body([fail])).json()["events"][0]["status"] == "accepted"
    report = client.get("/v1/admin/network-health?category=score_upload&platform=android", headers={"Authorization": "Bearer " + "a" * 40})
    assert report.status_code == 200 and report.json()["totals"]["attempts"] == 3
    assert report.json()["failures"][0]["request_id"] == fail["properties"]["request_id"]
    with app.state.engine.connect() as connection:
        connection.execute(text("SET LOCAL enable_seqscan=off"))
        plan = connection.execute(text("EXPLAIN SELECT id FROM product_events WHERE source='client' AND name='network_failure' AND occurred_at>=:first ORDER BY occurred_at DESC,id DESC LIMIT 201"), {"first": now()-86400}).all()
        assert any("ix_product_network_failures" in str(row) for row in plan)
