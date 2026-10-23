"""Public UGC: fresh consent, private blocks, exact reports and moderation effects."""
from dataclasses import replace
from uuid import uuid4

from sqlalchemy import func, select
from test_domains import FakeVerifier

from bmt_backend.community import TERMS_VERSION
from bmt_backend.community_models import CommunityAcceptance, PlayerBlock
from bmt_backend.studio_case_models import StudioCase, StudioCaseEvent
from bmt_backend.track_models import Track, TrackVersion, now


def auth(login):
    return {"Authorization": "Bearer " + login["access_token"], "Idempotency-Key": str(uuid4())}


def seed(app, player_id, name="Public loop"):
    document = {"schema": "creator-track-v5", "id": "fixture_" + uuid4().hex, "name": name,
                "shape": "oval", "points": [[0, 0], [20, 0], [20, 20], [0, 20]]}
    content_hash = app.state.blobs.put_json(document)
    with app.state.session_factory() as session:
        track = Track(owner_id=player_id)
        session.add(track)
        session.flush()
        version = TrackVersion(track_id=track.id, number=1, name=name, state="published",
            published_at=now()-1, content_hash=content_hash, manifest=FakeVerifier().validate_track(document),
            discovery={"theme": "pine", "points": document["points"]})
        session.add(version)
        session.commit()
        return track.id, version.id


def test_fresh_explicit_versioned_terms_before_any_upload(auth_app, auth_client, sign_in, monkeypatch):
    headers = auth(sign_in("Fresh publisher"))
    assert auth_client.get("/v1/community/terms", headers=headers).json()["accepted"] is False
    assert auth_client.post("/v1/community/terms", headers=headers,
        json={"version": TERMS_VERSION, "accepted": False}).status_code == 422
    assert auth_client.post("/v1/community/terms", headers=headers,
        json={"version": "old-version", "accepted": True}).status_code == 409

    def forbidden(*args):
        raise AssertionError("Unaccepted content must not reach storage")

    monkeypatch.setattr(auth_app.state.blobs, "put_json", forbidden)
    body = {"name": "Unaccepted", "document": {}, "vehicle_id": "compact", "contract": {}, "replay": {}}
    for _ in range(2):
        reply = auth_client.post("/v1/publications", headers=headers, json=body)
        assert reply.status_code == 403 and reply.json()["detail"] == "COMMUNITY_TERMS_REQUIRED"
    auth_app.state.settings = replace(auth_app.state.settings, local_drafts_only=False, environment="test", allow_sync_track_validation=True)
    legacy = auth_client.post("/v1/tracks", headers=headers, json={"name": "Unaccepted", "document": {}})
    assert legacy.status_code == 410 and legacy.json()["detail"].startswith("LOCAL_DRAFTS_ONLY")
    deferred = auth_client.post("/v1/tracks", headers=headers,
        json={"name": "Unaccepted", "document": {}, "defer_validation": True})
    assert deferred.status_code == 410 and deferred.json()["detail"].startswith("LOCAL_DRAFTS_ONLY")
    accepted = auth_client.post("/v1/community/terms", headers=headers,
        json={"version": TERMS_VERSION, "accepted": True})
    assert accepted.status_code == 200
    assert auth_client.post("/v1/community/terms", headers=headers,
        json={"version": TERMS_VERSION, "accepted": True}).json() == accepted.json()
    with auth_app.state.session_factory() as session:
        assert session.scalar(select(func.count()).select_from(CommunityAcceptance)) == 1
    assert auth_client.get("/v1/community/terms", headers=auth(sign_in("Fresh publisher"))).json()["accepted"]
    assert not auth_client.get("/v1/community/terms", headers=auth(sign_in("Other publisher"))).json()["accepted"]
    public = auth_client.get("/community-rules")
    assert public.status_code == 200 and TERMS_VERSION in public.text and "moderation owner" in public.text
    monkeypatch.setattr("bmt_backend.community.TERMS_VERSION", "bmt-community-next-version")
    assert not auth_client.get("/v1/community/terms", headers=headers).json()["accepted"]
    assert auth_client.post("/v1/publications", headers=headers, json=body).status_code == 403


