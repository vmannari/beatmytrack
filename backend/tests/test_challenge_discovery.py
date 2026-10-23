"""Discovery privacy, actionable filters and atomic challenge reward contracts."""
# ruff: noqa: F811
from sqlalchemy import select
from test_challenges import attempt, create, join, normal_run, setup
from test_domains import domain as challenge_rework_domain  # noqa: F401
from test_domains import headers

from bmt_backend.challenge_models import Challenge, ChallengeMember
from bmt_backend.community_models import CommunityAcceptance, PlayerBlock
from bmt_backend.economy_models import CoinReward
from bmt_backend.news_models import Friendship
from bmt_backend.track_models import Board, Track, TrackVersion


def public(d, version, **extra):
    response = d.client.post("/v1/challenges", json={"version_id": version, "vehicle_id": "compact",
        "mode": "group", "visibility": "public", **extra}, headers=headers(d, "Alice"))
    assert response.status_code == 201, response.text
    return response.json()


def browse(d, player="Bob", **query):
    response = d.client.get("/v1/challenges", params={"folder": "discover", **query}, headers=headers(d, player))
    assert response.status_code == 200, response.text
    return response.json()


def reward_rows(d, run_id):
    with d.factory() as session:
        return session.get(CoinReward, run_id).rows


def test_discovery_keeps_invitations_private_and_joins_without_a_code(challenge_rework_domain):
    d = challenge_rework_domain
    version = setup(d)
    private = create(d, version, mode="group")
    visible = public(d, version)
    assert private["visibility"] == "private"
    assert [item["id"] for item in browse(d)["items"]] == [visible["id"]]
    guest = d.client.get("/v1/challenges/discover").json()
    assert [item["id"] for item in guest["items"]] == [visible["id"]]
    assert guest["items"][0]["self_id"] == ""
    joined = join(d, browse(d)["items"][0]["code"])
    assert joined["joined"] and not browse(d)["items"]
    mine = d.client.get("/v1/challenges?folder=received", headers=headers(d, "Bob")).json()
    assert [item["id"] for item in mine["items"]] == [visible["id"]]
    assert d.client.post(f"/v1/challenges/{visible['code']}/tickets", headers=headers(d, "Bob")).status_code == 201


def test_public_sharing_requires_terms_without_changing_private_creation(challenge_rework_domain):
    d = challenge_rework_domain
    version = setup(d)
    with d.factory() as session:
        for row in session.scalars(select(CommunityAcceptance).where(CommunityAcceptance.player_id == d.players["Alice"])):
            session.delete(row)
        session.commit()
    response = d.client.post("/v1/challenges", json={"version_id": version, "vehicle_id": "compact",
        "mode": "group", "visibility": "public"}, headers=headers(d, "Alice"))
    assert response.status_code == 403 and response.json()["detail"] == "COMMUNITY_TERMS_REQUIRED"
    assert create(d, version, mode="group")["visibility"] == "private"


def test_discovery_filters_friends_and_mutual_blocks(challenge_rework_domain):
    d = challenge_rework_domain
    version = setup(d)
    public(d, version)
    assert browse(d, search="Circuit 0", mode="group", vehicle="compact")["items"]
    assert not browse(d, search="Circuit_")["items"]  # Search punctuation is literal.
    assert not browse(d, mode="beat")["items"]
    assert not browse(d, vehicle="kart")["items"]
    assert not browse(d, folder="friends")["items"]
    with d.factory() as session:
        low, high = sorted((d.players["Alice"], d.players["Bob"]))
        session.add(Friendship(low_id=low, high_id=high, requested_by=low, accepted=True))
        session.commit()
    assert browse(d, folder="friends")["items"]
    with d.factory() as session:
        session.add(PlayerBlock(player_id=d.players["Alice"], blocked_id=d.players["Bob"]))
        session.commit()
    assert not browse(d)["items"]
    assert not browse(d, folder="friends")["items"]
    with d.factory() as session:
        session.delete(session.get(PlayerBlock, (d.players["Alice"], d.players["Bob"])))
        code = session.scalar(select(Challenge.code))
        session.commit()
    join(d, code, player="Carol")
    with d.factory() as session:
        session.add(PlayerBlock(player_id=d.players["Carol"], blocked_id=d.players["Bob"]))
        session.commit()
    assert not browse(d)["items"]  # A blocked participant also makes joining unavailable.


