"""Durable occurrences, operator decisions and leased notification outbox."""

import base64
import hashlib
import hmac
import json
from uuid import UUID, uuid4

import requests
from fastapi import APIRouter, HTTPException, Query, Request
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import delete, func, or_, select, text

from .admin import Access
from .admin_models import AdminAudit
from .middleware import ParsedJSONRoute
from .studio_access import actor
from .studio_cases import begin, owner, safe_text
from .studio_platform_models import (
    StudioDelivery,
    StudioIncident,
    StudioIncidentEvent,
    StudioObservation,
    StudioSignal,
    StudioStaff,
)
from .studio_queries import read_snapshot
from .studio_settings import mapping
from .track_models import OperationState, digest, now

router = APIRouter(route_class=ParsedJSONRoute, tags=["Studio incidents"])


class Signal(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    key: str = Field(pattern=r"^[A-Za-z0-9_.-]{1,64}$")
    active: bool | None
    severity: str = Field(pattern="^(warning|critical)$")
    title: str = Field(min_length=1, max_length=160)
    evidence: str = Field(max_length=500)
    next_step: str = Field(max_length=500)
    target: str = Field(pattern=r"^[a-z]+(?:/[A-Za-z0-9_-]+)?(?:\?[A-Za-z0-9_=&.-]+)?$", max_length=160)


class Observation(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    id: str = Field(min_length=36, max_length=36)
    observed_at: int = Field(ge=1)
    signals: list[Signal] = Field(min_length=1, max_length=32)
    http: dict | None = None
    notifies_externally: bool = False


def incident_value(row):
    return {
        name: getattr(row, name)
        for name in (
            "id",
            "source",
            "signal",
            "occurrence",
            "title",
            "severity",
            "state",
            "revision",
            "opened_at",
            "last_seen_at",
            "recovered_at",
            "closed_at",
            "assignee",
            "evidence",
        )
    }


def event(db, settings, row, kind, identity, who, detail, request_hash, *, notify=True):
    db.add(
        StudioIncidentEvent(
            id=identity,
            incident_id=row.id,
            actor=who,
            kind=kind,
            revision=row.revision,
            detail=detail,
            request_hash=request_hash,
        )
    )
    if notify and settings.studio_monitor_webhook_url and kind in ("opened", "recovered", "escalated"):
        delivery_id = digest({"event": identity, "destination": settings.studio_monitor_webhook_url})
        db.add(
            StudioDelivery(
                id=delivery_id,
                incident_id=row.id,
                event_id=identity,
                payload={
                    "schema": "bmt-incident-v1",
                    "event_id": identity,
                    "kind": kind,
                    "incident": incident_value(row),
                },
            )
        )


def record(db, settings, source, body, *, notify=True):
    try:
        identity = str(UUID(body.id))
    except ValueError:
        raise HTTPException(422, "INVALID_OBSERVATION_ID") from None
    data = body.model_dump()
    if body.http is not None:
        from .studio_http_metrics import validate_report

        validate_report(body.http)
    fingerprint = digest({"source": source, **data})
    if db.bind.dialect.name == "sqlite":
        db.execute(text("BEGIN IMMEDIATE"))
    else:
        db.execute(
            text("SELECT pg_advisory_xact_lock(:key)"),
            {"key": int(hashlib.sha256(("monitor:" + source).encode()).hexdigest()[:15], 16)},
        )
    old = db.get(StudioObservation, identity)
    if old:
        if old.payload_hash != fingerprint:
            raise HTTPException(409, "OBSERVATION_ID_CONFLICT")
        return {"id": identity, "duplicate": True}
    if body.observed_at > now() + 60:
        raise HTTPException(422, "OBSERVATION_IN_FUTURE")
    if len({s.key for s in body.signals}) != len(body.signals):
        raise HTTPException(422, "DUPLICATE_SIGNAL")
    heartbeat = db.get(OperationState, "studio-monitor:" + source)
    if heartbeat is None:
        heartbeat = OperationState(id="studio-monitor:" + source, details={})
        db.add(heartbeat)
    prior = heartbeat.details or {}
    if body.observed_at > prior.get("observed_at", 0):
        current = {s.key: s.active is not None for s in body.signals}
        keys = set(current) | set(prior.get("known", {}))
        if len(keys) > 64:
            raise HTTPException(422, "MONITOR_SIGNAL_BUDGET_EXCEEDED")
        heartbeat.details = {
            "source": source,
            "observed_at": body.observed_at,
            "known": {key: current.get(key, False) for key in keys},
        }
    heartbeat.updated_at = now()
    db.add(
        StudioObservation(
            id=identity, source=source, observed_at=body.observed_at, payload_hash=fingerprint, values=data
        )
    )
    for signal in body.signals:
        state = db.scalar(
            select(StudioSignal)
            .where(StudioSignal.source == source, StudioSignal.key == signal.key)
            .with_for_update()
        )
        if state is None:
            state = StudioSignal(
                source=source,
                key=signal.key,
                occurrence=0,
                active=None,
                observed_at=0,
                suppressed_until=0,
                suppression_reason="",
            )
            db.add(state)
        if body.observed_at <= state.observed_at:
            continue
        row = (
            db.scalar(select(StudioIncident).where(StudioIncident.id == state.incident_id).with_for_update())
            if state.incident_id
            else None
        )
        prior_active = state.active
        state.observed_at = body.observed_at
        if signal.active is None:
            # Missing evidence does not recover a previously firing condition.
            continue
        state.active = signal.active
        if signal.active:
            if row is None or row.recovered_at is not None:
                state.occurrence += 1
                row = StudioIncident(
                    id=str(uuid4()),
                    source=source,
                    signal=signal.key,
                    occurrence=state.occurrence,
                    title=signal.title,
                    severity=signal.severity,
                    state="open",
                    revision=0,
                    opened_at=body.observed_at,
                    last_seen_at=body.observed_at,
                    assignee="",
                    evidence=signal.model_dump(),
                )
                state.incident_id = row.id
                db.add(row)
                event(
                    db,
                    settings,
                    row,
                    "opened",
                    str(uuid4()),
                    "monitor",
                    signal.model_dump(),
                    fingerprint,
                    notify=notify and state.suppressed_until <= now(),
                )
            else:
                escalated = row.severity != "critical" and signal.severity == "critical"
                row.last_seen_at, row.evidence, row.title = (
                    body.observed_at,
                    signal.model_dump(),
                    signal.title,
                )
                row.severity = signal.severity
                if escalated:
                    row.state, row.revision = "open", row.revision + 1
                    event(
                        db,
                        settings,
                        row,
                        "escalated",
                        str(uuid4()),
                        "monitor",
                        signal.model_dump(),
                        fingerprint,
                        notify=notify and state.suppressed_until <= now(),
                    )
        elif row and row.recovered_at is None and prior_active:
            row.state, row.recovered_at, row.last_seen_at = "recovered", body.observed_at, body.observed_at
            row.evidence, row.revision = signal.model_dump(), row.revision + 1
            event(
                db,
                settings,
                row,
                "recovered",
                str(uuid4()),
                "monitor",
                signal.model_dump(),
                fingerprint,
                notify=notify and state.suppressed_until <= now(),
            )
    expired = db.scalars(
        select(StudioObservation.id)
        .where(StudioObservation.observed_at < now() - 30 * 86400)
        .order_by(StudioObservation.observed_at)
        .limit(100)
    ).all()
    if expired:
        db.execute(delete(StudioObservation).where(StudioObservation.id.in_(expired)))
    db.commit()
    return {"id": identity, "duplicate": False}


@router.post("/v1/monitor/{source}/observations")
def ingest(source: str, body: Observation, request: Request):
    token = mapping(request.app.state.settings.studio_monitor_source_tokens).get(source, "")
    supplied = request.headers.get("authorization", "").removeprefix("Bearer ")
    if not token or not hmac.compare_digest(token.encode(), supplied.encode()):
        raise HTTPException(401, "MONITOR_AUTH_REQUIRED")
    if body.notifies_externally != (source in request.app.state.settings.studio_monitor_external_notifiers):
        raise HTTPException(409, "MONITOR_NOTIFICATION_AUTHORITY_MISMATCH")
    with request.app.state.session_factory() as db:
        return record(
            db,
            request.app.state.settings,
            source,
            body,
            notify=source not in request.app.state.settings.studio_monitor_external_notifiers,
        )


@router.get("/v1/monitor/{source}/control")
def control(source: str, request: Request):
    token = mapping(request.app.state.settings.studio_monitor_source_tokens).get(source, "")
    supplied = request.headers.get("authorization", "").removeprefix("Bearer ")
    if not token or not hmac.compare_digest(token.encode(), supplied.encode()):
        raise HTTPException(401, "MONITOR_AUTH_REQUIRED")
    with request.app.state.session_factory() as db:
        read_snapshot(db)
        rows = db.scalars(
            select(StudioSignal).where(StudioSignal.source == source).order_by(StudioSignal.key).limit(32)
        ).all()
        return {
            "source": source,
            "external_delivery": source in request.app.state.settings.studio_monitor_external_notifiers,
            "items": [
                {"key": r.key, "suppressed_until": r.suppressed_until, "reason": r.suppression_reason}
                for r in rows
            ],
        }


@router.get("/v1/admin/incidents")
def incidents(
    request: Request,
    role: Access,
    state: str = "actionable",
    limit: int = Query(50, ge=1, le=100),
    cursor: str = Query("", max_length=400),
):
    if state not in ("actionable", "all", "open", "acknowledged", "recovered", "closed"):
        raise HTTPException(422, "INVALID_INCIDENT_STATE")
    conditions = (
        [StudioIncident.state != "closed"]
        if state == "actionable"
        else []
        if state == "all"
        else [StudioIncident.state == state]
    )
    if cursor:
        try:
            anchor = json.loads(base64.urlsafe_b64decode(cursor + "=" * (-len(cursor) % 4)))
            if (
                set(anchor) != {"state", "at", "id"}
                or anchor["state"] != state
                or type(anchor["at"]) is not int
            ):
                raise ValueError()
            str(UUID(anchor["id"]))
            conditions.append(
                or_(
                    StudioIncident.opened_at < anchor["at"],
                    (StudioIncident.opened_at == anchor["at"]) & (StudioIncident.id > anchor["id"]),
                )
            )
        except (ValueError, KeyError, TypeError, AttributeError):
            raise HTTPException(422, "INVALID_INCIDENT_CURSOR") from None
    with request.app.state.session_factory() as db:
        read_snapshot(db)
        rows = db.scalars(
            select(StudioIncident)
            .where(*conditions)
            .order_by(StudioIncident.opened_at.desc(), StudioIncident.id)
            .limit(limit + 1)
        ).all()
        sources = db.scalars(
            select(OperationState).where(OperationState.id.startswith("studio-monitor:")).limit(100)
        ).all()
        source_values = {
            r.details["source"]: {
                "source": r.details["source"],
                "last_receipt_at": r.updated_at,
                "observed_at": r.details["observed_at"],
                "unknown_signals": sum(not v for v in r.details.get("known", {}).values()),
                "stale": now() - min(r.updated_at, r.details["observed_at"])
                > request.app.state.settings.studio_monitor_poll_seconds * 3,
            }
            for r in sources
        }
        for source in mapping(request.app.state.settings.studio_monitor_source_tokens):
            source_values.setdefault(
                source, {"source": source, "last_receipt_at": None, "observed_at": None, "stale": True}
            )
        delivery = dict(
            db.execute(select(StudioDelivery.state, func.count()).group_by(StudioDelivery.state)).all()
        )
        next_cursor = None
        if len(rows) > limit:
            next_cursor = (
                base64.urlsafe_b64encode(
                    json.dumps(
                        {"state": state, "at": rows[limit - 1].opened_at, "id": rows[limit - 1].id}
                    ).encode()
                )
                .decode()
                .rstrip("=")
            )
        return {
            "role": role,
            "as_of": now(),
            "items": [incident_value(row) for row in rows[:limit]],
            "truncated": len(rows) > limit,
            "next_cursor": next_cursor,
            "counts": dict(
                db.execute(select(StudioIncident.state, func.count()).group_by(StudioIncident.state)).all()
            ),
            "sources": list(source_values.values()),
            "configured_sources": list(mapping(request.app.state.settings.studio_monitor_source_tokens)),
            "delivery": delivery,
            "notifications_configured": bool(
                request.app.state.settings.studio_monitor_webhook_url
                or request.app.state.settings.studio_monitor_external_notifiers
            ),
        }


@router.get("/v1/admin/incidents/{identity}")
def detail(identity: UUID, request: Request, role: Access):
    with request.app.state.session_factory() as db:
        read_snapshot(db)
        row = db.get(StudioIncident, str(identity))
        if not row:
            raise HTTPException(404, "INCIDENT_NOT_FOUND")
        events = db.scalars(
            select(StudioIncidentEvent)
            .where(StudioIncidentEvent.incident_id == str(identity))
            .order_by(StudioIncidentEvent.created_at.desc(), StudioIncidentEvent.id)
            .limit(101)
        ).all()
        signal = db.get(StudioSignal, (row.source, row.signal))
        heartbeat = db.get(OperationState, "studio-monitor:" + row.source)
        return {
            "role": role,
            "item": incident_value(row),
            "signal": {
                "active": signal.active,
                "known": bool(heartbeat and heartbeat.details.get("known", {}).get(row.signal, False)),
                "observed_at": signal.observed_at,
                "suppressed_until": signal.suppressed_until,
            },
            "history": [
                {
                    "id": e.id,
                    "kind": e.kind,
                    "actor": e.actor,
                    "created_at": e.created_at,
                    "detail": e.detail,
                    "revision": e.revision,
                }
                for e in events[:100]
            ],
            "truncated": len(events) > 100,
        }


@router.get("/v1/admin/monitor/history")
def history(
    request: Request,
    role: Access,
    source: str = Query("", max_length=64),
    limit: int = Query(200, ge=1, le=500),
):
    with request.app.state.session_factory() as db:
        read_snapshot(db)
        conditions = [StudioObservation.source == source] if source else []
        rows = db.scalars(
            select(StudioObservation)
            .where(*conditions)
            .order_by(StudioObservation.observed_at.desc(), StudioObservation.id)
            .limit(limit + 1)
        ).all()
        return {
            "role": role,
            "as_of": now(),
            "items": [
                {
                    "source": r.source,
                    "observed_at": r.observed_at,
                    "received_at": r.received_at,
                    "signals": r.values["signals"],
                    "http": r.values.get("http"),
                }
                for r in rows[:limit]
            ],
            "truncated": len(rows) > limit,
            "retention_days": 30,
            "scope": "Latest bounded observation history. Missing collection intervals are unknown; history is not a continuous uptime denominator.",
        }


class Command(BaseModel):
    model_config = ConfigDict(extra="forbid")
    command_id: UUID
    expected_revision: int = Field(ge=0)
    action: str = Field(pattern="^(acknowledge|assign|clear|suppress)$")
    reason: str = Field(min_length=3, max_length=500)
    assignee: str = Field(default="", max_length=24)
    suppress_seconds: int = Field(default=0, ge=0, le=86400)


@router.get("/v1/admin/notifications")
def notifications(request: Request, role: Access, state: str = "dead"):
    if state not in ("dead", "pending", "delivered", "dismissed"):
        raise HTTPException(422, "INVALID_NOTIFICATION_STATE")
    with request.app.state.session_factory() as db:
        read_snapshot(db)
        rows = db.scalars(
            select(StudioDelivery)
            .where(StudioDelivery.state == state)
            .order_by(StudioDelivery.created_at.desc(), StudioDelivery.id)
            .limit(51)
        ).all()
        return {
            "role": role,
            "configured": bool(request.app.state.settings.studio_monitor_webhook_url),
            "items": [
                {
                    key: getattr(r, key)
                    for key in ("id", "incident_id", "state", "attempts", "created_at", "last_error")
                }
                for r in rows[:50]
            ],
            "truncated": len(rows) > 50,
            "scope": "Stored delivery events; retry preserves the original event and idempotency key.",
        }


class NotificationCommand(BaseModel):
    model_config = ConfigDict(extra="forbid")
    command_id: UUID
    expected_attempts: int = Field(ge=0)
    action: str = Field(pattern="^(retry|dismiss)$")
    reason: str = Field(min_length=3, max_length=500)


@router.post("/v1/admin/notifications/{identity}/commands")
def notification_command(identity: str, body: NotificationCommand, request: Request, role: Access):
    owner(role)
    if len(identity) != 64 or any(c not in "0123456789abcdef" for c in identity):
        raise HTTPException(422, "INVALID_NOTIFICATION_ID")
    fingerprint = digest({"id": identity, **body.model_dump(mode="json")})
    with request.app.state.session_factory() as db:
        begin(db, str(body.command_id))
        old = db.scalar(select(AdminAudit).where(AdminAudit.command_id == str(body.command_id)))
        if old:
            if old.request_hash != fingerprint:
                raise HTTPException(409, "COMMAND_ID_CONFLICT")
            return old.after
        row = db.scalar(select(StudioDelivery).where(StudioDelivery.id == identity).with_for_update())
        if not row:
            raise HTTPException(404, "NOTIFICATION_NOT_FOUND")
        if row.state != "dead" or row.attempts != body.expected_attempts:
            raise HTTPException(409, "NOTIFICATION_CHANGED")
        before = {"id": row.id, "state": row.state, "attempts": row.attempts}
        if body.action == "retry":
            if not request.app.state.settings.studio_monitor_webhook_url:
                raise HTTPException(409, "NOTIFICATIONS_NOT_CONFIGURED")
            row.state, row.attempts, row.next_attempt_at, row.lease_token, row.lease_until = (
                "pending",
                0,
                now(),
                None,
                0,
            )
        else:
            row.state = "dismissed"
        after = {"id": row.id, "state": row.state, "attempts": row.attempts}
        db.add(
            AdminAudit(
                command_id=str(body.command_id),
                actor=actor(role),
                action="notification_" + body.action,
                entity_id=row.incident_id,
                reason=safe_text(body.reason, 500),
                before=before,
                after=after,
                request_hash=fingerprint,
                request_id=request.state.request_id,
            )
        )
        db.commit()
        return after


@router.post("/v1/admin/incidents/{identity}/commands")
def command(identity: UUID, body: Command, request: Request, role: Access):
    owner(role)
    reason, command_id = safe_text(body.reason, 500), str(body.command_id)
    fingerprint = digest({"incident": str(identity), **body.model_dump(mode="json")})
    with request.app.state.session_factory() as db:
        begin(db, command_id)
        old = db.get(StudioIncidentEvent, command_id)
        if old:
            if old.request_hash != fingerprint:
                raise HTTPException(409, "INCIDENT_COMMAND_CONFLICT")
            return {"item": incident_value(db.get(StudioIncident, str(identity))), "duplicate": True}
        probe = db.get(StudioIncident, str(identity))
        if not probe:
            raise HTTPException(404, "INCIDENT_NOT_FOUND")
        signal = db.scalar(
            select(StudioSignal)
            .where(StudioSignal.source == probe.source, StudioSignal.key == probe.signal)
            .with_for_update()
        )
        row = db.scalar(
            select(StudioIncident)
            .where(StudioIncident.id == str(identity))
            .with_for_update()
            .execution_options(populate_existing=True)
        )
        if row.revision != body.expected_revision:
            raise HTTPException(409, "INCIDENT_REVISION_CHANGED")
        before = incident_value(row)
        if body.action == "clear":
            if row.recovered_at is None or row.state == "closed":
                raise HTTPException(409, "INCIDENT_MUST_RECOVER_FIRST")
            row.state, row.closed_at = "closed", now()
        elif body.action == "acknowledge":
            if row.state != "open":
                raise HTTPException(409, "INCIDENT_NOT_OPEN")
            row.state = "acknowledged"
        elif body.action == "assign":
            if body.assignee and not db.get(StudioStaff, body.assignee):
                raise HTTPException(422, "UNKNOWN_STAFF")
            row.assignee = body.assignee
        else:
            signal.suppressed_until, signal.suppression_reason = now() + body.suppress_seconds, reason
        row.revision += 1
        event(
            db,
            request.app.state.settings,
            row,
            body.action,
            command_id,
            actor(role),
            {"reason": reason},
            fingerprint,
        )
        db.add(
            AdminAudit(
                command_id=command_id,
                actor=actor(role),
                action="incident_" + body.action,
                entity_id=row.id,
                reason=reason,
                before=before,
                after=incident_value(row),
                request_hash=fingerprint,
                request_id=request.state.request_id,
            )
        )
        db.commit()
        return {"item": incident_value(row), "duplicate": False}


def deliver_one(factory, settings, *, transport=requests.post, at=None):
    """Claim and finalize separately; crashes retry the stable delivery ID."""
    if not settings.studio_monitor_webhook_url:
        return False
    at = now() if at is None else at
    with factory() as db:
        if db.bind.dialect.name == "sqlite":
            db.execute(text("BEGIN IMMEDIATE"))
        row = db.scalar(
            select(StudioDelivery)
            .where(
                StudioDelivery.state == "pending",
                StudioDelivery.next_attempt_at <= at,
                StudioDelivery.lease_until <= at,
            )
            .order_by(StudioDelivery.next_attempt_at, StudioDelivery.id)
            .with_for_update(skip_locked=True)
            .limit(1)
        )
        if row is None:
            return False
        token = str(uuid4())
        row.lease_token, row.lease_until, row.attempts = token, at + 30, row.attempts + 1
        identity, payload = row.id, row.payload
        db.commit()
    raw = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode()
    signature = hmac.new(
        settings.studio_monitor_webhook_key.encode(), str(at).encode() + b"." + raw, hashlib.sha256
    ).hexdigest()
    try:
        response = transport(
            settings.studio_monitor_webhook_url,
            data=raw,
            headers={
                "Content-Type": "application/json",
                "Idempotency-Key": identity,
                "X-BMT-Timestamp": str(at),
                "X-BMT-Signature": signature,
            },
            timeout=10,
            allow_redirects=False,
        )
        success, error = 200 <= response.status_code < 300, "HTTP_" + str(response.status_code)
        response.close()
    except requests.RequestException:
        success, error = False, "TRANSPORT_UNAVAILABLE"
    with factory() as db:
        if db.bind.dialect.name == "sqlite":
            db.execute(text("BEGIN IMMEDIATE"))
        row = db.scalar(select(StudioDelivery).where(StudioDelivery.id == identity).with_for_update())
        if row.lease_token != token:
            return True
        row.state = "delivered" if success else "dead" if row.attempts >= 12 else "pending"
        row.next_attempt_at = at + min(3600, 2**row.attempts * 5)
        row.last_error = "" if success else error
        row.lease_token, row.lease_until = None, 0
        db.commit()
    return True
