"""Shared, fail-fast discovery work credits and expensive-operation leases."""
import hashlib
import logging
import math
import secrets
import time
from contextlib import contextmanager
from dataclasses import dataclass

from fastapi import HTTPException
from sqlalchemy import and_, case, or_, select, text, update
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from sqlalchemy.exc import DBAPIError, SQLAlchemyError

from .client_address import ClientAddress, anonymous_network
from .discovery_models import DiscoveryGuard
from .identity_models import RateBucket

LEASE_MS = 10000
RETENTION_SECONDS = 180
UNIT_MS = 25
RESERVE = 60  # Reserve the 1.5s query allowance; refund unused credit afterward.
log = logging.getLogger("bmt.discovery")


def insert(db, model):
    return (sqlite_insert if db.bind.dialect.name == "sqlite" else pg_insert)(model)


def costly(query, random=False):
    """Include non-text filters that may have to skip many ordered candidates."""
    return bool(random or query.get("search") or query.get("minimum_rating") or query.get("age_days")
        or query.get("theme", "all") != "all" or query.get("race_count", "any") != "any"
        or query.get("race_history", "any") != "any" or query.get("section", "all") != "all"
        or query.get("feed") == "rated" or query.get("ids") is not None or query.get("raced_ids")
        or query.get("favorites_present") or query.get("frozen_blocks") or query.get("owner"))


def busy(detail="DISCOVERY_QUERY_BUSY", seconds=1):
    return HTTPException(503, detail, headers={"Retry-After": str(max(1, math.ceil(seconds)))})


@contextmanager
def short_locks(db):
    raw = None
    if db.bind.dialect.name == "postgresql":
        db.execute(text("SET LOCAL lock_timeout='50ms'"))
    else:
        connection = db.connection()
        raw = connection.connection.driver_connection
        old = raw.execute("PRAGMA busy_timeout").fetchone()[0]
        connection.info.setdefault("discovery_busy_timeout", old)
        raw.execute("PRAGMA busy_timeout=50")
    try:
        yield
    except DBAPIError as error:
        if getattr(error.orig, "sqlstate", "") in ("55P03", "40P01") or "database is locked" in str(error.orig).lower():
            raise busy() from None
        raise
    finally:
        if raw is not None and db.in_transaction() and db.is_active:
            connection = db.connection()
            if connection.connection.driver_connection is raw:
                raw.execute("PRAGMA busy_timeout=" + str(old))
                connection.info.pop("discovery_busy_timeout", None)


@dataclass
class Ticket:
    key: str
    lane: str
    window: int
    token: str
    reserved: int
    started: float


