"""On-demand operational alarms with durable, audited operator decisions.

The fixed registry bounds state to eight rows in the existing operation store.
Reads never acknowledge or clear a condition. No background monitoring is implied.
"""
from contextlib import nullcontext
from typing import Literal
from uuid import NAMESPACE_URL, UUID, uuid5

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError

from .admin import Access
from .admin_models import AdminAudit
from .middleware import ParsedJSONRoute
from .operations import competition_health
from .publication_models import PublicationIntent
from .studio_cases import begin, safe_text
from .telemetry_models import ProductEvent
from .track_models import OperationState, digest, now

router = APIRouter(route_class=ParsedJSONRoute, tags=["studio alarms"])
KEYS = ("verification_unavailable", "queue_delay", "queue_capacity", "verification_failures",
        "publication_failures", "storage_low", "backup_marker", "projection_delay")


def identity(key):
    if key not in KEYS:
        raise HTTPException(404, "ALARM_NOT_FOUND")
    return str(uuid5(NAMESPACE_URL, "bmt:studio:alarm:" + key))


def observe(app, *, existing_session=None):
    """Metadata only; time windows and review thresholds are explicit."""
    at = now()
    try:
        health = competition_health(app, existing_session=existing_session)
    except (OSError, RuntimeError):
        health = None
    with nullcontext(existing_session) if existing_session is not None else app.state.session_factory() as session:
        failures = session.scalar(select(func.count()).select_from(select(PublicationIntent.id).where(
            PublicationIntent.status == "failed", PublicationIntent.finished_at >= at - 300).limit(5001).subquery()))
        oldest = session.scalar(select(ProductEvent.received_at).where(ProductEvent.processed_at.is_(None))
            .order_by(ProductEvent.received_at, ProductEvent.id).limit(1))
    signals = {}

    def add(key, active, severity, title, impact, evidence, next_step, target, category):
        signals[key] = {"key": key, "active": active, "severity": severity, "title": title, "impact": impact,
            "evidence": evidence, "next_step": next_step, "target": target, "category": category, "observed_at": at}

    h = health or {}
    known = health is not None
    depth, age = h.get("queue_depth", 0), h.get("oldest_age_seconds", 0)
    add("verification_unavailable", h.get("status") != "ready" if known else None,
        "critical" if depth else "warning", "Verification workers unavailable",
        "Submitted results and new track publications may wait for a compatible worker.",
        f"{h.get('available_workers', 'Unknown')} compatible workers; {depth} queued items. "
        + (h.get("status", "Health source unavailable").replace("_", " ")),
        "Compare API and worker builds, then restore a compatible worker. Refresh to check recovery.",
        "system", "Verification")
    add("queue_delay", age >= 120 if known else None, "critical" if age >= 600 else "warning",
        "Verification queue is delayed", "Players are waiting for accepted results or publications.",
        f"Oldest queued item: {age} seconds. Review at 120 s; critical at 600 s.",
        "Inspect pending jobs and worker availability before retrying affected submissions.",
        "system/jobs?all=1", "Verification")
    capacity = h.get("queue_capacity", 0)
    add("queue_capacity", depth >= capacity if known and capacity > 0 else (False if known else None),
        "critical", "Verification queue is full", "New submissions may be refused until capacity returns.",
        f"{depth} queued items / {capacity} configured capacity.",
        "Restore worker throughput and inspect the oldest jobs; keep accepted evidence intact.",
        "system", "Verification")
    failed = h.get("failed_last_5_minutes", 0)
    add("verification_failures", failed > 0 if known else None, "warning", "Recent verification failures",
        "Some submitted races ended with an infrastructure failure.", f"{failed} failed races in the last 5 minutes.",
        "Inspect failure categories and affected race evidence. Rejected proofs are a separate outcome.",
        "races?state=failed&all=1", "Verification")
    add("publication_failures", failures > 0, "warning", "Recent publication failures",
        "Creators could not complete requested publications.",
        f"{'At least ' if failures > 5000 else ''}{min(failures, 5000)} failed requests in the last 5 minutes.",
        "Open the failed request and check its failure category and retry eligibility.",
        "publications?state=failed&all=1", "Content")
    free = h.get("storage_free_bytes")
    add("storage_low", free < 5 * 1024**3 if free is not None else (False if known else None),
        "critical" if free is not None and free < 1024**3 else "warning", "Local object storage is low",
        "Insufficient free space can interrupt uploads and verification.",
        f"{free / 1024**3:.2f} GiB free; review below 5 GiB, critical below 1 GiB." if free is not None
        else "Local free space is not measured for remote object storage.",
        "Check storage capacity and retention in Reliability before removing any data.", "system", "Storage")
    backup = h.get("backup", {}).get("status")
    add("backup_marker", backup in ("missing", "unreadable") if known else None, "warning",
        "Configured backup marker unavailable", "The configured backup completion marker cannot be confirmed.",
        "Backup marker: " + str(backup or "unknown").replace("_", " ") + ". A marker does not prove restore success.",
        "Inspect the configured backup job and marker path, then check recovery evidence.", "system", "Storage")
    lag = max(0, at - oldest) if oldest is not None else 0
    add("projection_delay", lag >= 300, "critical" if lag >= 1800 else "warning", "Activity reporting is delayed",
        "Prepared activity and cohort reports may not include recently received observations.",
        f"Oldest unprocessed observation: {lag} seconds. Review at 300 s; critical at 1800 s.",
        "Inspect the reporting watermark and restore event processing before interpreting activity changes.",
        "product", "Reporting")
    return at, signals


