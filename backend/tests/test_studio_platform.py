"""Platform contracts: trustworthy scope, retry safety and explicit missing coverage."""

import json
from dataclasses import replace
from datetime import datetime, timezone
from uuid import uuid4

import pytest
from sqlalchemy import func, select

from bmt_backend.economy import locked_wallet
from bmt_backend.economy_models import CoinWallet
from bmt_backend.product_analytics import ACTIVE, project_pending
from bmt_backend.studio_analysis import DAY, project
from bmt_backend.studio_erasure import erase_studio_private
from bmt_backend.studio_experiments import assignment, srm
from bmt_backend.studio_finance import import_admob, play_account
from bmt_backend.studio_incidents import deliver_one
from bmt_backend.studio_platform_models import (
    AnalysisDay,
    AnalysisPerson,
    StudioCoinEntry,
    StudioDelivery,
    StudioExperiment,
    StudioFinanceEvent,
    StudioIncident,
)
from bmt_backend.telemetry_models import ProductEvent, ProductProfile
from bmt_backend.track_models import digest, now

OWNER = {"Authorization": "Bearer " + "o" * 40}
ANALYST = {"Authorization": "Bearer " + "a" * 40}
MONITOR = {"Authorization": "Bearer " + "m" * 40}


@pytest.fixture
def platform(auth_app, auth_client, sign_in):
    auth_app.state.settings = replace(
        auth_app.state.settings,
        admin_owner_key="o" * 40,
        admin_analyst_key="a" * 40,
        telemetry_enabled=True,
        client_quality_enabled=True,
        studio_monitor_source_tokens=json.dumps({"fixture": "m" * 40}),
    )
    signed = sign_in("studio-platform")
    return (
        auth_app,
        auth_client,
        signed["player"]["id"],
        {"Authorization": "Bearer " + signed["access_token"]},
    )


def observation(at, active, *, identity=None, severity="warning"):
    return {
        "id": identity or str(uuid4()),
        "observed_at": at,
        "signals": [
            {
                "key": "queue_delay",
                "active": active,
                "severity": severity,
                "title": "Players are waiting",
                "evidence": "Oldest item240seconds",
                "next_step": "Inspect compatible workers and pending results",
                "target": "system/jobs",
            }
        ],
    }


def test_incident_occurrence_idempotency_unknown_recovery_and_operator_cas(platform):
    _app, client, _player, _auth = platform
    at = now() - 20
    first = observation(at, True)
    assert client.post("/v1/monitor/fixture/observations", headers=MONITOR, json=first).status_code == 200
    assert client.post("/v1/monitor/fixture/observations", headers=MONITOR, json=first).json()["duplicate"]
    changed = {**first, "observed_at": at + 1}
    assert client.post("/v1/monitor/fixture/observations", headers=MONITOR, json=changed).status_code == 409
    row = client.get("/v1/admin/incidents", headers=OWNER).json()["items"][0]
    command = {
        "command_id": str(uuid4()),
        "expected_revision": 0,
        "action": "acknowledge",
        "reason": "Investigating worker rollout",
    }
    url = "/v1/admin/incidents/" + row["id"] + "/commands"
    assert client.post(url, headers=ANALYST, json=command).status_code == 403
    assert client.post(url, headers=OWNER, json=command).json()["item"]["state"] == "acknowledged"
    assert client.post(url, headers=OWNER, json=command).json()["duplicate"]
    assert client.post(url, headers=OWNER, json={**command, "command_id": str(uuid4())}).status_code == 409
    client.post("/v1/monitor/fixture/observations", headers=MONITOR, json=observation(at + 1, None))
    detail = client.get("/v1/admin/incidents/" + row["id"], headers=OWNER).json()
    assert detail["item"]["recovered_at"] is None and detail["signal"]["active"] is True
    assert detail["signal"]["known"] is False
    clear = {**command, "command_id": str(uuid4()), "expected_revision": 1, "action": "clear"}
    assert client.post(url, headers=OWNER, json=clear).status_code == 409
    client.post("/v1/monitor/fixture/observations", headers=MONITOR, json=observation(at + 2, False))
    assert (
        client.post(url, headers=OWNER, json={**clear, "expected_revision": 2}).json()["item"]["state"]
        == "closed"
    )
    client.post("/v1/monitor/fixture/observations", headers=MONITOR, json=observation(at + 3, True))
    rows = client.get("/v1/admin/incidents?state=all", headers=OWNER).json()["items"]
    assert len(rows) == 2 and {r["occurrence"] for r in rows} == {1, 2}
    assert (
        client.post("/v1/monitor/fixture/observations", headers=OWNER, json=observation(at, True)).status_code
        == 401
    )


