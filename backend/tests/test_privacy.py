"""Real auth/SQL/files: erasure must keep public content and historical timing."""
import secrets
from dataclasses import replace
from uuid import uuid4

import pytest
from fastapi import HTTPException
from sqlalchemy import func, select, update
from test_domains import FakeVerifier

from bmt_backend.identity_models import BrowserLogin, Identity, Player, SessionToken
from bmt_backend.object_models import ObjectPin
from bmt_backend.privacy import EMPTY_HASH, REMOVED_NAME, cleanup_one
from bmt_backend.privacy_models import AccountDeletion
from bmt_backend.security import digest
from bmt_backend.track_models import Board, PersonalBest, Run, RunTicket, Track, TrackVersion, now


class RedactionVerifier(FakeVerifier):
    def validate_track(self, document):
        return {**super().validate_track(document), "track_content_hash": digest(str(document.get("creator")) + str(document.get("shape")))}


def deletion_body():
    return {"confirmation": "DELETE", "request_id": str(uuid4())}


def auth(signed):
    return {"Authorization": "Bearer " + signed["access_token"]}


def seed(app, signed):
    app.state.verifier = RedactionVerifier()
    doc = {"shape": "unchanged-geometry", "creator": signed["player"]["display_name"], "name": "Kept route"}
    original = app.state.blobs.put_json(doc)
    replay = app.state.blobs.put_json({"private": "fictional-driving-evidence"})
    with app.state.session_factory() as session:
        track = Track(owner_id=signed["player"]["id"])
        session.add(track); session.flush()
        version = TrackVersion(track_id=track.id, number=1, name="Kept route", content_hash=original,
            manifest=app.state.verifier.validate_track(doc), state="published", published_at=now(),
            discovery={"theme": "pine", "points": []})
        session.add(version); session.flush()
        board = Board(id=str(uuid4()), version_id=version.id, vehicle_id="compact", manifest=version.manifest)
        session.add(board); session.flush()
        ticket = RunTicket(player_id=signed["player"]["id"], board_id=board.id, expires_at=now()+300)
        session.add(ticket); session.flush()
        run = Run(player_id=ticket.player_id, ticket_id=ticket.id, board_id=board.id,
            replay_hash=replay, ghost_hash=replay, status="verified", time_ticks=600, lap_ticks=[120]*5, finished_at=now())
        session.add(run); session.flush()
        session.add(PersonalBest(board_id=board.id, player_id=ticket.player_id, run_id=run.id, time_ticks=600))
        session.commit()
        return version.id, board.id, run.id, original, replay, dict(version.manifest)


def drain(app):
    # Accelerate only fictional storage leases; production pins remain enforced.
    for _ in range(100):
        with app.state.session_factory() as session:
            session.execute(update(ObjectPin).values(expires_at=0))
            session.commit()
        if not cleanup_one(app):
            return
    raise AssertionError("Erasure failed to reach a stable complete state")


def test_deletion_preserves_public_route_and_exact_standings(auth_app, auth_client, sign_in):
    signed = sign_in("Removed creator")
    version, board, run_id, old, replay, manifest = seed(auth_app, signed)
    body = deletion_body()
    response = auth_client.post("/v1/privacy/account-deletion", json=body, headers=auth(signed))
    assert response.status_code == 202, response.text
    assert response.json()["tracks_retained"] and response.json()["standings_retained"]
    assert auth_client.get("/v1/me", headers=auth(signed)).status_code == 401
    assert auth_client.post("/v1/auth/refresh", json={"refresh_token": signed["refresh_token"]}).status_code == 401
    assert auth_client.get(f"/v1/track-versions/{version}").json()["creator"] == REMOVED_NAME
    assert auth_client.get(f"/v1/track-versions/{version}/document").status_code == 503
    assert auth_client.get(f"/v1/boards/{board}").json()["items"][0]["display_name"] == REMOVED_NAME
    drain(auth_app)
    document = auth_client.get(f"/v1/track-versions/{version}/document")
    assert document.status_code == 200 and document.json()["creator"] == REMOVED_NAME
    assert document.json()["shape"] == "unchanged-geometry"
    with auth_app.state.session_factory() as session:
        player = session.get(Player, signed["player"]["id"])
        assert player.deleted_at and player.username_key is None and player.country_code == ""
        assert session.scalar(select(func.count()).select_from(Identity)) == 0
        assert session.scalar(select(func.count()).select_from(SessionToken)) == 0
        retained = session.get(Run, run_id)
        assert retained.time_ticks == 600 and retained.lap_ticks == [120]*5
        assert retained.replay_hash == EMPTY_HASH and retained.ghost_hash is None
        assert session.get(TrackVersion, version).manifest == manifest
        assert session.get(AccountDeletion, player.id).completed_at
    assert not auth_app.state.blobs.store._path(old).exists()
    assert not auth_app.state.blobs.store._path(replay).exists()
    again = auth_client.post("/v1/privacy/account-deletion", json=body, headers=auth(signed))
    assert again.status_code == 202 and again.json()["status"] == "complete"
    fresh = sign_in("Removed creator")
    assert fresh["player"]["id"] != signed["player"]["id"]
    assert fresh["player"]["display_name"] == "Removed creator"


