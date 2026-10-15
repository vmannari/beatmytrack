"""Stable community queries: shared short-lived result order, bounded preview pages.

Snapshots store immutable version IDs, not documents/previews. Page reads recheck
visibility. DB persistence permits API replicas/restarts to share the same order.
"""
import hashlib
import json
import random
import threading
import time
import uuid
from collections import OrderedDict, deque

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import JSON, Index, Integer, String, any_, delete, func, literal, or_, select, update
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Mapped, aliased, mapped_column

from .client_address import ClientAddress
from .cursors import decode_cursor, encode_cursor
from .db import Base, get_session
from .identity_models import Player
from .middleware import ParsedJSONRoute, check_budget
from .security import bearer, current_player
from .track_models import Board, Run, Track, TrackVersion
from .tracks import discovery_payload

router = APIRouter(route_class=ParsedJSONRoute, tags=["discovery"])
PAGE_SIZE = 20
CACHE_SECONDS = 20
SNAPSHOT_SECONDS = 1800
MAX_MEMORY_IDS = 100_000


class DiscoverySnapshot(Base):
    __tablename__ = "discovery_snapshots"
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    query_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    expires_at: Mapped[int] = mapped_column(Integer, nullable=False)
    version_ids: Mapped[list] = mapped_column(JSON, nullable=False)
    entry_count: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    __table_args__ = (Index("ix_discovery_snapshot_expiry", "expires_at"),)


class DiscoveryBudget(Base):
    __tablename__ = "discovery_budget"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    entries: Mapped[int] = mapped_column(Integer, nullable=False)
    snapshots: Mapped[int] = mapped_column(Integer, nullable=False)


class Query(BaseModel):
    model_config = ConfigDict(extra="forbid")
    search: str = Field("", max_length=80)
    search_kind: int = Field(0, ge=0, le=2)
    theme: str = Field("all", max_length=40)
    minimum_rating: float = Field(0, ge=0, le=5)
    age_days: int = Field(0, ge=0, le=36500)
    race_count: str = Field("any", pattern="^(any|low|medium|high)$")
    race_history: str = Field("any", pattern="^(any|raced|unraced)$")
    raced_ids: list[str] = Field(default_factory=list, max_length=50000)
    ids: list[str] | None = Field(None, max_length=50000)
    section: str = Field("all", pattern="^(all|favorites|saved)$")
    feed: str = Field("recommended", pattern="^(recommended|new|popular|rated|trending)$")
    sort: str = Field("recommended", pattern="^(recommended|name|creator|score|plays|new)$")
    cursor: str = Field("", max_length=400)
    offset: int | None = Field(None, ge=0)
    fresh: bool = False
    exclude: str = Field("", max_length=80)
    locate_version: str = Field("", max_length=36)


def _identity(request, session, credentials):
    return current_player(request, credentials, session) if credentials else None


