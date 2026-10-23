"""Private news: constant-size finish capture and requested, bounded daily work."""
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import case, delete, exists, func, literal, or_, select, tuple_, union_all, update
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from sqlalchemy.orm import aliased, load_only

from .community import is_blocked
from .community_models import PlayerBlock
from .cursors import decode_cursor, encode_cursor
from .identity_models import Player
from .middleware import ParsedJSONRoute
from .news_models import (
    Friendship,
    NewsBands,
    NewsDemand,
    NewsItem,
    NewsPublication,
    NewsWatch,
    TrackRacer,
    TrackReach,
)
from .track_models import (
    Board,
    BoardTimeCount,
    LapPersonalBest,
    PersonalBest,
    Track,
    TrackVersion,
    VersionFinisher,
    digest,
    new_id,
    now,
)
from .tracks import DB, Auth
from .usernames import username_key

router = APIRouter(route_class=ParsedJSONRoute, tags=["garage news"])
BANDS = (1, 5, 10, 20, 30, 40, 50, 75, 100)
MILESTONES = (100, 1000, 10000)
BOARD_BATCH = 8
FRIEND_LIMIT = 100
RETENTION_DAYS = 90
FEED_LIMIT = 100
DEMAND_SECONDS = 600


def insert(session, model):
    return (pg_insert if session.bind.dialect.name == "postgresql" else sqlite_insert)(model)


def blocked(actor, recipient):
    return exists(select(PlayerBlock.player_id).where(or_(
        (PlayerBlock.player_id == actor) & (PlayerBlock.blocked_id == recipient),
        (PlayerBlock.player_id == recipient) & (PlayerBlock.blocked_id == actor))))


def emit(session, player_id, key, kind, version_id, *, board_id=None, actor_id=None, at=None, **details):
    # Wait for account removal, then recheck its latest row. This key-share lock
    # fences deletion without taking a recipient's exclusive writer lock.
    recipient = session.scalar(select(Player.id).where(Player.id == player_id,
        Player.disabled.is_(False), Player.deleted_at.is_(None)).with_for_update(read=True, key_share=True))
    if recipient is None:
        return
    values = {"id": new_id(), "player_id": player_id, "event_key": digest(key), "kind": kind,
              "version_id": version_id, "board_id": board_id, "actor_id": actor_id,
              "created_at": now() if at is None else at, "details": details}
    columns = NewsItem.__table__.c
    eligible = exists(select(Player.id).where(Player.id == player_id, Player.disabled.is_(False),
                                            Player.deleted_at.is_(None)))
    if actor_id:
        eligible &= ~blocked(actor_id, player_id)
    statement = insert(session, NewsItem).from_select(list(values), select(*(
        literal(value, type_=columns[name].type) for name, value in values.items())).where(eligible))
    session.execute(statement.on_conflict_do_nothing(index_elements=["player_id", "event_key"]))


