"""Weekly eligibility, grouping, deadlines and verified-only scoring."""
import json
import uuid
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from sqlalchemy import select
from test_domains import domain as _domain_fixture
from test_domains import headers, submit, upload

from bmt_backend.identity_models import Identity, Player
from bmt_backend.rivalry import eligible_versions, skill_score, week_window
from bmt_backend.rivalry_models import RivalryBest, RivalryGroup, RivalryMember
from bmt_backend.runs import board_manifest
from bmt_backend.track_models import Board, PersonalBest, Run, RunTicket, Track, TrackVersion, digest, now
from bmt_backend.worker import process_one

rivalry_domain = _domain_fixture


def seed(rivalry_domain, count=6, official=True):
    versions = []
    with rivalry_domain.factory() as session:
        for index in range(count):
            track = Track(owner_id=rivalry_domain.players["Creator"], official=official)
            session.add(track)
            session.flush()
            document = {"shape": "oval", "id": f"weekly_{index}", "name": f"Circuit {index}", "points": [[0, 0], [10, 0], [10, 10], [0, 10]]}
            version = TrackVersion(track_id=track.id, number=1, name=document["name"], state="published",
                content_hash=rivalry_domain.app.state.blobs.put_json(document), manifest=rivalry_domain.app.state.verifier.validate_track(document),
                discovery={"theme": "pine", "points": document["points"]}, rating_sum=41, rating_count=10)
            session.add(version)
            session.flush()
            versions.append(version.id)
        session.commit()
    return versions


def join(rivalry_domain, player="Alice", key=None):
    response = rivalry_domain.client.post("/v1/rivalry/join", json={"vehicle_id": "compact"}, headers=headers(rivalry_domain, player, key))
    assert response.status_code == 200, response.text
    return response.json()


def rivalry_ticket(rivalry_domain, group, player="Alice", slot=0):
    response = rivalry_domain.client.post(f"/v1/rivalry/{group}/tickets", json={"slot": slot}, headers=headers(rivalry_domain, player))
    assert response.status_code == 201, response.text
    return response.json()


def add_finishes(rivalry_domain, version_id, count, *, same_players=None):
    with rivalry_domain.factory() as session:
        version = session.get(TrackVersion, version_id)
        pinned = board_manifest(version, "compact")
        board_id = digest({"version_id": version.id, **pinned})
        board = session.get(Board, board_id)
        if board is None:
            session.add(Board(id=board_id, version_id=version.id, vehicle_id="compact", manifest=pinned))
            session.flush()
        players = same_players or []
        for index in range(count):
            if same_players is None:
                player = Player(display_name="Racer_" + uuid.uuid4().hex[:15])
                session.add(player)
                session.flush()
                players.append(player.id)
            ticket = RunTicket(player_id=players[index], board_id=board_id, expires_at=now()+7200)
            session.add(ticket)
            session.flush()
            run = Run(ticket_id=ticket.id, player_id=players[index], board_id=board_id, replay_hash="0"*64,
                      status="verified", time_ticks=100+index, finished_at=now())
            session.add(run)
            session.flush()
            session.add(PersonalBest(board_id=board_id, player_id=players[index], run_id=run.id, time_ticks=100+index))
        session.commit()
    return players


def test_exact_eligibility_and_official_provenance(rivalry_domain):
    versions = seed(rivalry_domain, 1, False)
    active = rivalry_domain.app.state.verifier.manifest()
    add_finishes(rivalry_domain, versions[0], 100)
    with rivalry_domain.factory() as session:
        assert eligible_versions(session, active, "compact") == []
    add_finishes(rivalry_domain, versions[0], 1)
    with rivalry_domain.factory() as session:
        assert len(eligible_versions(session, active, "compact")) == 1
        version = session.get(TrackVersion, versions[0])
        version.rating_sum = 40
        session.commit()
        assert eligible_versions(session, active, "compact") == []
        track = session.get(Track, version.track_id)
        track.official = True
        session.commit()
        assert len(eligible_versions(session, active, "compact")) == 1
        track.hidden = True
        session.commit()
        assert eligible_versions(session, active, "compact") == []


def test_insufficient_tracks_no_fabricated_field(rivalry_domain):
    seed(rivalry_domain, 4)
    current = rivalry_domain.client.get("/v1/rivalry/current?vehicle_id=compact", headers=headers(rivalry_domain, "Alice"))
    assert current.json()["eligible_track_count"] == 4
    response = rivalry_domain.client.post("/v1/rivalry/join", json={"vehicle_id": "compact"}, headers=headers(rivalry_domain, "Alice"))
    assert response.status_code == 409
    with rivalry_domain.factory() as session:
        assert session.scalars(select(RivalryGroup)).all() == []


