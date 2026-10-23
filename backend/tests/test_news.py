"""News correctness, explicit demand, query bounds and privacy on both databases."""
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier, Event

import pytest
from alembic import command
from sqlalchemy import delete, event, func, select, text
from test_domains import domain as domain_fixture
from test_domains import headers, public_course, race, upload

from bmt_backend import news
from bmt_backend.community_models import PlayerBlock
from bmt_backend.identity_models import Player
from bmt_backend.migrate import configuration, upgrade
from bmt_backend.news_models import (
    Friendship,
    NewsBands,
    NewsDemand,
    NewsItem,
    NewsPublication,
    NewsWatch,
    TrackRacer,
    TrackReach,
)
from bmt_backend.track_models import (
    Board,
    LapPersonalBest,
    PersonalBest,
    Run,
    RunTicket,
    Track,
    TrackVersion,
    now,
)

domain = domain_fixture


def get(domain, player="Creator", path="/v1/news"):
    result = domain.client.get(path, headers=headers(domain, player))
    assert result.status_code == 200, result.text
    return result.json()


def refresh(domain, player="Alice"):
    result = domain.client.post("/v1/news/refresh", headers=headers(domain, player))
    assert result.status_code == 200, result.text
    return result.json()


def befriend(domain):
    response = domain.client.post("/v1/news/friends", json={"name": "  bOB "}, headers=headers(domain, "Alice"))
    assert response.status_code == 200, response.text
    response = domain.client.put("/v1/news/friends/" + domain.players["Alice"], headers=headers(domain, "Bob"))
    assert response.status_code == 200, response.text


def kinds(domain, kind, player="Creator"):
    return [row for row in get(domain, player)["items"] if row["kind"] == kind]


def test_verified_records_are_atomic_best_only_and_ties_silent(domain):
    version, board = public_course(domain)
    race(domain, version, "Alice", frames=20)
    assert {r["metric"] for r in kinds(domain, "world_record")} == {"race", "lap"}
    race(domain, version, "Bob", frames=20)
    race(domain, version, "Alice", frames=30)
    assert len(kinds(domain, "world_record")) == 2
    race(domain, version, "Bob", frames=15)
    rows = kinds(domain, "world_record")
    assert len(rows) == 4
    assert all(r["actor_name"] == "Bob" for r in rows if r["time_ticks"] in (15, 75))
    with domain.factory() as session:
        assert session.get(TrackReach, session.get(TrackVersion, version["version_id"]).track_id).racers == 3
        before = session.scalar(select(func.count()).select_from(NewsItem))
        news.emit(session, domain.players["Creator"], ["rolled-back"], "world_record", version["version_id"])
        session.rollback()
        assert session.scalar(select(func.count()).select_from(NewsItem)) == before
        assert session.get(PersonalBest, (board, domain.players["Bob"])).time_ticks == 75


def test_track_milestone_is_lifetime_distinct_and_never_reannounced(domain):
    version, board = public_course(domain)
    with domain.factory() as session:
        track_id = session.get(TrackVersion, version["version_id"]).track_id
        session.add(TrackReach(track_id=track_id, racers=99, milestone=0))
        session.commit()
    race(domain, version, "Alice", frames=20)
    assert [r["count"] for r in kinds(domain, "milestone")] == [100]
    race(domain, version, "Alice", frames=15)
    with domain.factory() as session:
        assert session.get(TrackReach, track_id).racers == 100
        assert session.scalar(select(func.count()).select_from(TrackRacer).where(TrackRacer.track_id == track_id)) == 1
        ordinary = session.get(Board, board)
        second = Board(id="f" * 64, version_id=ordinary.version_id, vehicle_id="other",
                       manifest=ordinary.manifest)
        session.add(second)
        session.flush()
        fact = RunTicket(player_id=domain.players["Alice"], board_id=second.id, expires_at=now() + 3600)
        session.add(fact); session.flush()
        run = Run(ticket_id=fact.id, player_id=fact.player_id, board_id=second.id, status="verified",
                  replay_hash="0" * 64, time_ticks=50, lap_ticks=[10]*5, finished_at=now())
        session.add(run); session.flush()
        session.add(PersonalBest(board_id=second.id, player_id=run.player_id, run_id=run.id, time_ticks=50))
        session.flush()
        news.capture_verified(session, run, second, session.get(TrackVersion, second.version_id),
                              session.get(Track, track_id), session.get(Player, run.player_id))
        session.commit()
        assert session.get(TrackReach, track_id).racers == 100
    assert len(kinds(domain, "milestone")) == 1