def test_signed_outbox_retries_same_identity_and_finalises_once(platform):
    app, client, _p, _a = platform
    app.state.settings = replace(
        app.state.settings,
        studio_monitor_webhook_url="https://notifications.example/incident",
        studio_monitor_webhook_key="k" * 40,
    )
    client.post("/v1/monitor/fixture/observations", headers=MONITOR, json=observation(now() - 1, True))
    calls = []

    class Response:
        def __init__(self, status):
            self.status_code = status

        def close(self):
            pass

    def send(url, **kwargs):
        calls.append(kwargs)
        return Response(503 if len(calls) == 1 else 204)

    at = now()
    assert deliver_one(app.state.session_factory, app.state.settings, transport=send, at=at)
    assert not deliver_one(app.state.session_factory, app.state.settings, transport=send, at=at + 1)
    assert deliver_one(app.state.session_factory, app.state.settings, transport=send, at=at + 11)
    assert calls[0]["headers"]["Idempotency-Key"] == calls[1]["headers"]["Idempotency-Key"]
    assert len(calls[0]["headers"]["X-BMT-Signature"]) == 64 and not calls[0]["allow_redirects"]
    with app.state.session_factory() as db:
        assert db.scalar(select(StudioDelivery)).state == "delivered"


def test_watchdog_notifies_when_monitored_api_is_offline(platform):
    import requests

    from bmt_backend.studio_watchdog import cycle

    app, _client, _p, _a = platform
    settings = replace(
        app.state.settings,
        studio_monitor_webhook_url="https://notify.example/hook",
        studio_monitor_webhook_key="k" * 40,
    )
    calls = []

    class Response:
        status_code = 204

        def close(self):
            pass

    def offline(*_args, **_kwargs):
        raise requests.ConnectionError("offline fixture")

    def post(url, **kwargs):
        calls.append(url)
        if "/observations" in url:
            raise requests.ConnectionError("API remains offline")
        return Response()

    result = cycle(
        app.state.session_factory,
        settings,
        "https://game.example",
        "fixture",
        "m" * 40,
        get=offline,
        post=post,
    )
    assert result == {"readiness_failed": True, "synced": 0}
    assert calls[0] == "https://notify.example/hook"
    with app.state.session_factory() as db:
        assert db.scalar(select(func.count()).select_from(StudioIncident)) == 1


def event(player, name, at, **kwargs):
    return ProductEvent(
        id=str(uuid4()),
        player_id=player,
        source="client",
        name=name,
        occurred_at=at,
        received_at=now(),
        payload_hash="a" * 64,
        build_id="release-a",
        platform="android",
        properties={},
        **kwargs,
    )


def test_bounded_projection_deduplication_and_full_range_metadata(platform):
    app, client, player, _auth = platform
    at = now() - DAY
    with app.state.session_factory() as db:
        db.add_all([event(player, "session_started", at), event(player, "race_started", at + 1)])
        db.commit()
    project_pending(app.state.session_factory, at=now())
    project_pending(app.state.session_factory, at=now())
    url = f"/v1/admin/analysis/behaviour?since={at - 100}&until={at + 100}&build_id=release-a&view=all"
    result = client.get(url, headers=ANALYST)
    assert result.status_code == 200, result.text
    report = result.json()
    assert report["active_players"] == 1 and report["counters"]["race_started"] == 1
    assert report["since"] % DAY == 0 and report["until"] % DAY == 0
    assert not report["retention"][0]["d30"]["mature"]
    assert client.get(url + "&population=real", headers=OWNER).status_code == 409
    app.state.settings = replace(app.state.settings, studio_business_cohorts=True)
    assert client.get(url + "&population=real", headers=OWNER).json()["active_players"] == 1