def test_blocks_recheck_catalog_snapshots_links_tickets_and_unblock(auth_app, auth_client, sign_in):
    author = sign_in("Public author")
    viewer = sign_in("Viewing racer")
    other = sign_in("Other viewer")
    headers = auth(viewer)
    track_id, version_id = seed(auth_app, author["player"]["id"])
    query = {"feed": "new"}
    before = auth_client.post("/v1/discovery/tracks", headers=headers, json=query).json()
    assert before["total"] == 1 and before["items"][0]["track_id"] == track_id
    path = "/v1/community/blocks/" + author["player"]["id"]
    assert auth_client.put(path).status_code == 401
    assert auth_client.put("/v1/community/blocks/" + viewer["player"]["id"], headers=headers).status_code == 422
    assert auth_client.put(path, headers=headers).json()["blocked"] is True
    assert auth_client.put(path, headers=headers).status_code == 200
    assert auth_client.get("/v1/community/blocks", headers=headers).json()["items"] == [
        {"player_id": author["player"]["id"], "display_name": "Public author"}]
    assert auth_client.get("/v1/community/blocks", headers=auth(other)).json()["items"] == []
    after = auth_client.post("/v1/discovery/tracks", headers=headers, json=query).json()
    assert after["total"] == 0 and after["items"] == []
    stale = auth_client.post("/v1/discovery/tracks", headers=headers,
        json={**query, "cursor": before["page_cursor"]})
    assert stale.status_code == 422
    assert auth_client.post("/v1/discovery/random", headers=headers, json=query).json()["items"] == []
    assert auth_client.get("/v1/tracks", headers=headers).json()["items"] == []
    for suffix in ("", "/document"):
        assert auth_client.get("/v1/track-versions/" + version_id + suffix, headers=headers).status_code == 403
        assert auth_client.get("/v1/track-versions/" + version_id + suffix, headers=auth(other)).status_code == 200
    ticket = auth_client.post("/v1/run-tickets", headers=headers,
        json={"version_id": version_id, "vehicle_id": "compact"})
    assert ticket.status_code == 403 and ticket.json()["detail"] == "PLAYER_BLOCKED"
    assert auth_client.delete(path, headers=headers).json()["blocked"] is False
    assert auth_client.delete(path, headers=headers).status_code == 200
    assert auth_client.post("/v1/discovery/tracks", headers=headers, json=query).json()["total"] == 1
    with auth_app.state.session_factory() as session:
        assert session.scalar(select(func.count()).select_from(PlayerBlock)) == 0


def test_report_exact_targets_retry_privacy_and_owner_quarantine(auth_app, auth_client, sign_in):
    auth_app.state.settings = replace(auth_app.state.settings, admin_owner_key="o"*40, admin_analyst_key="a"*40)
    author = sign_in("Reported author")
    reporter = sign_in("Reporting racer")
    other = sign_in("Unrelated racer")
    track, version = seed(auth_app, author["player"]["id"])
    payload = {"command_id": str(uuid4()), "reason": "harassment", "text": "Abusive track name and layout",
               "track_id": track, "version_id": version, "reported_player_id": author["player"]["id"]}
    headers = auth(reporter)
    response = auth_client.post("/v1/reports", headers=headers, json=payload)
    assert response.status_code == 200
    assert auth_client.post("/v1/reports", headers=headers, json=payload).json() == response.json()
    assert auth_client.post("/v1/reports", headers=headers,
        json={**payload, "text": "changed body"}).status_code == 409
    case_id = response.json()["id"]
    assert len(auth_client.get("/v1/reports", headers=headers).json()["items"]) == 1
    assert auth_client.get("/v1/reports", headers=auth(other)).json()["items"] == []
    owner_headers = {"Authorization": "Bearer " + "o"*40}
    case = auth_client.get("/v1/admin/cases/"+case_id, headers=owner_headers).json()
    assert case["case"]["player_id"] == reporter["player"]["id"]
    assert case["case"]["reported_player_id"] == author["player"]["id"]
    assert case["events"][0]["detail"]["version_id"] == version
    target_context = auth_client.get("/v1/admin/catalogue/players/"+author["player"]["id"], headers=owner_headers).json()
    assert target_context["activity"]["open_cases"] == 1 and target_context["cases"][0]["id"] == case_id
    command = {"command_id": str(uuid4()), "expected_revision": 0, "kind": "quarantine",
               "text": "Confirmed public harassment after manual review"}
    assert auth_client.post("/v1/admin/cases/"+case_id+"/events", headers={"Authorization": "Bearer " + "a"*40}, json=command).status_code == 403
    assert auth_client.post("/v1/admin/cases/"+case_id+"/events", headers=owner_headers, json=command).status_code == 200
    assert auth_client.get("/v1/track-versions/"+version).status_code == 404
    assert auth_client.get("/v1/track-versions/"+version+"/document").status_code == 404
    assert auth_client.post("/v1/run-tickets", headers=headers,
        json={"version_id": version, "vehicle_id": "compact"}).status_code == 404
    with auth_app.state.session_factory() as session:
        assert session.scalar(select(func.count()).select_from(StudioCase)) == 1
        assert session.scalar(select(func.count()).select_from(StudioCaseEvent)) == 2
    wrong_track, _ = seed(auth_app, other["player"]["id"])
    assert auth_client.post("/v1/reports", headers=headers,
        json={**payload, "command_id": str(uuid4()), "track_id": wrong_track}).status_code == 404
    assert auth_client.post("/v1/reports", headers=auth(author),
        json={"reported_player_id": author["player"]["id"], "reason": "harassment",
              "text": "Self profile report", "command_id": str(uuid4())}).status_code == 422
    assert auth_client.post("/v1/reports", headers=auth(author),
        json={**payload, "reason": "privacy", "command_id": str(uuid4())}).status_code == 200


