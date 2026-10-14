"""H2-H4: real upload bounds, pre-auth admission and trusted proxy identity."""
import asyncio
import gzip
from dataclasses import replace

import httpx
import pytest
from fastapi.responses import JSONResponse
from fastapi.testclient import TestClient
from sqlalchemy import event, select
from test_domains import domain as domain_fixture
from test_domains import headers
from test_gcp_staging import config as cloud_config
from test_gcp_staging import staging
from test_publication_intents import body
from test_publication_intents import publications as publications_fixture

from bmt_backend.app import create_app
from bmt_backend.client_address import ClientAddress
from bmt_backend.config import Settings
from bmt_backend.identity_models import Player
from bmt_backend.middleware import RequestBoundary
from bmt_backend.storage import canonical_json

domain = domain_fixture
publications = publications_fixture


@pytest.mark.parametrize("compressed", [False, True])
def test_publication_larger_than_old_control_limit_is_durable(publications, compressed):
    content = body(publications)
    samples = [[tick, 1.23456789, 2.34567891, 0] for tick in range(0, 12001, 6)]
    content["replay"]["input_count"] = 12000
    content["replay"]["race_proof"]["samples"] = samples
    raw = canonical_json(content)
    assert 32768 < len(raw) < 8 * 1024 * 1024
    request_headers = {**headers(publications), "Content-Type": "application/json"}
    if compressed:
        request_headers["Content-Encoding"] = "gzip"
    response = publications.client.post("/v1/publications", content=gzip.compress(raw) if compressed else raw,
                                        headers=request_headers)
    assert response.status_code == 202, response.text
    identity = response.json()["publication_id"]
    status = publications.client.get("/v1/me/publications/" + identity, headers=headers(publications))
    assert status.status_code == 200 and status.json()["state"] == "queued"


@pytest.mark.parametrize("compressed", [False, True])
def test_publication_over_global_limit_is_rejected(auth_client, compressed):
    raw = b'{"document":"' + b"x" * (8 * 1024 * 1024) + b'"}'
    request_headers = {"Content-Type": "application/json"}
    if compressed:
        request_headers["Content-Encoding"] = "gzip"
    response = auth_client.post("/v1/publications", content=gzip.compress(raw) if compressed else raw,
                                headers=request_headers)
    assert response.status_code == 413 and response.json()["detail"] == "PAYLOAD_TOO_LARGE"


def test_publication_upload_slots_cover_handler_lifetime(auth_app, monkeypatch):
    monkeypatch.setattr("bmt_backend.middleware.check_budget", lambda *_a, **_kw: True)

    async def exercise():
        release, started = asyncio.Event(), asyncio.Event()
        live = [0]

        async def handler(scope, receive, send):
            assert "bounded_json" in scope["state"]
            live[0] += 1
            if live[0] == 2:
                started.set()
            await release.wait()
            live[0] -= 1
            await JSONResponse({"ok": True})(scope, receive, send)

        boundary = RequestBoundary(handler, replace(auth_app.state.settings, upload_concurrency=2),
                                   auth_app.state.session_factory)
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=boundary), base_url="http://test") as client:
            first = asyncio.create_task(client.post("/v1/publications", json={"document": "x" * 50000}))
            second = asyncio.create_task(client.post("/v1/publications", json={"document": "x" * 50000}))
            try:
                await asyncio.wait_for(started.wait(), 2)
                busy = await client.post("/v1/publications", json={"document": "x" * 50000})
                assert busy.status_code == 503 and busy.json()["detail"] == "REQUEST_VALIDATION_BUSY"
                assert live[0] == 2
            finally:
                release.set()
            assert [reply.status_code for reply in await asyncio.gather(first, second)] == [200, 200]
            assert (await client.post("/v1/publications", json={})).status_code == 200

    asyncio.run(exercise())


def test_exhausted_unknown_credential_budget_precedes_authentication(auth_app):
    app = create_app(replace(auth_app.state.settings, pre_auth_limit_per_minute=1), engine=auth_app.state.engine)
    queries = []

    def collect(_connection, _cursor, statement, _parameters, _context, _many):
        queries.append(statement.lower())

    event.listen(app.state.engine, "before_cursor_execute", collect)
    try:
        with TestClient(app) as client:
            assert client.get("/v1/me", headers={"Authorization": "Bearer " + "a" * 64}).status_code == 401
            queries.clear()
            assert client.get("/v1/me", headers={"Authorization": "Bearer " + "b" * 64}).status_code == 429
            assert not any("session_tokens" in sql for sql in queries)
            queries.clear()
            assert client.get("/v1/me", headers={"Authorization": "Bearer " + "c" * 64}).status_code == 429
            assert queries == []  # Even the exhausted peer's DB counter is now cached.
    finally:
        event.remove(app.state.engine, "before_cursor_execute", collect)


def test_admission_hint_never_caches_authentication_or_revocation(auth_app, auth_client, sign_in):
    credentials = sign_in("admission-fixture")
    request_headers = {"Authorization": "Bearer " + credentials["access_token"]}
    assert auth_client.get("/v1/me", headers=request_headers).status_code == 200
    with auth_app.state.session_factory() as session:
        player = session.scalar(select(Player).where(Player.id == credentials["player"]["id"]))
        player.disabled = True
        session.commit()
    assert auth_client.get("/v1/me", headers=request_headers).status_code == 401


