"""Bounded owner-authored case workflow; business grants/recovery require policy."""
import re
from uuid import NAMESPACE_URL, UUID, uuid5

from fastapi import APIRouter, HTTPException, Query, Request
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select, text

from .admin import Access
from .admin_models import AdminAudit
from .identity_models import Player
from .middleware import ParsedJSONRoute
from .studio_case_models import StudioCase, StudioCaseEvent, StudioQuarantine
from .track_models import Track, digest, now
from .tracks import Auth

router = APIRouter(route_class=ParsedJSONRoute, tags=["studio cases"])
TRANSITIONS = {"open": {"investigating", "resolved"}, "investigating": {"resolved"},
    "resolved": {"open", "appealed"}, "appealed": {"investigating", "resolved"}}


def value(case):
    return {key: getattr(case, key) for key in ("id", "player_id", "track_id", "title", "status", "revision", "created_at", "updated_at")}


def safe_text(value, limit):
    value = value.strip()
    if not value or len(value) > limit or any(ord(char) < 32 and char not in "\n\t" for char in value):
        raise HTTPException(422, "INVALID_CASE_TEXT")
    # Notes are staff evidence, not a credential vault. Avoid common pasted secrets.
    if re.search(r"(?i)(bearer\s+\S+|-----BEGIN .*PRIVATE KEY|(?:access_token|refresh_token|purchaseToken)\s*[:=])", value):
        raise HTTPException(422, "CREDENTIALS_NOT_CASE_EVIDENCE")
    return value


class Create(BaseModel):
    model_config = ConfigDict(extra="forbid")
    command_id: UUID
    title: str = Field(min_length=1, max_length=160)
    player_id: UUID | None = None
    track_id: UUID | None = None


class Action(BaseModel):
    model_config = ConfigDict(extra="forbid")
    command_id: UUID
    expected_revision: int = Field(ge=0)
    kind: str = Field(pattern="^(note|issue|transition|quarantine|restore)$")
    text: str = Field(default="", max_length=2000)
    status: str | None = None


def owner(role):
    if role != "owner":
        raise HTTPException(403, "OWNER_REQUIRED")


def begin(session, identity):
    if session.bind.dialect.name == "sqlite":
        session.execute(text("BEGIN IMMEDIATE"))
    else:
        session.execute(text("SELECT pg_advisory_xact_lock(:key)"), {"key": UUID(identity).int % (2**63)})


def replay(session, identity, request_hash, case_id=None):
    old = session.get(StudioCaseEvent, identity)
    if old:
        if old.request_hash != request_hash or case_id and old.case_id != case_id:
            raise HTTPException(409, "CASE_COMMAND_CONFLICT")
        return value(session.get(StudioCase, old.case_id))


@router.get("/v1/admin/cases")
def list_cases(request: Request, role: Access, limit: int = Query(50, ge=1, le=100),
               offset: int = Query(0, ge=0, le=10000), status: str | None = None):
    with request.app.state.session_factory() as session:
        query = select(StudioCase)
        if status:
            if status not in TRANSITIONS:
                raise HTTPException(422, "INVALID_CASE_STATUS")
            query = query.where(StudioCase.status == status)
        rows = session.scalars(query.order_by(StudioCase.updated_at.desc(), StudioCase.id).offset(offset).limit(limit + 1)).all()
        return {"items": [value(row) for row in rows[:limit]], "has_more": len(rows) > limit, "role": role}


@router.post("/v1/admin/cases")
def create_case(payload: Create, request: Request, role: Access):
    owner(role)
    title = safe_text(payload.title, 160)
    body = payload.model_dump(mode="json")
    request_hash = digest(body)
    identity = str(payload.command_id)
    with request.app.state.session_factory() as session:
        begin(session, identity)
        result = replay(session, identity, request_hash)
        if result:
            return result
        for model, field in ((Player, payload.player_id), (Track, payload.track_id)):
            if field and session.get(model, str(field)) is None:
                raise HTTPException(404, "CASE_ENTITY_NOT_FOUND")
        case = StudioCase(title=title, player_id=str(payload.player_id) if payload.player_id else None,
            track_id=str(payload.track_id) if payload.track_id else None)
        session.add(case)
        session.flush()
        session.add(StudioCaseEvent(id=identity, case_id=case.id, actor=role, kind="created",
            detail={"title": title}, request_hash=request_hash))
        session.commit()
        return value(case)


