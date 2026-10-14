"""Network observations are bounded, retry-safe and separate from product/game authority."""
# ruff: noqa: F811
from dataclasses import replace
from uuid import uuid4

import pytest
from sqlalchemy import func, select, text
from test_product_analytics import AT, body, observed, product, send  # noqa: F401

from bmt_backend.network_health import ARRAYS, COUNTERS, cleanup
from bmt_backend.network_models import NetworkHealthDay
from bmt_backend.product_analytics import project_pending
from bmt_backend.telemetry_models import ProductEvent, ProductPlayerDay


def summary(**changes):
    value = {"schema_version": 1, "category": "score_upload", "device_model": "Fixture phone", "os_version": "Fixture OS",
        **{field: 0 for field in COUNTERS}, **{field: [0] * size for field, size in ARRAYS.items()}}
    value.update(attempts=3, successes=1, retries=1, throttled=1, request_body_bytes=500, response_body_bytes=200,
        total_ms=600, queue_ms=60, encode_ms=40, http_ms=450, decode_ms=20, upload_age_samples=2)
    value["latency_buckets"][3] = 3; value["queue_buckets"][0] = 3; value["http_buckets"][3] = 3
    value["error_buckets"][0] = 1; value["error_buckets"][5] = 1; value["error_buckets"][13] = 1
    value["status_buckets"][0] = 1; value["status_buckets"][1] = 1; value["status_buckets"][4] = 1
    value["method_buckets"][1] = 3; value["upload_age_buckets"][4] = 2
    return {**value, **changes}


def failure(**changes):
    return {"schema_version": 1, "category": "score_upload", "device_model": "Fixture phone", "os_version": "Fixture OS",
        "method": "POST", "error_type": "throttled", "http_status": 429, "total_ms": 210, "queue_ms": 20,
        "encode_ms": 10, "http_ms": 170, "decode_ms": 10, "retry_index": 1, "upload_age_seconds": 120,
        "request_id": str(uuid4()), **changes}


def enabled(product):
    app = product[0]
    app.state.settings = replace(app.state.settings, client_quality_enabled=True)
    return app


def test_network_gate_commit_dedupe_projection_and_report(product):
    app, client, _auth, _player = product
    event = observed("network_summary", properties=summary())
    assert send(product, [event]).json()["events"][0]["status"] == "rejected"
    enabled(product); event["id"] = str(uuid4())
    assert send(product, [event]).json()["events"][0]["status"] == "accepted"
    assert send(product, [event]).json()["events"][0]["status"] == "duplicate"
    fail = observed("network_failure", properties=failure())
    assert send(product, [fail]).json()["events"][0]["status"] == "accepted"
    project_pending(app.state.session_factory, at=AT); project_pending(app.state.session_factory, at=AT)
    with app.state.session_factory() as session:
        row = session.scalar(select(NetworkHealthDay))
        assert row.counters["attempts"] == 3 and row.counters["throttled"] == 1
        assert row.buckets["upload_age_buckets"][4] == 2
        assert session.scalar(select(func.count()).select_from(ProductPlayerDay)) == 0
    url = f"/v1/admin/network-health?since={AT-3600}&until={AT+1}"
    assert client.get(url).status_code == 401
    headers = {"Authorization": "Bearer " + "a" * 40}
    # Use the fixture's event clock for the retention/reporting boundary.
    from unittest.mock import patch
    with patch("bmt_backend.network_health.now", return_value=AT):
        report = client.get(url, headers=headers).json()
        assert report["totals"]["attempts"] == 3 and report["failures"][0]["request_id"] == fail["properties"]["request_id"]
        assert not any(field in str(report) for field in ("access_token", "refresh_token", "player_id", "install_id", "session_id"))
        assert client.get(url + "&category=profile", headers=headers).json()["totals"] == {}
        assert client.get(url + "&device_model=Fixture%20phone", headers=headers).json()["failures"]
    for query in ("category=unregistered", "platform=unknown", "limit=1001"):
        assert client.get(url + "&" + query, headers=headers).status_code == 422
    assert client.get("/admin/assets/network.js").status_code == 200