def claim(db, actor, settings, lane):
    stamp = int(time.time() * 1000)
    window = stamp // 60000
    key = hashlib.sha256((actor + ":" + lane).encode()).hexdigest()
    reserved = 0 if lane == "storage" else RESERVE
    limit = (settings.discovery_expensive_units_per_minute if lane == "heavy"
             else settings.discovery_work_units_per_minute)
    token = secrets.token_hex(16) if lane != "light" else ""
    with short_locks(db):
        # A slow replica must not reset a newer window established elsewhere.
        allowed = [or_(DiscoveryGuard.window < window, DiscoveryGuard.used_units <= limit-reserved)]
        values = {"window": case((DiscoveryGuard.window >= window, DiscoveryGuard.window), else_=window),
            "expires_at": stamp//1000 + RETENTION_SECONDS,
            "used_units": case((DiscoveryGuard.window >= window, DiscoveryGuard.used_units+reserved), else_=reserved)}
        if token:
            allowed.append(DiscoveryGuard.lease_until <= stamp)
            values.update(lease_token=token, lease_until=stamp + LEASE_MS)
        if lane == "heavy":
            allowed.append(DiscoveryGuard.cooldown_until <= stamp)
        admitted = db.scalar(insert(db, DiscoveryGuard).values(id=key, scope=actor, lane=lane, window=window,
            used_units=reserved, failures=0, cooldown_until=0, lease_until=stamp+LEASE_MS if token else 0,
            lease_token=token, expires_at=stamp//1000+RETENTION_SECONDS).on_conflict_do_update(index_elements=["id"],
                set_=values, where=and_(*allowed)).returning(DiscoveryGuard.window))
        if admitted is None:
            row = db.scalar(select(DiscoveryGuard).where(DiscoveryGuard.id == key)
                .execution_options(populate_existing=True))
            if token and row.lease_until > stamp:
                raise busy(seconds=(row.lease_until-stamp)/1000)
            if lane == "heavy" and row.cooldown_until > stamp:
                raise busy("DISCOVERY_RETRY_COOLDOWN", (row.cooldown_until-stamp)/1000)
            raise HTTPException(429, "DISCOVERY_WORK_LIMIT", headers={"Retry-After": str(60-stamp//1000 % 60)})
        db.commit()  # Credits/lease survive a failed query, rollback or process death.
    ticket = Ticket(key, lane, admitted, token, reserved, time.monotonic())
    db.info.setdefault("discovery_tickets", []).append(ticket)
    return ticket


def owned(db):
    """Fence commits and hold expensive leases through their work transaction."""
    stamp = int(time.time() * 1000)
    for ticket in sorted(db.info.get("discovery_tickets", ()), key=lambda value: value.key):
        if not ticket.token:
            continue
        try:
            with db.no_autoflush:
                value = db.execute(select(DiscoveryGuard.lease_token, DiscoveryGuard.lease_until)
                    .where(DiscoveryGuard.id == ticket.key).with_for_update(nowait=True)).first()
        except DBAPIError as error:
            if getattr(error.orig, "sqlstate", "") == "55P03":
                raise busy() from None
            raise
        if value is None or value.lease_token != ticket.token or value.lease_until <= stamp:
            raise busy("DISCOVERY_LEASE_EXPIRED")


def finish(factory, tickets, error=None):
    """Use a fresh metadata transaction only after the request released its DB connection."""
    stamp = int(time.time() * 1000)
    for ticket in tickets:
        charge = 0 if ticket.lane == "storage" else max(4 if ticket.lane == "heavy" else 1,
            math.ceil((time.monotonic()-ticket.started)*1000/UNIT_MS))
        try:
            with factory() as db, short_locks(db):
                predicates = [DiscoveryGuard.id == ticket.key, DiscoveryGuard.window == ticket.window]
                values = {"used_units": DiscoveryGuard.used_units + charge-ticket.reserved}
                if ticket.token:
                    predicates.append(DiscoveryGuard.lease_token == ticket.token)
                    values.update(lease_until=0, lease_token="")
                if ticket.lane == "heavy":
                    failed = (isinstance(error, HTTPException) and error.status_code == 503
                        and error.detail in ("DISCOVERY_QUERY_BUDGET", "DISCOVERY_RANDOM_BUDGET",
                                             "DISCOVERY_VISIBILITY_CHANGED"))
                    if failed:
                        row = db.scalar(select(DiscoveryGuard).where(*predicates).with_for_update(nowait=True))
                        if row is None:
                            continue
                        failures = min(5, row.failures + 1)
                        retry = int(error.headers.get("Retry-After", "1")) if error.headers else 1
                        delay = max(retry, min(30, 2 ** failures))
                        values.update(failures=failures, cooldown_until=stamp + delay*1000)
                        error.headers = {**(error.headers or {}), "Retry-After": str(delay)}
                    elif error is None:
                        values.update(failures=0, cooldown_until=0)
                db.execute(update(DiscoveryGuard).where(*predicates).values(**values))
                db.commit()
        except SQLAlchemyError as failure:
            # A lost refund is conservative. A crashed/failed releaser's lease
            # expires; an old token can never release a replacement request.
            log.warning("discovery_guard_release_failed", extra={"exception_type": type(failure).__name__})
        except HTTPException:
            pass


def network_budget(db, request, category, limit, amount=1):
    peer = ClientAddress(request.app.state.settings.trusted_proxy_networks).resolve(request.scope)
    network = anonymous_network(peer)
    stamp = int(time.time())
    key = hashlib.sha256(f"discovery-network:{network}:{category}:{stamp//60}".encode()).hexdigest()
    with short_locks(db):
        result = db.scalar(insert(db, RateBucket).values(key=key, count=amount, expires_at=stamp+120)
            .on_conflict_do_update(index_elements=["key"], set_={"count": RateBucket.count+amount},
                where=RateBucket.count <= limit-amount).returning(RateBucket.count)) if amount <= limit else None
        db.commit()
    if result is None:
        raise HTTPException(429, "DISCOVERY_NETWORK_LIMIT", headers={"Retry-After": str(60-stamp % 60)})
