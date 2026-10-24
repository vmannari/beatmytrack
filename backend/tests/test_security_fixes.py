"""Adversarial authority and receiver checks for SEC03/04/06/07/08."""

import asyncio
import json
from contextlib import ExitStack
from dataclasses import replace
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from test_rivalry_appearance import appearance

from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.economy_models import CosmeticUnlock
from bmt_backend.migrate import upgrade
from bmt_backend.resume_models import ResumeReceipt
from bmt_backend.studio_platform_models import StudioStaff


@pytest.fixture
def service(tmp_path):
    stack = ExitStack()
    engines = []

    def make(**values):
        folder = tmp_path / str(len(engines))
        settings = Settings(database_url="sqlite://", object_dir=str(folder), **values)
        app = create_app(settings)
        upgrade(app.state.engine)
        engines.append(app.state.engine)
        client = stack.enter_context(TestClient(app))
        return app, client

    yield make
    stack.close()
    for engine in engines:
        engine.dispose()


@pytest.mark.parametrize(
    "values",
    [
        {"studio_legacy_keys_enabled": True},
        {"admin_owner_key": "o" * 40},
        {"admin_analyst_key": "a" * 40},
        {"studio_staff_require_mfa": False},
        {"temporary_ad_resumes_enabled": True},
    ],
)
def test_production_rejects_bypasses(values):
    with pytest.raises(ValueError):
        Settings(**values)


def test_explicit_test_legacy_and_preview_remain_available():
    settings = Settings(
        environment="test",
        studio_legacy_keys_enabled=True,
        admin_owner_key="o" * 40,
        temporary_ad_resumes_enabled=True,
    )
    assert settings.studio_legacy_keys_enabled and settings.temporary_ad_resumes_enabled


@pytest.mark.parametrize(
    "path",
    [
        "/admin",
        "/admin/assets/app.js",
        "/v1/admin/overview",
        "/v1/admin/publications",
        "/v1/admin/publications/" + str(uuid4()),
        "/v1/monitor/source/control",
    ],
)
@pytest.mark.parametrize("environment", ["production", "development", "test"])
def test_production_public_api_never_exposes_administration(service, path, environment):
    app, client = service(environment=environment)

    class Forbidden:
        def verify(self, _token):
            raise AssertionError("Public ingress must not attempt staff verification")

    app.state.staff_identity_verifier = Forbidden()
    assert client.get(path, headers={"Authorization": "Bearer staff-token"}).status_code == 404
    assert client.get("/healthz").status_code == 200


def test_private_admin_requires_named_mfa_and_checks_revocation(service):
    app, client = service(
        workload_role="admin",
        studio_staff_audiences=("staff",),
        studio_staff_subjects=json.dumps({"known": {"name": "Owner", "role": "owner"}}),
    )

    class Verifier:
        def verify(self, token):
            return {
                "sub": "unknown" if token == "unknown" else "known",
                "amr": [] if token == "password" else ["mfa"],
            }

    app.state.staff_identity_verifier = Verifier()
    assert client.get("/v1/auth/google/challenge").status_code == 404
    assert client.post("/v1/auth/google/challenge", json={}).status_code == 404
    assert client.get("/v1/game-config?platform=android&build_id=test").status_code == 404
    assert client.get("/v1/admin/overview").status_code == 401
    for token in ("unknown", "password"):
        assert (
            client.get("/v1/admin/overview", headers={"Authorization": "Bearer " + token}).status_code == 403
        )
    auth = {"Authorization": "Bearer allowed"}
    result = client.get("/v1/admin/staff", headers=auth)
    assert result.status_code == 200, result.text
    actor = result.json()["actor"]
    assert actor.startswith("s_")
    with app.state.session_factory() as session:
        session.get(StudioStaff, actor).enabled = False
        session.commit()
    assert client.get("/v1/admin/staff", headers=auth).status_code == 403


@pytest.mark.parametrize("path", ["/v1/me/appearances", "/v1/rivalry/appearance"])
def test_both_appearance_writes_require_account_unlocks(auth_app, auth_client, sign_in, path):
    signed = sign_in(analytics=False)
    other = sign_in("other", analytics=False)
    auth = {"Authorization": "Bearer " + signed["access_token"]}
    value = appearance()

    def write(current, previous=None):
        body = {"appearance": current, "previous": previous} if "/me/" in path else current
        return auth_client.put(path, headers=auth, json=body)

    assert write(value).status_code == 200
    priced = appearance()
    priced["customisation"]["body"] = "wide"
    before = auth_client.get("/v1/economy", headers=auth).json()
    assert before["balance"] == 0
    with auth_app.state.session_factory() as session:
        session.add(
            CosmeticUnlock(player_id=other["player"]["id"], item_id="kit/compact/body/wide", price=750)
        )
        session.commit()
    for previous in (None, value, priced):
        assert write(priced, previous).status_code == 403
    assert auth_client.get("/v1/me/appearances", headers=auth).json()["appearances"]["compact"] == value
    with auth_app.state.session_factory() as session:
        session.add(
            CosmeticUnlock(player_id=signed["player"]["id"], item_id="kit/compact/body/wide", price=0)
        )
        session.commit()
    assert write(priced, value).status_code == 200
    assert write(priced, value).status_code == 200
    assert auth_client.get("/v1/economy", headers=auth).json()["balance"] == before["balance"]