def test_no_demand_no_work_and_feed_reads_do_not_queue(domain):
    version, _ = public_course(domain)
    race(domain, version, "Alice", frames=20)
    get(domain, "Alice")
    assert not news.process_requested(domain.app)
    with domain.factory() as session:
        assert session.scalar(select(func.count()).select_from(NewsDemand)) == 0
        assert session.scalar(select(func.count()).select_from(NewsWatch)) == 0
    statements = []
    def observe(conn, cursor, sql, parameters, context, many):
        statements.append(sql.lower())
    event.listen(domain.app.state.engine, "before_cursor_execute", observe)
    try:
        assert not news.process_requested(domain.app)
    finally:
        event.remove(domain.app.state.engine, "before_cursor_execute", observe)
    assert len(statements) == 1
    assert "personal_bests" not in statements[0]


def test_newspaper_outline_reuses_one_bounded_page_query(domain):
    version, _ = public_course(domain)
    with domain.factory() as session:
        stored = session.get(TrackVersion, version["version_id"])
        stored.discovery = {"theme": "pine", "points": [[i, i * 2, "discard"] for i in range(300)]}
        for index in range(3):
            news.emit(session, domain.players["Creator"], ["paper", index], "milestone", stored.id, count=100)
        session.commit()
        player = session.get(Player, domain.players["Creator"])
        statements = []
        def observe(conn, cursor, sql, parameters, context, many):
            statements.append(sql.lower())
        event.listen(domain.app.state.engine, "before_cursor_execute", observe)
        try:
            payload = news.feed(session, player, "")
        finally:
            event.remove(domain.app.state.engine, "before_cursor_execute", observe)
        assert len(payload["items"]) == 4
        assert sum(item["kind"] == "track_published" for item in payload["items"]) == 1
        assert list(payload["tracks"]) == [stored.id]
        outline = payload["tracks"][stored.id]
        assert outline["available"] and len(outline["points"]) == 96
        assert all(len(p) == 2 for p in outline["points"])
        assert outline["points"][0] == [0, 0]
        assert len(statements) == 3  # Inbox page, bounded friend roster, demand status.
        assert not any("track_versions.manifest" in sql or "personal_bests" in sql for sql in statements)
        assert not news.process_requested(domain.app)
        stored.discovery = {"points": [[None, 1], [1e9, 0], "bad"]}
        session.commit()
        assert news.feed(session, player, "")["tracks"][stored.id]["points"] == []


def test_expired_request_is_not_processed_and_once_daily_is_server_enforced(domain, monkeypatch):
    version, _ = public_course(domain)
    race(domain, version, "Alice", frames=20)
    stamp = now()
    monkeypatch.setattr(news, "now", lambda: stamp)
    assert refresh(domain)["refreshing"]
    assert not news.process_requested(domain.app, clock=stamp + news.DEMAND_SECONDS + 1)
    assert news.process_requested(domain.app, clock=stamp)
    assert not refresh(domain)["refreshing"]
    assert not news.process_requested(domain.app, clock=stamp)
    stamp += 86400
    assert not news.process_requested(domain.app, clock=stamp) # No automatic tomorrow job.
    assert refresh(domain)["refreshing"]
    assert news.process_requested(domain.app, clock=stamp)