@router.get("/v1/admin/cases/{case_id}")
def inspect_case(case_id: UUID, request: Request, role: Access):
    with request.app.state.session_factory() as session:
        case = session.get(StudioCase, str(case_id))
        if case is None:
            raise HTTPException(404, "CASE_NOT_FOUND")
        query = select(StudioCaseEvent).where(StudioCaseEvent.case_id == case.id)
        # Case revision is a concurrency fence; event ID/time are source evidence.
        rows = session.scalars(query.order_by(StudioCaseEvent.revision.desc()).limit(101)).all()
        return {"case": value(case), "events": [{key: getattr(row, key) for key in
            ("id", "actor", "kind", "revision", "detail", "created_at")} for row in rows[:100]],
            "history_truncated": len(rows) > 100, "role": role,
            "allowed_transitions": sorted(TRANSITIONS[case.status]),
            "coverage": {"recovery": "unavailable", "production_compensation": "unavailable",
                "quarantine": "case-linked track visibility, audited; restoration checks intervening moderation",
                "staff_identity": "credential role; no individual SSO"}}


@router.post("/v1/admin/cases/{case_id}/events")
def append_event(case_id: UUID, payload: Action, request: Request, role: Access):
    owner(role)
    identity, request_hash = str(payload.command_id), digest(payload.model_dump(mode="json"))
    with request.app.state.session_factory() as session:
        begin(session, identity)
        result = replay(session, identity, request_hash, str(case_id))
        if result:
            return result
        case = session.scalar(select(StudioCase).where(StudioCase.id == str(case_id)).with_for_update())
        if case is None:
            raise HTTPException(404, "CASE_NOT_FOUND")
        if case.revision != payload.expected_revision:
            raise HTTPException(409, "STALE_CASE_REVISION")
        if payload.kind in ("quarantine", "restore"):
            if not case.track_id or payload.status is not None:
                raise HTTPException(422, "TRACK_CASE_REQUIRED")
            reason = safe_text(payload.text, 500)
            track = session.scalar(select(Track).where(Track.id == case.track_id).with_for_update())
            quarantine = session.get(StudioQuarantine, track.id)
            if payload.kind == "quarantine":
                if track.hidden or quarantine:
                    raise HTTPException(409, "TRACK_ALREADY_RESTRICTED")
                before = {"hidden": False}; track.hidden = True
            else:
                if not quarantine or quarantine.case_id != case.id or not track.hidden:
                    raise HTTPException(409, "CASE_DOES_NOT_OWN_QUARANTINE")
                # Never undo a later moderation action recorded by another workflow.
                source = session.get(AdminAudit, quarantine.audit_id)
                intervening = session.scalar(select(AdminAudit.id).where(AdminAudit.entity_id == track.id,
                    AdminAudit.id != source.id, AdminAudit.created_at >= source.created_at,
                    AdminAudit.action.in_(("track_visibility", "quarantine", "restore"))).limit(1))
                if intervening:
                    raise HTTPException(409, "INTERVENING_TRACK_MODERATION")
                before = {"hidden": True}; track.hidden = False
                session.delete(quarantine)
            audit = AdminAudit(command_id=identity, actor=role, action=payload.kind, entity_id=track.id,
                reason=reason, before=before, after={"hidden": track.hidden, "case_id": case.id},
                request_hash=request_hash, request_id=request.state.request_id)
            session.add(audit); session.flush()
            if payload.kind == "quarantine":
                session.add(StudioQuarantine(track_id=track.id, case_id=case.id, audit_id=audit.id))
            detail = {"track_id": track.id, "audit_id": audit.id, "reason": reason, "hidden": track.hidden}
        elif payload.kind == "transition":
            if payload.status not in TRANSITIONS[case.status] or not payload.text:
                raise HTTPException(409, "INVALID_CASE_TRANSITION")
            detail = {"from": case.status, "to": payload.status, "reason": safe_text(payload.text, 2000)}
            case.status = payload.status
        elif payload.status is not None:
            raise HTTPException(422, "UNEXPECTED_CASE_STATUS")
        else:
            detail = {"text": safe_text(payload.text, 2000)}
            if payload.kind == "issue" and not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._:/#-]{0,159}", payload.text):
                raise HTTPException(422, "INVALID_ISSUE_REFERENCE")
        case.revision += 1
        case.updated_at = now()
        session.add(StudioCaseEvent(id=identity, case_id=case.id, actor=role, kind=payload.kind,
            revision=case.revision, detail=detail, request_hash=request_hash))
        session.commit()
        return value(case)