def capture_verified(session, run, board, version, track, player):
    """Called in the accepted-result transaction. Never fans out to friends/racers."""
    if (player.is_test_driver or player.disabled or player.deleted_at is not None
            or board.manifest.get("test_population") or board.manifest.get("purpose")
            or version.state != "published" or track.hidden or track.archived):
        return
    candidates = session.execute(select(literal("race"), PersonalBest.time_ticks).where(
        PersonalBest.board_id == board.id, PersonalBest.player_id == player.id, PersonalBest.run_id == run.id)
        .union_all(select(literal("lap"), LapPersonalBest.time_ticks).where(
            LapPersonalBest.board_id == board.id, LapPersonalBest.player_id == player.id,
            LapPersonalBest.run_id == run.id))).all()
    if not candidates:
        return
    # One physical track/player pair, irrespective of revisions or selected car.
    added = session.scalar(insert(session, TrackRacer).values(track_id=track.id, player_id=player.id)
        .on_conflict_do_nothing().returning(TrackRacer.track_id))
    if added:
        created = session.scalar(insert(session, TrackReach).values(track_id=track.id, racers=0, milestone=0)
            .on_conflict_do_nothing().returning(TrackReach.track_id))
        reach = session.scalar(select(TrackReach).where(TrackReach.track_id == track.id).with_for_update())
        if created:
            # Fresh publications can already have ordinary creator results.
            # Seed those once, in SQL, so runtime and migration counts agree.
            previous = select(literal(track.id), VersionFinisher.player_id).join(
                TrackVersion, TrackVersion.id == VersionFinisher.version_id).join(
                Player, Player.id == VersionFinisher.player_id).where(TrackVersion.track_id == track.id,
                    VersionFinisher.player_id != player.id, Player.is_test_driver.is_(False)).distinct()
            session.execute(insert(session, TrackRacer).from_select(["track_id", "player_id"], previous)
                .on_conflict_do_nothing())
            reach.racers = session.scalar(select(func.count()).select_from(TrackRacer).where(TrackRacer.track_id == track.id)) - 1
            reach.milestone = max((n for n in MILESTONES if n <= reach.racers), default=0)
        reach.racers += 1
        for threshold in MILESTONES:
            if reach.milestone < threshold <= reach.racers:
                reach.milestone = threshold
                emit(session, track.owner_id, ["milestone", track.id, threshold], "milestone", version.id,
                     at=run.finished_at, count=threshold)
    for metric, ticks in candidates:
        model = PersonalBest if metric == "race" else LapPersonalBest
        # PB triggers already serialize this board. The rank indexes stop at the
        # first equal/faster eligible opponent; ties do not announce new records.
        competitor = session.scalar(select(model.player_id).join(Player, Player.id == model.player_id)
            .where(model.board_id == board.id, model.time_ticks <= ticks, model.player_id != player.id,
                   Player.disabled.is_(False), Player.is_test_driver.is_(False)).limit(1))
        if competitor is None:
            emit(session, track.owner_id, ["record", board.id, metric, run.id], "world_record", version.id,
                 board_id=board.id, actor_id=player.id, at=run.finished_at, metric=metric, time_ticks=ticks)


def locked_player(session, player_id):
    player = session.scalar(select(Player).where(Player.id == player_id).with_for_update(key_share=True)
        .execution_options(populate_existing=True))
    if player is None or player.disabled or player.deleted_at is not None or player.is_test_driver:
        raise HTTPException(403, "NEWS_UNAVAILABLE")
    return player


def capture_publication(session, version, track, player):
    """One shared fact in the successful publication transaction; no fan-out."""
    if (version.state != "published" or version.published_at is None or track.hidden or track.archived
            or player.disabled or player.deleted_at is not None or player.is_test_driver):
        return
    earlier = exists(select(TrackVersion.id).where(TrackVersion.track_id == track.id,
        TrackVersion.state == "published", TrackVersion.id != version.id))
    values = {"track_id": track.id, "version_id": version.id,
              "owner_id": player.id, "published_at": version.published_at}
    columns = NewsPublication.__table__.c
    # One statement: revisions (including pre-feature tracks) select no row.
    statement = insert(session, NewsPublication).from_select(list(values), select(*(
        literal(value, type_=columns[name].type) for name, value in values.items())).where(~earlier))
    session.execute(statement.on_conflict_do_nothing())


def friend_roster(session, player_id):
    other = case((Friendship.low_id == player_id, Friendship.high_id), else_=Friendship.low_id)
    return session.execute(select(other, Friendship.created_at).join(Player, Player.id == other).where(
        or_(Friendship.low_id == player_id, Friendship.high_id == player_id), Friendship.accepted.is_(True),
        Player.disabled.is_(False), Player.deleted_at.is_(None), Player.is_test_driver.is_(False),
        ~blocked(other, player_id)).limit(FRIEND_LIMIT)).all()