def test_livery_requires_unlock_independently_of_parts(auth_app, auth_client, sign_in):
    from bmt_backend.vehicle_appearance import CATALOG

    signed = sign_in(analytics=False)
    auth = {"Authorization": "Bearer " + signed["access_token"]}
    value = appearance(pattern=CATALOG["patterns"][-1])
    response = auth_client.put(
        "/v1/me/appearances", headers=auth, json={"appearance": value, "previous": None}
    )
    assert response.status_code == 403
    with auth_app.state.session_factory() as session:
        session.add(
            CosmeticUnlock(
                player_id=signed["player"]["id"], item_id="livery/" + value["livery"]["pattern"], price=500
            )
        )
        session.commit()
    assert (
        auth_client.put(
            "/v1/me/appearances", headers=auth, json={"appearance": value, "previous": None}
        ).status_code
        == 200
    )


def test_production_public_configuration_remains_available(service):
    _app, client = service()
    response = client.get("/v1/game-config?platform=android&build_id=test")
    assert response.status_code == 200, response.text
    assert response.json()["settings"]["ads.permitted"] is False


def test_production_no_ad_proof_never_grants_a_preview(auth_app, auth_client, sign_in):
    signed = sign_in(analytics=False)
    auth_app.state.settings = replace(
        auth_app.state.settings,
        environment="production",
        studio_legacy_keys_enabled=False,
        temporary_ad_resumes_enabled=False,
    )
    auth = {"Authorization": "Bearer " + signed["access_token"]}
    assert auth_client.get("/v1/resumes", headers=auth).json()["ad_preview_available"] is False
    race = auth_client.post(
        "/v1/resume-races", headers={**auth, "Idempotency-Key": str(uuid4())}, json={}
    ).json()
    url = "/v1/resume-races/" + race["race_id"] + "/resumes"
    one = {"ordinal": 1, "input_offset": 120, "from_tick": 120, "to_tick": 0}
    assert (
        auth_client.post(url, headers={**auth, "Idempotency-Key": str(uuid4())}, json=one).status_code == 200
    )
    two = {**one, "ordinal": 2, "input_offset": 240}
    assert (
        auth_client.post(url, headers={**auth, "Idempotency-Key": str(uuid4())}, json=two).status_code == 409
    )
    with auth_app.state.session_factory() as session:
        assert list(session.scalars(select(ResumeReceipt.source))) == ["daily"]


def scope(peer="192.0.2.1"):
    return {
        "type": "http",
        "asgi": {"version": "3.0"},
        "http_version": "1.1",
        "method": "POST",
        "scheme": "http",
        "path": "/v1/auth/google/challenge",
        "raw_path": b"/v1/auth/google/challenge",
        "root_path": "",
        "query_string": b"",
        "headers": [(b"content-type", b"application/json"), (b"content-length", b"2")],
        "client": (peer, 4000),
        "server": ("localhost", 80),
    }


def test_small_receiver_caps_release_on_cancellation_and_keep_health_available(auth_app, auth_client):
    async def run():
        reached = [asyncio.Event(), asyncio.Event()]
        release = asyncio.Event()

        async def held(index):
            reached[index].set()
            await release.wait()
            return {"type": "http.request", "body": b"{}", "more_body": False}

        async def discard(_message):
            pass

        tasks = [asyncio.create_task(auth_app(scope(), lambda i=i: held(i), discard)) for i in range(2)]
        try:
            await asyncio.wait_for(asyncio.gather(*(v.wait() for v in reached)), 3)
            responses = []

            async def forbidden():
                return {"type": "http.request", "body": b"{", "more_body": True}

            async def capture(message):
                responses.append(message)

            await auth_app(scope(), forbidden, capture)
            start = next(m for m in responses if m["type"] == "http.response.start")
            assert start["status"] == 503 and (b"connection", b"close") in start["headers"]
            assert auth_client.get("/healthz").status_code == 200
        finally:
            tasks[0].cancel()
            await asyncio.gather(tasks[0], return_exceptions=True)
            release.set()
            await tasks[1]
        accepted = auth_client.post("/v1/auth/google/challenge", json={})
        assert accepted.status_code == 201

    asyncio.run(run())


