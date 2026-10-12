"""Challenge authority, isolation, deadlines and durable best-only results."""
import json
import secrets
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace

import pytest
from sqlalchemy import select
from test_domains import FakeVerifier, headers, submit
from test_domains import domain as _domain_fixture
from test_rivalry import seed

from bmt_backend import challenges
from bmt_backend.challenge_models import Challenge, ChallengeMember, ChallengeTicket
from bmt_backend.identity_models import Player
from bmt_backend.track_models import Board, Run, Track, TrackVersion, now
from bmt_backend.worker import process_one

challenge_domain = _domain_fixture


class PosedVerifier(FakeVerifier):
    def verify_run(self, document, replay, vehicle_id, *, creator_test=False):
        proof = super().verify_run(document, replay, vehicle_id, creator_test=creator_test)
        ticks = proof["time_ticks"]
        proof["ghost"] = {"ticks": ticks, "poses": [[0, 0, 0, 0, 0, 0, 0], [ticks, 10, 10, 0, 0, 0, 0]]}
        return proof


def setup(domain):
    domain.app.state.verifier = PosedVerifier()
    version = seed(domain, 1)[0]
    return version


def normal_run(domain, version, player="Alice", frames=30):
    issued = domain.client.post("/v1/run-tickets", json={"version_id": version, "vehicle_id": "compact"},
                                headers=headers(domain, player)).json()
    run = submit(domain, issued, player, frames)
    assert process_one(domain.app)
    return run["run_id"]


def create(domain, version, player="Alice", mode="beat", run_id=None, key=None):
    body = {"version_id": version, "vehicle_id": "compact", "mode": mode}
    if run_id:
        body["source_run_id"] = run_id
    response = domain.client.post("/v1/challenges", json=body, headers=headers(domain, player, key))
    assert response.status_code == 201, response.text
    return response.json()


def join(domain, code, player="Bob", key=None):
    response = domain.client.post(f"/v1/challenges/{code}/join", headers=headers(domain, player, key))
    assert response.status_code == 200, response.text
    return response.json()


def attempt(domain, code, player="Bob", frames=20):
    issued = domain.client.post(f"/v1/challenges/{code}/tickets", headers=headers(domain, player))
    assert issued.status_code == 201, issued.text
    submitted = submit(domain, issued.json(), player, frames)
    assert process_one(domain.app)
    result = domain.client.get(f"/v1/challenge-results/{issued.json()['ticket_id']}", headers=headers(domain, player))
    assert result.status_code == 200, result.text
    return submitted, result.json()


def test_create_requires_owned_verified_compatible_result_and_idempotency(challenge_domain):
    d = challenge_domain
    version = setup(d)
    body = {"version_id": version, "vehicle_id": "compact"}
    assert d.client.post("/v1/challenges", json=body, headers=headers(d, "Alice")).status_code == 409
    run = normal_run(d, version)
    first = create(d, version, run_id=run, key="challenge-repeat-key")
    second = create(d, version, run_id=run, key="challenge-repeat-key")
    assert first == second
    assert first["target_ticks"] == 150 and first["manifest"]["laps"] == 5
    assert d.client.post("/v1/challenges", json={**body, "mode": "group"},
                         headers=headers(d, "Alice", "challenge-repeat-key")).status_code == 409
    assert d.client.post("/v1/challenges", json={**body, "source_run_id": run}, headers=headers(d, "Bob")).status_code == 409
    with d.factory() as session:
        assert len(session.scalars(select(Challenge)).all()) == 1


def test_ghost_lazy_reconstruction_and_public_preview_expose_no_inputs(challenge_domain):
    d = challenge_domain
    version = setup(d)
    run_id = normal_run(d, version)
    with d.factory() as session:
        session.get(Run, run_id).ghost_hash = None
        session.commit()
    challenge = create(d, version)
    preview = d.client.get(f"/v1/challenges/{challenge['code']}")
    assert preview.status_code == 200 and not preview.json()["joined"]
    ghost = d.client.get(f"/v1/challenges/{challenge['code']}/ghost")
    assert ghost.status_code == 200
    assert ghost.json()["recording"]["ticks"] == 150
    assert "frames" not in json.dumps(ghost.json()) and "replay_hash" not in json.dumps(preview.json())
    page = d.client.get(f"/c/{challenge['code']}")
    assert page.status_code == 200 and challenge["code"] in page.text and "Five laps" in page.text
    assert page.headers["cache-control"] == "no-store"