def publication_page(session, player_id, position, stamp):
    # Each friend contributes at most 31 eligible rows from the recent owner
    # index range; no catalogue documents or per-friend database roundtrips.
    sources = []
    for owner_id, since in friend_roster(session, player_id):
        query = (select(NewsPublication.track_id, NewsPublication.version_id.label("id"),
                        NewsPublication.published_at.label("created_at"))
            .join(Track, Track.id == NewsPublication.track_id)
            .join(TrackVersion, TrackVersion.id == NewsPublication.version_id)
            .where(NewsPublication.owner_id == owner_id,
                NewsPublication.published_at >= max(since, stamp - RETENTION_DAYS * 86400),
                NewsPublication.published_at <= stamp, Track.hidden.is_(False), Track.archived.is_(False),
                TrackVersion.state == "published"))
        if position:
            query = query.where(tuple_(NewsPublication.published_at, NewsPublication.version_id)
                                < (position["at"], position["id"]))
        source = query.order_by(NewsPublication.published_at.desc(), NewsPublication.version_id.desc()).limit(31).subquery()
        sources.append(select(*source.c))
    if not sources:
        return []
    candidates = union_all(*sources).subquery()
    still_friends = exists(select(Friendship.low_id).where(Friendship.accepted.is_(True),
        or_((Friendship.low_id == player_id) & (Friendship.high_id == NewsPublication.owner_id),
            (Friendship.high_id == player_id) & (Friendship.low_id == NewsPublication.owner_id)),
        Friendship.created_at <= NewsPublication.published_at))
    # Recheck current friendship, account and block state in this statement.
    # Select the small page before joining its stored outline JSON.
    page = (select(candidates.c.track_id, candidates.c.created_at, candidates.c.id)
        .join(NewsPublication, NewsPublication.track_id == candidates.c.track_id)
        .join(Player, Player.id == NewsPublication.owner_id)
        .where(still_friends, Player.disabled.is_(False), Player.deleted_at.is_(None),
               Player.is_test_driver.is_(False), ~blocked(NewsPublication.owner_id, player_id))
        .order_by(candidates.c.created_at.desc(), candidates.c.id.desc()).limit(31).subquery())
    return session.execute(select(NewsPublication, TrackVersion.name, Player.display_name, TrackVersion.discovery)
        .select_from(page).join(NewsPublication, NewsPublication.track_id == page.c.track_id)
        .join(TrackVersion, TrackVersion.id == NewsPublication.version_id)
        .join(Player, Player.id == NewsPublication.owner_id)).all()


@router.post("/news/refresh")
def request_refresh(session: DB, player: Auth):
    locked_player(session, player.id)
    stamp = now()
    day = stamp // 86400
    state = session.get(NewsDemand, player.id)
    if state is None:
        state = NewsDemand(player_id=player.id)
        session.add(state)
        session.flush()
    if state.completed_day < day:
        if state.requested_day != day:
            state.cursor = ""
        state.requested_day, state.requested_until, state.pending = day, stamp + DEMAND_SECONDS, True
    session.commit()
    return {"refreshing": state.pending, "checked_day": state.completed_day}