def test_blocked_group_participants_cannot_join_or_start_new_races(auth_app, auth_client, sign_in):
    from bmt_backend.challenge_models import Challenge, ChallengeMember
    from bmt_backend.runs import board_manifest
    from bmt_backend.track_models import Board

    host, peer, incoming = [sign_in(name) for name in ("Group host", "Group peer", "Incoming racer")]
    _, version_id = seed(auth_app, host["player"]["id"])
    code = "A123456789ABCDEF"
    with auth_app.state.session_factory() as session:
        pinned = board_manifest(session.get(TrackVersion, version_id), "compact")
        board = Board(id=str(uuid4()), version_id=version_id, vehicle_id="compact", manifest=pinned)
        session.add(board)
        session.flush()
        challenge = Challenge(code=code, board_id=board.id, creator_id=host["player"]["id"], mode="group",
            ends_at=now()+3600, member_count=2)
        session.add(challenge)
        session.flush()
        for member in (host, peer):
            session.add(ChallengeMember(challenge_id=challenge.id, player_id=member["player"]["id"]))
        session.commit()
    incoming_headers = auth(incoming)
    path = "/v1/community/blocks/" + peer["player"]["id"]
    assert auth_client.put(path, headers=incoming_headers).status_code == 200
    joined = auth_client.post(f"/v1/challenges/{code}/join", headers=incoming_headers)
    assert joined.status_code == 403 and joined.json()["detail"] == "PLAYER_BLOCKED"
    assert auth_client.delete(path, headers=incoming_headers).status_code == 200
    assert auth_client.put("/v1/community/blocks/" + incoming["player"]["id"], headers=auth(peer)).status_code == 200
    assert auth_client.post(f"/v1/challenges/{code}/join", headers=incoming_headers).status_code == 403
    # A block also fences existing members' fresh tickets without erasing their membership/results.
    assert auth_client.put("/v1/community/blocks/" + host["player"]["id"], headers=auth(peer)).status_code == 200
    assert auth_client.post(f"/v1/challenges/{code}/tickets", headers=auth(peer)).status_code == 403
    assert auth_client.get(f"/v1/challenges/{code}", headers=auth(peer)).status_code == 403
    assert auth_client.get("/v1/challenges", headers=auth(peer)).json()["items"] == []
    assert auth_client.put("/v1/community/blocks/" + peer["player"]["id"], headers=auth(host)).status_code == 200
    assert auth_client.post(f"/v1/challenges/{code}/cancel", headers=auth(host)).status_code == 200
    with auth_app.state.session_factory() as session:
        assert session.scalar(select(func.count()).select_from(ChallengeMember)) == 2


def test_deletion_erases_private_safety_preferences(auth_app, auth_client, sign_in):
    from bmt_backend.privacy import cleanup_one

    owner, other = sign_in("Safety deletion"), sign_in("Retained player")
    headers = auth(owner)
    assert auth_client.post("/v1/community/terms", headers=headers,
        json={"version": TERMS_VERSION, "accepted": True}).status_code == 200
    assert auth_client.put("/v1/community/blocks/"+other["player"]["id"], headers=headers).status_code == 200
    assert auth_client.put("/v1/community/blocks/"+owner["player"]["id"], headers=auth(other)).status_code == 200
    assert auth_client.post("/v1/privacy/account-deletion", headers=headers,
        json={"confirmation": "DELETE", "request_id": str(uuid4())}).status_code == 202
    for _ in range(100):
        if not cleanup_one(auth_app):
            break
    with auth_app.state.session_factory() as session:
        assert session.scalar(select(func.count()).select_from(CommunityAcceptance)) == 0
        assert session.scalar(select(func.count()).select_from(PlayerBlock)) == 0