def test_join_capacity_same_membership_retries_and_private_ticket_authority(challenge_domain):
    d = challenge_domain
    version = setup(d)
    normal_run(d, version)
    challenge = create(d, version)
    code = challenge["code"]
    assert d.client.post(f"/v1/challenges/{code}/tickets", headers=headers(d, "Bob")).status_code == 403
    joined = join(d, code, key="join-stable-key")
    assert joined == join(d, code, key="join-stable-key")
    assert len(join(d, code)["standings"]) == 2
    assert d.client.post(f"/v1/challenges/{code}/join", headers=headers(d, "Carol")).status_code == 409
    assert d.client.post(f"/v1/challenges/{code}/tickets", headers=headers(d, "Alice")).status_code == 409
    with d.factory() as session:
        assert session.get(Challenge, challenge["id"]).member_count == 2


def test_faster_tied_slower_runs_and_fixed_target_with_rematch(challenge_domain):
    d = challenge_domain
    version = setup(d)
    normal_run(d, version)
    challenge = create(d, version)
    join(d, challenge["code"])
    first, outcome = attempt(d, challenge["code"], frames=20)
    assert outcome["outcome"]["improved"] and outcome["outcome"]["beaten"]
    assert outcome["outcome"]["gap_ms"] == -417
    for frames in (20, 25):
        _, later = attempt(d, challenge["code"], frames=frames)
        assert not later["outcome"]["improved"]
        assert later["outcome"]["after"]["run_id"] == first["run_id"]
    normal_run(d, version, frames=10)  # Creator PB changes; invitation does not.
    assert d.client.get(f"/v1/challenges/{challenge['code']}").json()["target_ticks"] == 150
    rematch = d.client.post(f"/v1/challenges/{challenge['code']}/rematch", json={}, headers=headers(d, "Bob", "rematch-key"))
    assert rematch.status_code == 201, rematch.text
    assert rematch.json()["code"] != challenge["code"] and rematch.json()["target_ticks"] == 100
    assert rematch.json() == d.client.post(f"/v1/challenges/{challenge['code']}/rematch", json={}, headers=headers(d, "Bob", "rematch-key")).json()


def test_tie_does_not_beat_target_or_allow_rematch(challenge_domain):
    d = challenge_domain
    version = setup(d)
    normal_run(d, version)
    challenge = create(d, version)
    join(d, challenge["code"])
    _, result = attempt(d, challenge["code"], frames=30)
    assert not result["outcome"]["beaten"] and result["outcome"]["gap_ms"] == 0
    assert all(row["rank"] == 1 for row in result["challenge"]["standings"])
    assert d.client.post(f"/v1/challenges/{challenge['code']}/rematch", json={}, headers=headers(d, "Bob")).status_code == 409


def test_group_scores_only_challenge_attempts_and_one_best_per_driver(challenge_domain):
    d = challenge_domain
    version = setup(d)
    normal_run(d, version, "Bob", frames=1)
    challenge = create(d, version, mode="group")
    assert challenge["target_ms"] is None and challenge["standings"][0]["ms"] is None
    join(d, challenge["code"])
    join(d, challenge["code"], "Carol")
    for who, frames in (("Bob", 20), ("Carol", 20), ("Alice", 30), ("Bob", 25)):
        _, value = attempt(d, challenge["code"], who, frames)
    rows = value["challenge"]["standings"]
    assert [row["rank"] for row in rows] == [1, 1, 3]
    assert len(rows) == 3 and rows[0]["ticks"] == 100
    inbox = d.client.get("/v1/challenges?folder=received", headers=headers(d, "Bob")).json()
    sent = d.client.get("/v1/challenges?folder=sent", headers=headers(d, "Alice")).json()
    assert inbox["items"][0]["code"] == sent["items"][0]["code"] == challenge["code"]
    assert d.client.get("/v1/challenges?folder=sent", headers=headers(d, "Carol")).json()["items"] == []