@router.get("/news")
def feed(session: DB, player: Auth, cursor: str = Query("", max_length=400)):
    # Pure indexed read. Opening another page never schedules comparisons.
    actor = aliased(Player)
    query = (select(NewsItem, TrackVersion.name, Board.vehicle_id,
                    Board.manifest["tick_rate"].as_integer(), actor.display_name, Track.owner_id,
                    TrackVersion.discovery)
        .join(TrackVersion, TrackVersion.id == NewsItem.version_id).join(Track, Track.id == TrackVersion.track_id)
        .outerjoin(Board, Board.id == NewsItem.board_id).outerjoin(actor, actor.id == NewsItem.actor_id)
        .where(NewsItem.player_id == player.id, NewsItem.created_at >= now() - RETENTION_DAYS * 86400,
               Track.hidden.is_(False), Track.archived.is_(False), TrackVersion.state == "published",
               ~blocked(Track.owner_id, player.id),
               or_(NewsItem.actor_id.is_(None), ~blocked(NewsItem.actor_id, player.id))))
    position = None
    if cursor:
        position = decode_cursor(cursor)
        if (set(position) != {"at", "id"} or type(position["at"]) is not int
                or not isinstance(position["id"], str) or len(position["id"]) != 36):
            raise HTTPException(422, "INVALID_CURSOR")
        query = query.where(tuple_(NewsItem.created_at, NewsItem.id) < (position["at"], position["id"]))
    rows = session.execute(query.order_by(NewsItem.created_at.desc(), NewsItem.id.desc()).limit(31)).all()
    items = [{"id": row.id, "kind": row.kind, "created_at": row.created_at, "version_id": row.version_id,
              "board_id": row.board_id, "track_name": title, "vehicle_id": vehicle,
              "actor_id": row.actor_id, "creator_id": creator_id,
              "tick_rate": tick_rate or 120,
              "actor_name": name or "Removed account", **row.details}
             for row, title, vehicle, tick_rate, name, creator_id, _discovery in rows]
    discoveries = {row[0].version_id: row[-1] for row in rows}
    for publication, title, name, discovery in publication_page(session, player.id, position, now()):
        items.append({"id": publication.version_id, "kind": "friend_track", "created_at": publication.published_at,
            "version_id": publication.version_id, "board_id": None, "track_name": title, "vehicle_id": None,
            "actor_id": publication.owner_id, "creator_id": publication.owner_id,
            "tick_rate": 120, "actor_name": name})
        discoveries[publication.version_id] = discovery
    items.sort(key=lambda item: (item["created_at"], item["id"]), reverse=True)
    has_more = len(items) > 30
    items = items[:30]
    # Reuse the stored, bounded catalogue projection in this same page query.
    # One outline per version on the wire; no documents, object reads or jobs.
    from .studio_catalogue import preview
    tracks = {item["version_id"]: preview(discoveries[item["version_id"]]) for item in items}
    state = session.get(NewsDemand, player.id)
    refreshing = bool(state and state.pending and state.requested_until >= now())
    last = items[-1] if has_more else None
    return {"items": items, "tracks": tracks, "next_cursor": encode_cursor({"at": last["created_at"], "id": last["id"]}) if last else "",
            "refreshing": refreshing, "checked_day": state.completed_day if state else -1}


def friend_ids(session, player_id):
    return [pid for pid, _since in friend_roster(session, player_id)]


@router.get("/news/friends")
def friends(session: DB, player: Auth):
    other = case((Friendship.low_id == player.id, Friendship.high_id), else_=Friendship.low_id)
    rows = session.execute(select(Friendship, Player).join(Player, Player.id == other).where(
        or_(Friendship.low_id == player.id, Friendship.high_id == player.id),
        Player.disabled.is_(False), Player.deleted_at.is_(None), Player.is_test_driver.is_(False),
        ~blocked(other, player.id)).order_by(Friendship.created_at, other).limit(FRIEND_LIMIT)).all()
    return {"items": [{"player_id": p.id, "display_name": p.display_name,
                       "status": "friends" if f.accepted else "sent" if f.requested_by == player.id else "received"}
                      for f, p in rows]}


class FriendRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    name: str = Field(min_length=1, max_length=40)


@router.post("/news/friends")
def request_friend(body: FriendRequest, session: DB, player: Auth):
    target = session.scalar(select(Player).where(Player.username_key == username_key(body.name),
        Player.disabled.is_(False), Player.deleted_at.is_(None), Player.is_test_driver.is_(False)))
    if target is None or is_blocked(session, player.id, target.id, mutual=True):
        raise HTTPException(404, "PLAYER_NOT_FOUND")
    if target.id == player.id:
        raise HTTPException(422, "CANNOT_FRIEND_SELF")
    # Deterministic player locking also bounds both players' pending requests.
    pair = sorted((player.id, target.id))
    session.commit() # Release the authentication actor fence before pair ordering.
    for pid in pair:
        locked_player(session, pid)
    existing = session.get(Friendship, tuple(pair))
    if existing is None:
        for pid in pair:
            count = session.scalar(select(func.count()).select_from(Friendship).where(
                or_(Friendship.low_id == pid, Friendship.high_id == pid)))
            if count >= FRIEND_LIMIT:
                raise HTTPException(409, "FRIEND_LIMIT_REACHED")
        existing = Friendship(low_id=pair[0], high_id=pair[1], requested_by=player.id)
        session.add(existing)
    session.commit()
    return {"status": "friends" if existing.accepted else "sent" if existing.requested_by == player.id else "received"}