def test_random_pinned_unique_selection_idempotent_membership_and_private_views(rivalry_domain):
    eligible = seed(rivalry_domain)
    first = join(rivalry_domain, key="join-once-key")
    retry = join(rivalry_domain, key="join-once-key")
    again = join(rivalry_domain)
    assert first == retry
    assert again["group_id"] == first["group_id"]
    selected = [item["entry"]["version_id"] for item in first["tracks"]]
    assert len(set(selected)) == 5 and set(selected).issubset(eligible)
    assert first["driver_count"] == 1 and first["placement"] and first["group_forming"]
    assert first["standings"][0]["rank"] is None
    second = join(rivalry_domain, "Bob")
    assert second["group_id"] == first["group_id"]
    denied = rivalry_domain.client.get(f"/v1/rivalry/{first['group_id']}", headers=headers(rivalry_domain, "Carol"))
    assert denied.status_code == 404
    bad_slot = rivalry_domain.client.post(f"/v1/rivalry/{first['group_id']}/tickets", json={"slot":5}, headers=headers(rivalry_domain, "Alice"))
    assert bad_slot.status_code == 422
    with rivalry_domain.factory() as session:
        assert len(session.scalars(select(RivalryMember)).all()) == 2


def test_verified_weekly_bests_points_ties_and_no_attempt_farming(rivalry_domain):
    seed(rivalry_domain)
    group = join(rivalry_domain)["group_id"]
    join(rivalry_domain, "Bob")
    first = rivalry_ticket(rivalry_domain, group)
    queued = submit(rivalry_domain, first, "Alice", frames=30)
    snapshot = rivalry_domain.client.get(f"/v1/rivalry/{group}", headers=headers(rivalry_domain, "Alice")).json()
    assert snapshot["standings"][0]["points"] == 0
    assert process_one(rivalry_domain.app)
    result = rivalry_domain.client.get(f"/v1/rivalry/tickets/{first['ticket_id']}/result", headers=headers(rivalry_domain,"Alice")).json()
    assert result["outcome"]["points_delta"] == 30
    assert result["status"] == "verified"
    bob = rivalry_ticket(rivalry_domain, group, "Bob")
    submit(rivalry_domain, bob, "Bob", frames=20)
    assert process_one(rivalry_domain.app)
    next_race = rivalry_ticket(rivalry_domain, group)
    submit(rivalry_domain, next_race, "Alice", frames=19)
    assert process_one(rivalry_domain.app)
    change = rivalry_domain.client.get(f"/v1/rivalry/tickets/{next_race['ticket_id']}/result", headers=headers(rivalry_domain,"Alice")).json()["outcome"]
    assert change["before"]["rank"] == 2 and change["after"]["rank"] == 1
    assert change["points_delta"] == 4 and change["beaten"][0]["id"] == rivalry_domain.players["Bob"]
    slower = rivalry_ticket(rivalry_domain, group)
    submit(rivalry_domain, slower, "Alice", frames=40)
    assert process_one(rivalry_domain.app)
    held = rivalry_domain.client.get(f"/v1/rivalry/tickets/{slower['ticket_id']}/result", headers=headers(rivalry_domain,"Alice")).json()["outcome"]
    assert not held["improved"] and held["points_delta"] == 0
    tie = rivalry_ticket(rivalry_domain, group, "Bob")
    submit(rivalry_domain, tie, "Bob", frames=19)
    assert process_one(rivalry_domain.app)
    board = rivalry_domain.client.get(f"/v1/rivalry/{group}", headers=headers(rivalry_domain,"Alice")).json()["tracks"][0]["entries"]
    assert all(row["rank"] == 1 and row["points"] == 30 for row in board)
    with rivalry_domain.factory() as session:
        assert len(session.scalars(select(RivalryBest)).all()) == 2
        assert session.get(Run, queued["run_id"]).status == "verified"


def test_skill_uses_verified_comparable_percentiles_and_separates_placement(rivalry_domain):
    versions = seed(rivalry_domain)
    players = add_finishes(rivalry_domain, versions[0], 5)
    for version in versions[1:3]:
        add_finishes(rivalry_domain, version, 5, same_players=players)
    active = rivalry_domain.app.state.verifier.manifest()
    with rivalry_domain.factory() as session:
        assert skill_score(session, players[0], "compact", active, now()) == 1000
        assert skill_score(session, players[4], "compact", active, now()) == 0
        assert skill_score(session, rivalry_domain.players["Alice"], "compact", active, now()) is None
    response = rivalry_domain.client.post("/v1/rivalry/join",json={"vehicle_id":"compact"},headers={"x-test-player":players[0],"Idempotency-Key":str(uuid.uuid4())})
    assert response.status_code == 200
    assert not response.json()["placement"]
    assert join(rivalry_domain)["group_id"] != response.json()["group_id"]