def test_late_verification_counts_timely_upload_and_expiry_blocks_new_races(challenge_domain, monkeypatch):
    d = challenge_domain
    version = setup(d)
    challenge = create(d, version, mode="group")
    join(d, challenge["code"])
    issued = d.client.post(f"/v1/challenges/{challenge['code']}/tickets", headers=headers(d, "Bob")).json()
    submitted = submit(d, issued, "Bob")
    end = now()+1
    with d.factory() as session:
        session.get(Challenge, challenge["id"]).ends_at = end
        session.commit()
    monkeypatch.setattr(challenges, "now", lambda: end+1)
    assert d.client.get(f"/v1/challenges/{challenge['code']}").json()["state"] == "settling"
    assert d.client.post(f"/v1/challenges/{challenge['code']}/tickets", headers=headers(d, "Bob")).status_code == 410
    assert d.client.post(f"/v1/challenges/{challenge['code']}/join", headers=headers(d, "Carol")).status_code == 410
    assert process_one(d.app)
    result = d.client.get(f"/v1/challenge-results/{issued['ticket_id']}", headers=headers(d, "Bob")).json()
    assert result["status"] == "verified" and result["outcome"]["counted"]
    assert result["challenge"]["state"] == "complete"
    assert d.client.get(f"/v1/challenge-results/{issued['ticket_id']}", headers=headers(d, "Carol")).status_code == 404
    with d.factory() as session:
        assert session.get(Run, submitted["run_id"]).status == "verified"


def test_cancel_authority_and_pending_attempt_cannot_change_standings(challenge_domain):
    d = challenge_domain
    version = setup(d)
    challenge = create(d, version, mode="group")
    join(d, challenge["code"])
    issued = d.client.post(f"/v1/challenges/{challenge['code']}/tickets", headers=headers(d, "Bob")).json()
    submit(d, issued, "Bob")
    assert d.client.post(f"/v1/challenges/{challenge['code']}/cancel", headers=headers(d, "Bob")).status_code == 403
    cancelled = d.client.post(f"/v1/challenges/{challenge['code']}/cancel", headers=headers(d, "Alice"))
    assert cancelled.status_code == 200 and cancelled.json()["state"] == "cancelled"
    assert process_one(d.app)
    result = d.client.get(f"/v1/challenge-results/{issued['ticket_id']}", headers=headers(d, "Bob")).json()
    assert not result["outcome"]["counted"]
    assert all(row["ticks"] is None for row in result["challenge"]["standings"])


def test_hidden_track_private_draft_and_build_changes_reject_without_upgrading(challenge_domain):
    d = challenge_domain
    version = setup(d)
    challenge = create(d, version, mode="group")
    with d.factory() as session:
        board = session.get(Board, session.get(Challenge, challenge["id"]).board_id)
        pinned = dict(board.manifest)
    d.app.state.verifier.manifest = lambda: {**FakeVerifier().manifest(), "physics_version": "new-physics"}
    assert d.client.post(f"/v1/challenges/{challenge['code']}/join", headers=headers(d, "Bob")).status_code == 409
    with d.factory() as session:
        assert session.get(Board, session.get(Challenge, challenge["id"]).board_id).manifest == pinned
        track = session.get(Track, session.get(TrackVersion, version).track_id)
        track.hidden = True
        session.commit()
    assert d.client.get(f"/v1/challenges/{challenge['code']}").status_code == 404


def test_artificial_identity_is_excluded_from_creation_membership_and_results(challenge_domain):
    d = challenge_domain
    version = setup(d)
    challenge = create(d, version, mode="group")
    with d.factory() as session:
        session.get(Player, d.players["Bob"]).is_test_driver = True
        session.commit()
    for path, body in (("/v1/challenges", {"version_id": version, "vehicle_id": "compact", "mode": "group"}),
                       (f"/v1/challenges/{challenge['code']}/join", {}),
                       (f"/v1/challenges/{challenge['code']}/tickets", {})):
        assert d.client.post(path, json=body, headers=headers(d, "Bob")).status_code == 403
    assert d.client.get("/v1/challenges", headers=headers(d, "Bob")).status_code == 403


def test_group_capacity_twenty_and_no_member_reservation_on_rejected_join(challenge_domain):
    d = challenge_domain
    version = setup(d)
    challenge = create(d, version, mode="group")
    with d.factory() as session:
        record = session.get(Challenge, challenge["id"])
        record.member_count = 20
        session.commit()
    assert d.client.post(f"/v1/challenges/{challenge['code']}/join", headers=headers(d, "Bob")).status_code == 409
    with d.factory() as session:
        assert session.get(ChallengeMember, (challenge["id"], d.players["Bob"])) is None
        assert session.get(Challenge, challenge["id"]).member_count == 20


