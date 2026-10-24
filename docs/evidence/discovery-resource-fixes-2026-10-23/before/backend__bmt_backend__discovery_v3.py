"""Indexed discovery pages. No request constructs a complete matching catalogue."""
import base64
import hashlib
import hmac
import json
import re
import secrets
import time
import uuid
from contextlib import contextmanager

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, ConfigDict, Field, model_validator
from sqlalchemy import and_, exists, func, or_, select, text, tuple_, union_all
from sqlalchemy.exc import DBAPIError

from .client_address import ClientAddress
from .community import blocked_ids
from .db import get_session
from .discovery import Query
from .discovery_models import (
    LIFETIME,
    PARTITIONS,
    DiscoveryBootstrap,
    DiscoveryBoundary,
    DiscoveryChange,
    DiscoveryCollection,
    DiscoveryHead,
    DiscoveryMember,
    DiscoveryPartition,
    DiscoverySession,
)
from .discovery_models import DiscoveryEntry as E
from .discovery_projection import insert
from .identity_models import Player
from .middleware import ParsedJSONRoute, check_budget
from .security import bearer, current_player
from .track_models import Track, TrackVersion, now
from .tracks import discovery_payload

router = APIRouter(route_class=ParsedJSONRoute, tags=["indexed discovery"])
PAGE = 20
QUERY_SECONDS = 1.5
RANDOM_SMALL = 256
RANDOM_TRIALS = 4096


class PageRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    query: Query | None = None
    cursor: str = Field("", max_length=400)
    exclude: str = Field("", max_length=80)
    locate_version: str = Field("", max_length=36)

    @model_validator(mode="after")
    def no_legacy_paging(self):
        if self.query and (self.query.offset is not None or self.query.cursor or
                self.query.locate_version or self.query.exclude):
            raise ValueError("V3 paging and selection fields belong outside query; offsets are unsupported")
        return self


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()).hexdigest()


@contextmanager
def query_budget(db):
    deadline = time.monotonic() + QUERY_SECONDS
    raw = None
    if db.bind.dialect.name == "sqlite":
        raw = db.connection().connection.driver_connection
        raw.set_progress_handler(lambda: int(time.monotonic() > deadline), 1000)
    else:
        db.execute(text("SET LOCAL statement_timeout=1500"))
    try:
        yield deadline
    except DBAPIError as error:
        code = getattr(error.orig, "sqlstate", "")
        if code == "57014" or "interrupted" in str(error.orig).lower():
            db.rollback()
            raise HTTPException(503, "DISCOVERY_QUERY_BUDGET", headers={"Retry-After": "1"}) from None
        raise
    finally:
        if raw is not None:
            raw.set_progress_handler(None, 0)


def check_deadline(db, deadline):
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        raise HTTPException(503, "DISCOVERY_QUERY_BUDGET", headers={"Retry-After": "1"})
    if db.bind.dialect.name == "postgresql":
        db.execute(select(func.set_config("statement_timeout", str(max(1, int(remaining * 1000))), True)))


def scope(request, player):
    identity = "player:" + player.id if player else "peer:" + ClientAddress(
        request.app.state.settings.trusted_proxy_networks).resolve(request.scope)
    return digest(identity)


def token(view, boundary):
    value = view.id + ":" + boundary.id
    mac = hmac.new(view.secret.encode(), value.encode(), hashlib.sha256).hexdigest()[:32]
    return base64.urlsafe_b64encode(json.dumps([view.id, boundary.id, mac], separators=(",", ":")).encode()).decode().rstrip("=")