@router.put("/news/friends/{target_id}")
def accept_friend(target_id: UUID, session: DB, player: Auth):
    pair = sorted((player.id, str(target_id)))
    session.commit()
    for pid in pair:
        locked_player(session, pid)
    row = session.get(Friendship, tuple(pair))
    if row is None or (not row.accepted and row.requested_by == player.id):
        raise HTTPException(404, "FRIEND_REQUEST_NOT_FOUND")
    if is_blocked(session, player.id, str(target_id), mutual=True):
        raise HTTPException(404, "FRIEND_REQUEST_NOT_FOUND")
    if not row.accepted:
        row.created_at = now()  # Do not announce tracks predating the friendship.
    row.accepted = True
    session.commit()
    return {"status": "friends"}


@router.delete("/news/friends/{target_id}")
def remove_friend(target_id: UUID, session: DB, player: Auth):
    pair = sorted((player.id, str(target_id)))
    session.commit()
    for pid in pair:
        locked_player(session, pid)
    session.execute(delete(Friendship).where(Friendship.low_id == pair[0], Friendship.high_id == pair[1]))
    session.commit()
    return {"removed": True}


def cutoffs(session, board_id, model):
    if model is PersonalBest:
        frequencies = select(BoardTimeCount.time_ticks.label("ticks"), BoardTimeCount.public_count.label("n")).where(
            BoardTimeCount.board_id == board_id, BoardTimeCount.public_count > 0).subquery()
    else:
        frequencies = (select(LapPersonalBest.time_ticks.label("ticks"), func.count().label("n"))
            .join(Player, Player.id == LapPersonalBest.player_id).where(LapPersonalBest.board_id == board_id,
                Player.disabled.is_(False), Player.is_test_driver.is_(False))
            .group_by(LapPersonalBest.time_ticks).subquery())
    ranked = select(frequencies.c.ticks,
        (func.sum(frequencies.c.n).over(order_by=frequencies.c.ticks) - frequencies.c.n + 1).label("rank"),
        func.sum(frequencies.c.n).over().label("total")).subquery()
    # Only nine scalar cutoffs leave SQL, regardless of leaderboard population.
    aggregates = [func.max(case(
        (ranked.c.rank * 100 <= ranked.c.total * threshold, ranked.c.ticks), else_=None))
        for threshold in BANDS]
    return list(session.execute(select(*aggregates)).one())


def board_bands(session, board, day):
    revision = board.stats_revision + board.lap_revision
    cached = session.get(NewsBands, board.id)
    if cached is not None and (cached.checked_day == day or cached.revision == revision):
        return cached
    # Serialize only the presentation cache. Ranking aggregates must never hold
    # a competitive Board lock or delay another player's verified PB write.
    session.execute(insert(session, NewsBands).values(board_id=board.id, checked_day=-1,
        revision=-1, race=[], lap=[]).on_conflict_do_nothing())
    cached = session.scalar(select(NewsBands).where(NewsBands.board_id == board.id).with_for_update()
        .execution_options(populate_existing=True))
    if cached is not None and (cached.checked_day == day or cached.revision == board.stats_revision + board.lap_revision):
        return cached
    race_limits, lap_limits = cutoffs(session, board.id, PersonalBest), cutoffs(session, board.id, LapPersonalBest)
    if cached is None:
        cached = NewsBands(board_id=board.id)
        session.add(cached)
    cached.race, cached.lap = race_limits, lap_limits
    cached.checked_day, cached.revision = day, board.stats_revision + board.lap_revision
    return cached


def band(ticks, limits):
    if ticks is None:
        return None
    return next((threshold for threshold, limit in zip(BANDS, limits) if limit is not None and ticks <= limit), 100)