@pytest.mark.parametrize("body", [{}, {"confirmation": "KEEP", "request_id": str(uuid4())},
    {"confirmation": "DELETE", "request_id": "x"*36}, {"confirmation": "DELETE", "request_id": str(uuid4()), "player_id": "other"}])
def test_deletion_requires_exact_confirmation_and_operation(auth_client, sign_in, body):
    signed = sign_in()
    assert auth_client.post("/v1/privacy/account-deletion", json=body, headers=auth(signed)).status_code == 422
    assert auth_client.get("/v1/me", headers=auth(signed)).status_code == 200


def test_repeat_receipt_cannot_cross_accounts_or_requests(auth_client, sign_in):
    alice, bob = sign_in(), sign_in("bob")
    body = deletion_body()
    assert auth_client.post("/v1/privacy/account-deletion", json=body, headers=auth(alice)).status_code == 202
    assert auth_client.post("/v1/privacy/account-deletion", json=deletion_body(), headers=auth(alice)).status_code == 401
    assert auth_client.get("/v1/me", headers=auth(bob)).status_code == 200
    assert auth_client.post("/v1/privacy/account-deletion", json=body).status_code == 401


def test_preference_stops_client_and_server_analytics(auth_app, auth_client, sign_in):
    from test_product_analytics import body, observed

    from bmt_backend.telemetry import append_server_event
    from bmt_backend.telemetry_models import ProductEvent
    signed = sign_in()
    auth_app.state.settings = replace(auth_app.state.settings, telemetry_enabled=True)
    response = auth_client.post("/v1/privacy/preferences", json={"analytics_enabled": False}, headers=auth(signed))
    assert response.json() == {"analytics_enabled": False}
    assert auth_client.get("/v1/me", headers=auth(signed)).json()["analytics_enabled"] is False
    assert auth_client.post("/v1/telemetry/batches", json=body([observed("menu_ready")]), headers=auth(signed)).status_code == 403
    with auth_app.state.session_factory() as session:
        append_server_event(session, "race_accepted", str(uuid4()), signed["player"]["id"], {})
        session.commit()
        assert session.scalar(select(func.count()).select_from(ProductEvent)) == 0


def test_new_account_analytics_is_off_until_explicit_choice(auth_client, sign_in):
    signed = sign_in(analytics=False)
    assert signed["player"]["analytics_enabled"] is False
    assert auth_client.get("/v1/me", headers=auth(signed)).json()["analytics_enabled"] is False
    assert auth_client.post("/v1/privacy/preferences", headers=auth(signed), json={"analytics_enabled": True}).json()["analytics_enabled"] is True


def test_erasure_ledger_reapplies_to_an_offline_backup(auth_app, auth_client, sign_in, tmp_path):
    from bmt_backend.privacy import export_ledger, reapply_ledger
    signed = sign_in()
    assert auth_client.post("/v1/privacy/account-deletion", json=deletion_body(), headers=auth(signed)).status_code == 202
    ledger = tmp_path / "erasure.jsonl"
    export_ledger(auth_app.state.session_factory, ledger)
    assert signed["access_token"] not in ledger.read_text() and "alice" not in ledger.read_text()
    with auth_app.state.session_factory() as session:
        player = session.get(Player, signed["player"]["id"])
        player.deleted_at, player.display_name, player.needs_username = None, "Old backup name", False
        session.add(Identity(player_id=player.id, provider="google", subject="restored-subject"))
        session.commit()
    assert reapply_ledger(auth_app, ledger) == 1
    with auth_app.state.session_factory() as session:
        assert session.get(Player, signed["player"]["id"]).deleted_at
        assert session.scalar(select(func.count()).select_from(Identity)) == 0


