"""The daily hundred lead a complete, stable, bounded Free Race catalogue."""
import time
import uuid

from alembic import command
from sqlalchemy import event, func, inspect, select, update
from test_discovery_daily import build, finish
from test_discovery_paging import auth_app as auth_app_fixture
from test_discovery_v3 import browse
from test_discovery_v3 import indexed as indexed_fixture

from bmt_backend.discovery_models import DiscoveryEntry, DiscoveryHead, DiscoveryPartition, DiscoverySession
from bmt_backend.discovery_projection import settle_for_diagnostics
from bmt_backend.migrate import configuration
from bmt_backend.track_models import Track, TrackVersion

auth_app = auth_app_fixture
indexed = indexed_fixture


def collect(d, first=None):
    page = first or browse(d, {"feed": "daily"})
    pages = []
    for _ in range(40):
        assert len(page["items"]) <= 20
        pages.append(page)
        if not page["has_more"]:
            break
        page = browse(d, cursor=page["next_cursor"])
    else:
        raise AssertionError("Finite fixture catalogue did not terminate")
    ids = [i["track_id"] for p in pages for i in p["items"]]
    assert len(ids) == len(set(ids))
    return pages, ids


def tail_order(d, selected):
    with d.app.state.session_factory() as db:
        return list(db.scalars(select(DiscoveryEntry.track_id).where(DiscoveryEntry.until.is_(None),
            DiscoveryEntry.track_id.not_in([i["track_id"] for i in selected]))
            .order_by(DiscoveryEntry.recommendation_score.desc(), DiscoveryEntry.track_id.desc())))


def test_boundary_revisit_and_continuation_sql_remain_bounded(indexed):
    d = indexed
    selected = build(d)
    pages, ids = collect(d)
    assert ids[:100] == [i["track_id"] for i in selected]
    assert ids[100:] == tail_order(d, selected)
    assert len(ids) == 180 and len(pages) == 9
    assert pages[4]["has_more"] and pages[5]["items"]
    assert browse(d, cursor=pages[5]["previous_cursor"])["items"] == pages[4]["items"]
    statements = []
    def capture(_conn, _cursor, sql, *_):
        statements.append(sql.lower())
    event.listen(d.app.state.engine, "before_cursor_execute", capture)
    try:
        assert browse(d, cursor=pages[5]["page_cursor"])["items"] == pages[5]["items"]
    finally:
        event.remove(d.app.state.engine, "before_cursor_execute", capture)
    assert not any("from runs" in s or "count(" in s for s in statements)
    assert sum("select" in s and "discovery_entries" in s for s in statements) == 1
    with d.app.state.session_factory() as db:
        assert all("ids" not in view.query and "version_ids" not in view.query
            for view in db.scalars(select(DiscoverySession)))


def test_partial_daily_page_blends_into_tail_and_skips_current_hides(indexed):
    d = indexed
    selected = build(d)
    remaining = tail_order(d, selected)
    hidden = [i["track_id"] for i in selected[:7]] + remaining[:4]
    with d.app.state.session_factory() as db:
        db.execute(update(Track).where(Track.id.in_(hidden)).values(hidden=True))
        db.commit()
    pages, ids = collect(d)
    assert len(ids) == 180 - len(hidden)
    assert ids[:93] == [i["track_id"] for i in selected[7:]]
    assert ids[93:] == remaining[4:]
    assert len(pages[4]["items"]) == 20 # Thirteen daily picks plus seven continuation cards.
    assert browse(d, cursor=pages[5]["previous_cursor"])["items"] == pages[4]["items"]


def test_hidden_daily_section_does_not_hide_available_tail(indexed):
    d = indexed
    selected = build(d)
    remaining = tail_order(d, selected)
    survivor = remaining[-1]
    with d.app.state.session_factory() as db:
        db.execute(update(Track).where(Track.id != survivor).values(hidden=True))
        db.commit()
    pages, ids = collect(d)
    assert ids == [survivor] and not pages[0]["has_more"]