def test_discovery_excludes_full_expired_cancelled_hidden_and_incompatible(challenge_rework_domain):
    d = challenge_rework_domain
    version = setup(d)
    item = public(d, version)
    for field, value in (("member_count", 20), ("ends_at", 1), ("cancelled", True)):
        with d.factory() as session:
            row = session.get(Challenge, item["id"])
            previous = getattr(row, field)
            setattr(row, field, value)
            session.commit()
        assert not browse(d)["items"], field
        with d.factory() as session:
            setattr(session.get(Challenge, item["id"]), field, previous)
            session.commit()
    with d.factory() as session:
        board = session.get(Board, session.get(Challenge, item["id"]).board_id)
        original = dict(board.manifest)
        board_id = board.id
        board.manifest = {**original, "physics_version": "old-build"}
        session.commit()
    assert not browse(d)["items"]
    with d.factory() as session:
        session.get(Board, board_id).manifest = original
        session.get(Track, session.get(TrackVersion, version).track_id).hidden = True
        session.commit()
    assert not browse(d)["items"]
    with d.factory() as session:
        track = session.get(Track, session.get(TrackVersion, version).track_id)
        track.hidden = False
        track.archived = True
        session.commit()
    assert not browse(d)["items"]


def test_discovery_keyset_pagination_binds_filters_and_identity(challenge_rework_domain):
    d = challenge_rework_domain
    version = setup(d)
    item = public(d, version)
    with d.factory() as session:
        original = session.get(Challenge, item["id"])
        for index in range(24):
            row = Challenge(code=f"{index:016X}", creator_id=original.creator_id, board_id=original.board_id,
                mode="group", visibility="public", ends_at=original.ends_at+index)
            session.add(row)
            session.flush()
            session.add(ChallengeMember(challenge_id=row.id, player_id=original.creator_id))
        session.commit()
    first = browse(d)
    second = browse(d, cursor=first["next_cursor"])
    assert len(first["items"]) == 20 and len(second["items"]) == 5 and not second["next_cursor"]
    assert len({row["id"] for row in first["items"]+second["items"]}) == 25
    for changed in ({"mode": "group"}, {"sort": "newest"}, {"search": "Circuit"}):
        assert d.client.get("/v1/challenges", params={"folder":"discover", "cursor":first["next_cursor"], **changed},
            headers=headers(d, "Bob")).status_code == 422
    assert d.client.get("/v1/challenges", params={"folder":"discover", "cursor":first["next_cursor"]},
        headers=headers(d, "Carol")).status_code == 422


def test_verified_rewards_are_visible_once_and_limited_per_day(challenge_rework_domain, monkeypatch):
    d = challenge_rework_domain
    version = setup(d)
    for index in range(4):
        item = public(d, version)
        joined = join(d, item["code"])
        assert joined["rewards"]["remaining_today"] == max(0, 3-index)
        submitted, result = attempt(d, item["code"], frames=30)
        rows = [row for row in reward_rows(d, submitted["run_id"]) if row["title"].startswith("Challenge")]
        assert [row["amount"] for row in rows] == ([50] if index < 3 else [])
        assert not result["outcome"]["beaten"]  # No rival time, no goal grant.
        assert result["challenge"]["rewards"]["finish_earned"] == (index < 3)
        if index == 0:
            again, _ = attempt(d, item["code"], frames=25)
            assert not any(row["title"].startswith("Challenge") for row in reward_rows(d, again["run_id"]))
    assert not result["challenge"]["rewards"]["eligible"]
    import time
    tomorrow = time.time()+86400
    monkeypatch.setattr(time, "time", lambda: tomorrow)
    next_day, result = attempt(d, item["code"], frames=30)
    assert [r["amount"] for r in reward_rows(d, next_day["run_id"]) if r["title"].startswith("Challenge")] == [50]
    assert result["challenge"]["rewards"]["remaining_today"] == 2


def test_goal_requires_a_real_rival_and_is_credited_atomically(challenge_rework_domain):
    d = challenge_rework_domain
    version = setup(d)
    normal_run(d, version)
    item = public(d, version, mode="beat")
    join(d, item["code"])
    submitted, result = attempt(d, item["code"], frames=20)
    assert result["outcome"]["beaten"]
    assert result["challenge"]["rewards"]["finish_earned"] and result["challenge"]["rewards"]["goal_earned"]
    assert [r["amount"] for r in reward_rows(d, submitted["run_id"]) if r["title"].startswith("Challenge")] == [50,100]
    slower, _ = attempt(d, item["code"], frames=25)
    assert not any(r["title"].startswith("Challenge") for r in reward_rows(d, slower["run_id"]))
    assert not d.app.state.pending_finalization
    group = public(d, version)
    join(d, group["code"])
    attempt(d, group["code"], frames=30)
    join(d, group["code"], player="Carol")
    tied, result = attempt(d, group["code"], player="Carol", frames=30)
    assert not result["outcome"]["beaten"]
    assert [r["amount"] for r in reward_rows(d, tied["run_id"]) if r["title"].startswith("Challenge")] == [50]
    lead, result = attempt(d, group["code"], player="Carol", frames=20)
    assert result["outcome"]["beaten"]
    assert [r["amount"] for r in reward_rows(d, lead["run_id"]) if r["title"].startswith("Challenge")] == [100]