def test_control_deadline_closes_connection_and_frees_receiver(auth_app, monkeypatch):
    monkeypatch.setattr("bmt_backend.middleware.CONTROL_BODY_STALL_SECONDS", 0.02)

    async def run():
        messages = []

        async def receive():
            await asyncio.Event().wait()

        async def send(message):
            messages.append(message)

        await asyncio.wait_for(auth_app(scope(), receive, send), 3)
        start = next(m for m in messages if m["type"] == "http.response.start")
        assert start["status"] == 408 and (b"connection", b"close") in start["headers"]

    asyncio.run(run())


def test_worker_children_receive_no_administration_credentials(monkeypatch):
    from bmt_backend import service_worker

    secrets = {
        "BMT_ADMIN_OWNER_KEY": "owner",
        "BMT_ADMIN_ANALYST_KEY": "analyst",
        "BMT_STUDIO_STAFF_SUBJECTS": "subjects",
        "BMT_STUDIO_MONITOR_SOURCE_TOKENS": "source",
        "BMT_STUDIO_MONITOR_WEBHOOK_KEY": "webhook",
        "BMT_STUDIO_MONITOR_WEBHOOK_URL": "https://private.fixture.invalid/secret",
        "BMT_API_DB_PASSWORD": "api",
        "BMT_ADMIN_DB_PASSWORD": "admin",
        "BMT_MIGRATOR_DB_PASSWORD": "migrator",
    }
    for key, value in secrets.items():
        monkeypatch.setenv(key, value)
    monkeypatch.setenv("BMT_DATABASE_URL", "worker-only-url")
    captured = {}
    monkeypatch.setattr(service_worker.subprocess, "Popen", lambda command, **kw: captured.update(kw))
    service_worker._spawn("worker", ["python", "worker"])
    env = captured["env"]
    assert not (secrets.keys() & env.keys())
    assert env["BMT_WORKLOAD_ROLE"] == "worker" and env["BMT_DATABASE_URL"] == "worker-only-url"


def test_control_total_deadline_limits_a_sender_that_keeps_dripping(auth_app, monkeypatch):
    monkeypatch.setattr("bmt_backend.middleware.CONTROL_BODY_SECONDS", 0.04)
    monkeypatch.setattr("bmt_backend.middleware.CONTROL_BODY_STALL_SECONDS", 0.03)

    async def run():
        messages = []

        async def receive():
            await asyncio.sleep(0.01)
            return {"type": "http.request", "body": b" ", "more_body": True}

        async def send(message):
            messages.append(message)

        request_scope = scope()
        request_scope["headers"] = [(b"content-type", b"application/json"), (b"content-length", b"1000")]
        await asyncio.wait_for(auth_app(request_scope, receive, send), 3)
        assert next(m for m in messages if m["type"] == "http.response.start")["status"] == 408

    asyncio.run(run())


def test_migration_grandfathers_only_server_stored_selections(tmp_path):
    from alembic import command
    from sqlalchemy.orm import Session

    from bmt_backend.db import make_engine
    from bmt_backend.identity_models import Player
    from bmt_backend.migrate import configuration

    engine = make_engine("sqlite:///" + (tmp_path / "cutover.sqlite").as_posix())
    try:
        command.upgrade(configuration(engine), "0060_game_configuration")
        value = appearance(pattern="offset_gt")
        value["customisation"]["body"] = "wide"
        with Session(engine) as db:
            old = Player(display_name="Before cutover", vehicle_appearances={"compact": value})
            deleted = Player(display_name="Deleted", deleted_at=1, vehicle_appearances={"compact": value})
            clean = Player(display_name="Clean")
            db.add_all([old, deleted, clean])
            db.flush()
            old_id, deleted_id, clean_id = old.id, deleted.id, clean.id
            db.add(CosmeticUnlock(player_id=old.id, item_id="livery/offset_gt", price=500))
            db.commit()
        upgrade(engine)
        upgrade(engine)
        with Session(engine) as db:
            rows = list(db.scalars(select(CosmeticUnlock)))
            assert {(r.player_id, r.item_id, r.price) for r in rows} == {
                (old_id, "livery/offset_gt", 500),
                (old_id, "kit/compact/body/wide", 0),
            }
            assert not any(r.player_id in (deleted_id, clean_id) for r in rows)
            # A future appearance arriving after cutover cannot create a grant.
            db.get(Player, clean_id).vehicle_appearances = {"compact": value}
            db.commit()
        upgrade(engine)
        with Session(engine) as db:
            assert not list(db.scalars(select(CosmeticUnlock).where(CosmeticUnlock.player_id == clean_id)))
    finally:
        engine.dispose()