def compare_board(session, player_id, best, board, version, day, watch, roster, lap_ticks, peers, runs):
    fields = board_bands(session, board, day)
    times = (best.time_ticks, lap_ticks)
    metrics = ("race", "lap")
    positions = (band(times[0], fields.race), band(times[1], fields.lap))
    if watch:
        for index, metric in enumerate(metrics):
            previous = watch.race_band if index == 0 else watch.lap_band
            current = positions[index]
            if previous is not None and current is not None and current > previous:
                emit(session, player_id, ["percentile", board.id, metric, day], "percentile_drop", version.id,
                     board_id=board.id, metric=metric, threshold=previous, current_band=current)
        old_times = (watch.race_ticks, watch.lap_ticks)
        for pid, current in peers.items():
            if pid not in watch.friends:
                continue # A new friendship establishes a baseline, never old defeat spam.
            previous = watch.friends[pid]
            for index, metric in enumerate(metrics):
                if (old_times[index] is not None and times[index] is not None and current[index] is not None
                        and current[index] < times[index]
                        and (previous[index] is None or previous[index] >= old_times[index])):
                    emit(session, player_id, ["friend", board.id, metric, pid, runs[(pid, index)]],
                         "friend_overtake", version.id, board_id=board.id, actor_id=pid,
                         metric=metric, time_ticks=current[index], your_ticks=times[index])
    else:
        watch = NewsWatch(player_id=player_id, board_id=board.id)
        session.add(watch)
    watch.race_ticks, watch.lap_ticks = times
    watch.race_band, watch.lap_band = positions
    watch.friends, watch.friend_key, watch.revision = peers, roster, fields.revision


def process_requested(app, *, clock=None):
    """One <=8-board transaction, only within ten minutes of an explicit request."""
    stamp = now() if clock is None else clock
    with app.state.session_factory() as session:
        # Active-range index excludes completed AND expired inactive demands.
        player = session.scalar(select(Player).join(NewsDemand, NewsDemand.player_id == Player.id).where(
            NewsDemand.pending.is_(True), NewsDemand.requested_until >= stamp,
            Player.disabled.is_(False), Player.deleted_at.is_(None), Player.is_test_driver.is_(False))
            .order_by(NewsDemand.requested_until, Player.id)
            .with_for_update(skip_locked=True, of=Player, key_share=True).limit(1))
        if player is None:
            return False
        demand = session.scalar(select(NewsDemand).where(NewsDemand.player_id == player.id).with_for_update())
        if not demand.pending or demand.requested_until < stamp:
            return False
        # Do not continue yesterday's queued pass across a UTC boundary.
        if demand.requested_day != stamp // 86400:
            demand.pending = False
            session.commit()
            return True
        rows = session.execute(select(PersonalBest, Board, TrackVersion, NewsWatch.revision, NewsWatch.friend_key)
            .select_from(PersonalBest)
            .join(Board, Board.id == PersonalBest.board_id).join(TrackVersion, TrackVersion.id == Board.version_id)
            .join(Track, Track.id == TrackVersion.track_id)
            .outerjoin(NewsWatch, (NewsWatch.board_id == PersonalBest.board_id) & (NewsWatch.player_id == player.id))
            .options(load_only(PersonalBest.board_id, PersonalBest.player_id, PersonalBest.time_ticks),
                     load_only(Board.id, Board.stats_revision, Board.lap_revision), load_only(TrackVersion.id))
            .where(PersonalBest.player_id == player.id,
                PersonalBest.board_id > demand.cursor, TrackVersion.state == "published",
                Track.hidden.is_(False), Track.archived.is_(False),
                Board.manifest["test_population"].as_boolean().is_not(True),
                Board.manifest["purpose"].as_string().is_(None))
            .order_by(PersonalBest.board_id).limit(BOARD_BATCH + 1)).all()
        ids = friend_ids(session, player.id)
        roster = digest(sorted(ids))
        changed = [(best, board, version) for best, board, version, revision, friend_key in rows[:BOARD_BATCH]
                   if revision is None or revision != board.stats_revision + board.lap_revision or friend_key != roster]
        changed_ids = [board.id for _, board, _ in changed]
        # Unchanged boards load neither old friend snapshots nor route/manifest JSON.
        watches = {watch.board_id: watch for watch in session.scalars(select(NewsWatch).where(
            NewsWatch.player_id == player.id, NewsWatch.board_id.in_(changed_ids)))} if changed_ids else {}
        own_laps = {}
        peers = {bid: {pid: [None, None] for pid in ids} for bid in changed_ids}
        sources = {bid: {} for bid in changed_ids}
        if changed_ids:
            # Two bounded queries for the whole batch, never one query per friend.
            for bid, pid, ticks, source in session.execute(select(LapPersonalBest.board_id,
                    LapPersonalBest.player_id, LapPersonalBest.time_ticks, LapPersonalBest.run_id).where(
                    LapPersonalBest.board_id.in_(changed_ids), LapPersonalBest.player_id.in_([player.id, *ids]))):
                if pid == player.id:
                    own_laps[bid] = ticks
                else:
                    peers[bid][pid][1], sources[bid][(pid, 1)] = ticks, source
            if ids:
                for bid, pid, ticks, source in session.execute(select(PersonalBest.board_id,
                        PersonalBest.player_id, PersonalBest.time_ticks, PersonalBest.run_id).where(
                        PersonalBest.board_id.in_(changed_ids), PersonalBest.player_id.in_(ids))):
                    peers[bid][pid][0], sources[bid][(pid, 0)] = ticks, source
        for best, board, version in changed:
            compare_board(session, player.id, best, board, version, demand.requested_day,
                          watches.get(board.id), roster, own_laps.get(board.id), peers[board.id], sources[board.id])
        for _, board, _, _, _ in rows[:BOARD_BATCH]:
            demand.cursor = board.id
        if len(rows) <= BOARD_BATCH:
            demand.completed_day, demand.pending = demand.requested_day, False
        # Retain at most 100 visible items for this returning player.
        excess = select(NewsItem.id).where(NewsItem.player_id == player.id).order_by(
            NewsItem.created_at.desc(), NewsItem.id.desc()).offset(FEED_LIMIT).limit(100).subquery()
        session.execute(delete(NewsItem).where(NewsItem.id.in_(select(excess.c.id))))
        session.commit()
    return True


