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


def create(domain, version, player="Alice", mode="beat", run_id=None, key=None, attempt_limit=None):
    body = {"version_id": version, "vehicle_id": "compact", "mode": mode}
    if attempt_limit is not None:
        body["attempt_limit"] = attempt_limit
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


def test_finished_ticket_pins_slower_result_instead_of_personal_best(challenge_domain):
    d = challenge_domain
    version = setup(d)
    normal_run(d, version, frames=10)
    finished = normal_run(d, version, frames=30)
    with d.factory() as session:
        ticket_id = session.get(Run, finished).ticket_id
    body = {"version_id": version, "vehicle_id": "compact", "source_ticket_id": ticket_id}
    source = d.client.get("/v1/challenges/sources", params={"version_id": version, "vehicle_id": "compact", "ticket_id": ticket_id}, headers=headers(d, "Alice"))
    assert source.json()["run_id"] == finished and source.json()["ms"] == 1250
    for mode in ("beat", "group"):
        response = d.client.post("/v1/challenges", json={**body, "mode": mode}, headers=headers(d, "Alice"))
        assert response.status_code == 201, response.text
        assert response.json()["standings"][0]["run_id"] == finished
        assert response.json()["standings"][0]["ticks"] == 150
        if mode == "beat": assert response.json()["target_ticks"] == 150
    assert d.client.post("/v1/challenges", json=body, headers=headers(d, "Bob")).status_code == 404
    assert d.client.post("/v1/challenges", json={**body, "source_run_id": finished}, headers=headers(d, "Alice")).status_code == 422


def test_pending_finished_ticket_never_falls_back_to_an_existing_pb(challenge_domain):
    d = challenge_domain
    version = setup(d)
    normal_run(d, version, frames=10)
    issued = d.client.post("/v1/run-tickets", json={"version_id": version, "vehicle_id": "compact"}, headers=headers(d, "Alice")).json()
    body = {"version_id": version, "vehicle_id": "compact", "source_ticket_id": issued["ticket_id"]}
    assert d.client.post("/v1/challenges", json=body, headers=headers(d, "Alice")).status_code == 409
    submit(d, issued, "Alice", frames=30)
    assert d.client.post("/v1/challenges", json=body, headers=headers(d, "Alice")).status_code == 409
    with d.factory() as session:
        assert session.scalars(select(Challenge)).all() == []
    assert process_one(d.app)
    response = d.client.post("/v1/challenges", json=body, headers=headers(d, "Alice"))
    assert response.status_code == 201 and response.json()["target_ticks"] == 150


def test_ghost_lazy_storage_and_public_preview_expose_no_inputs(challenge_domain,monkeypatch):
    d = challenge_domain
    version = setup(d)
    run_id = normal_run(d, version)
    with d.factory() as session:
        run = session.get(Run, run_id)
        recording = d.app.state.blobs.get_json(run.ghost_hash)
        replay = d.app.state.blobs.get_json(run.replay_hash)
        run.replay_hash = d.app.state.blobs.put_json({**replay,"ghost":recording})
        run.ghost_hash = None
        session.commit()
    def forbidden(*_args,**_kwargs):
        raise AssertionError("Ghost storage must not re-verify or re-simulate the race")
    monkeypatch.setattr(d.app.state.verifier,"verify_run",forbidden)
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


def test_attempt_limit_reserves_starts_and_retries_are_idempotent(challenge_domain):
    d = challenge_domain
    version = setup(d)
    normal_run(d, version)
    value = create(d, version, attempt_limit=3)
    assert value["attempt_limit"] == 3 and value["attempts_used"] == 1
    joined = join(d, value["code"])
    assert joined["attempts_remaining"] == 3
    path = f"/v1/challenges/{value['code']}/tickets"
    first = d.client.post(path, headers=headers(d, "Bob", "same-start-key"))
    assert first.status_code == 201
    assert first.json()["attempts_remaining"] == 2
    repeated = d.client.post(path, headers=headers(d, "Bob", "same-start-key"))
    assert repeated.status_code == 201 and repeated.json() == first.json()
    # An abandoned start counts; a rejected upload does not refund it either.
    second = d.client.post(path, headers=headers(d, "Bob"))
    bad = submit(d, second.json(), "Bob", frames=20, steering=-127)
    assert process_one(d.app)
    third = d.client.post(path, headers=headers(d, "Bob"))
    assert third.status_code == 201 and third.json()["attempts_remaining"] == 0
    denied = d.client.post(path, headers=headers(d, "Bob"))
    assert denied.status_code == 409 and denied.json()["detail"] == "No tries remaining"
    # Retrying an issued start still works after the limit is exhausted.
    assert d.client.post(path, headers=headers(d, "Bob", "same-start-key")).json() == first.json()
    submitted = submit(d, third.json(), "Bob", frames=10)
    assert process_one(d.app)
    result = d.client.get(f"/v1/challenge-results/{third.json()['ticket_id']}", headers=headers(d, "Bob")).json()
    assert result["status"] == "verified" and result["outcome"]["counted"]
    assert result["challenge"]["attempts_used"] == 3
    assert result["challenge"]["attempts_remaining"] == 0
    assert "3 tries per driver" in d.client.get(f"/c/{value['code']}").text
    rematch = d.client.post(f"/v1/challenges/{value['code']}/rematch", json={}, headers=headers(d, "Bob"))
    assert rematch.status_code == 201 and rematch.json()["attempt_limit"] == 3