def test_open_view_freezes_tail_rank_and_new_revisions_never_repeat_daily_tracks(indexed):
    d = indexed
    selected = build(d)
    expected = tail_order(d, selected)
    first = browse(d, {"feed": "daily"})
    target = expected[-1]
    with d.app.state.session_factory() as db:
        db.execute(update(TrackVersion).where(TrackVersion.track_id == target)
            .values(rating_sum=5000, rating_count=1000))
        db.execute(update(DiscoveryHead).where(DiscoveryHead.track_id == target)
            .values(popularity=1000, activity_races=5000, activity_replays=4000))
        # A curated track is excluded by logical ID even after its latest
        # revision changes, while the first hundred retain the pinned revision.
        db.add(TrackVersion(id=str(uuid.uuid4()), track_id=selected[0]["track_id"], number=2,
            name="New curated revision", content_hash="b" * 64, manifest={},
            discovery={"theme": "pine", "points": []}, state="published", published_at=int(time.time())))
        db.commit()
    settle_for_diagnostics(d.app.state.session_factory, clock=int(time.time()) + 61)
    _, original = collect(d, first)
    assert original[100:] == expected
    fresh_pages, fresh = collect(d)
    assert fresh[:100] == original[:100] and fresh[100] == target
    assert len(fresh) == len(set(fresh)) == 180
    assert fresh_pages[0]["items"][0]["version_id"] == selected[0]["version_id"]


def test_rank_migration_preserves_sources_and_waits_for_bounded_backfill(indexed):
    d = indexed
    build(d)
    ordinary = browse(d, {"sort": "name"})
    browse(d, {"feed": "daily"})
    engine = d.app.state.engine
    command.downgrade(configuration(engine), "0066_cost_archives")
    with d.app.state.session_factory() as db:
        assert db.scalar(select(func.count()).select_from(Track)) == 180
        assert all("daily_day" not in view.query for view in db.scalars(select(DiscoverySession)))
    command.upgrade(configuration(engine), "head")
    assert "ix_discovery_entry_recommended" in {i["name"] for i in inspect(engine).get_indexes("discovery_entries")}
    with d.app.state.session_factory() as db:
        assert not any(db.scalars(select(DiscoveryPartition.ready)))
    # An already-open name cursor can still use its retained history.
    assert browse(d, cursor=ordinary["page_cursor"])["items"] == ordinary["items"]
    preparing = d.client.post("/v1/discovery/v3/tracks", json={"query": {"feed": "daily"}})
    assert preparing.status_code == 503 and preparing.json()["detail"] == "DISCOVERY_INDEX_PREPARING"
    settle_for_diagnostics(d.app.state.session_factory)
    _, ids = collect(d)
    assert len(ids) == 180


def test_repeat_races_refresh_composite_rank_without_a_new_unique_player(indexed, sign_in):
    d = indexed
    stamp = int(time.time())
    driver = sign_in("Repeat racer")["player"]["id"]
    finish(d, driver, stamp=stamp - 1)
    settle_for_diagnostics(d.app.state.session_factory, clock=stamp)
    settle_for_diagnostics(d.app.state.session_factory, clock=stamp + 61)
    def current_score():
        with d.app.state.session_factory() as db:
            return db.scalar(select(DiscoveryEntry.recommendation_score).where(
                DiscoveryEntry.track_id == d.tracks[0]["id"], DiscoveryEntry.until.is_(None)))
    first_score = current_score()
    finish(d, driver, count=2, stamp=stamp - 1)
    settle_for_diagnostics(d.app.state.session_factory, clock=stamp + 62)
    settle_for_diagnostics(d.app.state.session_factory, clock=stamp + 123)
    assert current_score() > first_score
    with d.app.state.session_factory() as db:
        assert db.get(DiscoveryHead, d.tracks[0]["id"]).popularity == 1