def cleanup_expired(session, stamp, limit=100):
    old = select(NewsItem.id).where(NewsItem.created_at < stamp - RETENTION_DAYS * 86400).order_by(
        NewsItem.created_at, NewsItem.id).limit(limit).subquery()
    removed = session.execute(delete(NewsItem).where(NewsItem.id.in_(select(old.c.id)))).rowcount
    if removed < limit:
        publications = select(NewsPublication.track_id).where(NewsPublication.published_at < stamp - RETENTION_DAYS * 86400
            ).order_by(NewsPublication.published_at, NewsPublication.track_id).limit(limit - removed).subquery()
        removed += session.execute(delete(NewsPublication).where(
            NewsPublication.track_id.in_(select(publications.c.track_id)))).rowcount
    return removed


def erase_private(session, player_id, limit=100):
    """Extend the existing deletion plan without changing its persistent stages."""
    remaining = limit
    for model, criterion in (
            (NewsItem, NewsItem.player_id == player_id),
            (NewsWatch, NewsWatch.player_id == player_id),
            (NewsDemand, NewsDemand.player_id == player_id),
            (Friendship, or_(Friendship.low_id == player_id, Friendship.high_id == player_id))):
        columns = list(model.__table__.primary_key.columns)
        selected = select(*columns).where(criterion).limit(remaining).subquery()
        key = columns[0] if len(columns) == 1 else tuple_(*columns)
        removed = session.execute(delete(model).where(key.in_(select(*selected.c))))
        remaining -= removed.rowcount
        if remaining <= 0:
            return False
    selected = select(NewsItem.id).where(NewsItem.actor_id == player_id).limit(remaining).subquery()
    changed = session.execute(update(NewsItem).where(NewsItem.id.in_(select(selected.c.id))).values(actor_id=None))
    return changed.rowcount < remaining
