"""Quality observations are bounded, deduplicated and never scoring evidence."""
# ruff: noqa: F811
from dataclasses import replace
from uuid import uuid4

import pytest
from sqlalchemy import func, select
from test_product_analytics import AT, body, observed, product, send  # noqa: F401

from bmt_backend.product_analytics import project_pending
from bmt_backend.quality_models import QualityFact


def frames(**changes):
    return {"device_class": "android_arm64", "scene": "menu", "samples": 100, "slow": 10,
        **{f"b{i}": 90 if i == 2 else 10 if i == 5 else 0 for i in range(8)}, **changes}


def test_quality_gate_validation_dedupe_projection_and_read_budget(product):
    app, client, _auth, _player = product
    observation = observed("quality_summary", properties=frames())
    assert send(product, [observation]).json()["events"][0]["status"] == "rejected"
    app.state.settings = replace(app.state.settings, client_quality_enabled=True)
    # A rejected ID is permanently handled; a newly valid event needs its own ID.
    observation["id"] = str(uuid4())
    assert send(product, [observation]).json()["events"][0]["status"] == "accepted"
    assert send(product, [observation]).json()["events"][0]["status"] == "duplicate"
    for props in (frames(samples=101), frames(email="secret@example.invalid"), frames(b0=True), frames(device_class="unique-device-id")):
        assert send(product, [observed("quality_summary", properties=props)]).json()["events"][0]["status"] == "rejected"
    project_pending(app.state.session_factory, at=AT)
    project_pending(app.state.session_factory, at=AT)
    assert client.get('/v1/admin/quality').status_code == 401
    query = f'/v1/admin/quality?since={AT-3600}&until={AT+1}'
    report = client.get(query, headers={"Authorization": "Bearer " + "a" * 40}).json()
    assert len(report['items']) == 1 and report['items'][0]['samples'] == 100
    assert report['items'][0]['slow'] == 10 and report['coverage']['guest'] == 'unavailable'
    assert client.get(query+'&limit=1001', headers={"Authorization": "Bearer " + "a" * 40}).status_code == 422


def test_spatial_and_exit_contracts_are_typed_bounded_not_arbitrary_capture(product):
    app, _client, _auth, _player = product
    app.state.settings = replace(app.state.settings, client_quality_enabled=True)
    cell = {"track_version_id": str(uuid4()), "segment": 2, "cell_x": -3, "cell_y": 4, "samples": 15, "slow": 1}
    for props in (cell, {**cell, 'segment': 31}):
        assert send(product, [observed('segment_summary', properties=props)]).json()['events'][0]['status'] == 'rejected'
    assert send(product, [observed('quality_summary', properties=frames(scene='race'))]).json()['events'][0]['status'] == 'rejected'
    for props in ({**cell, 'segment': 32}, {**cell, 'cell_x': 5001}, {**cell, 'slow': 16}, {**cell, 'track_version_id': 'invalid'}):
        assert send(product, [observed('segment_summary', properties=props)]).json()['events'][0]['status'] == 'rejected'
    assert send(product, [observed('process_exit', properties={'device_class':'android_arm64','exit_reason':6})]).json()['events'][0]['status'] == 'accepted'
    assert send(product, [observed('process_exit', properties={'device_class':'android_arm64','exit_reason':2,'stack':'secret'})]).json()['events'][0]['status'] == 'rejected'
    project_pending(app.state.session_factory, at=AT)
    with app.state.session_factory() as session:
        assert session.scalar(select(func.count()).select_from(QualityFact)) == 1


def test_quality_requires_telemetry_transport():
    from bmt_backend.config import Settings
    with pytest.raises(ValueError, match='transport'):
        Settings(client_quality_enabled=True)
