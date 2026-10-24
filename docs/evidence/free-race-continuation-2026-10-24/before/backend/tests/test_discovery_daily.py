"""Ranking balance, bounded background publication and real Free Race/search API."""
import time
import uuid

from alembic import command
from sqlalchemy import event, func, select, update
from test_discovery_paging import auth_app as auth_app_fixture
from test_discovery_v3 import browse
from test_discovery_v3 import indexed as indexed_fixture

from bmt_backend import discovery_daily as daily
from bmt_backend.discovery_erasure import erase_private
from bmt_backend.discovery_models import (
    DiscoveryActivity,
    DiscoveryDay,
    DiscoveryHead,
    DiscoveryPartition,
    DiscoverySession,
)
from bmt_backend.discovery_projection import settle_for_diagnostics
from bmt_backend.identity_models import Player
from bmt_backend.migrate import configuration
from bmt_backend.track_models import Board, Run, RunTicket, Track, TrackVersion

auth_app = auth_app_fixture
indexed = indexed_fixture


def build(d, stamp=None):
    stamp = int(time.time()) if stamp is None else stamp
    for _ in range(100):
        if not daily.step(d.app.state.session_factory, clock=stamp):
            break
    else:
        raise AssertionError("Daily build did not finish within a bounded test catalogue")
    with d.app.state.session_factory() as db:
        row = db.get(DiscoveryDay, stamp // daily.DAY)
        assert row.published_at > 0 and not row.pools
        return row.items


def finish(d, player, *, count=1, stamp=None, purpose=None, track=0):
    stamp = int(time.time()) - 1 if stamp is None else stamp
    with d.app.state.session_factory() as db:
        board = Board(id=uuid.uuid4().hex * 2, version_id=d.versions[track]["id"],
            vehicle_id="compact", manifest=purpose or {})
        db.add(board)
        db.flush()
        ids = []
        for _ in range(count):
            ticket = RunTicket(player_id=player, board_id=board.id, expires_at=stamp + 100)
            db.add(ticket)
            db.flush()
            run = Run(ticket_id=ticket.id, player_id=player, board_id=board.id, replay_hash="a" * 64,
                status="verified", time_ticks=100, lap_ticks=[20] * 5, finished_at=stamp)
            db.add(run)
            db.flush()
            ids.append(run.id)
        db.commit()
    return ids


def activity(d):
    with d.app.state.session_factory() as db:
        head = db.get(DiscoveryHead, d.tracks[0]["id"])
        return head.activity_races, head.activity_replays


def test_score_balances_confidence_freshness_reach_volume_and_replay():
    base = {"rating_sum": 0, "rating_count": 0, "recent_players": 0, "lifetime_players": 0,
        "races": 0, "replays": 0, "created_at": 0, "stamp": 30 * daily.DAY}
    baseline = daily.score(**base)
    for change in ({"recent_players": 30}, {"lifetime_players": 200}, {"races": 30, "replays": 20},
                   {"created_at": base["stamp"]}, {"rating_sum": 90, "rating_count": 20}):
        assert daily.score(**{**base, **change}) > baseline
    assert daily.score(**{**base, "rating_sum": 5, "rating_count": 1}) < daily.score(
        **{**base, "rating_sum": 90, "rating_count": 20})
    assert daily.score(**{**base, "rating_sum": 100, "rating_count": 100}) < baseline
    assert daily.score(**{**base, "races": 10**12, "recent_players": 10**12,
        "lifetime_players": 10**12, "replays": 10**12}) <= 1_000_000


def test_mix_deduplicates_and_spreads_creators_and_biomes():
    items = [{"track_id": str(n), "owner_id": str(n % 40), "theme": str(n % 5),
        "score": 1000 - n, "rotation": str(n).zfill(3), "unseen": True} for n in range(200)]
    pools = {lane: daily.retain(items, lane) for lane in ("ranked", "fresh", "explore")}
    result = daily.select_mix(pools)
    assert len({i["track_id"] for i in result}) == daily.SIZE
    assert max(sum(i["owner_id"] == str(n) for i in result) for n in range(40)) <= 3
    assert {lane: sum(i["reason"] == lane for i in result) for lane in pools} == {
        "ranked": 60, "fresh": 20, "explore": 20}
    assert len({i["theme"] for i in result}) == 5
    assert len(daily.retain(items * 20, "ranked")) <= daily.POOL


def test_daily_publication_stable_resumable_and_rotates(indexed):
    d = indexed
    stamp = int(time.time())
    daily.step(d.app.state.session_factory, clock=stamp)
    with d.app.state.session_factory() as db:
        job = db.get(DiscoveryDay, stamp // daily.DAY)
        assert not job.published_at and len(job.pools["ranked"]) <= daily.BATCH
    first = build(d, stamp)
    assert len(first) == len({i["track_id"] for i in first}) == daily.SIZE
    with d.app.state.session_factory() as db:
        db.execute(update(DiscoveryHead).values(activity_races=5000, activity_replays=4000))
        db.commit()
    assert build(d, stamp + 1) == first
    tomorrow = build(d, stamp + daily.DAY)
    assert {i["track_id"] for i in tomorrow} != {i["track_id"] for i in first}
    assert any(i["reason"] == "explore" and i["track_id"] not in {x["track_id"] for x in first} for i in tomorrow)


def test_daily_pages_search_full_catalogue_and_bounded_sql(indexed):
    d = indexed
    selected = build(d)
    first = page = browse(d, {"feed": "daily"})
    found = []
    while True:
        found.extend(i["track_id"] for i in page["items"])
        if not page["next_cursor"]:
            break
        page = browse(d, cursor=page["next_cursor"])
    assert found == [i["track_id"] for i in selected]
    assert browse(d, cursor=first["page_cursor"])["items"] == first["items"]
    missing = next(i for i, t in enumerate(d.tracks) if t["id"] not in found)
    result = browse(d, {"feed": "daily", "search": d.versions[missing]["name"]})
    assert [i["track_id"] for i in result["items"]] == [d.tracks[missing]["id"]]
    assert len(browse(d, {"feed": "daily", "theme": "pine"})["items"]) == 20
    statements = []
    def capture(_c, _cursor, sql, *_args):
        statements.append(sql.lower())
    event.listen(d.app.state.engine, "before_cursor_execute", capture)
    try:
        browse(d, cursor=first["next_cursor"])
    finally:
        event.remove(d.app.state.engine, "before_cursor_execute", capture)
    assert not any("from runs" in s or "count(" in s or "discovery_entries" in s for s in statements)


def test_daily_hiding_blocks_and_random_use_current_authority(indexed, sign_in):
    d = indexed
    build(d)
    first = browse(d, {"feed": "daily"})
    hidden = first["items"][0]["track_id"]
    with d.app.state.session_factory() as db:
        db.execute(update(Track).where(Track.id == hidden).values(hidden=True))
        db.commit()
    assert hidden not in [i["track_id"] for i in browse(d, cursor=first["page_cursor"])["items"]]
    response = d.client.post("/v1/discovery/v3/random", json={"cursor": first["page_cursor"]})
    assert response.status_code == 200
    assert response.json()["items"][0]["track_id"] != hidden
    random_id = response.json()["items"][0]["version_id"]
    anchored = browse(d, {"feed": "daily"}, locate_version=random_id)
    assert anchored["anchored"] and anchored["items"][0]["version_id"] == random_id
    reader = sign_in("Daily reader")
    headers = {"Authorization": "Bearer " + reader["access_token"]}
    assert d.client.put("/v1/community/blocks/" + d.owner, headers=headers).status_code == 200
    blocked = d.client.post("/v1/discovery/v3/tracks", json={"query": {"feed": "daily"}}, headers=headers)
    assert blocked.status_code == 200 and not blocked.json()["items"]
    with d.app.state.session_factory() as db:
        db.execute(update(Player).where(Player.id == d.owner).values(disabled=True))
        db.commit()
    assert not browse(d, cursor=first["page_cursor"])["items"]


def test_ranking_uses_verified_signals_and_edit_does_not_renew_freshness(indexed):
    d = indexed
    stamp = int(time.time())
    with d.app.state.session_factory() as db:
        db.execute(update(Track).values(created_at=stamp - 40 * daily.DAY))
        db.execute(update(TrackVersion).values(created_at=stamp, published_at=stamp))
        db.execute(update(TrackVersion).where(TrackVersion.id == d.versions[179]["id"])
            .values(rating_sum=475, rating_count=100))
        db.execute(update(DiscoveryHead).where(DiscoveryHead.track_id == d.tracks[179]["id"])
            .values(popularity=500, activity_races=2000, activity_replays=1500))
        db.commit()
    settle_for_diagnostics(d.app.state.session_factory, clock=stamp + 61)
    selected = build(d, stamp + 61)
    assert selected[0]["track_id"] == d.tracks[179]["id"]
    assert not any(i["reason"] == "fresh" for i in selected)


def test_rollover_uses_yesterday_until_published_and_preserves_open_cursor(indexed, monkeypatch):
    from bmt_backend import discovery_v3
    d = indexed
    stamp = int(time.time())
    original = build(d, stamp)
    tomorrow = (stamp // daily.DAY + 1) * daily.DAY + 1
    monkeypatch.setattr(discovery_v3, "now", lambda: tomorrow)
    # Health remains current in this isolated future-clock fixture.
    settle_for_diagnostics(d.app.state.session_factory, clock=tomorrow)
    with d.app.state.session_factory() as db:
        db.execute(update(DiscoveryPartition).values(checked_at=tomorrow * 1_000_000_000))
        db.commit()
    first = browse(d, {"feed": "daily"})
    assert [i["track_id"] for i in first["items"]] == [i["track_id"] for i in original[:20]]
    build(d, tomorrow)
    assert browse(d, cursor=first["page_cursor"])["items"] == first["items"]
    fresh = browse(d, {"feed": "daily"})
    assert fresh["page_cursor"] != first["page_cursor"]


def test_empty_selection_is_valid_but_unbuilt_selection_is_retryable(indexed):
    d = indexed
    result = d.client.post("/v1/discovery/v3/tracks", json={"query": {"feed": "daily"}})
    assert result.status_code == 503 and result.json()["detail"] == "DISCOVERY_DAILY_PREPARING"
    assert "retry-after" in result.headers
    with d.app.state.session_factory() as db:
        db.execute(update(Track).values(hidden=True))
        db.commit()
    build(d)
    assert not browse(d, {"feed": "daily"})["items"]


def test_rollback_invalidates_only_daily_cursors_and_preserves_sources(indexed):
    d = indexed
    build(d)
    browse(d, {"feed": "daily"})
    browse(d, {"sort": "name"})
    engine = d.app.state.engine
    command.downgrade(configuration(engine), "0063_custom_challenge_tracks")
    with d.app.state.session_factory() as db:
        views = list(db.scalars(select(DiscoverySession)))
        assert len(views) == 1 and "daily_day" not in views[0].query
        assert db.scalar(select(func.count()).select_from(Track)) == 180
        assert db.scalar(select(func.count()).select_from(TrackVersion)) == 180
    command.upgrade(configuration(engine), "head")
    assert len(browse(d, {"sort": "name"})["items"]) == 20


def test_real_activity_caps_replays_excludes_owner_and_nonpublic_runs(indexed, sign_in):
    d = indexed
    driver = sign_in("Daily driver")["player"]["id"]
    finish(d, driver, count=12)
    finish(d, d.owner, count=4)
    finish(d, driver, count=2, purpose={"purpose": "creator_test"})
    finish(d, driver, count=2, purpose={"test_population": True})
    settle_for_diagnostics(d.app.state.session_factory)
    assert activity(d) == (5, 4)
    settle_for_diagnostics(d.app.state.session_factory)
    assert activity(d) == (5, 4)
    with d.app.state.session_factory() as db:
        assert db.scalar(select(func.count()).select_from(DiscoveryActivity)) == 1


def test_activity_expiry_restriction_restore_and_erasure(indexed, sign_in):
    d = indexed
    driver = sign_in("Returning driver")["player"]["id"]
    stamp = int(time.time())
    finish(d, driver, count=3, stamp=stamp - 1)
    settle_for_diagnostics(d.app.state.session_factory, clock=stamp)
    assert activity(d) == (3, 2)
    with d.app.state.session_factory() as db:
        db.get(Player, driver).disabled = True
        db.commit()
    settle_for_diagnostics(d.app.state.session_factory, clock=stamp)
    assert activity(d) == (0, 0)
    with d.app.state.session_factory() as db:
        db.get(Player, driver).disabled = False
        db.commit()
    settle_for_diagnostics(d.app.state.session_factory, clock=stamp)
    assert activity(d) == (3, 2)
    settle_for_diagnostics(d.app.state.session_factory, clock=stamp + 7 * daily.DAY)
    assert activity(d) == (0, 0)
    finish(d, driver, count=2, stamp=stamp + 7 * daily.DAY)
    settle_for_diagnostics(d.app.state.session_factory, clock=stamp + 7 * daily.DAY)
    assert activity(d) == (2, 1)
    with d.app.state.session_factory() as db:
        db.get(Player, driver).deleted_at = stamp
        db.get(Player, driver).disabled = True
        db.commit()
    for _ in range(100):
        with d.app.state.session_factory() as db:
            done = erase_private(db, driver, limit=5)
            db.commit()
        if done:
            break
    assert done and activity(d) == (0, 0)