def resolve(db, value, actor, stamp):
    try:
        decoded = json.loads(base64.b64decode(value + "=" * (-len(value) % 4), altchars=b"-_", validate=True))
        if (not isinstance(decoded, list) or len(decoded) != 3 or
                any(not isinstance(v, str) for v in decoded) or [len(v) for v in decoded] != [36, 64, 32]):
            raise ValueError
    except (ValueError, UnicodeError, TypeError):
        raise HTTPException(422, "INVALID_CURSOR") from None
    view = db.get(DiscoverySession, decoded[0])
    boundary = db.get(DiscoveryBoundary, decoded[1])
    if view is None or boundary is None or view.expires_at <= stamp or boundary.expires_at <= stamp:
        raise HTTPException(410, "DISCOVERY_CURSOR_EXPIRED")
    if view.scope != actor or boundary.session_id != view.id or not hmac.compare_digest(token(view, boundary), value):
        raise HTTPException(422, "INVALID_CURSOR")
    return view, boundary


def boundary(db, view, positions, phase, previous=None, anchor=None):
    identity = digest([view.id, positions, phase, previous, anchor])
    created = db.scalar(insert(db, DiscoveryBoundary).values(id=identity, session_id=view.id,
        expires_at=view.expires_at, positions=positions, phase=phase,
        previous_id=previous, anchor_version=anchor).on_conflict_do_nothing(index_elements=["id"])
        .returning(DiscoveryBoundary))
    return created if created is not None else db.get(DiscoveryBoundary, identity)