def test_journey_refreshes_when_only_inactive_milestone_arrives(platform):
    app, _client, player, _auth = platform
    at = now() - 2 * DAY
    from bmt_backend.product_analytics import FIRST_RACE

    with app.state.session_factory() as db:
        profile = ProductProfile(player_id=player, milestones=[[FIRST_RACE[0], at, "", 0, 0]], truncations={})
        project(db, [event(player, "session_started", at)], {player: profile}, ACTIVE)
        db.commit()
    with app.state.session_factory() as db:
        profile = ProductProfile(
            player_id=player,
            milestones=[[name, at + i, "", i * 100, i] for i, name in enumerate(FIRST_RACE[:5])],
            truncations={},
        )
        project(db, [event(player, "race_finished", at + 4)], {player: profile}, set())
        db.commit()
        assert db.get(AnalysisPerson, player).journey["steps"] == 5


def test_full_scope_quality_and_network_totals_ignore_detail_prefix(platform):
    app, client, _p, _a = platform
    from bmt_backend.network_health import ARRAYS, COUNTERS
    from bmt_backend.network_models import NetworkHealthDay
    from bmt_backend.race_statistics_models import RaceStatisticsDay

    day = now() // DAY
    with app.state.session_factory() as db:
        for i in range(3):
            db.add(
                RaceStatisticsDay(
                    day=day,
                    dimension=str(i),
                    build_id="release-a",
                    platform="android",
                    device_class="phone",
                    device_model="device" + str(i),
                    os_version="14",
                    outcome="finished",
                    races=10,
                    frame_buckets=[0, 0, 100, 0, 0, 10, 2**32, 0],
                )
            )
            counters = {k: 0 for k in COUNTERS}
            counters.update(attempts=10, successes=9, request_body_bytes=2**32)
            db.add(
                NetworkHealthDay(
                    day=day,
                    dimension=str(i),
                    platform="android",
                    build_id="release-a",
                    category="profile",
                    device_model="device" + str(i),
                    os_version="14",
                    counters=counters,
                    buckets={k: [10] + [0] * (size - 1) for k, size in ARRAYS.items()},
                    latest_received_at=now(),
                )
            )
        db.commit()
    quality = client.get("/v1/admin/race-statistics?limit=1", headers=OWNER).json()
    assert quality["truncated"] and quality["totals"]["races"] == 30 and quality["frame_buckets"][2] == 300
    assert quality["frame_buckets"][6] == 3 * 2**32
    network = client.get("/v1/admin/network-health?limit=1", headers=OWNER).json()
    assert network["totals"]["request_body_bytes"] == 3 * 2**32
    assert (
        network["truncated"]
        and network["totals"]["attempts"] == 30
        and network["buckets"]["latency_buckets"][0] == 30
    )
    compare = client.get("/v1/admin/analysis/releases?build_id=release-a", headers=OWNER)
    assert compare.status_code == 200, compare.text
    assert compare.json()["candidate"]["attempts"] == 30


def admob_report(total):
    return [
        {"header": {"localizationSettings": {"currencyCode": "EUR"}}},
        {
            "row": {
                "dimensionValues": {"DATE": {"value": "20261015"}, "APP": {"value": "fixture-app"}},
                "metricValues": {"ESTIMATED_EARNINGS": {"microsValue": str(total)}},
            }
        },
        {"footer": {"matchingRowCount": 1}},
    ]