def test_write_released_for_external_io_cannot_resurrect_account(auth_app, auth_client, sign_in):
    signed = sign_in()
    body = deletion_body()
    with auth_app.state.session_factory() as stale:
        stale.info["privacy_actor"] = signed["player"]["id"]
        stale.rollback()  # The upload releases its transaction before external IO.
        assert auth_client.post("/v1/privacy/account-deletion", json=body, headers=auth(signed)).status_code == 202
        stale.add(Identity(player_id=signed["player"]["id"], provider="google", subject="resurrected"))
        with pytest.raises(HTTPException, match="INVALID_SESSION"):
            stale.commit()
        stale.rollback()
    with auth_app.state.session_factory() as session:
        assert session.scalar(select(func.count()).select_from(Identity)) == 0


def web_login(app, client, subject):
    app.state.settings = replace(app.state.settings, google_web_client_id="test-client", public_base_url="https://game.example")
    started = client.post("/v1/auth/google/browser/start", json={}).json()
    token = secrets.token_urlsafe(32)
    with app.state.session_factory() as session:
        session.add(BrowserLogin(browser_hash=digest(secrets.token_urlsafe(32)), poll_hash=digest(token),
            nonce="fixture", display_name="", subject=subject, expires_at=now()+300))
        session.commit()
    assert "#" in started["browser_url"]
    return token


def test_web_deletion_never_creates_an_account(auth_app, auth_client, sign_in):
    token = web_login(auth_app, auth_client, "no-account")
    assert auth_client.post("/v1/privacy/web-session", json={"token": token}).status_code == 404
    with auth_app.state.session_factory() as session:
        assert session.scalar(select(func.count()).select_from(Player)) == 0
    signed = sign_in()
    token = web_login(auth_app, auth_client, "alice")
    assert auth_client.post("/v1/privacy/web-session", json={"token": token}).json()["status"] == "ready"
    body = {**deletion_body(), "token": token}
    assert auth_client.post("/v1/privacy/web-delete", json=body).status_code == 202
    assert auth_client.post("/v1/privacy/web-delete", json=body).status_code == 202
    assert auth_client.get("/v1/me", headers=auth(signed)).status_code == 401


def test_public_pages_are_accessible_escaped_and_cookie_free(auth_app, auth_client):
    auth_app.state.settings = replace(auth_app.state.settings, privacy_developer_name="<script>fixture</script>")
    policy = auth_client.get("/privacy")
    assert policy.status_code == 200 and "&lt;script&gt;fixture&lt;/script&gt;" in policy.text
    assert "placeholders" in policy.text and "Removed account" in policy.text
    assert "frame-ancestors 'none'" in policy.headers["content-security-policy"]
    assert "set-cookie" not in policy.headers
    assert auth_client.get("/account-deletion").status_code == 200
    assert auth_client.get("/privacy/deletion.js").status_code == 200


def test_storage_failure_does_not_complete_erasure(auth_app, auth_client, sign_in, monkeypatch):
    signed = sign_in()
    seed(auth_app, signed)
    assert auth_client.post("/v1/privacy/account-deletion", json=deletion_body(), headers=auth(signed)).status_code == 202
    monkeypatch.setattr(auth_app.state.blobs, "get_json", lambda _: (_ for _ in ()).throw(OSError("fictional unavailable storage")))
    with pytest.raises(OSError):
        for _ in range(100):
            with auth_app.state.session_factory() as session:
                session.execute(update(ObjectPin).values(expires_at=0)); session.commit()
            cleanup_one(auth_app)
    with auth_app.state.session_factory() as session:
        job = session.get(AccountDeletion, signed["player"]["id"])
        assert job.completed_at is None and job.next_attempt_at > now()


def test_later_racing_on_retained_tracks_cannot_recreate_removed_analytics(auth_app, auth_client, sign_in):
    from bmt_backend.product_analytics import project_pending
    from bmt_backend.telemetry import append_server_event
    from bmt_backend.telemetry_models import ProductProfile, ProductPublication
    removed, other = sign_in(), sign_in("other")
    assert auth_client.post("/v1/privacy/account-deletion", json=deletion_body(), headers=auth(removed)).status_code == 202
    drain(auth_app)
    version = str(uuid4())
    with auth_app.state.session_factory() as session:
        append_server_event(session, "race_accepted", str(uuid4()), other["player"]["id"],
            {"owner_id": removed["player"]["id"], "track_version": version, "published_at": now()})
        session.commit()
    project_pending(auth_app.state.session_factory)
    with auth_app.state.session_factory() as session:
        assert session.get(ProductProfile, removed["player"]["id"]) is None
        assert session.get(ProductPublication, version) is None


