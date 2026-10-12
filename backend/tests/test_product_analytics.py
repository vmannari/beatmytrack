"""Product facts must remain durable, ordered, bounded and separate from racing."""
# ruff: noqa: F811

import asyncio
import secrets
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace
from uuid import uuid4

import httpx
import pytest
from sqlalchemy import event, func, select
from starlette.responses import JSONResponse
from test_auth_postgres import postgres_auth  # noqa: F401

from bmt_backend.middleware import RequestBoundary
from bmt_backend.product_analytics import DAY, bounded_milestones, prepared_report, project_pending
from bmt_backend.telemetry import POLICY, SCHEMA, append_server_event
from bmt_backend.telemetry_models import ProductEvent, ProductMetric, ProductProfile, ProductState

AT = 2000000000 // DAY * DAY + 3600


@pytest.fixture
def product(auth_app, auth_client, sign_in, monkeypatch):
    auth_app.state.settings = replace(auth_app.state.settings, telemetry_enabled=True,
        admin_analyst_key="a" * 40, admin_owner_key="o" * 40)
    signed = sign_in("product-player")
    from bmt_backend.identity_models import Identity
    with auth_app.state.session_factory() as session:
        player_id = session.scalar(select(Identity.player_id).where(Identity.subject == "product-player"))
    monkeypatch.setattr("bmt_backend.telemetry.now", lambda: AT)
    monkeypatch.setattr("bmt_backend.product_analytics.now", lambda: AT)
    return auth_app, auth_client, {"Authorization": "Bearer " + signed["access_token"]}, player_id


def observed(name, at=AT, properties=None, **extra):
    return {"id": str(uuid4()), "name": name, "occurred_at": at, "session_id": str(uuid4()),
        "seq": 1, "monotonic_ms": 100, "properties": properties or {}, **extra}


def body(events):
    return {"schema": SCHEMA, "purpose_policy": POLICY, "build_id": "fixture-v1", "platform": "android", "events": events}


def send(product, events):
    _app, client, headers, _player = product
    return client.post("/v1/telemetry/batches", headers=headers, json=body(events))


