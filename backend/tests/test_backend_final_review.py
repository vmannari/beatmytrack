"""Final combined-source checks for expiry and interrupted authenticated uploads."""
import asyncio
import threading
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace
from types import SimpleNamespace
from uuid import uuid4

import httpx
import pytest
from sqlalchemy import func, select, update
from test_attack_resistance import catalogue as catalogue_fixture
from test_attack_resistance import domain as domain_fixture
from test_attack_resistance import isolated_scope, query
from test_auth_postgres import google_request, postgres_auth  # noqa: F401
from test_domains import FakeVerifier
from test_privacy import auth, deletion_body, drain
from test_publication_intents import body

from bmt_backend import discovery
from bmt_backend.identity_models import SessionFamily
from bmt_backend.publication_models import PublicationIntent, PublicationUpload
from bmt_backend.track_models import Track

domain = domain_fixture
catalogue = catalogue_fixture


@pytest.mark.parametrize("access", ["cached", "cursor", "restart"])
def test_discovery_reports_remaining_lifetime_of_reused_snapshot(catalogue, monkeypatch, access):
    epoch = 1_800_000_300
    monkeypatch.setattr(discovery, "time", SimpleNamespace(time=lambda: epoch))
    first = query(catalogue, fresh=True)
    assert first.status_code == 200
    assert first.json()["expires_in"] == 1800
    # Stay in the same 20-second refresh window to cover the RAM hint as well.
    monkeypatch.setattr(discovery, "time", SimpleNamespace(time=lambda: epoch + 15))
    values = {"fresh": True}
    if access == "cursor":
        values = {"cursor": first.json()["page_cursor"]}
    elif access == "restart":
        catalogue.app.state.discovery_memory.clear()
        catalogue.app.state.discovery_aliases.clear()
    response = query(catalogue, **values)
    assert response.status_code == 200
    assert response.json()["snapshot"] == first.json()["snapshot"]
    assert response.json()["expires_in"] == 1785
    monkeypatch.setattr(discovery, "time", SimpleNamespace(time=lambda: epoch + 1800))
    assert query(catalogue, cursor=first.json()["page_cursor"]).status_code == 410


def test_session_revoked_during_upload_cannot_reach_the_endpoint(auth_app, sign_in):
    signed = sign_in()
    async def exercise():
        messages = []
        async def receive():
            # Authentication succeeded before receive; invalidate it while the
            # admitted caller is still delivering its body.
            with auth_app.state.session_factory() as session:
                session.execute(update(SessionFamily).where(
                    SessionFamily.player_id == signed["player"]["id"]).values(revoked=True))
                session.commit()
            return {"type": "http.request", "body": b"{}", "more_body": False}
        async def send(message):
            messages.append(message)
        await auth_app(isolated_scope("/v1/runs", credential="Bearer " + signed["access_token"]), receive, send)
        assert next(message["status"] for message in messages if message["type"] == "http.response.start") == 401
    asyncio.run(exercise())


def test_postgres_real_publication_upload_is_fenced_by_account_deletion(postgres_auth, monkeypatch):  # noqa: F811
    app, client = postgres_auth
    app.state.verifier = FakeVerifier()
    app.state.settings = replace(app.state.settings, local_drafts_only=True)
    signed_response = client.post("/v1/auth/google", json=google_request(app, client, "final-upload-removal"))
    assert signed_response.status_code == 200
    signed = signed_response.json()
    reached, resume = threading.Event(), threading.Event()
    original = app.state.blobs.put_json
    calls = []
    def paused_put(data):
        calls.append(1)
        if len(calls) == 1:
            reached.set()
            assert resume.wait(10)
        return original(data)
    monkeypatch.setattr(app.state.blobs, "put_json", paused_put)
    key = str(uuid4())
    with ThreadPoolExecutor(max_workers=1) as pool:
        pending = pool.submit(client.post, "/v1/publications", json=body(SimpleNamespace(app=app)),
            headers={**auth(signed), "Idempotency-Key": key})
        try:
            assert reached.wait(10)
            with app.state.session_factory() as session:
                assert session.get(PublicationUpload, (signed["player"]["id"], key)) is not None
            removed = client.post("/v1/privacy/account-deletion", json=deletion_body(), headers=auth(signed))
            assert removed.status_code == 202, removed.text
        finally:
            resume.set()
        response = pending.result(15)
        assert response.status_code == 401 and response.json()["detail"] == "INVALID_SESSION"
    with app.state.session_factory() as session:
        assert session.scalar(select(func.count()).select_from(PublicationIntent)) == 0
        assert session.scalar(select(func.count()).select_from(Track)) == 0
    drain(app)
    with app.state.session_factory() as session:
        assert session.scalar(select(func.count()).select_from(PublicationUpload)) == 0


def test_cancelled_uploads_release_all_parser_slots(auth_app, sign_in):
    signed = sign_in()
    async def exercise():
        reached = [asyncio.Event(), asyncio.Event()]
        async def receive(index):
            reached[index].set()
            await asyncio.Event().wait()
        async def send(_message):
            pass
        tasks = [asyncio.create_task(auth_app(isolated_scope("/v1/runs",
            credential="Bearer " + signed["access_token"]),
            lambda index=index: receive(index), send)) for index in range(2)]
        try:
            await asyncio.wait_for(asyncio.gather(*(event.wait() for event in reached)), 5)
        finally:
            for task in tasks:
                task.cancel()
            results = await asyncio.gather(*tasks, return_exceptions=True)
            assert all(isinstance(result, asyncio.CancelledError) for result in results)
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=auth_app), base_url="http://test") as client:
            response = await client.post("/v1/runs", headers={"Authorization": "Bearer " + signed["access_token"],
                "Idempotency-Key": str(uuid4())}, json={"ticket_id": str(uuid4()),
                "replay": {"schema": "bmt-trajectory-v1", "input_count": 6, "race_proof": {}}})
            assert response.status_code == 404 and response.json()["detail"] == "Run ticket not found"
    asyncio.run(exercise())