@pytest.mark.parametrize("changes", [
    {"attempts": True}, {"successes": 2}, {"throttled": 0}, {"retries": 4}, {"category": "raw/private/path"},
    {"device_model": "hidden\nidentifier"}, {"os_version": "x" * 81}, {"url": "https://private.invalid/token"},
    {"method_buckets": [0] * 8}, {"latency_buckets": [3, 0, 0, 0, 0, 0, 0]}, {"total_ms": 1},
    {"request_body_bytes": 8388608 * 4}, {"upload_age_samples": 4}, {"category": "profile"},
])
def test_network_summary_rejects_private_unbounded_or_inconsistent_data(product, changes):
    enabled(product)
    assert send(product, [observed("network_summary", properties=summary(**changes))]).json()["events"][0]["status"] == "rejected"


@pytest.mark.parametrize("changes", [
    {"request_id": "not-a-server-id"}, {"request_id": str(uuid4()) + "\n"}, {"error_type": "stack trace"},
    {"method": "raw-request-method"}, {"http_status": True}, {"retry_index": 1001}, {"upload_age_seconds": -2},
    {"total_ms": 1}, {"payload": {"credential": "private"}}, {"device_model": "x" * 81},
])
def test_network_failure_has_strict_small_correlation_fields(product, changes):
    enabled(product)
    assert send(product, [observed("network_failure", properties=failure(**changes))]).json()["events"][0]["status"] == "rejected"


def test_selected_failures_without_response_ids_and_bounded_lookup(product, monkeypatch):
    app, client, _auth, player = product; enabled(product)
    value = failure(error_type="dns", http_status=0, upload_age_seconds=-1); value.pop("request_id")
    assert send(product, [observed("network_failure", properties=value)]).json()["events"][0]["status"] == "accepted"
    # A selected-sample page may be narrower than the actual failure population.
    with app.state.session_factory() as session:
        for index in range(205):
            session.add(ProductEvent(id=str(uuid4()), player_id=player, source="client", name="network_failure",
                occurred_at=AT, received_at=AT, build_id="fixture-v1", platform="android", properties=failure(),
                payload_hash="a" * 64))
        session.commit()
    monkeypatch.setattr("bmt_backend.network_health.now", lambda: AT)
    report = client.get(f"/v1/admin/network-health?since={AT-1}&until={AT+1}",
        headers={"Authorization": "Bearer " + "a" * 40}).json()
    assert len(report["failures"]) == 50 and report["failure_candidates_truncated"] and report["failure_samples_truncated"]
    with app.state.engine.connect() as connection:
        plan = connection.execute(text("EXPLAIN QUERY PLAN SELECT id FROM product_events WHERE source='client' AND name='network_failure' AND occurred_at>=:first ORDER BY occurred_at DESC,id DESC LIMIT201".replace("LIMIT201", "LIMIT 201")), {"first": AT-1}).all()
        assert any("ix_product_network_failures" in str(row) for row in plan)


def test_network_fact_retention_is_paced_and_expired_facts_hidden(product, monkeypatch):
    app, client, _auth, _player = product; enabled(product)
    assert send(product, [observed("network_summary", properties=summary())]).json()["events"][0]["status"] == "accepted"
    project_pending(app.state.session_factory, at=AT)
    future = AT + 181 * 86400
    monkeypatch.setattr("bmt_backend.network_health.now", lambda: future)
    report = client.get(f"/v1/admin/network-health?since={AT-1}&until={AT+1}",
        headers={"Authorization": "Bearer " + "a" * 40}).json()
    assert report["totals"] == {} and not report["failures"]
    with app.state.session_factory() as session:
        cleanup(session, future, 1, 180); session.commit()
        assert session.scalar(select(func.count()).select_from(NetworkHealthDay)) == 0
