"""Global UTC authority, permanent novelty, startup exhaustion and safe reads."""
import time
import uuid
from concurrent.futures import ThreadPoolExecutor

from alembic import command
from sqlalchemy import event, func, inspect, select, update
from test_discovery_paging import auth_app as auth_app_fixture
from test_discovery_v3 import indexed as indexed_fixture

from bmt_backend import track_of_day as daily
from bmt_backend.discovery_models import DiscoveryEntry, TrackOfDay, TrackOfDayHistory, TrackOfDayState
from bmt_backend.discovery_projection import settle_for_diagnostics
from bmt_backend.identity_models import Player
from bmt_backend.migrate import configuration, upgrade
from bmt_backend.track_models import Track, TrackVersion

auth_app = auth_app_fixture
indexed = indexed_fixture


def build(d, day=None):
    day = int(time.time()) // daily.DAY if day is None else day
    daily.step(d.app.state.session_factory, clock=day * daily.DAY + 10)
    with d.app.state.session_factory() as db:
        return db.get(TrackOfDay, day)


def small(d, size=3):
    with d.app.state.session_factory() as db:
        db.execute(update(Track).where(Track.id.not_in([t["id"] for t in d.tracks[:size]])).values(hidden=True))
        db.commit()


def test_pool_is_random_union_of_top_and_trending_with_unseen_before_limit(indexed, monkeypatch):
    d = indexed
    with d.app.state.session_factory() as db:
        for i, track in enumerate(d.tracks):
            db.execute(update(DiscoveryEntry).where(DiscoveryEntry.track_id == track["id"])
                .values(recommendation_score=1000-i, popularity=i))
        db.commit()
        pool = daily.candidates(db)
        assert {p["track_id"] for p in pool} == {t["id"] for t in d.tracks[:50]+d.tracks[-50:]}
        assert {p["reason"] for p in pool} == {"top", "trending"}
        for item in pool:
            db.add(TrackOfDayHistory(track_id=item["track_id"], first_day=1, last_day=1))
        db.commit()
        second = daily.candidates(db)
        assert {p["track_id"] for p in second} == {t["id"] for t in d.tracks[50:-50]}
    called = []
    def choose(items):
        called.append(items)
        return items[-1]
    monkeypatch.setattr(daily.secrets, "choice", choose)
    chosen = build(d)
    assert called and chosen.track_id == called[0][-1]["track_id"]


def test_one_day_is_atomic_across_workers_and_persistent_across_restarts(indexed):
    d = indexed
    with ThreadPoolExecutor(max_workers=4) as workers:
        results = list(workers.map(lambda _: daily.step(d.app.state.session_factory), range(4)))
    assert results.count(True) == 1
    first = build(d)
    assert build(d).version_id == first.version_id
    with d.app.state.session_factory() as db:
        assert db.scalar(select(func.count()).select_from(TrackOfDay)) == 1
        assert db.scalar(select(func.count()).select_from(TrackOfDayHistory)) == 1
    assert not daily.step(d.app.state.session_factory, clock=(first.day-1)*daily.DAY)


def test_permanent_history_and_mature_catalogue_never_repeat(indexed):
    d = indexed
    first = build(d)
    with d.app.state.session_factory() as db:
        assert db.get(TrackOfDayState, 1).mature
        for track in d.tracks:
            if track["id"] != first.track_id:
                db.add(TrackOfDayHistory(track_id=track["id"], first_day=first.day-400, last_day=first.day-400))
        db.commit()
    assert build(d, first.day+400).reason == "exhausted"
    # A later supply drop cannot re-enable the startup exception.
    small(d)
    assert build(d, first.day+401).track_id is None
    with d.app.state.session_factory() as db:
        assert db.get(TrackOfDayHistory, first.track_id).first_day == first.day


def test_startup_uses_all_unseen_tracks_before_least_recent_repeat_and_new_supply(indexed):
    d = indexed
    small(d)
    first = build(d)
    picks = [first] + [build(d, first.day+i) for i in (1, 2)]
    assert len({p.track_id for p in picks}) == 3
    repeat = build(d, first.day+3)
    assert repeat.reason == "startup_repeat" and repeat.track_id == first.track_id
    with d.app.state.session_factory() as db:
        db.execute(update(Track).where(Track.id == d.tracks[3]["id"]).values(hidden=False))
        db.commit()
    assert build(d, first.day+4).track_id == d.tracks[3]["id"]