def test_retention_preserves_challenge_target_and_best_ghosts(challenge_domain):
    from bmt_backend.maintenance import retain
    d = challenge_domain
    version = setup(d)
    target = normal_run(d, version)
    challenge = create(d, version)
    normal_run(d, version, frames=10)  # Target no longer the all-time PB.
    join(d, challenge["code"])
    best, _ = attempt(d, challenge["code"])
    normal_run(d, version, "Bob", frames=1)  # Challenge best is also superseded globally.
    with d.factory() as session:
        for run_id in (target, best["run_id"]):
            session.get(Run, run_id).finished_at = now()-100*86400
        session.commit()
    retain(d.factory, d.app.state.blobs, apply=True, offline=True)
    with d.factory() as session:
        assert session.get(Run, target) is not None and session.get(Run, best["run_id"]) is not None
        assert session.scalar(select(ChallengeTicket).where(ChallengeTicket.challenge_id == challenge["id"])) is not None


def test_inbox_cursor_keeps_same_second_invitations_and_rejects_cross_folder(challenge_domain):
    d = challenge_domain
    version = setup(d)
    first = create(d, version, mode="group")
    with d.factory() as session:
        first_record = session.get(Challenge, first["id"])
        for _index in range(52):
            record = Challenge(code=secrets.token_hex(8).upper(), creator_id=d.players["Alice"],
                board_id=first_record.board_id, mode="group", ends_at=first_record.ends_at,
                created_at=first_record.created_at)
            session.add(record)
            session.flush()
            session.add(ChallengeMember(challenge_id=record.id, player_id=d.players["Alice"]))
        session.commit()
    page = d.client.get("/v1/challenges?folder=sent", headers=headers(d, "Alice")).json()
    assert len(page["items"]) == 50 and page["next_cursor"]
    next_page = d.client.get("/v1/challenges", params={"folder": "sent", "cursor": page["next_cursor"]},
                             headers=headers(d, "Alice")).json()
    assert len(next_page["items"]) == 3 and next_page["next_cursor"] is None
    assert len({row["id"] for row in page["items"]+next_page["items"]}) == 53
    assert d.client.get("/v1/challenges", params={"cursor": page["next_cursor"]}, headers=headers(d, "Alice")).status_code == 422


def test_android_association_is_explicitly_configured_and_preview_escapes_names(challenge_domain):
    d = challenge_domain
    version = setup(d)
    challenge = create(d, version, mode="group")
    assert d.client.get("/.well-known/assetlinks.json").status_code == 404
    certificate = ":".join(["AB"]*32)
    d.app.state.settings = replace(d.app.state.settings, android_app_link_certificates=(certificate,))
    association = d.client.get("/.well-known/assetlinks.json")
    assert association.status_code == 200
    assert association.json()[0]["target"]["sha256_cert_fingerprints"] == [certificate]
    with d.factory() as session:
        session.get(TrackVersion, version).name = '<script>alert("x")</script>'
        session.commit()
    page = d.client.get(f"/c/{challenge['code']}")
    assert "<script>" not in page.text and "&lt;script&gt;" in page.text


def test_concurrent_final_duel_slot_and_duplicate_membership(challenge_domain):
    d = challenge_domain
    if not d.postgres:
        pytest.skip("Row-lock proof uses the isolated PostgreSQL fixture")
    version = setup(d)
    normal_run(d, version)
    challenge = create(d, version)
    path = f"/v1/challenges/{challenge['code']}/join"
    with ThreadPoolExecutor(max_workers=2) as executor:
        results = list(executor.map(lambda player: d.client.post(path, headers=headers(d, player)), ("Bob", "Carol")))
    assert sorted(response.status_code for response in results) == [200, 409]
    with d.factory() as session:
        assert session.get(Challenge, challenge["id"]).member_count == 2
        assert len(session.scalars(select(ChallengeMember).where(ChallengeMember.challenge_id == challenge["id"])).all()) == 2
    group = create(d, version, mode="group")
    with ThreadPoolExecutor(max_workers=2) as executor:
        results = list(executor.map(lambda key: d.client.post(f"/v1/challenges/{group['code']}/join",
            headers=headers(d, "Bob", key)), ("concurrent-join-a", "concurrent-join-b")))
    assert all(response.status_code == 200 for response in results)
    with d.factory() as session:
        assert session.get(Challenge, group["id"]).member_count == 2