def test_friend_overtakes_both_metrics_and_percentile_only_after_baseline(domain, monkeypatch):
    version, _ = public_course(domain)
    race(domain, version, "Alice", frames=20)
    race(domain, version, "Bob", frames=30)
    befriend(domain)
    stamp = now()
    monkeypatch.setattr(news, "now", lambda: stamp)
    refresh(domain)
    assert news.process_requested(domain.app, clock=stamp)
    assert not kinds(domain, "friend_overtake", "Alice")
    assert not kinds(domain, "percentile_drop", "Alice")
    race(domain, version, "Bob", frames=15)
    assert not refresh(domain)["refreshing"]
    stamp += 86400
    refresh(domain)
    assert news.process_requested(domain.app, clock=stamp)
    overtakes = kinds(domain, "friend_overtake", "Alice")
    assert {r["metric"] for r in overtakes} == {"race", "lap"}
    assert all(r["actor_name"] == "Bob" for r in overtakes)
    drops = kinds(domain, "percentile_drop", "Alice")
    assert {r["metric"] for r in drops} == {"race", "lap"}
    assert all(r["threshold"] == 40 for r in drops) # Creator also has a public result.
    stamp += 86400
    refresh(domain)
    assert news.process_requested(domain.app, clock=stamp)
    assert len(kinds(domain, "friend_overtake", "Alice")) == 2
    assert len(kinds(domain, "percentile_drop", "Alice")) == 2


def test_unchanged_board_reuses_cutoffs_and_skips_friend_queries(domain, monkeypatch):
    version, _ = public_course(domain)
    race(domain, version, "Alice", frames=20)
    befriend(domain)
    stamp = now()
    monkeypatch.setattr(news, "now", lambda: stamp)
    refresh(domain)
    news.process_requested(domain.app, clock=stamp)
    stamp += 86400
    refresh(domain)
    statements = []
    def observe(conn, cursor, sql, parameters, context, many):
        statements.append(sql.lower())
    event.listen(domain.app.state.engine, "before_cursor_execute", observe)
    try:
        assert news.process_requested(domain.app, clock=stamp)
    finally:
        event.remove(domain.app.state.engine, "before_cursor_execute", observe)
    assert not any("over (" in sql or "board_time_counts" in sql for sql in statements)
    assert not any("lap_personal_bests" in sql for sql in statements)


def test_mutual_friend_requests_are_private_and_blocked_actors_hidden(domain):
    version, _ = public_course(domain)
    race(domain, version, "Bob", frames=20)
    assert len(kinds(domain, "world_record")) == 2
    response = domain.client.post("/v1/news/friends", json={"name": "Bob"}, headers=headers(domain, "Alice"))
    assert response.json()["status"] == "sent"
    assert get(domain, "Bob", "/v1/news/friends")["items"][0]["status"] == "received"
    assert get(domain, "Carol", "/v1/news/friends")["items"] == []
    assert domain.client.put("/v1/news/friends/" + domain.players["Bob"], headers=headers(domain, "Alice")).status_code == 404
    domain.client.put("/v1/news/friends/" + domain.players["Alice"], headers=headers(domain, "Bob"))
    assert get(domain, "Alice", "/v1/news/friends")["items"][0]["status"] == "friends"
    with domain.factory() as session:
        session.add(PlayerBlock(player_id=domain.players["Creator"], blocked_id=domain.players["Bob"]))
        session.commit()
    assert kinds(domain, "world_record") == []
    response = domain.client.put("/v1/community/blocks/" + domain.players["Alice"], headers=headers(domain,"Bob"))
    assert response.status_code == 200
    with domain.factory() as session:
        assert session.scalar(select(func.count()).select_from(Friendship)) == 0
    assert get(domain, "Alice", "/v1/news/friends")["items"] == []
    assert domain.client.post("/v1/news/friends", json={"name": "Bob"}, headers=headers(domain, "Alice")).status_code == 404


def publish_as(domain, player="Bob"):
    version = upload(domain, player=player)
    race(domain, version, player=player, frames=60)
    response = domain.client.post(f"/v1/track-versions/{version['version_id']}/publish", headers=headers(domain, player))
    assert response.status_code == 200, response.text
    return version