def test_shared_objects_and_active_leases_survive_cleanup(auth_app, auth_client, sign_in):
    alice, bob = sign_in(), sign_in("bob")
    _version, _board, _run, _old, replay, _manifest = seed(auth_app, alice)
    with auth_app.state.session_factory() as session:
        track = Track(owner_id=bob["player"]["id"])
        session.add(track); session.flush()
        session.add(TrackVersion(track_id=track.id, number=1, name="Shared content reference", content_hash=replay,
            manifest={}, state="draft"))
        session.commit()
    assert auth_client.post("/v1/privacy/account-deletion", json=deletion_body(), headers=auth(alice)).status_code == 202
    drain(auth_app)
    assert auth_app.state.blobs.store._path(replay).exists()


def test_recording_redaction_does_not_allow_future_token_issuance(auth_app, auth_client, sign_in):
    from bmt_backend.auth import issue_tokens
    from bmt_backend.identity_models import SessionFamily
    signed = sign_in()
    assert auth_client.post("/v1/privacy/account-deletion", json=deletion_body(), headers=auth(signed)).status_code == 202
    with auth_app.state.session_factory() as session:
        player = session.get(Player, signed["player"]["id"])
        with pytest.raises(HTTPException, match="ACCOUNT_REMOVED"):
            issue_tokens(session, SessionFamily(player_id=player.id, expires_at=now()+300), player, auth_app.state.settings)


def test_independent_journal_survives_without_primary_database(auth_app, auth_client, sign_in, tmp_path, monkeypatch):
    from bmt_backend.erasure_journal import export_journal
    signed = sign_in()
    assert auth_client.post("/v1/privacy/account-deletion", json=deletion_body(), headers=auth(signed)).status_code == 202
    monkeypatch.setattr(auth_app.state, "session_factory", lambda: (_ for _ in ()).throw(AssertionError("Primary database is unavailable")))
    ledger = tmp_path / "independent-ledger.jsonl"
    assert export_journal(auth_app.state.erasure_journal, ledger) == 1
    assert signed["player"]["id"] in ledger.read_text() and signed["access_token"] not in ledger.read_text()


def test_journal_failure_never_acknowledges_and_same_request_recovers(auth_app, auth_client, sign_in, monkeypatch):
    signed = sign_in()
    body = deletion_body()
    original = auth_app.state.erasure_journal.put_json
    monkeypatch.setattr(auth_app.state.erasure_journal, "put_json", lambda _: (_ for _ in ()).throw(OSError("fictional journal outage")))
    assert auth_client.post("/v1/privacy/account-deletion", json=body, headers=auth(signed)).status_code == 503
    assert auth_client.get("/v1/me", headers=auth(signed)).status_code == 401
    monkeypatch.setattr(auth_app.state.erasure_journal, "put_json", original)
    assert auth_client.post("/v1/privacy/account-deletion", json=body, headers=auth(signed)).status_code == 202
    with auth_app.state.session_factory() as session:
        assert session.get(AccountDeletion, signed["player"]["id"]).journal_written_at


def test_old_manifest_is_retained_while_source_is_redacted(auth_app, auth_client, sign_in):
    signed = sign_in()
    version, _board, _run, _old, _replay, manifest = seed(auth_app, signed)
    historical = {**manifest, "engine_version": "older-pinned-engine", "compiler_version": "older-pinned-compiler"}
    with auth_app.state.session_factory() as session:
        session.get(TrackVersion, version).manifest = historical
        session.commit()
    assert auth_client.post("/v1/privacy/account-deletion", json=deletion_body(), headers=auth(signed)).status_code == 202
    drain(auth_app)
    with auth_app.state.session_factory() as session:
        assert session.get(TrackVersion, version).manifest == historical
    assert auth_client.get(f"/v1/track-versions/{version}/document").json()["creator"] == REMOVED_NAME


def test_snapshot_redaction_keeps_track_titles_and_other_people():
    from bmt_backend.privacy import redact_snapshot
    value = {"creator_id": "removed", "creator": "Old name", "name": "Original track title",
        "entries": [{"id": "removed", "name": "Old name", "country_code": "FI", "ticks": 600},
                    {"id": "other", "name": "Other racer", "country_code": "SE", "ticks": 700}]}
    result = redact_snapshot(value, "removed")
    assert result["creator"] == REMOVED_NAME and result["name"] == "Original track title"
    assert result["entries"][0] == {"id": "removed", "name": REMOVED_NAME, "country_code": "", "ticks": 600}
    assert result["entries"][1] == value["entries"][1]