def test_financial_provider_restatement_is_an_immutable_delta_not_double_revenue(platform):
    app, _c, _p, _a = platform
    for at, total, expected in ((100, 6500000, 1), (101, 6500000, 0), (102, 7000000, 1), (103, 6500000, 1)):
        with app.state.session_factory() as db:
            assert import_admob(db, "accounts/pub-12345678", admob_report(total), at) == expected
    with app.state.session_factory() as db:
        assert db.scalar(select(func.sum(StudioFinanceEvent.amount_micros))) == 6500000
        assert db.scalar(select(func.count()).select_from(StudioFinanceEvent)) == 3
        with pytest.raises(ValueError, match="STALE"):
            import_admob(db, "accounts/pub-12345678", admob_report(9000000), 99)
    incomplete = admob_report(6500000)
    incomplete[-1]["footer"]["matchingRowCount"] = 2
    with app.state.session_factory() as db, pytest.raises(ValueError, match="INCOMPLETE"):
        import_admob(db, "accounts/pub-12345678", incomplete, 104)


def test_existing_wallet_opening_balance_is_not_earnings(platform):
    app, _c, player, _a = platform
    with app.state.session_factory() as db:
        db.add(CoinWallet(player_id=player, balance=1234, revision=7))
        db.commit()
    for _ in range(2):
        with app.state.session_factory() as db:
            assert locked_wallet(db, player).balance == 1234
            db.commit()
    with app.state.session_factory() as db:
        rows = db.scalars(select(StudioCoinEntry)).all()
        assert len(rows) == 1 and rows[0].kind == "opening" and rows[0].amount == 1234


def test_verified_play_purchase_binding_and_replay_never_double_grant(platform):
    app, client, player, auth = platform
    app.state.settings = replace(app.state.settings, studio_play_package="com.example.fixture")

    class Provider:
        def verify(self, token):
            return {
                "obfuscatedExternalAccountId": play_account(player),
                "purchaseCompletionTime": datetime.fromtimestamp(now(), timezone.utc).isoformat(),
                "purchaseStateContext": {"purchaseState": "PURCHASED"},
                "productLineItem": [
                    {
                        "productId": "creator_slot_1",
                        "productOfferDetails": {
                            "quantity": 1,
                            "refundableQuantity": 1,
                            "consumptionState": "CONSUMPTION_STATE_YET_TO_BE_CONSUMED",
                        },
                    }
                ],
            }

        def complete(self, *args):
            pass

    app.state.studio_play_provider = Provider()
    body = {"product_id": "creator_slot_1", "purchase_token": "fixture-secret-token"}
    first = client.post("/v1/billing/google-play/verify", headers=auth, json=body)
    assert first.status_code == 200, first.text
    again = client.post("/v1/billing/google-play/verify", headers=auth, json=body)
    assert again.status_code == 200, again.text
    assert first.json()["entitlements"] == again.json()["entitlements"]
    assert "fixture-secret-token" not in first.text
    with app.state.session_factory() as db:
        assert db.scalar(select(func.count()).select_from(StudioFinanceEvent)) == 0