def seed_publication(session, owner, at, name="New circuit"):
    track = Track(owner_id=owner.id)
    session.add(track); session.flush()
    version = TrackVersion(track_id=track.id, number=1, name=name, content_hash="0" * 64,
        manifest={}, discovery={"points": [[0, 0], [10, 0], [10, 20]]}, state="published", published_at=at)
    session.add(version); session.flush()
    news.capture_publication(session, version, track, owner)
    return version


def test_friend_first_publication_is_read_on_demand_without_inbox_fanout(domain):
    befriend(domain)
    version = publish_as(domain)
    assert not news.process_requested(domain.app)
    rows = kinds(domain, "friend_track", "Alice")
    assert len(rows) == 1 and rows[0]["version_id"] == version["version_id"]
    assert rows[0]["actor_id"] == domain.players["Bob"] and rows[0]["actor_name"] == "Bob"
    assert not kinds(domain, "friend_track", "Carol") and not kinds(domain, "friend_track", "Bob")
    # Same-day cached comparisons need not run again for another publication.
    from bmt_backend.commerce_models import Entitlements
    with domain.factory() as session:
        session.get(Entitlements, domain.players["Bob"]).slots += 1
        session.commit()
    second = publish_as(domain)
    assert {r["version_id"] for r in kinds(domain, "friend_track", "Alice")} == {version["version_id"], second["version_id"]}
    with domain.factory() as session:
        assert session.scalar(select(func.count()).select_from(NewsPublication)) == 2
        assert session.scalar(select(func.count()).select_from(NewsItem)) == 2
        assert set(session.scalars(select(NewsItem.player_id))) == {domain.players["Bob"]}
        assert session.scalar(select(func.count()).select_from(NewsDemand)) == 0
        stored = session.get(TrackVersion, version["version_id"])
        news.capture_publication(session, stored, session.get(Track, stored.track_id), session.get(Player, domain.players["Bob"]))
        session.commit()
        assert session.scalar(select(func.count()).select_from(NewsPublication)) == 2


def test_friend_publications_exclude_pending_old_hidden_removed_and_blocked(domain, monkeypatch):
    stamp = now()
    monkeypatch.setattr(news, "now", lambda: stamp)
    with domain.factory() as session:
        owner = session.get(Player, domain.players["Bob"])
        old = seed_publication(session, owner, stamp - 100)
        new = seed_publication(session, owner, stamp)
        pair = sorted((domain.players["Alice"], owner.id))
        friendship = Friendship(low_id=pair[0], high_id=pair[1], requested_by=domain.players["Alice"], created_at=stamp - 50)
        session.add(friendship); session.commit()
        new_id, track_id = new.id, new.track_id
    assert not kinds(domain, "friend_track", "Alice")
    befriend(domain)
    rows = kinds(domain, "friend_track", "Alice")
    assert [r["version_id"] for r in rows] == [new_id] and rows[0]["version_id"] != old.id
    with domain.factory() as session:
        track = session.get(Track, track_id)
        track.hidden = True; session.commit()
        assert not kinds(domain, "friend_track", "Alice")
        track.hidden = False; track.archived = True; session.commit()
        assert not kinds(domain, "friend_track", "Alice")
        track.archived = False
        session.get(Player, domain.players["Bob"]).disabled = True; session.commit()
        assert not kinds(domain, "friend_track", "Alice")
        session.get(Player, domain.players["Bob"]).disabled = False; session.commit()
    assert len(kinds(domain, "friend_track", "Alice")) == 1
    domain.client.delete("/v1/news/friends/" + domain.players["Bob"], headers=headers(domain, "Alice"))
    assert not kinds(domain, "friend_track", "Alice")
    befriend(domain)
    domain.client.put("/v1/community/blocks/" + domain.players["Alice"], headers=headers(domain, "Bob"))
    assert not kinds(domain, "friend_track", "Alice")


