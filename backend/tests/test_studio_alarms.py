"""Real metadata projection and shared, revision-fenced alarm decisions."""
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace
from uuid import uuid4

import pytest
from sqlalchemy import func, select
from test_auth_postgres import postgres_auth  # noqa: F401
from test_studio import headers

from bmt_backend.admin_models import AdminAudit
from bmt_backend.identity_models import Player
from bmt_backend.publication_models import PublicationIntent
from bmt_backend.telemetry_models import ProductEvent
from bmt_backend.track_models import OperationState

AT = 2000000000


@pytest.fixture(params=["sqlite", pytest.param("postgres", marks=pytest.mark.postgres)])
def alarms(request, monkeypatch):
    if request.param == "postgres":
        app, client = request.getfixturevalue("postgres_auth")
    else:
        app, client = request.getfixturevalue("auth_app"), request.getfixturevalue("auth_client")
    app.state.settings = replace(app.state.settings, admin_owner_key="o" * 40, admin_analyst_key="a" * 40)
    with app.state.session_factory() as session:
        player = Player(display_name="Alarm fixture driver")
        session.add(player); session.commit(); ids = {"player": player.id}
    health = {"status": "ready", "available_workers": 1, "queue_depth": 0,
        "queue_capacity": 100, "oldest_age_seconds": 0, "failed_last_5_minutes": 0,
        "storage_free_bytes": 20 * 1024**3, "backup": {"status": "complete"}}
    monkeypatch.setattr("bmt_backend.studio_alarms.now", lambda: AT)
    monkeypatch.setattr("bmt_backend.studio_alarms.competition_health", lambda app, **kw: dict(health))
    return client, app, ids, health


def action(client, key="verification_unavailable", revision=0, **changes):
    body = {"command_id": str(uuid4()), "expected_revision": revision,
        "action": "acknowledge", "reason": "Investigate compatible workers", **changes}
    return client.post(f"/v1/admin/alarms/{key}/actions", headers=headers("owner"), json=body), body


def test_alarm_auth_and_reads_do_not_create_state(alarms):
    client, app, _, health = alarms
    for endpoint in ("alarms", "alarms/queue_delay"):
        assert client.get("/v1/admin/" + endpoint).status_code == 401
        assert client.get("/v1/admin/" + endpoint, headers=headers()).status_code == 200
    assert client.get("/v1/admin/alarms/unknown", headers=headers()).status_code == 404
    result = client.get("/v1/admin/alarms", headers=headers()).json()
    assert result["items"] == [] and result["checks"] == 8 and result["unknown_checks"] == 0
    health.update(status="worker_unavailable", queue_depth=2)
    result = client.get("/v1/admin/alarms", headers=headers()).json()
    assert result["items"][0]["severity"] == "critical"
    with app.state.session_factory() as session:
        assert session.scalar(select(func.count()).select_from(OperationState).where(
            OperationState.id.startswith("admin-alarm:"))) == 0


def test_shared_ack_recovery_clear_recurrence_and_audit(alarms):
    client, app, _, health = alarms
    health.update(status="worker_build_mismatch", queue_depth=3)
    response, body = action(client)
    assert response.status_code == 200, response.text
    assert response.json()["after"]["revision"] == 1
    assert client.post("/v1/admin/alarms/verification_unavailable/actions", headers=headers("owner"),
        json=body).json() == response.json()
    report = client.get("/v1/admin/alarms/verification_unavailable", headers=headers()).json()
    assert report["item"]["status"] == "acknowledged" and not report["item"]["can_clear"]
    assert len(report["history"]) == 1 and report["history"][0]["actor"] == "owner"
    assert action(client, revision=0)[0].status_code == 409
    assert action(client, revision=1, action="clear")[0].status_code == 409
    health.update(status="ready", queue_depth=0)
    report = client.get("/v1/admin/alarms", headers=headers()).json()
    assert report["items"][0]["status"] == "recovered" and report["items"][0]["can_clear"]
    assert action(client, revision=1, action="clear", reason="Worker restored and evidence checked")[0].status_code == 200
    report = client.get("/v1/admin/alarms/verification_unavailable", headers=headers()).json()
    assert report["item"]["status"] == "cleared" and len(report["history"]) == 2
    health.update(status="worker_unavailable", queue_depth=1)
    assert client.get("/v1/admin/alarms", headers=headers()).json()["items"][0]["status"] == "open"
    assert action(client, revision=2)[0].status_code == 200
    with app.state.session_factory() as session:
        assert session.scalar(select(func.count()).select_from(AdminAudit).where(
            AdminAudit.action.like("alarm_%"))) == 3
        assert session.scalar(select(func.count()).select_from(OperationState).where(
            OperationState.id.startswith("admin-alarm:"))) == 1