def report(product, *, since=AT // DAY * DAY, until=AT + 1, at=AT):
    app, _client, _headers, _player = product
    with app.state.session_factory() as session:
        return prepared_report(session, since, until, at)


def test_no_collection_is_unknown_and_signed_in_only(product):
    app, client, headers, _player = product
    initial = report(product)
    assert initial["daily"][0]["active_players"] is None
    assert initial["weekly_active_players"] is None
    assert initial["funnels"]["first_race"]["cohort_players"] is None
    assert client.post("/v1/telemetry/batches", json=body([observed("menu_ready")])).status_code == 401
    app.state.settings = replace(app.state.settings, telemetry_enabled=False)
    assert send(product, [observed("menu_ready")]).status_code == 503
    assert client.get("/v1/admin/product-analytics", headers=headers).status_code == 401


def test_partial_batch_ack_commit_duplicate_conflict_and_redacted_rejection(product):
    app, _client, _headers, player = product
    good = observed("race_started", properties={"car_id": "compact", "biome": "pine"})
    bad = observed("unknown_event", properties={"email": "private@example.invalid"})
    response = send(product, [good, bad])
    assert response.status_code == 200
    assert [row["status"] for row in response.json()["events"]] == ["accepted", "rejected"]
    assert "private@" not in response.text
    assert send(product, [good]).json()["events"][0]["status"] == "duplicate"
    assert send(product, [{**good, "properties": {"car_id": "kart"}}]).json()["events"][0] ["reason"] == "ID_CONFLICT"
    with app.state.session_factory() as session:
        events = session.scalars(select(ProductEvent)).all()
        assert len(events) == 2
        assert {event.player_id for event in events} == {player}
        assert all("private@" not in str(event.properties) for event in events)
        assert session.get(ProductState, 1).pending_clients == 2


def test_unknown_properties_finite_dimensions_and_claimed_authority_rejected(product):
    response = send(product, [observed("menu_ready", player_id=str(uuid4())),
        observed("race_accepted"), observed("track_exposed", properties={"biome": "arbitrary_dimension"}),
        observed("car_selected", properties={"car_id": "secret-script"})])
    assert response.status_code == 200
    assert all(item["status"] == "rejected" for item in response.json()["events"])
    assert len(send(product, [observed("menu_ready") for _ in range(51)]).content) < 16384


def test_backlog_admission_is_bounded_and_duplicates_ack_at_capacity(product):
    app, _client, _headers, _player = product
    app.state.settings = replace(app.state.settings, telemetry_client_backlog=50)
    events = [observed("menu_ready") for _ in range(50)]
    assert send(product, events).status_code == 200
    assert send(product, events).json()["events"][0]["status"] == "duplicate"
    assert send(product, [observed("menu_ready")]).status_code == 503
    result = project_pending(app.state.session_factory, limit=25, at=AT)
    assert result["processed"] == 25
    assert send(product, [observed("menu_ready")]).status_code == 200


def test_server_outbox_rollback_and_deduplication_never_client_acceptance(product):
    app, _client, _headers, player = product
    source = str(uuid4())
    with app.state.session_factory() as session:
        append_server_event(session, "race_accepted", source, player, {"car_id": "compact"}, occurred_at=AT)
        session.rollback()
    with app.state.session_factory() as session:
        assert session.scalar(select(func.count()).select_from(ProductEvent)) == 0
        for _ in range(3):
            append_server_event(session, "race_accepted", source, player,
                {"car_id": "compact", "run_id": source, "ticket_id": str(uuid4())}, occurred_at=AT, is_test_driver=False)
        session.commit()
    assert send(product, [observed("race_finished")]).status_code == 200
    project_pending(app.state.session_factory, at=AT)
    result = report(product)
    assert result["daily"][0]["accepted_races"] == 1
    assert result["daily"][0]["observed_race_finishes"] == 1
    project_pending(app.state.session_factory, at=AT)
    assert report(product)["daily"][0]["accepted_races"] == 1


def test_distinct_activity_prefers_actual_car_offers_and_is_replay_safe(product):
    app, _client, _headers, _player = product
    events = [observed("menu_ready"), observed("session_heartbeat", properties={"foreground_ms": 60000}),
        observed("track_exposed", properties={"car_id": "compact", "biome": "pine"}),
        observed("track_selected", properties={"biome": "pine"}), observed("car_selected", properties={"car_id": "kart"})]
    assert send(product, events).status_code == 200
    project_pending(app.state.session_factory, at=AT)
    result = report(product)
    assert result["daily"][0]["active_players"] == 1
    assert result["preferences"]["cars"] == [{"id": "kart", "exposures": 0, "selections": 1}]
    assert result["preferences"]["biomes"] == [{"id": "pine", "exposures": 1, "selections": 1}]
    assert send(product, events).json()["events"][0]["status"] == "duplicate"
    project_pending(app.state.session_factory, at=AT)
    assert report(product)["preferences"] == result["preferences"]


def test_exact_retention_waits_full_target_and_watermark_and_late_events_restate(product, monkeypatch):
    app, _client, _headers, player = product
    initial = AT - 8 * DAY
    for timestamp in (initial, initial + DAY, initial + 7 * DAY):
        monkeypatch.setattr("bmt_backend.telemetry.now", lambda timestamp=timestamp: timestamp)
        assert send(product, [observed("session_started", timestamp)]).status_code == 200
    project_pending(app.state.session_factory, at=AT)
    result = report(product, since=initial // DAY * DAY, at=AT)
    assert result["retention"][0]["d1"] == {"returned": 1, "eligible": 1, "mature": True}
    assert result["retention"][0]["d7"] == {"returned": 1, "eligible": 1, "mature": True}
    with app.state.session_factory() as session:
        assert session.get(ProductProfile, player).first_activity_at == initial
        state = session.get(ProductState, 1)
        state.processed_through = initial + 7 * DAY + 1
        session.commit()
    assert report(product, since=initial // DAY * DAY)["retention"][0]["d7"]["returned"] is None


def test_ordered_first_race_and_creator_mature_funnels(product, monkeypatch):
    app, _client, _headers, player = product
    initial = AT - 9 * DAY
    monkeypatch.setattr("bmt_backend.telemetry.now", lambda: initial + 20)
    names = ["app_first_open", "menu_ready", "race_attempt", "race_started", "race_finished",
        "editor_opened", "draft_saved", "publish_requested"]
    events = [observed(name, initial + index) for index, name in enumerate(names)]
    events.append(observed("race_started", initial + 10))
    assert send(product, events).status_code == 200
    with app.state.session_factory() as session:
        append_server_event(session, "track_published", str(uuid4()), player, {}, occurred_at=initial + 15)
        session.commit()
    project_pending(app.state.session_factory, at=AT)
    result = report(product, since=initial // DAY * DAY)
    assert [step["count"] for step in result["funnels"]["first_race"]["steps"]] == [1] * 6
    assert [step["count"] for step in result["funnels"]["creator"]["steps"]] == [1] * 4


def test_future_precollection_and_unprocessed_day_remain_unknown(product):
    app, _client, _headers, _player = product
    assert send(product, [observed("menu_ready")]).status_code == 200
    project_pending(app.state.session_factory, at=AT)
    result = report(product, since=(AT // DAY - 1) * DAY, until=(AT // DAY + 3) * DAY)
    assert [row["active_players"] for row in result["daily"]] == [None, 1, None, None]
    future = report(product, since=(AT // DAY + 1) * DAY, until=(AT // DAY + 3) * DAY)
    assert future["period_active_players"] is None
    assert future["funnels"]["first_race"]["cohort_players"] is None
    assert future["store"]["opened"] is None
    assert future["challenges"]["challenge_opened"] is None
    with app.state.session_factory() as session:
        session.get(ProductState, 1).processed_through = AT - DAY
        session.commit()
    assert report(product)["daily"][0]["active_players"] is None


def test_milestone_frontier_keeps_late_earlier_events_and_ignores_later_replays():
    values = [["app_first_open", 100], ["menu_ready", 101], ["race_started", 102]]
    values += [["race_started", 100 + DAY + index] for index in range(300)]
    values += [["race_attempt", 101]]
    result, truncated = bounded_milestones(values)
    assert ["race_attempt", 101] in result
    assert ["race_started", 102] in result
    assert len(result) == 5  # Incomplete journey retains the exact 24-hour boundary.
    assert not truncated


def test_quality_maxima_are_reported_counts_not_replayed_business_effects(product):
    app, _client, _headers, _player = product
    for dropped in (5, 5, 8):
        assert send(product, [observed("collection_summary", properties={"dropped_events": dropped})]).status_code == 200
        project_pending(app.state.session_factory, at=AT)
    assert report(product)["quality"]["dropped_events"] == 8


def test_dashboard_selects_only_prepared_tables(product):
    app, client, _headers, _player = product
    statements = []
    def record(_connection, _cursor, statement, *_args):
        statements.append(statement.lower())
    event.listen(app.state.engine, "before_cursor_execute", record)
    try:
        response = client.get("/v1/admin/product-analytics", headers={"Authorization": "Bearer " + "a" * 40})
        assert response.status_code == 200
        assert response.json()["role"] == "analyst"
        assert all("from product_events" not in statement and "from runs" not in statement for statement in statements)
    finally:
        event.remove(app.state.engine, "before_cursor_execute", record)


def test_expired_fact_coverage_is_unknown_and_mature_return_flags_not_erased(product, monkeypatch):
    app, _client, _headers, player = product
    first = AT - 8 * DAY
    for timestamp in (first, first + DAY, first + 7 * DAY):
        monkeypatch.setattr("bmt_backend.telemetry.now", lambda timestamp=timestamp: timestamp)
        assert send(product, [observed("session_started", timestamp)]).status_code == 200
    project_pending(app.state.session_factory, at=AT)
    later = AT + 30 * DAY
    project_pending(app.state.session_factory, at=later, fact_days=14)
    monkeypatch.setattr("bmt_backend.telemetry.now", lambda: later)
    assert send(product, [observed("session_started", later)]).status_code == 200
    project_pending(app.state.session_factory, at=later, fact_days=14)
    expired = report(product, since=first // DAY * DAY, until=(first // DAY + 8) * DAY, at=later)
    assert all(row["active_players"] is None and not row["observed"] for row in expired["daily"])
    assert expired["period_active_players"] is None
    assert expired["coverage"]["fact_retention_days"] == 14
    with app.state.session_factory() as session:
        saved = session.get(ProductProfile, player).projection
        assert saved[f"{first // DAY}|retention_d1_returned|"] == 1
        assert saved[f"{first // DAY}|retention_d7_returned|"] == 1


def test_store_and_challenge_actions_remain_observations_and_provider_fulfillment_unknown(product):
    app, _client, _headers, player = product
    assert send(product, [observed("store_opened"), observed("offer_exposed", properties={"product_id": "creator_slot_1"}),
        observed("purchase_requested", properties={"product_id": "creator_slot_1"}), observed("challenge_joined")]).status_code == 200
    with app.state.session_factory() as session:
        append_server_event(session, "challenge_joined", str(uuid4()), player, {}, occurred_at=AT)
        session.commit()
    project_pending(app.state.session_factory, at=AT)
    result = report(product)
    assert result["store"] == {"opened": 1, "offers": [{"id": "creator_slot_1", "exposures": 1, "requests": 1}], "fulfilled": None}
    assert result["challenges"]["challenge_joined"] == 1


def test_external_creator_value_excludes_own_races_and_never_marks_passive_owner_active(product):
    app, _client, _headers, owner = product
    from bmt_backend.identity_models import Player
    from bmt_backend.telemetry_models import ProductPlayerDay
    published = AT - 9 * DAY
    version = str(uuid4())
    with app.state.session_factory() as session:
        external = Player(display_name="External artificial racer", is_test_driver=True)
        session.add(external)
        session.flush()
        context = {"track_version": version, "owner_id": owner, "published_at": published}
        append_server_event(session, "track_published", version, owner, context, occurred_at=published, is_test_driver=False)
        append_server_event(session, "race_accepted", str(uuid4()), owner, context, occurred_at=published + 10, is_test_driver=False)
        append_server_event(session, "race_accepted", str(uuid4()), external.id, context,
            occurred_at=published + 2 * DAY, is_test_driver=True)
        session.commit()
    project_pending(app.state.session_factory, at=AT)
    result = report(product, since=published // DAY * DAY)
    assert result["creator_value"] == {"published_versions": 1, "mature_published_versions": 1,
        "external_racer_7d_versions": 1, "cohort_followup_days": 7}
    with app.state.session_factory() as session:
        assert session.get(ProductPlayerDay, {"day": (published + 2 * DAY) // DAY, "player_id": owner}) is None


def test_completed_funnel_does_not_accumulate_ordinary_later_replays():
    values = [[name, 100 + index] for index, name in enumerate(
        ["app_first_open", "menu_ready", "race_attempt", "race_started", "race_finished"])]
    values += [["race_started", 110 + index] for index in range(500)]
    result, truncated = bounded_milestones(values)
    assert len(result) == 6
    assert not truncated


def test_raw_retirement_and_server_tombstone_cannot_double_prepared_effect(product, monkeypatch):
    app, _client, _headers, player = product
    client_event = observed("menu_ready")
    assert send(product, [client_event]).status_code == 200
    source = str(uuid4())
    with app.state.session_factory() as session:
        server_id = append_server_event(session, "race_accepted", source, player, {"car_id": "kart"}, occurred_at=AT, is_test_driver=False)
        session.commit()
    project_pending(app.state.session_factory, at=AT)
    later = AT + 10 * DAY
    project_pending(app.state.session_factory, at=later)
    monkeypatch.setattr("bmt_backend.telemetry.now", lambda: later)
    assert send(product, [client_event]).json()["events"][0]["reason"] == "CLOCK_OUTSIDE_WINDOW"
    with app.state.session_factory() as session:
        assert session.get(ProductEvent, server_id).compacted
        assert session.get(ProductEvent, server_id).properties == {}
        append_server_event(session, "race_accepted", source, player, {"car_id": "kart"}, occurred_at=AT, is_test_driver=False)
        session.commit()
    project_pending(app.state.session_factory, at=later)
    result = report(product, since=AT // DAY * DAY, until=(AT // DAY + 1) * DAY, at=later)
    assert result["daily"][0]["accepted_races"] == 1


@pytest.mark.postgres
def test_postgres_duplicate_ingestion_and_parallel_projection_are_one_effect(postgres_auth, monkeypatch):
    app, client = postgres_auth
    app.state.settings = replace(app.state.settings, telemetry_enabled=True)
    challenge = client.post("/v1/auth/google/challenge").json()
    identity_token = secrets.token_urlsafe(32)
    app.state.identity_verifier.claims[identity_token] = {"sub": "product-pg", "nonce": challenge["nonce"]}
    signed = client.post("/v1/auth/google", json={"id_token": identity_token, "challenge_id": challenge["challenge_id"],
        "display_name": "Product PG"})
    assert signed.status_code == 200
    headers = {"Authorization": "Bearer " + signed.json()["access_token"]}
    monkeypatch.setattr("bmt_backend.telemetry.now", lambda: AT)
    payload = body([observed("menu_ready")])
    with ThreadPoolExecutor(max_workers=4) as pool:
        responses = list(pool.map(lambda _index: client.post("/v1/telemetry/batches", headers=headers, json=payload), range(4)))
    assert all(response.status_code in (200, 503) for response in responses)
    responses = [client.post("/v1/telemetry/batches", headers=headers, json=payload)
        if response.status_code == 503 else response for response in responses]
    assert all(response.status_code == 200 for response in responses)
    assert sorted(response.json()["events"][0]["status"] for response in responses) == ["accepted", "duplicate", "duplicate", "duplicate"]
    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda _index: project_pending(app.state.session_factory, limit=1, at=AT), range(2)))
    assert sorted(result["processed"] for result in results) == [0, 1]
    with app.state.session_factory() as session:
        assert session.get(ProductState, 1).pending_clients == 0
        assert session.get(ProductMetric, {"day": AT // DAY, "key": "active_players", "dimension": ""}).value == 1
        from bmt_backend.telemetry_models import ProductPlayerDay
        expired_day = AT // DAY - 20
        session.add_all(ProductPlayerDay(day=expired_day, player_id=str(uuid4())) for _index in range(5))
        session.add_all(ProductMetric(day=expired_day, key="expired_" + str(index), dimension="", value=1) for index in range(5))
        session.commit()
    project_pending(app.state.session_factory, limit=2, at=AT, fact_days=14)
    with app.state.session_factory() as session:
        assert session.scalar(select(func.count()).select_from(ProductPlayerDay).where(ProductPlayerDay.day == expired_day)) == 3
        assert session.scalar(select(func.count()).select_from(ProductMetric).where(ProductMetric.day == expired_day)) == 3


def test_retention_cleanup_limits_composite_rows_not_whole_days(product):
    app, _client, _headers, _player = product
    from bmt_backend.telemetry_models import ProductPlayerDay
    expired_day = AT // DAY - 20
    with app.state.session_factory() as session:
        session.add_all(ProductPlayerDay(day=expired_day, player_id=str(uuid4())) for _index in range(5))
        session.add_all(ProductMetric(day=expired_day, key="expired_" + str(index), dimension="", value=1) for index in range(5))
        session.commit()
    project_pending(app.state.session_factory, limit=2, at=AT, fact_days=14)
    with app.state.session_factory() as session:
        assert session.scalar(select(func.count()).select_from(ProductPlayerDay).where(ProductPlayerDay.day == expired_day)) == 3
        assert session.scalar(select(func.count()).select_from(ProductMetric).where(ProductMetric.day == expired_day)) == 3


def test_second_race_requires_post_finish_order_and_extra_maturity_margin(product, monkeypatch):
    app, _client, _headers, _player = product
    cohort_day = AT // DAY - 4
    first = (cohort_day + 1) * DAY - 1
    finished = first + DAY
    valid_second = observed("race_started", finished + 599)
    monkeypatch.setattr("bmt_backend.telemetry.now", lambda: finished + 599)
    events = [observed("app_first_open", first), observed("menu_ready", first), observed("race_attempt", first),
        observed("race_started", first + 1), observed("race_started", finished - 1), observed("race_retried", finished - 1),
        observed("race_finished", finished)]
    assert send(product, events).status_code == 200
    project_pending(app.state.session_factory, at=AT)
    old = report(product, since=cohort_day * DAY)
    assert old["funnels"]["first_race"]["steps"][-1]["count"] == 0
    assert send(product, [valid_second, valid_second]).status_code == 200
    project_pending(app.state.session_factory, at=(cohort_day + 2) * DAY + 599)
    immature = report(product, since=cohort_day * DAY, until=(cohort_day + 1) * DAY,
        at=(cohort_day + 2) * DAY + 599)
    assert not immature["funnels"]["first_race"]["mature"]
    project_pending(app.state.session_factory, at=(cohort_day + 2) * DAY + 600)
    mature = report(product, since=cohort_day * DAY, until=(cohort_day + 1) * DAY,
        at=(cohort_day + 2) * DAY + 600)
    assert mature["funnels"]["first_race"]["steps"][-1]["count"] == 1


def test_same_second_second_race_uses_session_monotonic_order(product, monkeypatch):
    app, _client, _headers, _player = product
    initial = AT - 3 * DAY
    session_id = str(uuid4())
    monkeypatch.setattr("bmt_backend.telemetry.now", lambda: initial + 10)
    events = [observed(name, initial + min(index, 4), session_id=session_id, monotonic_ms=100 + index, seq=index)
        for index, name in enumerate(["app_first_open", "menu_ready", "race_attempt", "race_started", "race_finished", "race_started"])]
    assert send(product, list(reversed(events))).status_code == 200
    project_pending(app.state.session_factory, at=AT)
    assert report(product, since=initial // DAY * DAY)["funnels"]["first_race"]["steps"][-1]["count"] == 1


def test_funnel_overflow_is_scoped_and_recovers_when_complete_proof_arrives(product, monkeypatch):
    app, _client, _headers, _player = product
    first = AT - 9 * DAY
    monkeypatch.setattr("bmt_backend.telemetry.now", lambda: first + 100)
    events = [observed("app_first_open", first), observed("menu_ready", first + 1), observed("race_attempt", first + 2)]
    events += [observed("race_started", first + 3 + index) for index in range(25)]
    assert send(product, events).status_code == 200
    project_pending(app.state.session_factory, at=AT)
    bad = report(product, since=first // DAY * DAY)
    assert bad["funnels"]["first_race"]["truncated_cohort_players"] == 1
    assert bad["funnels"]["first_race"]["cohort_players"] is None
    unrelated = report(product, since=(first // DAY + 1) * DAY)
    assert unrelated["funnels"]["first_race"]["cohort_players"] == 0
    later = [observed("race_started", first + 51), observed("race_finished", first + 50)]
    assert send(product, later).status_code == 200
    project_pending(app.state.session_factory, at=AT)
    recovered = report(product, since=first // DAY * DAY)
    assert recovered["coverage"]["truncated_profiles"] == 0
    assert recovered["funnels"]["first_race"]["steps"][-1]["count"] == 1


def test_telemetry_handler_budget_does_not_borrow_race_upload_slots(auth_app, monkeypatch):
    monkeypatch.setattr("bmt_backend.middleware.check_budget", lambda *_args, **_kwargs: True)
    async def exercise():
        release, telemetry_started, races_started = asyncio.Event(), asyncio.Event(), asyncio.Event()
        live = {"telemetry": 0, "races": 0}
        async def handler(scope, receive, send):
            kind = "telemetry" if scope["path"] == "/v1/telemetry/batches" else "races"
            live[kind] += 1
            if live["telemetry"] == 1:
                telemetry_started.set()
            if live["races"] == 2:
                races_started.set()
            await release.wait()
            live[kind] -= 1
            await JSONResponse({"ok": True})(scope, receive, send)
        boundary = RequestBoundary(handler, replace(auth_app.state.settings, upload_concurrency=2), auth_app.state.session_factory)
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=boundary), base_url="http://test") as client:
            first = asyncio.create_task(client.post("/v1/telemetry/batches", json={}))
            await asyncio.wait_for(telemetry_started.wait(), 2)
            races = [asyncio.create_task(client.post("/v1/runs", json={})) for _index in range(2)]
            await asyncio.wait_for(races_started.wait(), 2)
            busy = await client.post("/v1/telemetry/batches", json={})
            assert busy.status_code == 503 and busy.json()["detail"] == "REQUEST_VALIDATION_BUSY"
            assert live == {"telemetry": 1, "races": 2}
            release.set()
            assert all(response.status_code == 200 for response in await asyncio.gather(first, *races))
            assert boundary.telemetry_parsers._value == 1
            assert boundary.parsers._value == 2
    asyncio.run(exercise())