def test_new_revisions_and_rolled_back_publications_do_not_announce_tracks(domain):
    befriend(domain)
    with domain.factory() as session:
        owner = session.get(Player, domain.players["Bob"])
        first = seed_publication(session, owner, now())
        track = session.get(Track, first.track_id)
        revision = TrackVersion(track_id=track.id, number=2, name="Revised circuit", content_hash="1"*64,
            manifest={}, state="published", published_at=now())
        session.add(revision); session.flush()
        news.capture_publication(session, revision, track, owner)
        session.commit()
        assert session.scalar(select(func.count()).select_from(NewsPublication)) == 1
        # Even after expiry, another revision cannot recreate an announcement.
        session.execute(delete(NewsPublication)); session.flush()
        news.capture_publication(session, revision, track, owner)
        session.commit()
        assert session.scalar(select(func.count()).select_from(NewsPublication)) == 0
        seed_publication(session, owner, now())
        session.rollback()
        assert session.scalar(select(func.count()).select_from(NewsPublication)) == 0
    assert not kinds(domain, "friend_track", "Alice")


def test_friend_publications_merge_with_inbox_keyset_and_bounded_retention(domain):
    befriend(domain)
    stamp = now()
    with domain.factory() as session:
        owner = session.get(Player, domain.players["Bob"])
        for index in range(40):
            version = seed_publication(session, owner, stamp, f"Circuit {index}")
            if index < 35:
                news.emit(session, domain.players["Alice"], ["mix", index], "milestone", version.id, at=stamp, count=100)
        expired = seed_publication(session, owner, stamp - 91 * 86400)
        session.commit()
        expired_track = expired.track_id
    items, cursor = [], ""
    while True:
        payload = get(domain, "Alice", "/v1/news" + ("?cursor=" + cursor if cursor else ""))
        items.extend(payload["items"])
        cursor = payload["next_cursor"]
        if not cursor: break
    assert len(items) == len({r["id"] for r in items}) == 75
    assert sum(r["kind"] == "friend_track" for r in items) == 40
    assert [(r["created_at"], r["id"]) for r in items] == sorted(((r["created_at"], r["id"]) for r in items), reverse=True)
    with domain.factory() as session:
        assert news.cleanup_expired(session, stamp, limit=1) == 1
        session.commit()
        assert session.get(NewsPublication, expired_track) is not None
        assert news.cleanup_expired(session, stamp, limit=1) == 1
        session.commit()
        assert session.get(NewsPublication, expired_track) is None


def test_publication_reads_are_batched_at_the_full_friend_limit(domain):
    stamp = now()
    with domain.factory() as session:
        for index in range(news.FRIEND_LIMIT):
            owner = Player(display_name=f"Friend {index}")
            session.add(owner); session.flush()
            low, high = sorted((domain.players["Alice"], owner.id))
            session.add(Friendship(low_id=low, high_id=high, requested_by=owner.id, accepted=True, created_at=stamp-1))
            if index == 0:
                for _ in range(35): seed_publication(session, owner, stamp)
        session.commit()
        statements = []
        def observe(conn, cursor, sql, parameters, context, many): statements.append(sql.lower())
        event.listen(domain.app.state.engine, "before_cursor_execute", observe)
        try:
            rows = news.publication_page(session, domain.players["Alice"], None, stamp)
        finally:
            event.remove(domain.app.state.engine, "before_cursor_execute", observe)
        assert len(rows) == 31 and len(statements) == 2  # Roster plus one bounded union, never 100 roundtrips.
        assert statements[1].count("union all") == 99


def test_feed_keyset_pagination_private_scope_and_expiry(domain):
    version, _ = public_course(domain)
    stamp = now()
    with domain.factory() as session:
        for index in range(35):
            news.emit(session, domain.players["Alice"], [index], "milestone", version["version_id"], at=stamp, count=index)
        news.emit(session, domain.players["Alice"], ["expired"], "milestone", version["version_id"],
                  at=stamp - 91 * 86400, count=100)
        session.commit()
    page = get(domain, "Alice")
    assert len(page["items"]) == 30 and page["next_cursor"]
    rest = get(domain, "Alice", "/v1/news?cursor=" + page["next_cursor"])
    assert len(rest["items"]) == 5 and not rest["next_cursor"]
    assert len({r["id"] for r in page["items"] + rest["items"]}) == 35
    assert get(domain, "Bob")["items"] == []
    assert domain.client.get("/v1/news?cursor=bad", headers=headers(domain, "Alice")).status_code == 422
    with domain.factory() as session:
        assert news.cleanup_expired(session, stamp) == 1
        session.commit()