def collection(db, request, actor, query, stamp, deadline, blocks):
    values = {"favorite": sorted(set(query.ids or [])), "raced": sorted(set(query.raced_ids)),"block":blocks}
    if not any(values.values()):
        return None
    identity = digest([actor, values, stamp // LIFETIME])
    existing = db.get(DiscoveryCollection, identity)
    if existing:
        return identity
    active = list(db.scalars(select(DiscoveryCollection.id).where(DiscoveryCollection.scope == actor,
        DiscoveryCollection.expires_at > stamp).limit(32)))
    if len(active) >= 32:
        raise HTTPException(429, "DISCOVERY_COLLECTION_LIMIT")
    size = sum(len(v) for v in values.values())
    if not check_budget(request.app.state.session_factory, actor, "discovery_collection_rows", 101000, size, session=db):
        raise HTTPException(429, "DISCOVERY_COLLECTION_LIMIT")
    inserted = db.scalar(insert(db, DiscoveryCollection).values(id=identity, scope=actor,
        expires_at=(stamp // LIFETIME + 2) * LIFETIME).on_conflict_do_nothing(index_elements=["id"])
        .returning(DiscoveryCollection.id))
    if inserted:
        rows = [{"collection_id": identity, "kind": kind, "track_id": tid} for kind, ids in values.items() for tid in ids]
        for start in range(0, len(rows), 256):
            check_deadline(db, deadline)
            db.execute(insert(db, DiscoveryMember).values(rows[start:start + 256]).on_conflict_do_nothing())
    return identity


def new_session(db, request, actor, player, query, stamp, anchor, deadline):
    check_deadline(db, deadline)
    # Sixteen bounded index probes, one network round trip. Never GROUP/COUNT
    # the journal: an arbitrarily large backlog must not slow admission checks.
    oldest = select(DiscoveryChange.created_at).where(
        DiscoveryChange.partition == DiscoveryPartition.id, DiscoveryChange.processed_at.is_(None)
        ).order_by(DiscoveryChange.id).limit(1).correlate(DiscoveryPartition).scalar_subquery()
    health = list(db.execute(select(DiscoveryPartition, oldest, DiscoveryBootstrap.ready)
        .join(DiscoveryBootstrap, DiscoveryBootstrap.id == 1).order_by(DiscoveryPartition.id)))
    partitions = [row[0] for row in health]
    if len(partitions) != PARTITIONS or not all(p.ready and ready for p, _, ready in health):
        raise HTTPException(503, "DISCOVERY_INDEX_PREPARING", headers={"Retry-After": "2"})
    if any(p.checked_at < (stamp - 120) * 1_000_000_000 for p in partitions):
        raise HTTPException(503, "DISCOVERY_INDEX_STALE", headers={"Retry-After": "2"})
    # A running consumer can still fall behind. Inspect one indexed pending
    # receipt per partition rather than counting or scanning the journal.
    for _, pending_at, _ in health:
        if pending_at is not None and pending_at < stamp - 120:
            raise HTTPException(503, "DISCOVERY_INDEX_STALE", headers={"Retry-After": "2"})
    if query.section == "saved" and player is None:
        raise HTTPException(401, "AUTH_REQUIRED")
    # Freeze the bounded personal exclusion set, while delivery still checks
    # current blocks. A new block/unblock opens a different view immediately.
    blocks = list(db.scalars(blocked_ids(db,player.id).order_by("blocked_id").limit(1001))) if player else []
    if len(blocks) > 1000:
        raise HTTPException(429,"DISCOVERY_COLLECTION_LIMIT")
    values = query.model_dump(exclude={"cursor", "offset", "fresh", "exclude", "locate_version", "ids", "raced_ids"})
    values["owner"] = player.id if player and query.section == "saved" else ""
    values["favorites_present"] = query.ids is not None
    values["frozen_blocks"] = bool(blocks)
    identity = str(uuid.uuid5(uuid.NAMESPACE_URL, digest([actor, query.model_dump(),
        [p.epoch for p in partitions], stamp // 20, anchor, blocks])))
    existing = db.get(DiscoverySession, identity)
    if existing and existing.expires_at > stamp:
        return existing, boundary(db, existing, {}, 0, anchor=anchor or None)
    if existing:
        identity = str(uuid.uuid4()) # An explicitly expired view is never resurrected.
    if len(list(db.scalars(select(DiscoverySession.id).where(DiscoverySession.scope == actor,
            DiscoverySession.expires_at > stamp).limit(64)))) >= 64:
        raise HTTPException(429, "DISCOVERY_SESSION_LIMIT")
    if not check_budget(request.app.state.session_factory, actor, "discovery_v3_create",
            request.app.state.settings.discovery_create_per_minute, session=db):
        raise HTTPException(429, "DISCOVERY_CREATION_LIMIT")
    check_deadline(db, deadline)
    collection_id = collection(db, request, actor, query, stamp, deadline, blocks)
    view = db.scalar(insert(db, DiscoverySession).values(id=identity, scope=actor, created_at=stamp,
        expires_at=stamp + LIFETIME, secret=secrets.token_hex(32), query=values,
        epochs=[p.epoch for p in partitions], slots=[p.slots for p in partitions],
        collection_id=collection_id).on_conflict_do_nothing(index_elements=["id"]).returning(DiscoverySession))
    if view is None:
        view = db.get(DiscoverySession, identity)
    return view, boundary(db, view, {}, 0, anchor=anchor or None)


def ordering(query):
    name = query["sort"]
    if name == "recommended":
        name = {"new": "new", "popular": "popular", "trending": "popular", "rated": "score"}.get(query["feed"], "recommended")
    fields = {
        "new": [("published_at", True), ("track_id", True)],
        "recommended": [("published_at", True), ("track_id", True)],
        "name": [("name_key", False), ("track_id", False)],
        "creator": [("creator_key", False), ("name_key", False), ("track_id", False)],
        "score": [("rated", True), ("score", True), ("published_at", True), ("track_id", True)],
        "plays": [("finishers", True), ("published_at", True), ("track_id", True)],
        "popular": [("popularity", True), ("published_at", True), ("track_id", True)],
    }
    return name, fields[name]


def key(row, fields):
    return [row[name] for name, _ in fields]


def seek(fields, values, inclusive=False):
    if values is None:
        return True
    if not isinstance(values, list) or len(values) != len(fields):
        raise HTTPException(422, "INVALID_CURSOR")
    options = []
    for index, (name, descending) in enumerate(fields):
        col = getattr(E, name)
        if isinstance(values[index], bool):
            comparison = col.is_(not descending) if values[index] == descending else False
        else:
            comparison = col < values[index] if descending else col > values[index]
        options.append(and_(*(getattr(E, n) == values[i] for i, (n, _) in enumerate(fields[:index])), comparison))
    if inclusive:
        options.append(and_(*(getattr(E, n) == values[i] for i, (n, _) in enumerate(fields))))
    return or_(*options)


def conditions(view, player, authority=True, postgres=False):
    q = view.query
    result = [E.visible.is_(True)]
    if authority:
        result.extend([Track.hidden.is_(False), TrackVersion.state == "published",
            Player.disabled.is_(False), Player.deleted_at.is_(None), Player.is_test_driver.is_(False)])
    if player and authority:
        result.append(~E.owner_id.in_(blocked_ids(None, player.id)))
    if q.get("frozen_blocks"):
        result.append(~exists(select(DiscoveryMember.track_id).where(DiscoveryMember.collection_id == view.collection_id,
            DiscoveryMember.kind == "block", DiscoveryMember.track_id == E.owner_id)))
    if q["owner"]:
        result.append(E.owner_id == q["owner"])
    if q["theme"] != "all":
        result.append(E.theme == q["theme"])
    if q["minimum_rating"]:
        result.extend([E.rating_count > 0, E.rating_sum >= (q["minimum_rating"] - .000001) * E.rating_count])
    if q["age_days"]:
        result.append(E.created_at >= view.created_at - q["age_days"] * 86400)
    if q["race_count"] == "low":
        result.append(E.finishers < 10)
    elif q["race_count"] == "medium":
        result.extend([E.finishers >= 10, E.finishers < 50])
    elif q["race_count"] == "high":
        result.append(E.finishers >= 50)
    if q["feed"] == "rated":
        result.append(E.rating_count > 0)
    term = q["search"].strip()
    if term:
        name, creator = E.name.icontains(term, autoescape=True), E.creator.icontains(term, autoescape=True)
        if postgres and not re.search(r"[^\W_]{3}", term):
            # Trigrams cannot accelerate these patterns. The immutable SQL
            # function uses database lower()/characters, including punctuation;
            # ILIKE remains the exact final substring predicate.
            grams = func.discovery_short_grams(term)
            name = and_(func.discovery_short_grams(E.name).op("@>")(grams), name)
            creator = and_(func.discovery_short_grams(E.creator).op("@>")(grams), creator)
        result.append(name if q["search_kind"] == 1 else creator if q["search_kind"] == 2 else or_(name, creator))
    def member(kind):
        return exists(select(DiscoveryMember.track_id).where(DiscoveryMember.collection_id == view.collection_id,
            DiscoveryMember.kind == kind, DiscoveryMember.track_id == E.track_id))
    if q["favorites_present"] or q["section"] == "favorites":
        result.append(member("favorite") if view.collection_id else False)
    if q["race_history"] != "any":
        match = member("raced") if view.collection_id else False
        result.append(match if q["race_history"] == "raced" else ~match if match is not False else True)
    return result


def at_epoch(shard, epoch):
    return and_(E.partition == shard, E.epoch <= epoch, or_(E.until.is_(None), E.until > epoch))


def base(authority=True, columns=None):
    statement = select(*(columns if columns is not None else (E,)))
    if authority:
        statement = (statement.join(Track, Track.id == E.track_id).join(Player, Player.id == Track.owner_id)
            .join(TrackVersion, TrackVersion.id == E.version_id))
    return statement


def fetch(db, view, player, fields, after=None, official=None, limit=PAGE + 1, extra=(), inclusive=False, authority=True):
    predicates = conditions(view, player, authority, db.bind.dialect.name == "postgresql")
    names = dict.fromkeys(["track_id", "version_id", "official", *(n for n, _ in fields)])
    columns = [getattr(E, name) for name in names]
    orders = [getattr(E, n).desc() if desc else getattr(E, n).asc() for n, desc in fields]
    pieces = []
    for shard, epoch in enumerate(view.epochs):
        statement = base(authority, columns).where(at_epoch(shard, epoch), *predicates, seek(fields, after, inclusive), *extra)
        if official is not None:
            statement = statement.where(E.official == official)
        sub = statement.order_by(*orders).limit(limit).subquery()
        pieces.append(select(*sub.c))
    merged = union_all(*pieces).subquery()
    order = [merged.c[n].desc() if desc else merged.c[n].asc() for n, desc in fields]
    return list(db.execute(select(merged).order_by(*order).limit(limit)).mappings())


def hydrate(db, request, rows, player):
    if not rows:
        return {}
    # Recheck current authority; frozen filter/rank fields never authorize access.
    statement = (select(TrackVersion, Track, Player.display_name).join(Track, Track.id == TrackVersion.track_id)
        .join(Player, Player.id == Track.owner_id).where(TrackVersion.id.in_([r["version_id"] for r in rows]),
            TrackVersion.state == "published", Track.hidden.is_(False), Player.disabled.is_(False),
            Player.deleted_at.is_(None), Player.is_test_driver.is_(False)))
    if player:
        statement = statement.where(~Track.owner_id.in_(blocked_ids(db, player.id)))
    return {v.id: {**discovery_payload(request, v, t, name), "verified_finishers": v.verified_finishers}
        for v, t, name in db.execute(statement)}


def page(db, request, view, start, player, deadline):
    order, fields = ordering(view.query)
    positions, phase = dict(start.positions), start.phase
    anchor = None
    if start.anchor_version:
        matches = fetch(db, view, player, fields, limit=1, extra=(E.version_id == start.anchor_version,))
        if not matches:
            raise HTTPException(409, "DISCOVERY_ANCHOR_UNAVAILABLE", headers={"Retry-After": "1"})
        anchor = matches[0]
        positions = {"all": key(anchor, fields)} if order != "recommended" else {
            "official": key(anchor, fields), "community": key(anchor, fields)}
        phase = 1 if anchor["official"] else 0
    rows = [anchor] if anchor else []
    if order != "recommended":
        check_deadline(db, deadline)
        candidates = fetch(db, view, player, fields, positions.get("all"),authority=False)
        rows.extend(candidates[:PAGE + 1 - len(rows)])
        for row in rows[:PAGE]:
            positions["all"] = key(row, fields)
    else:
        streams = {}
        for name, official in (("official", True), ("community", False)):
            check_deadline(db, deadline)
            streams[name] = fetch(db, view, player, fields, positions.get(name), official,authority=False)
        indices = {"official": 0, "community": 0}
        saved_phase = phase
        while len(rows) <= PAGE:
            name = "community" if phase == 3 else "official"
            if indices[name] >= len(streams[name]):
                name = "official" if name == "community" else "community"
            if indices[name] >= len(streams[name]):
                break
            row = streams[name][indices[name]]
            indices[name] += 1
            rows.append(row)
            phase = (phase + 1) % 4
            if len(rows) <= PAGE:
                positions[name], saved_phase = key(row, fields), phase
        phase = saved_phase
    has_more = len(rows) > PAGE
    rows = rows[:PAGE]
    check_deadline(db, deadline)
    payloads = hydrate(db, request, rows, player)
    items = [payloads[r["version_id"]] for r in rows if r["version_id"] in payloads]
    check_deadline(db, deadline)
    next_page = boundary(db, view, positions, phase, previous=start.id) if has_more else None
    previous = db.get(DiscoveryBoundary, start.previous_id) if start.previous_id else None
    return {"schema": "bmt-discovery-page-v3", "items": items, "total": None, "has_more": has_more,
        "next_cursor": token(view, next_page) if next_page else None,
        "previous_cursor": token(view, previous) if previous else None, "page_cursor": token(view, start),
        "expires_in": max(0, view.expires_at - now()), "anchored": bool(anchor)}


def choose(db, request, view, player, exclude, deadline):
    _, fields = ordering(view.query)
    check_deadline(db, deadline)
    small = fetch(db, view, player, fields, limit=RANDOM_SMALL + 1, extra=(E.track_id != exclude,))
    if len(small) <= RANDOM_SMALL:
        if not small and exclude:
            small = fetch(db, view, player, fields, limit=1, extra=(E.track_id == exclude,))
        selected = [secrets.choice(small)] if small else []
    else:
        # Uniform slots, including holes. Rejection retains exact conditional
        # uniformity; rare eligibility may explicitly exhaust the work budget.
        total = sum(view.slots)
        selected = []
        for batch in range(RANDOM_TRIALS // 128):
            check_deadline(db, deadline)
            draws = []
            for _ in range(128):
                value = secrets.randbelow(total)
                for shard, count in enumerate(view.slots):
                    if value < count:
                        draws.append((shard, value + 1))
                        break
                    value -= count
            rows = list(db.execute(base(columns=(E.track_id, E.version_id,
                DiscoveryHead.partition.label("sample_partition"), DiscoveryHead.slot.label("sample_slot")))
                .join(DiscoveryHead, DiscoveryHead.track_id == E.track_id)
                .where(tuple_(DiscoveryHead.partition, DiscoveryHead.slot).in_(draws),
                    or_(*(at_epoch(p, epoch) for p, epoch in enumerate(view.epochs))),
                    *conditions(view, player, postgres=db.bind.dialect.name == "postgresql"), E.track_id != exclude)).mappings())
            by_slot = {(row["sample_partition"], row["sample_slot"]): row for row in rows}
            selected = next(([by_slot[d]] for d in draws if d in by_slot), [])
            if selected:
                break
        if not selected:
            raise HTTPException(503, "DISCOVERY_RANDOM_BUDGET", headers={"Retry-After": "1"})
    check_deadline(db, deadline)
    items = list(hydrate(db, request, selected, player).values())
    if selected and not items:
        raise HTTPException(503, "DISCOVERY_VISIBILITY_CHANGED", headers={"Retry-After": "1"})
    return {"schema": "bmt-discovery-random-v3", "items": items, "complete": True}


def handle(body, request, db, credentials, random_choice):
    player = current_player(request, credentials, db) if credentials else None
    actor, stamp = scope(request, player), now()
    with query_budget(db) as deadline:
        if body.cursor:
            if body.query is not None or body.locate_version:
                raise HTTPException(422, "CURSOR_QUERY_CONFLICT")
            view, start = resolve(db, body.cursor, actor, stamp)
        else:
            if body.query is None:
                raise HTTPException(422, "DISCOVERY_QUERY_REQUIRED")
            view, start = new_session(db, request, actor, player, body.query, stamp, body.locate_version, deadline)
        gate = getattr(request.state, "discovery_expensive_gate", None)
        if gate is not None and view.query["search"].strip() and not getattr(request.state, "discovery_search_admitted", False):
            if not gate.acquire(blocking=False):
                raise HTTPException(503, "DISCOVERY_SEARCH_BUSY", headers={"Retry-After": "1"})
            request.state.discovery_search_admitted = True
        check_deadline(db, deadline)
        result = choose(db, request, view, player, body.exclude, deadline) if random_choice else page(
            db, request, view, start, player, deadline)
        check_deadline(db, deadline)
        db.commit()
    return result


@router.post("/v1/discovery/v3/tracks")
def discover(body: PageRequest, request: Request, db=Depends(get_session), credentials=Depends(bearer)):
    return handle(body, request, db, credentials, False)


@router.post("/v1/discovery/v3/random")
def random_track(body: PageRequest, request: Request, db=Depends(get_session), credentials=Depends(bearer)):
    return handle(body, request, db, credentials, True)