def test_group_source_counts_once_and_unlimited_remains_unlimited(challenge_domain):
    d = challenge_domain
    version = setup(d)
    source = normal_run(d, version)
    seeded = create(d, version, mode="group", run_id=source, attempt_limit=1)
    assert seeded["attempts_used"] == 1 and seeded["attempts_remaining"] == 0
    assert d.client.post(f"/v1/challenges/{seeded['code']}/tickets", headers=headers(d, "Alice")).status_code == 409
    empty = create(d, version, mode="group", attempt_limit=1)
    assert empty["attempts_used"] == 0 and empty["attempts_remaining"] == 1
    attempt(d, empty["code"], player="Alice", frames=20)
    assert d.client.post(f"/v1/challenges/{empty['code']}/tickets", headers=headers(d, "Alice")).status_code == 409
    unlimited = create(d, version, mode="group")
    assert unlimited["attempt_limit"] is None and unlimited["attempts_remaining"] is None
    for _ in range(6):
        assert d.client.post(f"/v1/challenges/{unlimited['code']}/tickets", headers=headers(d, "Alice")).status_code == 201
    view = d.client.get(f"/v1/challenges/{unlimited['code']}/me", headers=headers(d, "Alice")).json()
    assert view["attempts_used"] == 6 and view["attempts_remaining"] is None


@pytest.mark.parametrize("limit", [0, -1, 2, 4, 6, True, "3", 3.0])
def test_invalid_attempt_limits_rejected(challenge_domain, limit):
    d = challenge_domain
    version = setup(d)
    response = d.client.post("/v1/challenges", json={"version_id":version,"vehicle_id":"compact","mode":"group","attempt_limit":limit}, headers=headers(d,"Alice"))
    assert response.status_code == 422


def test_concurrent_final_try_and_same_key(challenge_domain):
    d = challenge_domain
    if not d.postgres:
        pytest.skip("SQLite test pool shares one connection; row concurrency runs on owned PostgreSQL")
    version = setup(d)
    value = create(d, version, mode="group", attempt_limit=1)
    join(d, value["code"])
    path = f"/v1/challenges/{value['code']}/tickets"
    with ThreadPoolExecutor(max_workers=4) as pool:
        answers = list(pool.map(lambda _: d.client.post(path, headers=headers(d,"Bob","concurrent-start")), range(4)))
    assert all(answer.status_code == 201 for answer in answers)
    assert len({answer.json()["ticket_id"] for answer in answers}) == 1
    join(d, value["code"], player="Carol")
    with ThreadPoolExecutor(max_workers=4) as pool:
        answers = list(pool.map(lambda _: d.client.post(path, headers=headers(d,"Carol")), range(4)))
    assert sorted(answer.status_code for answer in answers) == [201,409,409,409]
    view = d.client.get(f"/v1/challenges/{value['code']}/me", headers=headers(d,"Carol")).json()
    assert view["attempts_used"] == 1 and view["attempts_remaining"] == 0


def test_additive_attempt_migration_preserves_existing_challenges(challenge_domain):
    from alembic import command
    from bmt_backend.migrate import configuration
    d = challenge_domain
    version = setup(d)
    source = normal_run(d, version)
    value = create(d, version, mode="group", run_id=source)
    join(d, value["code"])
    attempt(d, value["code"], player="Alice", frames=20)
    attempt(d, value["code"], player="Bob", frames=10)
    before = d.client.get(f"/v1/challenges/{value['code']}/me", headers=headers(d,"Alice")).json()
    # Exercise the actual additive transition over an existing schema0020 field.
    command.downgrade(configuration(d.app.state.engine), "0020_challenges")
    command.upgrade(configuration(d.app.state.engine), "head")
    after = d.client.get(f"/v1/challenges/{value['code']}/me", headers=headers(d,"Alice")).json()
    assert after["attempt_limit"] is None and after["attempts_remaining"] is None
    assert after["attempts_used"] == 2
    assert after["standings"] == before["standings"] and after["target_id"] == before["target_id"]
    other = d.client.get(f"/v1/challenges/{value['code']}/me", headers=headers(d,"Bob")).json()
    assert other["attempts_used"] == 1 and other["attempt_limit"] is None


def test_unlimited_creation_retries_keep_pre_migration_identity(challenge_domain):
    from bmt_backend.track_models import IdempotencyRecord, digest
    d = challenge_domain
    version = setup(d)
    normal_run(d, version)
    key = "existing-unlimited-create"
    value = create(d, version, key=key)
    with d.factory() as session:
        record = session.get(IdempotencyRecord, (d.players["Alice"], "challenge_create", key))
        record.request_hash = digest({"version_id":version,"vehicle_id":"compact","mode":"beat","duration_seconds":604800,
                                      "source_run_id":None,"source_ticket_id":None})
        record.response = {name:item for name,item in value.items() if name not in ("attempt_limit","attempts_used","attempts_remaining")}
        old_response = dict(record.response)
        session.commit()
    response = d.client.post("/v1/challenges", json={"version_id":version,"vehicle_id":"compact","attempt_limit":None}, headers=headers(d,"Alice",key))
    assert response.status_code == 201 and response.json() == old_response
    assert d.client.post("/v1/challenges", json={"version_id":version,"vehicle_id":"compact","attempt_limit":3}, headers=headers(d,"Alice",key)).status_code == 409
    with d.factory() as session:
        assert len(session.scalars(select(Challenge)).all()) == 1