def test_tied_percentile_cutoffs_use_shared_rank_and_no_population_rounding(domain):
    version, board = public_course(domain)
    race(domain, version, "Alice", frames=20)
    race(domain, version, "Bob", frames=20)
    with domain.factory() as session:
        limits = news.cutoffs(session, board, PersonalBest)
        assert news.band(100, limits) == 40 # Shared first rank / 3 players (including creator).
        assert limits[0] is None # No top 1% claim in a two-player field.
        assert news.cutoffs(session, board, LapPersonalBest)[-1] == 60


def test_only_eight_boards_per_batch_and_resume_after_expiry(domain, monkeypatch):
    _version, source_board = public_course(domain)
    with domain.factory() as session:
        source = session.get(Board, source_board)
        for index in range(10):
            board = Board(id=f"{index:064x}", version_id=source.version_id, vehicle_id="compact", manifest=source.manifest)
            session.add(board); session.flush()
            ticket = RunTicket(player_id=domain.players["Alice"], board_id=board.id, expires_at=now() + 3600)
            session.add(ticket); session.flush()
            run = Run(ticket_id=ticket.id, board_id=board.id, player_id=ticket.player_id, status="verified",
                      replay_hash="0"*64, time_ticks=100, lap_ticks=[20]*5, finished_at=now())
            session.add(run); session.flush()
            session.add(PersonalBest(board_id=board.id, player_id=run.player_id, run_id=run.id, time_ticks=100))
        session.commit()
    stamp = now()
    monkeypatch.setattr(news, "now", lambda: stamp)
    refresh(domain)
    assert news.process_requested(domain.app, clock=stamp)
    with domain.factory() as session:
        assert session.scalar(select(func.count()).select_from(NewsWatch)) == news.BOARD_BATCH
        assert session.get(NewsDemand, domain.players["Alice"]).pending
    assert not news.process_requested(domain.app, clock=stamp + 601)
    stamp += 602
    refresh(domain)
    assert news.process_requested(domain.app, clock=stamp)
    with domain.factory() as session:
        assert session.scalar(select(func.count()).select_from(NewsWatch)) == 10
        assert not session.get(NewsDemand, domain.players["Alice"]).pending


def test_no_inactive_account_worker_scan_even_with_expired_demands(domain):
    with domain.factory() as session:
        for pid in domain.players.values():
            session.add(NewsDemand(player_id=pid, pending=True, requested_day=1, requested_until=100))
        session.commit()
    assert not news.process_requested(domain.app, clock=now())
    with domain.factory() as session:
        assert session.scalar(select(func.count()).select_from(NewsWatch)) == 0
        assert session.scalar(select(func.count()).select_from(NewsBands)) == 0


def test_deleted_public_record_still_prevents_false_world_records(domain):
    version, board = public_course(domain)
    race(domain, version, "Bob", frames=15)
    before = len(kinds(domain, "world_record"))
    with domain.factory() as session:
        session.get(Player, domain.players["Bob"]).deleted_at = now()
        session.commit()
    race(domain, version, "Alice", frames=20)
    assert len(kinds(domain, "world_record")) == before
    with domain.factory() as session:
        assert news.band(20, news.cutoffs(session, board, LapPersonalBest)) == 75


def test_shared_board_cutoffs_rebuilt_only_on_demand_once_daily(domain, monkeypatch):
    version, _ = public_course(domain)
    race(domain, version, "Alice", frames=20)
    race(domain, version, "Bob", frames=30)
    stamp = now()
    monkeypatch.setattr(news, "now", lambda: stamp)
    original = news.cutoffs
    calls = []
    def counted(*args):
        calls.append(args[2])
        return original(*args)
    monkeypatch.setattr(news, "cutoffs", counted)
    refresh(domain, "Alice")
    assert news.process_requested(domain.app, clock=stamp)
    race(domain, version, "Bob", frames=15)
    refresh(domain, "Bob")
    assert news.process_requested(domain.app, clock=stamp)
    assert len(calls) == 2 # One race + one lap aggregate, shared by both players.
    stamp += 86400
    assert not news.process_requested(domain.app, clock=stamp)
    assert len(calls) == 2
    refresh(domain, "Alice")
    assert news.process_requested(domain.app, clock=stamp)
    assert len(calls) == 4