def test_experiments_assignment_exposure_srm_and_reversible_activation(platform):
    app, client, _player, auth = platform
    body = {
        "command_id": str(uuid4()),
        "name": "A/A fixture",
        "reason": "Validate assignment and exposure path",
        "followup_days": 7,
        "minimum_per_variant": 100,
        "allocation": {"control": 5000, "variant": 5000},
        "variants": {
            "control": {"onboarding_message": "Welcome"},
            "variant": {"onboarding_message": "Welcome"},
        },
    }
    created = client.post("/v1/admin/experiments", headers=OWNER, json=body)
    assert created.status_code == 200, created.text
    identity = created.json()["id"]
    transition = {
        "command_id": str(uuid4()),
        "expected_revision": 0,
        "state": "active",
        "reason": "Start fixture only",
    }
    assert (
        client.post(
            "/v1/admin/experiments/" + identity + "/state", headers=OWNER, json=transition
        ).status_code
        == 200
    )
    first = client.post("/v1/experiments/assignments", headers=auth).json()["items"][0]
    second = client.post("/v1/experiments/assignments", headers=auth).json()["items"][0]
    assert first == second
    score = client.get("/v1/admin/experiments/" + identity + "/scorecard", headers=OWNER).json()
    assert sum(v["exposed"] for v in score["variants"]) == 0
    exposure = {"event_id": str(uuid4()), "variant": first["variant"], "revision": first["revision"]}
    for _ in range(2):
        assert (
            client.post("/v1/experiments/" + identity + "/exposures", headers=auth, json=exposure).status_code
            == 200
        )
    score = client.get("/v1/admin/experiments/" + identity + "/scorecard", headers=OWNER).json()
    assert sum(v["exposed"] for v in score["variants"]) == 1 and score["winner"] is None
    transition.update(command_id=str(uuid4()), expected_revision=1, state="paused")
    assert (
        client.post(
            "/v1/admin/experiments/" + identity + "/state", headers=OWNER, json=transition
        ).status_code
        == 200
    )
    assert not client.post("/v1/experiments/assignments", headers=auth).json()["items"]
    assert not srm({"control": 500, "variant": 500}, body["allocation"])["failed"]
    assert srm({"control": 900, "variant": 100}, body["allocation"])["failed"]
    with app.state.session_factory() as db:
        row = db.get(StudioExperiment, identity)
        counts = {v: 0 for v in body["variants"]}
        for i in range(10000):
            counts[assignment(row, str(i))] += 1
        assert abs(counts["control"] - 5000) < 200
    unsafe = {
        **body,
        "command_id": str(uuid4()),
        "variants": {"control": {"physics": "new"}, "variant": {"physics": "old"}},
    }
    assert client.post("/v1/admin/experiments", headers=OWNER, json=unsafe).status_code == 422
    from bmt_backend.studio_platform_models import AnalysisState, StudioAssignment

    with app.state.session_factory() as db:
        db.get(StudioAssignment, (identity, _player)).exposed_at = now() - 200 * DAY
        db.get(AnalysisState, 1).processed_through = now()
        db.commit()
    expired = client.get("/v1/admin/experiments/" + identity + "/scorecard", headers=OWNER).json()
    assert expired["expired_followups"] == 1 and not expired["enough_mature_players"]
    assert all(v["returned"] is None and v["rate"] is None for v in expired["variants"])


def test_named_staff_roles_audit_and_revocation(platform):
    app, client, _p, _a = platform
    app.state.settings = replace(
        app.state.settings,
        studio_staff_audiences=("staff-audience",),
        studio_staff_subjects=json.dumps({"subject": {"name": "Fixture owner", "role": "owner"}}),
    )

    class Verifier:
        def verify(self, token):
            return {"sub": "subject", "amr": ["mfa"]} if token == "staff-token" else {"sub": "subject"}

    app.state.staff_identity_verifier = Verifier()
    headers = {"Authorization": "Bearer staff-token"}
    who = client.get("/v1/admin/staff", headers=headers).json()
    assert who["actor"].startswith("s_") and who["display_name"] == "Fixture owner"
    assert client.get("/v1/admin/staff", headers={"Authorization": "Bearer missing-mfa"}).status_code == 403
    body = {
        "command_id": str(uuid4()),
        "build_id": "fixture-build",
        "name": "Fixture",
        "state": "testing",
        "expected_revision": 0,
        "reason": "Validate named audit",
    }
    assert client.post("/v1/admin/releases", headers=headers, json=body).status_code == 200
    from bmt_backend.admin_models import AdminAudit

    with app.state.session_factory() as db:
        assert (
            db.scalar(select(AdminAudit).where(AdminAudit.command_id == body["command_id"])).actor
            == who["actor"]
        )
    app.state.settings = replace(app.state.settings, studio_staff_audiences=(), studio_staff_subjects="")
    assert client.get("/v1/admin/staff", headers=headers).status_code == 401