def _hash(query, owner):
    values = query.model_dump(exclude={"cursor", "offset", "fresh", "exclude", "locate_version"})
    values["search"] = query.search.strip()
    for key in ("ids", "raced_ids"):
        if values[key] is not None:
            if any(not isinstance(v, str) or not 1 <= len(v) <= 80 for v in values[key]):
                raise HTTPException(422, "INVALID_TRACK_IDS")
            values[key] = sorted(set(values[key]))
    values["owner"] = owner
    return hashlib.sha256(json.dumps(values, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def _cache(request):
    if not hasattr(request.app.state, "discovery_memory"):
        # create_app normally installs this; keep standalone route tests safe.
        request.app.state.discovery_memory = OrderedDict()
        request.app.state.discovery_lock = threading.RLock()
    return request.app.state.discovery_memory, request.app.state.discovery_lock


def _remember(request, key, expires, ids, fingerprint):
    cache, _lock = _cache(request)
    cache[key] = (expires, ids, fingerprint)
    cache.move_to_end(key)
    while len(cache) > 64 or sum(len(v[1]) for v in cache.values()) > MAX_MEMORY_IDS:
        cache.popitem(last=False)


def _ordered_ids(session, query, owner, timestamp):
    newer = aliased(TrackVersion)
    statement = select(TrackVersion.id, Track.official).select_from(TrackVersion).join(Track).join(Player, Player.id == Track.owner_id).where(
        TrackVersion.state == "published", Track.hidden.is_(False), Player.disabled.is_(False), Player.is_test_driver.is_(False),
        TrackVersion.published_at <= timestamp,
        ~select(newer.id).where(newer.track_id == Track.id, newer.state == "published",
            newer.published_at <= timestamp, newer.number > TrackVersion.number).exists())
    if owner: statement = statement.where(Track.owner_id == owner)
    if query.ids is not None: statement = statement.where(_in_ids(Track.id, query.ids, session))
    if query.section == "favorites" and query.ids is None: statement = statement.where(False)
    if query.theme != "all": statement = statement.where(TrackVersion.discovery["theme"].as_string() == query.theme)
    if query.minimum_rating: statement = statement.where(TrackVersion.rating_count > 0,
        TrackVersion.rating_sum >= (query.minimum_rating-0.000001) * TrackVersion.rating_count)
    if query.age_days: statement = statement.where(TrackVersion.created_at >= timestamp-query.age_days*86400)
    if query.race_history == "raced": statement = statement.where(_in_ids(Track.id, query.raced_ids, session))
    if query.race_history == "unraced": statement = statement.where(~_in_ids(Track.id, query.raced_ids, session))
    if query.race_count == "low": statement = statement.where(TrackVersion.verified_finishers < 10)
    if query.race_count == "medium": statement = statement.where(TrackVersion.verified_finishers >= 10, TrackVersion.verified_finishers < 50)
    if query.race_count == "high": statement = statement.where(TrackVersion.verified_finishers >= 50)
    if query.search.strip():
        name = TrackVersion.name.icontains(query.search.strip(), autoescape=True)
        creator = Player.display_name.icontains(query.search.strip(), autoescape=True)
        statement = statement.where(name if query.search_kind == 1 else creator if query.search_kind == 2 else or_(name, creator))
    ordering = query.sort
    if ordering == "recommended": ordering = {"new":"new", "popular":"popular", "trending":"popular", "rated":"score"}.get(query.feed, "recommended")
    if query.feed == "rated": statement = statement.where(TrackVersion.rating_count > 0)
    if ordering == "popular":
        # Aggregate actual recent verified entrants, excluding creator proof and artificial identities.
        recent = select(TrackVersion.track_id.label("track_id"), func.count(func.distinct(Run.player_id)).label("drivers")).select_from(Run).join(Board, Board.id == Run.board_id).join(TrackVersion, TrackVersion.id == Board.version_id).join(Player, Player.id == Run.player_id).where(
            Run.status == "verified", Run.finished_at >= timestamp-7*86400, Player.disabled.is_(False), Player.is_test_driver.is_(False),
            or_(Board.manifest["purpose"].as_string().is_(None), Board.manifest["purpose"].as_string() != "creator_test"),
            or_(Board.manifest["test_population"].as_boolean().is_(None), Board.manifest["test_population"].as_boolean().is_(False)),
            or_(TrackVersion.creator_test_run_id.is_(None), Run.id != TrackVersion.creator_test_run_id)).group_by(TrackVersion.track_id).subquery()
        statement = statement.outerjoin(recent, recent.c.track_id == Track.id).order_by(func.coalesce(recent.c.drivers, 0).desc())
    elif ordering == "score":
        # Provisional confidence weight: five neutral 3.5-star observations; displayed average is unchanged.
        statement = statement.order_by((TrackVersion.rating_count > 0).desc(), ((TrackVersion.rating_sum+17.5)/(TrackVersion.rating_count+5.0)).desc())
    elif ordering == "plays": statement = statement.order_by(TrackVersion.verified_finishers.desc())
    elif ordering == "creator": statement = statement.order_by(func.lower(Player.display_name), func.lower(TrackVersion.name))
    elif ordering == "name": statement = statement.order_by(func.lower(TrackVersion.name))
    statement = statement.order_by(TrackVersion.published_at.desc(), TrackVersion.id)
    maximum = query._catalogue_limit if hasattr(query, "_catalogue_limit") else 100000
    rows = session.execute(statement.limit(maximum + 1)).all()
    if len(rows) > maximum:
        raise HTTPException(503, "DISCOVERY_CATALOGUE_LIMIT")
    if ordering == "recommended":
        # Three trusted official choices followed by one community choice; all remain accessible.
        official = deque(row[0] for row in rows if row[1])
        community = deque(row[0] for row in rows if not row[1])
        result = []
        while official or community:
            for _ in range(min(3, len(official))): result.append(official.popleft())
            if community: result.append(community.popleft())
        return result
    return [row[0] for row in rows]


def _in_ids(column, values, session):
    # One bound parameter even for a large personal collection/history.
    if session.get_bind().dialect.name == "postgresql":
        return column == any_(literal(values, type_=ARRAY(String(80))))
    table = func.json_each(json.dumps(values)).table_valued("value")
    return column.in_(select(table.c.value))


def _snapshot(request, session, query, owner):
    timestamp = int(time.time())
    fingerprint = _hash(query, owner)
    if query.cursor:
        value = decode_cursor(query.cursor)
        if value.get("query") != fingerprint or not isinstance(value.get("snapshot"), str) or type(value.get("offset")) is not int or value["offset"] < 0:
            raise HTTPException(422, "INVALID_CURSOR")
        identity, offset = value["snapshot"], value["offset"] if query.offset is None else query.offset
        window = None
    else:
        generation = fingerprint+":"+str(timestamp//CACHE_SECONDS)+(":fresh" if query.fresh else "")
        identity = str(uuid.uuid5(uuid.NAMESPACE_URL, generation))
        window = identity
        offset = query.offset or 0
    cache, lock = _cache(request)
    with lock:
        aliases = getattr(request.app.state, "discovery_aliases", None)
        if aliases is None:
            request.app.state.discovery_aliases = aliases = OrderedDict()
        flights = getattr(request.app.state, "discovery_flights", None)
        if flights is None:
            request.app.state.discovery_flights = flights = {}
        flight = flights.setdefault(identity, threading.Lock())

    def remember(identity, expires, ids):
        with lock:
            _remember(request, identity, expires, ids, fingerprint)
            if window:
                aliases[window] = identity
                aliases.move_to_end(window)
                while len(aliases) > 64:
                    aliases.popitem(last=False)

    flight_key = identity
    try:
        with flight:
            with lock:
                if window:
                    identity = aliases.get(window, identity)
                cached = cache.get(identity)
            if cached is not None and cached[0] > timestamp and cached[2] == fingerprint:
                with lock: cache.move_to_end(identity)
                return identity, fingerprint, offset, cached[1], cached[0]
            row = session.get(DiscoverySnapshot, identity)
            if row is not None and row.query_hash == fingerprint and row.expires_at > timestamp:
                remember(identity, row.expires_at, row.version_ids)
                return identity, fingerprint, offset, row.version_ids, row.expires_at
            if query.cursor: raise HTTPException(410, "DISCOVERY_SNAPSHOT_EXPIRED")
            settings = request.app.state.settings
            actor = getattr(request.state, "budget_player_id", None)
            admission = "player:"+actor if actor else "peer:"+ClientAddress(settings.trusted_proxy_networks).resolve(request.scope)
            if not check_budget(request.app.state.session_factory, admission, "discovery_create",
                                settings.discovery_create_per_minute, session=session):
                raise HTTPException(429, "DISCOVERY_CREATION_LIMIT")
            query._catalogue_limit = settings.discovery_catalogue_limit
            ids = _ordered_ids(session, query, owner, timestamp)
            # Refreshes with identical order share the stored vector for this
            # lifetime bucket. A changed order retains a distinct frozen cursor.
            order = hashlib.sha256(json.dumps(ids, separators=(",", ":")).encode()).hexdigest()
            identity = str(uuid.uuid5(uuid.NAMESPACE_URL,
                fingerprint+":"+str(timestamp//SNAPSHOT_SECONDS)+":"+order))
            session.rollback()
            if session.bind.dialect.name == "sqlite":
                session.execute(update(DiscoveryBudget).where(DiscoveryBudget.id == 1)
                    .values(entries=DiscoveryBudget.entries))
            budget = session.scalar(select(DiscoveryBudget).where(DiscoveryBudget.id == 1).with_for_update()
                .execution_options(populate_existing=True))
            # The budget lock also serializes first creation across API replicas.
            row = session.get(DiscoverySnapshot, identity)
            if row is not None and row.query_hash == fingerprint and row.expires_at > timestamp:
                session.rollback()
                remember(identity, row.expires_at, row.version_ids)
                return identity, fingerprint, offset, row.version_ids, row.expires_at
            expired = dict(session.execute(select(DiscoverySnapshot.id, DiscoverySnapshot.entry_count)
                .where(DiscoverySnapshot.expires_at <= timestamp).limit(64)).all())
            if row is not None:
                if row.expires_at > timestamp:
                    raise HTTPException(503, "DISCOVERY_SNAPSHOT_CONFLICT")
                expired.setdefault(identity, row.entry_count)
            if expired:
                session.execute(delete(DiscoverySnapshot).where(DiscoverySnapshot.id.in_(expired)))
                budget.entries -= sum(expired.values())
                budget.snapshots -= len(expired)
            if (budget.entries + len(ids) > settings.discovery_snapshot_ids
                    or budget.snapshots >= settings.discovery_snapshot_count):
                session.commit()  # Keep bounded expiry cleanup even when admission is full.
                raise HTTPException(503, "DISCOVERY_SNAPSHOT_LIMIT")
            budget.entries += len(ids)
            budget.snapshots += 1
            row = DiscoverySnapshot(id=identity, query_hash=fingerprint, expires_at=timestamp+SNAPSHOT_SECONDS,
                                    version_ids=ids, entry_count=len(ids))
            session.add(row)
            try: session.commit()
            except IntegrityError:
                session.rollback()
                row = session.get(DiscoverySnapshot, identity)
                if row is None or row.query_hash != fingerprint: raise
                ids = row.version_ids
            remember(identity, row.expires_at, ids)
            return identity, fingerprint, offset, ids, row.expires_at
    finally:
        with lock:
            if flights.get(flight_key) is flight: flights.pop(flight_key, None)


def _page(request, session, query, credentials, random_choice=False):
    player = _identity(request, session, credentials) if query.section == "saved" else None
    if query.section == "saved" and player is None: raise HTTPException(401, "AUTH_REQUIRED")
    snapshot, fingerprint, offset, ids, expires_at = _snapshot(request, session, query, player.id if player else "")
    if not random_choice and not query.cursor and query.locate_version in ids:
        offset = ids.index(query.locate_version)//PAGE_SIZE*PAGE_SIZE
    if random_choice:
        # Uniform sampling of the entire filtered snapshot, independent of client cache residency.
        candidates = list(enumerate(ids))
        random.SystemRandom().shuffle(candidates)
    else: candidates = list(enumerate(ids[offset:offset+PAGE_SIZE], offset))
    items = []
    fallback = None
    batches = [candidates] if not random_choice else [candidates[i:i+100] for i in range(0,len(candidates),100)]
    for batch in batches:
        chosen = dict(batch)
        rows = session.execute(select(TrackVersion, Track, Player.display_name).select_from(TrackVersion).join(Track).join(Player, Player.id == Track.owner_id).where(
            TrackVersion.id.in_(list(chosen.values())), TrackVersion.state == "published", Track.hidden.is_(False), Player.disabled.is_(False), Player.is_test_driver.is_(False))).all()
        available = {row[0].id: row for row in rows}
        for position, version_id in chosen.items():
            if version_id not in available: continue
            version, track, name = available[version_id]
            item = discovery_payload(request, version, track, name)
            item.update(discovery_index=position, verified_finishers=version.verified_finishers)
            if random_choice and track.id == query.exclude:
                fallback = item
                continue
            items.append(item)
            if random_choice: break
        if random_choice and items: break
    if random_choice and not items and fallback is not None: items = [fallback]
    next_offset = offset+PAGE_SIZE
    cursor = encode_cursor({"snapshot":snapshot,"query":fingerprint,"offset":next_offset}) if next_offset < len(ids) else None
    session.commit()
    return {"items":items,"next_cursor":cursor,"page_cursor":encode_cursor({"snapshot":snapshot,"query":fingerprint,"offset":0}),"total":len(ids),"offset":offset,"snapshot":snapshot,"page_size":PAGE_SIZE,"expires_in":max(0, expires_at-int(time.time()))}


@router.post("/discovery/tracks")
def discover(query: Query, request: Request, session=Depends(get_session), credentials=Depends(bearer)):
    return _page(request, session, query, credentials)


@router.post("/discovery/random")
def choose_random(query: Query, request: Request, session=Depends(get_session), credentials=Depends(bearer)):
    return _page(request, session, query, credentials, True)