def test_friend_limit_and_idempotent_requests(domain):
    with domain.factory() as session:
        for index in range(news.FRIEND_LIMIT):
            p = Player(display_name=f"Friend {index}")
            session.add(p); session.flush()
            low, high = sorted((domain.players["Alice"], p.id))
            session.add(Friendship(low_id=low, high_id=high, requested_by=p.id))
        session.commit()
    result = domain.client.post("/v1/news/friends", json={"name":"Bob"}, headers=headers(domain,"Alice"))
    assert result.status_code == 409 and result.json()["detail"] == "FRIEND_LIMIT_REACHED"
    with domain.factory() as session:
        assert session.scalar(select(func.count()).select_from(Friendship)) == news.FRIEND_LIMIT


def test_private_erasure_is_bounded_and_never_recreates_news(domain):
    version, _ = public_course(domain)
    alice = domain.players["Alice"]
    with domain.factory() as session:
        for index in range(205):
            news.emit(session, alice, ["private",index], "milestone", version["version_id"], count=100)
        news.emit(session, domain.players["Creator"], ["actor-private"], "world_record", version["version_id"], actor_id=alice)
        session.add(NewsDemand(player_id=alice))
        session.commit()
        for expected in (False, False, True):
            before = session.scalar(select(func.count()).select_from(NewsItem))
            assert news.erase_private(session, alice) is expected
            after = session.scalar(select(func.count()).select_from(NewsItem))
            assert before - after <= 100
            session.commit()
        assert session.get(NewsDemand, alice) is None
        assert session.scalar(select(NewsItem.actor_id).where(NewsItem.player_id == domain.players["Creator"])) is None
        session.get(Player, alice).deleted_at = now()
        session.commit()
        news.emit(session, alice, ["after-delete"], "milestone", version["version_id"], count=100)
        session.commit()
        assert session.scalar(select(func.count()).select_from(NewsItem).where(NewsItem.player_id == alice)) == 0


def test_migration_seeds_existing_racers_without_old_news(domain):
    version, _ = public_course(domain)
    race(domain, version, "Alice", frames=20)
    before = get(domain)["items"]
    assert before
    command.downgrade(configuration(domain.app.state.engine), "0037_earned_coins")
    upgrade(domain.app.state.engine)
    with domain.factory() as session:
        track = session.get(TrackVersion, version["version_id"]).track_id
        assert session.get(TrackReach, track).racers == 2 # Existing creator and Alice.
        assert session.scalar(select(func.count()).select_from(TrackRacer)) == 2
        assert session.scalar(select(func.count()).select_from(NewsItem)) == 0


def test_crossed_recipient_writes_do_not_deadlock(domain):
    if not domain.postgres:
        pytest.skip("PostgreSQL row-lock protocol")
    version, _ = public_course(domain)
    barrier = Barrier(2)
    def write(actor, recipient):
        with domain.factory() as session:
            session.scalar(select(Player).where(Player.id == actor).with_for_update(key_share=True))
            barrier.wait(timeout=10)
            news.emit(session, recipient, [actor, recipient], "world_record", version["version_id"], actor_id=actor)
            session.commit()
    with ThreadPoolExecutor(max_workers=2) as executor:
        first = executor.submit(write, domain.players["Alice"], domain.players["Bob"])
        second = executor.submit(write, domain.players["Bob"], domain.players["Alice"])
        first.result(timeout=20)
        second.result(timeout=20)
    assert len(get(domain,"Alice")["items"]) == len(get(domain,"Bob")["items"]) == 1