def test_saved_view_is_actor_scoped_retry_safe_and_csv_neutralises_formulas(platform):
    app, client, player, _a = platform
    body = {
        "command_id": str(uuid4()),
        "id": str(uuid4()),
        "expected_revision": 0,
        "name": "Retention review",
        "route": "product",
        "filters": {"tab": "retention", "platform": "android"},
    }
    for _ in range(2):
        assert client.post("/v1/admin/saved-views", headers=OWNER, json=body).status_code == 200
    assert len(client.get("/v1/admin/saved-views", headers=OWNER).json()["items"]) == 1
    assert not client.get("/v1/admin/saved-views", headers=ANALYST).json()["items"]
    with app.state.session_factory() as db:
        db.add(
            AnalysisDay(
                day=now() // DAY,
                player_id=player,
                dimension="a" * 64,
                build_id="=unsafe()",
                platform="android",
                first_at=now(),
                last_at=now(),
                counters={"active": 1, "race_started": 2},
            )
        )
        db.commit()
    result = client.get("/v1/admin/exports/activity.csv", headers=OWNER)
    assert result.status_code == 200 and "'=unsafe()" in result.text and player not in result.text


def test_new_private_facts_are_erased_in_bounded_batches_without_changing_plan(platform):
    app, _c, player, _a = platform
    with app.state.session_factory() as db:
        for i in range(101):
            db.add(
                AnalysisDay(
                    day=now() // DAY,
                    player_id=player,
                    dimension=digest({"i": i}),
                    first_at=now(),
                    last_at=now(),
                    counters={},
                )
            )
        db.commit()
    with app.state.session_factory() as db:
        assert erase_studio_private(db, player)
        db.commit()
        assert db.scalar(select(func.count()).select_from(AnalysisDay)) == 1
    with app.state.session_factory() as db:
        assert erase_studio_private(db, player)
        db.commit()
        assert not erase_studio_private(db, player)


def test_server_http_burn_requires_complete_sufficient_samples_and_redacts_identifiers():
    from datetime import datetime, timezone

    from bmt_backend.studio_http_metrics import aggregate, signals

    until = now() // 60 * 60
    lines = []
    for window in (60, 600, 4000):
        for index in range(200):
            lines.append(
                json.dumps(
                    {
                        "timestamp": datetime.fromtimestamp(until - window, timezone.utc).isoformat(),
                        "jsonPayload": {
                            "event": "http_request",
                            "route": "/v1/runs/{run_id}",
                            "request_id": str(window) + "-" + str(index),
                            "status": 503 if index < 10 else 200,
                            "duration_ms": 2000 if index < 10 else 100,
                            "ignored_secret": "must never leave collector",
                        },
                    }
                )
            )
    report, ignored = aggregate(lines, until=until, complete=True)
    assert ignored == 0 and report["windows"][0]["requests"] == 200
    assert signals(report)[0]["active"] is True
    assert "must never leave" not in json.dumps(report) and "request_id" not in json.dumps(report)
    incomplete, _ = aggregate(lines, until=until, complete=False)
    assert all(s["active"] is None for s in signals(incomplete))
    duplicated, _ = aggregate(lines + lines, until=until, complete=True)
    assert duplicated == report


def test_queue_paging_has_no_duplicates_and_full_summaries(platform):
    app, client, _player, _auth = platform
    with app.state.session_factory() as db:
        for index in range(5):
            db.add(
                StudioDelivery(
                    id=digest({"delivery": index}),
                    incident_id=str(uuid4()),
                    event_id=str(uuid4()),
                    payload={},
                    created_at=now() - 100,
                    state="pending",
                )
            )
        db.commit()
    items = []
    cursor = ""
    while True:
        response = client.get(
            "/v1/admin/jobs?kind=notification&limit=2" + ("&cursor=" + cursor if cursor else ""),
            headers=OWNER,
        )
        assert response.status_code == 200, response.text
        value = response.json()
        assert value["summary"][0]["pending"] == 5
        items.extend(row["id"] for row in value["items"])
        cursor = value["next_cursor"]
        if not cursor:
            break
    assert len(items) == len(set(items)) == 5