class Report(BaseModel):
    model_config = ConfigDict(extra="forbid")
    command_id: UUID
    reason: str = Field(pattern="^(track_issue|abuse|billing_issue|technical_issue)$")
    text: str = Field(min_length=1, max_length=2000)
    track_id: UUID | None = None


@router.post("/v1/reports")
def player_report(payload: Report, request: Request, player: Auth):
    identity = str(uuid5(NAMESPACE_URL, "bmt-report/" + player.id + "/" + str(payload.command_id)))
    request_hash = digest(payload.model_dump(mode="json"))
    with request.app.state.session_factory() as session:
        begin(session, identity)
        result = replay(session, identity, request_hash)
        if result:
            return {"id": result["id"], "status": result["status"]}
        if payload.track_id and session.get(Track, str(payload.track_id)) is None:
            raise HTTPException(404, "TRACK_NOT_FOUND")
        case = StudioCase(player_id=player.id, track_id=str(payload.track_id) if payload.track_id else None,
            title=payload.reason.replace("_", " ").capitalize())
        session.add(case); session.flush()
        session.add(StudioCaseEvent(id=identity, case_id=case.id, actor="player", kind="reported",
            detail={"reason": payload.reason, "text": safe_text(payload.text, 2000)}, request_hash=request_hash))
        session.commit()
        return {"id": case.id, "status": case.status}


class Appeal(BaseModel):
    model_config = ConfigDict(extra="forbid")
    command_id: UUID
    expected_revision: int = Field(ge=0)
    text: str = Field(min_length=1, max_length=2000)


@router.get("/v1/reports")
def my_reports(request: Request, player: Auth):
    with request.app.state.session_factory() as session:
        rows = session.scalars(select(StudioCase).where(StudioCase.player_id == player.id)
            .where(select(StudioCaseEvent.id).where(StudioCaseEvent.case_id == StudioCase.id,
                StudioCaseEvent.kind == "reported", StudioCaseEvent.actor == "player").exists())
            .order_by(StudioCase.updated_at.desc(), StudioCase.id).limit(51)).all()
        return {"items": [{"id": row.id, "title": row.title, "status": row.status,
            "revision": row.revision} for row in rows[:50]], "has_more": len(rows) > 50}


@router.post("/v1/reports/{case_id}/appeal")
def player_appeal(case_id: UUID, payload: Appeal, request: Request, player: Auth):
    identity = str(uuid5(NAMESPACE_URL, "bmt-appeal/" + player.id + "/" + str(payload.command_id)))
    hashed = digest({"case_id": str(case_id), **payload.model_dump(mode="json")})
    with request.app.state.session_factory() as session:
        begin(session, identity)
        case = session.scalar(select(StudioCase).where(StudioCase.id == str(case_id),
            StudioCase.player_id == player.id,
            select(StudioCaseEvent.id).where(StudioCaseEvent.case_id == StudioCase.id,
                StudioCaseEvent.kind == "reported", StudioCaseEvent.actor == "player").exists()).with_for_update())
        if case is None:
            raise HTTPException(404, "CASE_NOT_FOUND")
        prior = replay(session, identity, hashed, case.id)
        if prior:
            return {"id": case.id, "status": case.status}
        if case.status != "resolved" or case.revision != payload.expected_revision:
            raise HTTPException(409, "CASE_NOT_APPEALABLE_REFRESH_REQUIRED")
        case.status = "appealed"; case.revision += 1; case.updated_at = now()
        session.add(StudioCaseEvent(id=identity, case_id=case.id, actor="player", kind="appealed",
            revision=case.revision, detail={"text": safe_text(payload.text, 2000)}, request_hash=hashed))
        session.commit()
        return {"id": case.id, "status": case.status}