def test_invalid_credential_denial_is_peer_scoped_and_does_not_block_a_valid_cold_user(auth_app, sign_in):
    credentials = sign_in("cold-after-denial")
    app = create_app(replace(auth_app.state.settings, rate_limit_per_minute=1), engine=auth_app.state.engine)

    async def exercise():
        garbage = {"Authorization": "Bearer " + "x" * 64}
        first = httpx.ASGITransport(app=app, client=("192.0.2.10", 1000))
        second = httpx.ASGITransport(app=app, client=("192.0.2.20", 1000))
        async with httpx.AsyncClient(transport=first, base_url="http://test") as a:
            assert (await a.get("/v1/bootstrap", headers=garbage)).status_code == 200
            assert (await a.get("/v1/bootstrap", headers=garbage)).status_code == 429
            assert (await a.get("/v1/me", headers={"Authorization": "Bearer " + credentials["access_token"]})).status_code == 200
        async with httpx.AsyncClient(transport=second, base_url="http://test") as b:
            assert (await b.get("/v1/bootstrap", headers=garbage)).status_code == 200

    asyncio.run(exercise())


def test_peer_denial_expires_at_the_next_budget_window(auth_app, monkeypatch):
    boundary = RequestBoundary(None, auth_app.state.settings, auth_app.state.session_factory)
    epoch = [1900000000]
    monkeypatch.setattr("bmt_backend.middleware.time.time", lambda: epoch[0])

    async def exercise():
        assert await boundary.peer_budget("192.0.2.30", "credential_admission", 1)
        assert not await boundary.peer_budget("192.0.2.30", "credential_admission", 1)
        epoch[0] += 60
        assert await boundary.peer_budget("192.0.2.30", "credential_admission", 1)

    asyncio.run(exercise())


def test_trusted_proxy_clients_have_independent_auth_limits(auth_app):
    app = create_app(replace(auth_app.state.settings, auth_limit_per_minute=2,
                             trusted_proxy_networks=("10.0.0.9/32",)), engine=auth_app.state.engine)

    async def exercise():
        transport = httpx.ASGITransport(app=app, client=("10.0.0.9", 12345))
        async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
            first = {"X-Forwarded-For": "198.51.100.200, 192.0.2.10"}
            second = {"X-Forwarded-For": "198.51.100.200, 192.0.2.20"}
            assert [(await client.post("/v1/auth/google/challenge", headers=first)).status_code
                    for _ in range(3)] == [201, 201, 429]
            assert (await client.post("/v1/auth/google/challenge", headers=second)).status_code == 201

    asyncio.run(exercise())


@pytest.mark.parametrize("peer,header,networks,expected", [
    ("192.0.2.8", "203.0.113.9", (), "192.0.2.8"),
    ("192.0.2.8", "203.0.113.9", ("10.0.0.0/24",), "192.0.2.8"),
    ("10.0.0.9", "198.51.100.88, 192.0.2.10", ("10.0.0.9/32",), "192.0.2.10"),
    ("10.0.0.9", "198.51.100.88, 192.0.2.10, 10.0.0.8", ("10.0.0.0/24",), "192.0.2.10"),
    ("10.0.0.9", "malicious-prefix, 192.0.2.10", ("10.0.0.9/32",), "192.0.2.10"),
    ("10.0.0.9", "malformed", ("10.0.0.9/32",), "10.0.0.9"),
    ("2001:db8:ffff::1", "192.0.2.99, 2001:db8:1::2", ("2001:db8:ffff::/64",), "2001:db8:1::2"),
    ("::ffff:10.0.0.9", "::ffff:192.0.2.10", ("10.0.0.9/32",), "192.0.2.10"),
])
def test_only_trusted_chain_suffix_sets_identity(peer, header, networks, expected):
    scope = {"client": (peer, 12345), "headers": [(b"x-forwarded-for", header.encode())]}
    assert ClientAddress(networks).resolve(scope) == expected


@pytest.mark.parametrize("networks", [("*",), ("0.0.0.0/0",), ("::/0",), ("0.0.0.0/1", "128.0.0.0/1")])
def test_internet_wide_proxy_trust_is_rejected(networks):
    with pytest.raises(ValueError):
        Settings(trusted_proxy_networks=networks)


def test_cloud_run_plan_prepares_explicit_proxy_trust_without_weakening_server_command():
    config = cloud_config()
    environment = staging.environment(config, "api")
    assert environment["BMT_TRUSTED_PROXY_NETWORKS"] == "127.0.0.1/32,169.254.0.0/16"
    config["trusted_proxy_networks"] = ["10.0.0.9/32", "2001:db8:ffff::/64"]
    assert staging.environment(config, "api")["BMT_TRUSTED_PROXY_NETWORKS"] == "10.0.0.9/32,2001:db8:ffff::/64"
    assert "BMT_TRUSTED_PROXY_NETWORKS" not in staging.environment(config, "worker")


@pytest.mark.parametrize("networks", [["*"], ["0.0.0.0/0"], ["0.0.0.0/1", "128.0.0.0/1"]])
def test_deployment_plan_rejects_internet_wide_proxy_trust(networks):
    config = cloud_config()
    config["trusted_proxy_networks"] = networks
    with pytest.raises(ValueError):
        staging.environment(config, "api")