def test_external_monitor_is_the_single_notification_authority(platform):
    app, client, _player, _auth = platform
    app.state.settings = replace(
        app.state.settings,
        studio_monitor_webhook_url="https://notify.example/hook",
        studio_monitor_webhook_key="k" * 40,
        studio_monitor_external_notifiers=("fixture",),
    )
    body = observation(now() - 1, True)
    assert client.post("/v1/monitor/fixture/observations", headers=MONITOR, json=body).status_code == 409
    body["notifies_externally"] = True
    assert client.post("/v1/monitor/fixture/observations", headers=MONITOR, json=body).status_code == 200
    assert client.get("/v1/monitor/fixture/control", headers=MONITOR).json()["external_delivery"]
    with app.state.session_factory() as db:
        assert db.scalar(select(func.count()).select_from(StudioDelivery)) == 0


def test_exhausted_notification_retry_is_owner_only_and_idempotent(platform):
    app, client, _player, _auth = platform
    app.state.settings = replace(
        app.state.settings,
        studio_monitor_webhook_url="https://notify.example/hook",
        studio_monitor_webhook_key="k" * 40,
    )
    identity = digest({"dead": "fixture"})
    with app.state.session_factory() as db:
        db.add(
            StudioDelivery(
                id=identity,
                incident_id=str(uuid4()),
                event_id=str(uuid4()),
                state="dead",
                attempts=12,
                payload={},
            )
        )
        db.commit()
    body = {
        "command_id": str(uuid4()),
        "action": "retry",
        "expected_attempts": 12,
        "reason": "Retry after receiver recovery",
    }
    url = "/v1/admin/notifications/" + identity + "/commands"
    assert client.post(url, headers=ANALYST, json=body).status_code == 403
    for _ in range(2):
        assert client.post(url, headers=OWNER, json=body).json()["state"] == "pending"
    assert client.post(url, headers=OWNER, json={**body, "command_id": str(uuid4())}).status_code == 409


def test_case_owner_priority_and_due_date_use_audited_revision_commands(platform):
    _app, client, player, _auth = platform
    case = client.post(
        "/v1/admin/cases",
        headers=OWNER,
        json={"command_id": str(uuid4()), "title": "Fixture investigation", "player_id": player},
    )
    assert case.status_code == 200, case.text
    url = "/v1/admin/cases/" + case.json()["id"] + "/triage"
    body = {
        "command_id": str(uuid4()),
        "expected_revision": 0,
        "priority": "urgent",
        "reason": "Respond to quality regression",
        "due_at": now() + 3600,
    }
    assert client.post(url, headers=ANALYST, json=body).status_code == 403
    for _ in range(2):
        assert client.post(url, headers=OWNER, json=body).json()["revision"] == 1
    assert client.get(url, headers=OWNER).json()["priority"] == "urgent"
    assert client.post(url, headers=OWNER, json={**body, "command_id": str(uuid4())}).status_code == 409


def test_all_pipeline_monitoring_preserves_unknown_news_age_and_delayed_projection():
    from bmt_backend.studio_watchdog import queue_signals

    names = ("race", "publication", "validation", "erasure", "histogram", "news", "notification")
    value = {
        "summary": [{"kind": name, "pending": 0, "oldest_at": None} for name in names],
        "projection": {"oldest_receipt_at": 600},
    }
    value["summary"][0].update(pending=2, oldest_at=500)
    value["summary"][5].update(pending=1, oldest_at=0)
    signals = {s.key: s.active for s in queue_signals(value, at=1000)}
    assert signals["pipeline_race"] is True and signals["pipeline_reporting"] is True
    assert signals["pipeline_news"] is None and signals["pipeline_publication"] is False
