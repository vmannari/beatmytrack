"""Offline diagnostics: assertions describe observed vulnerabilities, not desired behavior.

No live host is targeted. Identity signatures and game geometry compilation are
substituted, while request admission, bearer sessions, SQL and storage are real.
"""
import asyncio
import os
import secrets
import threading
from dataclasses import replace
from pathlib import Path
from types import SimpleNamespace
from uuid import uuid4

import httpx
import pytest
from bmt_backend.app import create_app
from bmt_backend.commerce_models import Entitlements
from bmt_backend.config import Settings
from bmt_backend.discovery import DiscoverySnapshot
from bmt_backend.maintenance import cleanup, retain
from bmt_backend.migrate import upgrade
from bmt_backend.publication_models import PublicationIntent
from bmt_backend.publications import CONTRACT_FIELDS, process_one
from bmt_backend.track_models import QueueCapacity, Track, TrackVersion, now
from fastapi import HTTPException
from fastapi.testclient import TestClient
from sqlalchemy import func, select
from test_domains import FakeVerifier


class OfflineIdentity:
    def __init__(self):
        self.claims = {}

    def verify(self, token):
        if token not in self.claims:
            raise HTTPException(401, "INVALID_GOOGLE_TOKEN")
        return self.claims[token]


@pytest.fixture
def audit(tmp_path):
    settings = Settings(database_url=f"sqlite:///{(tmp_path / 'audit.sqlite').as_posix()}",
                        object_dir=str(tmp_path / "objects"), google_client_ids=("offline-client",))
    identity = OfflineIdentity()
    app = create_app(settings, identity_verifier=identity, verifier=FakeVerifier())
    upgrade(app.state.engine)
    with TestClient(app) as client:
        challenge = client.post("/v1/auth/google/challenge").json()
        token = secrets.token_urlsafe(32)
        identity.claims[token] = {"sub": "offline-attacker", "nonce": challenge["nonce"]}
        login = client.post("/v1/auth/google", json={"id_token": token,
                            "challenge_id": challenge["challenge_id"], "display_name": "Offline attacker"})
        assert login.status_code == 200, login.text
        credentials = login.json()
        yield SimpleNamespace(app=app, client=client, factory=app.state.session_factory,
                              player_id=credentials["player"]["id"],
                              auth={"Authorization": "Bearer " + credentials["access_token"]})
    app.state.engine.dispose()


@pytest.mark.parametrize("credential", [None, "Bearer " + "x" * 43])
def test_unauthenticated_slow_uploads_block_authenticated_submissions(audit, credential):
    async def exercise():
        release = asyncio.Event()
        reached = [asyncio.Event(), asyncio.Event()]

        async def slow(index):
            headers = [(b"content-type", b"application/json"), (b"content-length", b"2")]
            if credential:
                headers.append((b"authorization", credential.encode()))
            scope = {"type": "http", "asgi": {"version": "3.0"}, "http_version": "1.1",
                     "method": "POST", "scheme": "http", "path": "/v1/runs", "raw_path": b"/v1/runs",
                     "query_string": b"", "root_path": "", "headers": headers,
                     "client": ("192.0.2.44", 4000 + index), "server": ("test", 80)}
            messages = []

            async def receive():
                reached[index].set()
                await release.wait()
                return {"type": "http.request", "body": b"{}", "more_body": False}

            async def send(message):
                messages.append(message)

            await audit.app(scope, receive, send)
            return next(item["status"] for item in messages if item["type"] == "http.response.start")

        attackers = [asyncio.create_task(slow(index)) for index in range(2)]
        payload = {"ticket_id": str(uuid4()), "replay": {"schema": "bmt-trajectory-v1",
                   "input_count": 6, "race_proof": {}}}
        try:
            await asyncio.wait_for(asyncio.gather(*(item.wait() for item in reached)), 3)
            async with httpx.AsyncClient(transport=httpx.ASGITransport(app=audit.app),
                                         base_url="http://test") as client:
                blocked = await client.post("/v1/runs", json=payload, headers=audit.auth)
                assert blocked.status_code == 503
                assert blocked.json()["detail"] == "REQUEST_VALIDATION_BUSY"
        finally:
            release.set()
            finished = await asyncio.wait_for(asyncio.gather(*attackers), 3)
        assert finished == [401, 401]
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=audit.app),
                                     base_url="http://test") as client:
            recovered = await client.post("/v1/runs", json=payload,
                                           headers={**audit.auth, "Idempotency-Key": str(uuid4())})
            assert recovered.status_code == 404  # Handler is reached once the slots release.
            assert recovered.json()["detail"] == "Run ticket not found"

    asyncio.run(exercise())