def test_deadline_settlement_and_continue_no_claimed_rewards(rivalry_domain, monkeypatch):
    seed(rivalry_domain)
    original = join(rivalry_domain)
    issued = rivalry_ticket(rivalry_domain, original["group_id"])
    abandoned = rivalry_ticket(rivalry_domain, original["group_id"])
    submit(rivalry_domain, issued, "Alice", frames=20)
    monkeypatch.setattr("bmt_backend.rivalry.now", lambda: original["ends_at"])
    at_end = rivalry_domain.client.get(f"/v1/rivalry/{original['group_id']}", headers=headers(rivalry_domain,"Alice")).json()
    assert at_end["state"] == "settling"
    expired = rivalry_domain.client.get(f"/v1/rivalry/tickets/{abandoned['ticket_id']}/result", headers=headers(rivalry_domain,"Alice"))
    assert expired.json()["status"] == "expired" and expired.json()["outcome"] is None
    denied = rivalry_domain.client.post(f"/v1/rivalry/{original['group_id']}/tickets",json={"slot":0},headers=headers(rivalry_domain,"Alice"))
    assert denied.status_code == 410
    assert process_one(rivalry_domain.app)
    finished = rivalry_domain.client.get(f"/v1/rivalry/{original['group_id']}", headers=headers(rivalry_domain,"Alice")).json()
    assert finished["state"] == "complete" and finished["standings"][0]["points"] == 30
    response = rivalry_domain.client.post(f"/v1/rivalry/{original['group_id']}/continue",json={},headers=headers(rivalry_domain,"Alice"))
    assert response.json() == {"acknowledged": True}


def test_group_capacity_and_repeat_joins(rivalry_domain):
    seed(rivalry_domain)
    with rivalry_domain.factory() as session:
        players = [Player(display_name="Entrant_"+str(index)) for index in range(21)]
        session.add_all(players)
        session.flush()
        ids = [player.id for player in players]
        session.commit()

    def enroll(player_id):
        response = rivalry_domain.client.post("/v1/rivalry/join", json={"vehicle_id":"compact"},
            headers={"x-test-player":player_id,"Idempotency-Key":str(uuid.uuid4())})
        assert response.status_code == 200, response.text
        return response.json()

    if rivalry_domain.postgres:
        with ThreadPoolExecutor(max_workers=8) as pool:
            joined = list(pool.map(enroll, ids))
        with ThreadPoolExecutor(max_workers=4) as pool:
            repeated = list(pool.map(enroll, [ids[0]]*4))
    else:
        joined = [enroll(player_id) for player_id in ids]
        repeated = [enroll(ids[0]) for _ in range(4)]
    assert len({item["group_id"] for item in joined}) == 2
    assert all(item["group_id"] == joined[0]["group_id"] for item in repeated)
    with rivalry_domain.factory() as session:
        counts = sorted(group.member_count for group in session.scalars(select(RivalryGroup)))
        assert counts == [1,20]
        assert len(session.scalars(select(RivalryMember)).all()) == 21


def test_five_track_championship_golden_points(rivalry_domain):
    fixture = json.loads((Path(__file__).parent / "fixtures/weekly_points_v1.json").read_text())
    seed(rivalry_domain)
    group = join(rivalry_domain)["group_id"]
    join(rivalry_domain, "Bob")
    for name, expected in fixture["drivers"].items():
        for slot, ticks in enumerate(expected["ticks"]):
            if ticks is None:
                continue
            issued = rivalry_ticket(rivalry_domain, group, name, slot)
            submit(rivalry_domain, issued, name, frames=ticks//5)
            assert process_one(rivalry_domain.app)
    value = rivalry_domain.client.get(f"/v1/rivalry/{group}", headers=headers(rivalry_domain,"Alice")).json()
    assert value["points_policy"] == fixture["policy"]
    for name, expected in fixture["drivers"].items():
        overall = next(row for row in value["standings"] if row["name"] == name)
        assert (overall["points"],overall["rank"],overall["completed"]) == (expected["total"],expected["rank"],expected["completed"])
        points = [next(row["points"] for row in item["entries"] if row["name"] == name) for item in value["tracks"]]
        assert points == expected["track_points"]


def test_official_flag_cannot_be_claimed_by_player_or_display_name(rivalry_domain):
    version_id = seed(rivalry_domain, 1, False)[0]
    with rivalry_domain.factory() as session:
        session.get(Player, rivalry_domain.players["Creator"]).display_name = "Beat my track"
        session.commit()
        assert eligible_versions(session, rivalry_domain.app.state.verifier.manifest(), "compact") == []
        assert not session.get(Track, session.get(TrackVersion, version_id).track_id).official
    spoof = rivalry_domain.client.post("/v1/rivalry/join", json={"vehicle_id":"compact","skill":1000,"official":True},
        headers=headers(rivalry_domain,"Alice"))
    assert spoof.status_code == 422
    assert rivalry_domain.client.get("/v1/rivalry/current?vehicle_id=compact").status_code == 401
    # Future uploads inherit official provenance from the authenticated reserved
    # identity; clients cannot opt into it through a name or document field.
    ordinary = upload(rivalry_domain, "Carol", document={"shape":"oval","creator":"Beat my track"})
    with rivalry_domain.factory() as session:
        assert not session.get(Track, ordinary["track_id"]).official
        session.add(Identity(player_id=rivalry_domain.players["Creator"],provider="development",subject="developer"))
        session.commit()
    official = upload(rivalry_domain)
    with rivalry_domain.factory() as session:
        assert session.get(Track, official["track_id"]).official


def test_monday_utc_window():
    start, end, year, week = week_window(1791072000)  # 2026-10-04 UTC
    assert end-start == 604800 and year == 2026 and week == 40
    assert week_window(end)[0] == end