def project(signal, state):
    details = state.details if state else {}
    active = signal["active"]
    acknowledged = details.get("status") == "acknowledged" and (
        details.get("severity") == signal["severity"] or details.get("severity") == "critical")
    status = ("acknowledged" if acknowledged else "open") if active else (
        "unknown" if active is None else "inactive" if not state else "cleared" if details.get("status") == "cleared" else "recovered")
    return {**signal, "status": status, "revision": details.get("revision", 0),
        "last_action_at": state.updated_at if state else None, "last_reason": details.get("reason"),
        "last_actor": details.get("actor"), "can_clear": active is False and bool(state)
        and details.get("status") != "cleared"}


@router.get("/v1/admin/alarms")
def alarms(request: Request, role: Access):
    at, signals = observe(request.app)
    with request.app.state.session_factory() as session:
        states = {row.id: row for row in session.scalars(select(OperationState).where(
            OperationState.id.in_(["admin-alarm:" + key for key in KEYS])))}
        items = [project(signal, states.get("admin-alarm:" + key)) for key, signal in signals.items()
            if signal["active"] is not False or "admin-alarm:" + key in states]
    return {"as_of": at, "role": role, "items": items, "checks": len(KEYS),
        "unknown_checks": sum(signal["active"] is None for signal in signals.values()),
        "scope": "Current backend snapshot; five-minute failure windows. Refresh to recheck. No background alerting or notification delivery."}


@router.get("/v1/admin/alarms/{key}")
def alarm_detail(key: str, request: Request, role: Access):
    entity_id = identity(key)
    at, signals = observe(request.app)
    with request.app.state.session_factory() as session:
        state = session.get(OperationState, "admin-alarm:" + key)
        events = session.scalars(select(AdminAudit).where(AdminAudit.entity_id == entity_id,
            AdminAudit.action.in_(("alarm_acknowledge", "alarm_clear")))
            .order_by(AdminAudit.created_at.desc(), AdminAudit.id).limit(26)).all()
        return {"as_of": at, "role": role, "item": project(signals[key], state),
            "history": [{"action": event.action, "reason": event.reason, "actor": event.actor,
                "created_at": event.created_at, "revision": event.after["revision"]} for event in events[:25]],
            "history_truncated": len(events) > 25}


class Decision(BaseModel):
    model_config = ConfigDict(extra="forbid")
    command_id: UUID
    expected_revision: int = Field(ge=0)
    action: Literal["acknowledge", "clear"]
    reason: str = Field(min_length=8, max_length=500)


@router.post("/v1/admin/alarms/{key}/actions")
def decide(key: str, payload: Decision, request: Request, role: Access):
    if role != "owner":
        raise HTTPException(403, "OWNER_REQUIRED")
    entity_id, command_id = identity(key), str(payload.command_id)
    reason = safe_text(payload.reason, 500)
    if len(reason) < 8:
        raise HTTPException(422, "REASON_REQUIRED")
    request_hash = digest({"key": key, **payload.model_dump(mode="json")})
    with request.app.state.session_factory() as session:
        # One lock per signal also serializes creation of the first state row.
        begin(session, entity_id)
        prior = session.scalar(select(AdminAudit).where(AdminAudit.command_id == command_id))
        if prior:
            if prior.request_hash != request_hash:
                raise HTTPException(409, "COMMAND_ID_REUSED")
            return {"after": prior.after}
        state = session.get(OperationState, "admin-alarm:" + key)
        before = dict(state.details) if state else {}
        if before.get("revision", 0) != payload.expected_revision:
            raise HTTPException(409, "ALARM_CHANGED_REFRESH_REQUIRED")
        # Recheck immediately before a decision. Missing evidence cannot clear.
        at, signals = observe(request.app, existing_session=session)
        signal = signals[key]
        if payload.action == "clear" and (signal["active"] is not False or not state
                or before.get("status") == "cleared"):
            raise HTTPException(409, "ALARM_NOT_RECOVERED_REFRESH_REQUIRED")
        if payload.action == "acknowledge" and signal["active"] is not True:
            raise HTTPException(409, "ALARM_NOT_ACTIVE_REFRESH_REQUIRED")
        after = {"status": "acknowledged" if payload.action == "acknowledge" else "cleared",
            "revision": before.get("revision", 0) + 1, "severity": signal["severity"],
            "reason": reason, "actor": role, "evidence": signal["evidence"], "observed_at": at}
        if state is None:
            state = OperationState(id="admin-alarm:" + key)
            session.add(state)
        state.details, state.updated_at = after, at
        session.add(AdminAudit(command_id=command_id, actor=role, action="alarm_" + payload.action,
            entity_id=entity_id, reason=reason, before=before, after=after,
            request_hash=request_hash, request_id=request.state.request_id))
        try:
            session.commit()
        except IntegrityError:
            session.rollback()
            prior = session.scalar(select(AdminAudit).where(AdminAudit.command_id == command_id))
            if prior and prior.request_hash == request_hash:
                return {"after": prior.after}
            raise HTTPException(409, "COMMAND_ID_REUSED") from None
        return {"after": after}