@pytest.mark.parametrize("method", ["GET", "HEAD", "DELETE", "OPTIONS"])
def test_unsupported_methods_bypass_global_parser_concurrency(audit, monkeypatch, method):
    from bmt_backend.middleware import parse_body
    release, all_started = threading.Event(), threading.Event()
    lock, state = threading.Lock(), {"live": 0, "peak": 0}

    def held_parser(raw):
        with lock:
            state["live"] += 1
            state["peak"] = max(state["peak"], state["live"])
            if state["live"] == 4:
                all_started.set()
        try:
            assert release.wait(5), "Diagnostic parser barrier timed out"
            return parse_body(raw)
        finally:
            with lock:
                state["live"] -= 1

    monkeypatch.setattr("bmt_backend.middleware.parse_body", held_parser)

    async def exercise():
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=audit.app),
                                     base_url="http://test") as client:
            tasks = [asyncio.create_task(client.request(method, "/v1/publications",
                       json={"padding": "x" * 50000})) for _ in range(4)]
            try:
                assert await asyncio.to_thread(all_started.wait, 3)
                assert state["peak"] == 4 > audit.app.state.settings.upload_concurrency
            finally:
                release.set()
            replies = await asyncio.wait_for(asyncio.gather(*tasks), 3)
            assert [reply.status_code for reply in replies] == [405] * 4

    asyncio.run(exercise())


def publication_body(audit, index):
    document = {"schema": "creator-track-v5", "id": "offline_" + str(index),
                "name": "Offline invalid publication", "shape": "oval"}
    manifest = audit.app.state.verifier.validate_track(document)
    manifest["config_hash"] = manifest["vehicles"]["compact"]["config_hash"]
    document.update(invalid=True, padding=secrets.token_hex(8000))
    return {"name": document["name"], "document": document, "vehicle_id": "compact",
            "contract": {field: manifest[field] for field in CONTRACT_FIELDS},
            "replay": {"schema": "bmt-trajectory-v1", "input_count": 6,
                       "race_proof": {"schema": "bmt-race-path-v1",
                                      "samples": [[0, index, 0, 0], [6, index, 0, 0]]}}}


def test_rejected_publication_blobs_survive_retention_and_do_not_consume_slots(audit):
    hashes = set()
    for index in range(3):
        response = audit.client.post("/v1/publications", json=publication_body(audit, index),
                                    headers={**audit.auth, "Idempotency-Key": str(uuid4())})
        assert response.status_code == 202, response.text
        assert process_one(audit.app)
        with audit.factory() as session:
            row = session.get(PublicationIntent, response.json()["publication_id"])
            assert row.status == "failed" and row.failure_code == "invalid_creator_proof"
            assert row.receipt is None
            hashes.update((row.content_hash, row.replay_hash))
            row.created_at = row.finished_at = now() - 120 * 86400
            session.commit()
    for digest in hashes:
        path = Path(audit.app.state.settings.object_dir) / digest[:2] / (digest + ".json")
        os.utime(path, (now() - 120 * 86400, now() - 120 * 86400))
    # All local writers have stopped before the isolated offline cleanup applies.
    cleanup(audit.factory)
    report = retain(audit.factory, audit.app.state.blobs, 90, apply=True, offline=True)
    assert report["orphaned_objects"] == 0
    with audit.factory() as session:
        assert session.scalar(select(func.count()).select_from(PublicationIntent)) == 3
        assert session.get(Entitlements, audit.player_id).slots == 1
        assert session.get(QueueCapacity, 1).pending == 0
    for digest in hashes:
        assert audit.app.state.blobs.get_json(digest)


def test_anonymous_fresh_discovery_persists_duplicate_catalogue_snapshots(audit):
    with audit.factory() as session:
        for index in range(12):
            track = Track(owner_id=audit.player_id)
            session.add(track)
            session.flush()
            session.add(TrackVersion(track_id=track.id, number=1, name="Offline route " + str(index),
                        content_hash="f" * 64, manifest={"laps": 5}, state="published",
                        published_at=now() - 1, discovery={"theme": "pine"}))
        session.commit()
    snapshots = []
    for _ in range(3):
        response = audit.client.post("/v1/discovery/tracks", json={"fresh": True})
        assert response.status_code == 200, response.text
        assert response.json()["total"] == 12
        snapshots.append(response.json()["snapshot"])
    assert len(set(snapshots)) == 3
    with audit.factory() as session:
        rows = session.scalars(select(DiscoverySnapshot)).all()
        assert len(rows) == 3
        assert all(len(row.version_ids) == 12 for row in rows)
        assert rows[0].version_ids == rows[1].version_ids == rows[2].version_ids