def test_recipient_deletion_wins_against_waiting_projection(domain):
    if not domain.postgres:
        pytest.skip("PostgreSQL row-lock protocol")
    version, _ = public_course(domain)
    started = Event()
    alice = domain.players["Alice"]
    def write():
        with domain.factory() as session:
            started.set()
            news.emit(session, alice, ["late"], "world_record", version["version_id"])
            session.commit()
    with ThreadPoolExecutor(max_workers=1) as executor:
        with domain.factory() as session:
            row = session.scalar(select(Player).where(Player.id == alice).with_for_update())
            row.deleted_at = now()
            session.flush()
            pending = executor.submit(write)
            assert started.wait(timeout=10)
            session.commit()
        pending.result(timeout=20)
    with domain.factory() as session:
        assert session.scalar(select(func.count()).select_from(NewsItem).where(NewsItem.player_id == alice)) == 0


def test_real_bearer_auth_and_account_erasure(auth_app, auth_client, sign_in):
    from test_privacy import auth, deletion_body, drain, seed

    assert auth_client.get("/v1/news").status_code == 401
    alice, bob = sign_in("News Alice"), sign_in("News Bob")
    version, board, *_ = seed(auth_app, alice)
    assert auth_client.post("/v1/news/friends", json={"name":"News Bob"}, headers=auth(alice)).status_code == 200
    assert auth_client.put("/v1/news/friends/" + alice["player"]["id"], headers=auth(bob)).status_code == 200
    assert auth_client.post("/v1/news/refresh", headers=auth(alice)).status_code == 200
    assert news.process_requested(auth_app)
    with auth_app.state.session_factory() as session:
        news.emit(session, alice["player"]["id"], ["private"], "milestone", version, count=100)
        news.emit(session, bob["player"]["id"], ["public-actor"], "world_record", version, actor_id=alice["player"]["id"])
        session.commit()
    assert auth_client.post("/v1/privacy/account-deletion", json=deletion_body(), headers=auth(alice)).status_code == 202
    drain(auth_app)
    assert auth_client.get("/v1/news", headers=auth(alice)).status_code == 401
    assert auth_client.get("/v1/news/friends", headers=auth(bob)).json()["items"] == []
    with auth_app.state.session_factory() as session:
        aid = alice["player"]["id"]
        assert session.get(NewsDemand, aid) is None
        assert session.get(NewsWatch, (aid,board)) is None
        assert session.scalar(select(func.count()).select_from(NewsItem).where(NewsItem.player_id == aid)) == 0
        assert session.scalar(select(NewsItem.actor_id).where(NewsItem.player_id == bob["player"]["id"])) is None
        assert session.get(PersonalBest, (board,aid)) is not None # Public historical score retained.


def test_feed_and_active_demand_have_indexed_access_paths(domain, record_property):
    queries = {
        "ix_news_publications_owner": "SELECT version_id FROM news_publications WHERE owner_id=:pid AND published_at>=:stamp ORDER BY published_at DESC,version_id DESC LIMIT 31",
        "ix_news_feed": "SELECT id FROM news_items WHERE player_id=:pid AND created_at>=:stamp ORDER BY created_at DESC,id DESC LIMIT 31",
        "ix_news_demand_active": "SELECT player_id FROM news_demand WHERE pending=true AND requested_until>=:stamp ORDER BY requested_until,player_id LIMIT 1",
        "ix_news_pb_player_board": "SELECT board_id FROM personal_bests WHERE player_id=:pid AND board_id>:board ORDER BY board_id LIMIT 9",
        "ix_news_lap_rank": "SELECT time_ticks FROM lap_personal_bests WHERE board_id=:board ORDER BY time_ticks,player_id LIMIT 1",
    }
    with domain.factory() as session:
        if domain.postgres:
            session.execute(text("SET LOCAL enable_seqscan=off")) # Capability check on intentionally sparse fixtures.
        prefix = "EXPLAIN (FORMAT JSON) " if domain.postgres else "EXPLAIN QUERY PLAN "
        for name, query in queries.items():
            plan = str([tuple(row) for row in session.execute(text(prefix + query),
                {"pid":domain.players["Alice"], "stamp":now(), "board":""})])
            assert name in plan, plan
            record_property(name, plan)