def test_revisions_do_not_reset_history_and_day_pins_revision(indexed):
    d = indexed
    first = build(d)
    with d.app.state.session_factory() as db:
        old = db.get(TrackVersion, first.version_id)
        revised = TrackVersion(id=str(uuid.uuid4()), track_id=old.track_id, number=2,
            name="Revised daily", content_hash=old.content_hash, manifest={}, discovery=old.discovery,
            state="published", published_at=int(time.time())+1)
        db.add(revised)
        db.commit()
    settle_for_diagnostics(d.app.state.session_factory, clock=int(time.time())+61)
    assert build(d).version_id == first.version_id
    with d.app.state.session_factory() as db:
        assert first.track_id not in {p["track_id"] for p in daily.candidates(db)}


def test_api_global_selection_blocks_moderation_rollover_and_no_old_fallback(indexed, sign_in, monkeypatch):
    d = indexed
    preparing = d.client.get("/v1/track-of-the-day")
    assert preparing.status_code == 503 and preparing.headers["retry-after"] == "30"
    chosen = build(d)
    first = d.client.get("/v1/track-of-the-day")
    assert first.status_code == 200 and first.headers["cache-control"] == "private, no-store"
    assert first.json()["track"]["version_id"] == chosen.version_id
    login = sign_in("Daily reader")
    headers = {"Authorization": "Bearer " + login["access_token"]}
    assert d.client.get("/v1/track-of-the-day", headers=headers).json()["track"] == first.json()["track"]
    assert d.client.put("/v1/community/blocks/"+d.owner, headers=headers).status_code == 200
    assert d.client.get("/v1/track-of-the-day", headers=headers).json()["track"] is None
    with d.app.state.session_factory() as db:
        db.execute(update(Track).where(Track.id == chosen.track_id).values(hidden=True))
        db.commit()
    assert d.client.get("/v1/track-of-the-day").json()["status"] == "unavailable"
    assert build(d).track_id == chosen.track_id # Never silently replace a published pick.
    monkeypatch.setattr(daily, "now", lambda: (chosen.day+1)*daily.DAY)
    assert d.client.get("/v1/track-of-the-day").status_code == 503


def test_empty_disabled_and_test_owners_are_ineligible(indexed):
    d = indexed
    with d.app.state.session_factory() as db:
        db.execute(update(Player).where(Player.id == d.owner).values(is_test_driver=True))
        db.commit()
    assert build(d).reason == "empty"
    with d.app.state.session_factory() as db:
        db.execute(update(Player).where(Player.id == d.owner).values(is_test_driver=False, disabled=True))
        db.commit()
    assert build(d, int(time.time())//daily.DAY+1).reason == "empty"


def test_migration_rollback_preserves_tracks_and_discovery(indexed):
    d = indexed
    build(d)
    command.downgrade(configuration(d.app.state.engine), "0067_discovery_rank")
    tables = inspect(d.app.state.engine).get_table_names()
    assert "track_of_days" not in tables and "discovery_days" in tables
    with d.app.state.session_factory() as db:
        assert db.scalar(select(func.count()).select_from(Track)) == 180
    upgrade(d.app.state.engine)
    assert build(d).track_id


def test_one_track_startup_and_supply_growth_permanently_close_exception(indexed):
    d = indexed
    small(d, 1)
    first = build(d)
    assert build(d, first.day+1).track_id == first.track_id
    with d.app.state.session_factory() as db:
        db.execute(update(Track).values(hidden=False))
        db.commit()
    assert build(d, first.day+2).track_id != first.track_id
    with d.app.state.session_factory() as db:
        assert db.get(TrackOfDayState, 1).mature
    small(d, 1)
    assert build(d, first.day+3).reason == "exhausted"


def test_http_read_does_not_select_rankings_or_write_selection(indexed):
    d = indexed
    build(d)
    statements = []
    def capture(_connection, _cursor, sql, *_args):
        statements.append(sql.lower())
    event.listen(d.app.state.engine, "before_cursor_execute", capture)
    try:
        assert d.client.get("/v1/track-of-the-day").status_code == 200
    finally:
        event.remove(d.app.state.engine, "before_cursor_execute", capture)
    assert not any("discovery_entries" in sql or "from runs" in sql for sql in statements)
    assert not any("insert into track_of" in sql or "update track_of" in sql for sql in statements)