def test_player_credentials_do_not_grant_admin_or_development_authority(audit):
    audit.app.state.settings = replace(audit.app.state.settings, admin_owner_key="o" * 40)
    for url in ("/v1/admin/overview", "/v1/admin/entities/players", "/v1/admin/publications"):
        assert audit.client.get(url, headers=audit.auth).status_code == 401
    assert audit.client.post("/v1/auth/developer", headers={"X-Dev-Auth-Key": "o" * 40}).status_code == 404
    denied = audit.client.get("/v1/development/purchases", headers=audit.auth)
    assert denied.status_code == 403 and denied.json()["detail"] == "PURCHASE_SIMULATION_DISABLED"


@pytest.mark.parametrize("raw", [
    b'{"display_name":"a","display_name":"b"}',
    b'{"display_name":1e400}', b'{"display_name":"\\ud800"}',
    b'{"display_name":NaN}', b'[' * 33 + b'0' + b']' * 33,
])
def test_malformed_json_is_rejected_without_echoing_payload(audit, raw):
    response = audit.client.patch("/v1/me", content=raw,
                                  headers={**audit.auth, "Content-Type": "application/json"})
    assert response.status_code == 400
    assert response.json()["detail"] == "INVALID_JSON"
    assert set(response.json()) == {"detail", "request_id"}
    assert response.headers["x-request-id"] == response.json()["request_id"]


def test_cross_player_private_access_is_denied(audit):
    from bmt_backend.identity_models import Player
    from bmt_backend.track_models import Board, Run, RunTicket
    with audit.factory() as session:
        victim = Player(display_name="Offline victim")
        session.add(victim)
        session.flush()
        track = Track(owner_id=victim.id)
        session.add(track)
        session.flush()
        version = TrackVersion(track_id=track.id, number=1, name="Private route",
                               content_hash="f" * 64, manifest={"laps": 5}, state="draft")
        session.add(version)
        session.flush()
        board = Board(id="e" * 64, version_id=version.id, vehicle_id="compact", manifest={"laps": 5})
        session.add(board)
        session.flush()
        ticket = RunTicket(player_id=victim.id, board_id=board.id, expires_at=now() + 600)
        session.add(ticket)
        session.flush()
        run = Run(ticket_id=ticket.id, player_id=victim.id, board_id=board.id,
                  replay_hash="d" * 64, status="queued")
        intent = PublicationIntent(player_id=victim.id, operation_key=str(uuid4()), request_hash="c" * 64,
                    authoring_id="victim", name="Private publication", content_hash="f" * 64,
                    replay_hash="d" * 64, vehicle_id="compact", contract={})
        session.add_all((run, intent))
        session.commit()
        private_urls = ("/v1/runs/" + run.id, "/v1/me/publications/" + intent.id,
                        "/v1/me/track-versions/" + version.id + "/document",
                        "/v1/track-versions/" + version.id + "/document")
    for url in private_urls:
        assert audit.client.get(url, headers=audit.auth).status_code == 404


def test_manufactured_plausible_trajectory_is_accepted_by_design():
    from bmt_backend.trajectory_verifier import check
    geometry = {"start": [0, -0.1, 0], "creator_start": [0, -0.1, 0],
                "extent": [20, 20], "maximum_speed": {"compact": 50}, "manifest": {},
                "gates": [[1, 0, -5, 0, 1, 0, -1, 1, 0],
                          [0, 1, -5, 1, 0, 0, 9, 11, 0],
                          [-1, 0, 5, 0, 1, 0, 9, 11, 0],
                          [0, -1, 0, 1, 0, 0, -1, 1, 0]]}
    samples = [[0, 0, -0.1, 0]]
    tick, x, y = 0, 0.0, -0.1
    for _ in range(5):
        for target_x, target_y in ((10, -0.1), (10, 10), (0, 10), (0, -0.1)):
            original_x, original_y = x, y
            for step in range(1, 11):
                tick += 6
                x = original_x + (target_x - original_x) * step / 10
                y = original_y + (target_y - original_y) * step / 10
                samples.append([tick, x, y, 0])
    result = check(geometry, {"schema": "bmt-race-path-v1", "samples": samples}, tick, "compact")
    assert result["time_ticks"] == 1200 and result["lap_ticks"] == [240] * 5
    assert result["verification_method"] == "trajectory-v1"


def test_every_admin_get_route_requires_admin_credentials(audit):
    import re

    from fastapi.routing import iter_route_contexts
    checked = 0
    for context in iter_route_contexts(audit.app.router.routes):
        if not context.path.startswith("/v1/admin/") or "GET" not in context.original_route.methods:
            continue
        target = re.sub(r"\{[^}]+\}", str(uuid4()), context.path)
        response = audit.client.get(target, headers=audit.auth)
        assert response.status_code == 401, (context.path, response.status_code, response.text)
        checked += 1
    assert checked == 26  # All GET routes in this recorded application snapshot.