def test_analyst_reason_unknown_signal_and_idempotency_conflicts(alarms, monkeypatch):
    client, _, _, health = alarms
    health.update(status="worker_unavailable", queue_depth=1)
    _, body = action(client)
    endpoint = "/v1/admin/alarms/verification_unavailable/actions"
    assert client.post(endpoint, headers=headers(), json=body).status_code == 403
    assert client.post(endpoint, headers=headers("owner"), json={**body, "reason": "changed reason"}).status_code == 409
    assert action(client, revision=1, reason="Bearer SECRET_CREDENTIAL")[0].status_code == 422
    assert action(client, revision=1, reason="        ")[0].status_code == 422
    def unavailable(*args, **kwargs):
        raise OSError("private filesystem information")
    monkeypatch.setattr("bmt_backend.studio_alarms.competition_health", unavailable)
    report = client.get("/v1/admin/alarms", headers=headers())
    assert report.status_code == 200 and report.json()["unknown_checks"] == 6
    assert "private filesystem" not in report.text
    assert report.json()["items"][0]["status"] == "unknown"
    assert action(client, revision=1, action="clear")[0].status_code == 409


def test_severity_escalation_returns_to_action_queue(alarms):
    client, _, _, health = alarms
    health.update(oldest_age_seconds=150, queue_depth=2)
    assert action(client, "queue_delay")[0].status_code == 200
    health["oldest_age_seconds"] = 601
    report = client.get("/v1/admin/alarms/queue_delay", headers=headers()).json()
    assert report["item"]["status"] == "open" and report["item"]["severity"] == "critical"
    assert action(client, "queue_delay", revision=1)[0].status_code == 200
    health["oldest_age_seconds"] = 150
    assert client.get("/v1/admin/alarms/queue_delay", headers=headers()).json()["item"]["status"] == "acknowledged"


@pytest.mark.parametrize("field,value,key", [("queue_depth", 100, "queue_capacity"),
    ("oldest_age_seconds", 120, "queue_delay"), ("failed_last_5_minutes", 1, "verification_failures"),
    ("storage_free_bytes", 1024**3 - 1, "storage_low"), ("backup", {"status": "missing"}, "backup_marker")])
def test_actual_check_thresholds(alarms, field, value, key):
    client, _, _, health = alarms
    health[field] = value
    items = client.get("/v1/admin/alarms", headers=headers()).json()["items"]
    assert key in [item["key"] for item in items]


def test_recent_publication_failure_expires_without_hiding_historical_request(alarms):
    client, app, ids, _ = alarms
    with app.state.session_factory() as session:
        publication = PublicationIntent(player_id=ids["player"], operation_key="alarm-fixture",
            request_hash="a" * 64, authoring_id="alarm-fixture", name="Failed publication",
            content_hash="b" * 64, replay_hash="c" * 64, vehicle_id="compact", contract={},
            status="failed", created_at=AT-600, finished_at=AT-1)
        session.add(publication); session.commit(); publication_id = publication.id
    assert action(client, "publication_failures")[0].status_code == 200
    with app.state.session_factory() as session:
        session.get(PublicationIntent, publication_id).finished_at = AT-301; session.commit()
    item = client.get("/v1/admin/alarms/publication_failures", headers=headers()).json()["item"]
    assert item["status"] == "recovered" and item["can_clear"]
    with app.state.session_factory() as session:
        assert session.get(PublicationIntent, publication_id).status == "failed"


def test_concurrent_decisions_preserve_one_revision(alarms):
    client, app, _, health = alarms
    health.update(status="worker_unavailable", queue_depth=1)
    with ThreadPoolExecutor(max_workers=2) as pool:
        responses = list(pool.map(lambda _: action(client)[0].status_code, range(2)))
    assert sorted(responses) == [200, 409]
    with app.state.session_factory() as session:
        assert session.get(OperationState, "admin-alarm:verification_unavailable").details["revision"] == 1


def test_reporting_delay_uses_oldest_unprocessed_receipt(alarms):
    client, app, ids, _ = alarms
    with app.state.session_factory() as session:
        event = ProductEvent(id=str(uuid4()), player_id=ids["player"], source="server", name="race_accepted",
            occurred_at=AT-99999, received_at=AT-300, payload_hash="a" * 64)
        session.add(event); session.commit(); event_id = event.id
    item = client.get("/v1/admin/alarms/projection_delay", headers=headers()).json()["item"]
    assert item["active"] and item["severity"] == "warning"
    assert action(client, "projection_delay")[0].status_code == 200
    with app.state.session_factory() as session:
        session.get(ProductEvent, event_id).processed_at = AT; session.commit()
    assert client.get("/v1/admin/alarms/projection_delay", headers=headers()).json()["item"]["can_clear"]


def test_two_alarm_keys_cannot_share_a_command_identity(alarms):
    client, app, _, health = alarms
    health.update(status="worker_unavailable", queue_depth=2, oldest_age_seconds=200)
    command = str(uuid4())
    with ThreadPoolExecutor(max_workers=2) as pool:
        responses = list(pool.map(lambda key: action(client, key, command_id=command)[0].status_code,
            ["verification_unavailable", "queue_delay"]))
    assert sorted(responses) == [200, 409]
    with app.state.session_factory() as session:
        assert session.scalar(select(func.count()).select_from(OperationState).where(
            OperationState.id.startswith("admin-alarm:"))) == 1
