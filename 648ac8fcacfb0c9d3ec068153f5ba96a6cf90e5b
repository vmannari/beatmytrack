"""Grouped player reports and audited, result-preserving track removal."""
from typing import Literal
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, Request
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import case, func, or_, select
from sqlalchemy.exc import IntegrityError

from .admin import Access
from .admin_models import AdminAudit
from .identity_models import Player
from .middleware import ParsedJSONRoute
from .studio_case_models import StudioCase, StudioCaseEvent, StudioQuarantine
from .studio_cases import begin, owner, safe_text
from .studio_catalogue import preview, response, snapshot
from .track_models import Track, TrackVersion, digest, now

router = APIRouter(route_class=ParsedJSONRoute, tags=["Studio reported tracks"])


def reports():
    # Notes, appeals and repeated delivery never increase the report count.
    return select(StudioCaseEvent.case_id,
                  func.min(StudioCaseEvent.created_at).label("reported_at")).where(
        StudioCaseEvent.kind == "reported", StudioCaseEvent.actor == "player"
    ).group_by(StudioCaseEvent.case_id).subquery()


def state_token(session, track):
    audits = session.scalar(select(func.count()).select_from(AdminAudit).where(AdminAudit.entity_id == track.id))
    version = session.scalar(select(func.max(TrackVersion.number)).where(TrackVersion.track_id == track.id))
    return digest({"track": track.id, "hidden": track.hidden, "archived": track.archived,
                   "audit_count": audits, "latest_version": version})


def latest_id():
    return select(TrackVersion.id).where(TrackVersion.track_id == Track.id).order_by(
        TrackVersion.number.desc(), TrackVersion.id).limit(1).correlate(Track).scalar_subquery()


def deleted_track():
    return select(AdminAudit.id).where(AdminAudit.entity_id == Track.id,
                                       AdminAudit.action == "track_deletion").correlate(Track).exists()


@router.get("/v1/admin/reported-tracks")
def reported_tracks(request: Request, role: Access, q: str = Query("", max_length=100),
                    visibility: Literal["active", "deleted", "all"] = "active",
                    sort: Literal["reports", "recent"] = "reports",
                    offset: int = Query(0, ge=0, le=10000), limit: int = Query(25, ge=1, le=100)):
    source = reports()
    counts = select(StudioCase.track_id,
        func.count().label("report_count"), func.count(func.distinct(StudioCase.player_id)).label("reporters"),
        func.sum(case((StudioCase.status != "resolved", 1), else_=0)).label("unresolved"),
        func.max(source.c.reported_at).label("last_reported_at")
    ).join(source, source.c.case_id == StudioCase.id).where(StudioCase.track_id.is_not(None)).group_by(
        StudioCase.track_id).subquery()
    with request.app.state.session_factory() as session:
        snapshot(session)
        query = select(Track, TrackVersion, Player.display_name, counts, deleted_track().label("deleted")).select_from(Track).join(
            counts, counts.c.track_id == Track.id).join(TrackVersion, TrackVersion.id == latest_id()).join(
            Player, Player.id == Track.owner_id)
        if visibility != "all":
            query = query.where(deleted_track() if visibility == "deleted" else ~deleted_track())
        if q.strip():
            pattern = "%" + q.strip().replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_") + "%"
            query = query.where(or_(TrackVersion.name.ilike(pattern, escape="\\"),
                                    Player.display_name.ilike(pattern, escape="\\"), Track.id == q.strip()))
        order = [counts.c.report_count.desc(), counts.c.last_reported_at.desc()] if sort == "reports" else [
            counts.c.last_reported_at.desc(), counts.c.report_count.desc()]
        rows = session.execute(query.order_by(*order, Track.id).offset(offset).limit(limit + 1)).all()
        items = []
        for row in rows[:limit]:
            track, version, creator = row[:3]
            values = row._mapping
            items.append({"track_id": track.id, "version_id": version.id, "name": version.name,
                          "creator_id": track.owner_id, "creator_name": creator,
                          "hidden": track.hidden, "deleted": values["deleted"], "preview": preview(version.discovery),
                          **{field: values[field] for field in ("report_count", "reporters", "unresolved", "last_reported_at")}})
        return response({"role": role, "items": items, "offset": offset, "limit": limit,
                         "has_more": len(rows) > limit, "scope": "All retained player reports, across every track version"})


@router.get("/v1/admin/reported-tracks/{track_id}")
def reported_track(track_id: UUID, request: Request, role: Access,
                   offset: int = Query(0, ge=0, le=10000), limit: int = Query(25, ge=1, le=100)):
    source = reports()
    with request.app.state.session_factory() as session:
        snapshot(session)
        track = session.get(Track, str(track_id))
        if track is None:
            raise HTTPException(404, "TRACK_NOT_FOUND")
        total, reporters, unresolved = session.execute(select(func.count(),
            func.count(func.distinct(StudioCase.player_id)),
            func.coalesce(func.sum(case((StudioCase.status != "resolved", 1), else_=0)), 0)
        ).select_from(StudioCase).join(source, source.c.case_id == StudioCase.id).where(
            StudioCase.track_id == track.id)).one()
        if not total:
            raise HTTPException(404, "REPORTED_TRACK_NOT_FOUND")
        version = session.scalar(select(TrackVersion).where(TrackVersion.track_id == track.id).order_by(
            TrackVersion.number.desc(), TrackVersion.id).limit(1))
        rows = session.execute(select(StudioCase, StudioCaseEvent, Player.display_name).join(
            StudioCaseEvent, StudioCaseEvent.case_id == StudioCase.id).outerjoin(
            Player, Player.id == StudioCase.player_id).where(StudioCase.track_id == track.id,
            StudioCaseEvent.kind == "reported", StudioCaseEvent.actor == "player").order_by(
            StudioCaseEvent.created_at.desc(), StudioCase.id).offset(offset).limit(limit + 1)).all()
        return response({"role": role, "track": {"track_id": track.id, "name": version.name if version else "Removed track",
            "version_id": version.id if version else None,
            "deleted": session.scalar(select(deleted_track()).select_from(Track).where(Track.id == track.id)), "hidden": track.hidden,
            "state_token": state_token(session, track), "report_count": total, "reporters": reporters,
            "unresolved": unresolved, "preview": preview(version.discovery if version else {})},
            "items": [{"case_id": c.id, "revision": c.revision, "status": c.status,
                       "reporter": name or "Removed account", "reported_at": event.created_at,
                       "reason": event.detail.get("reason", "track_issue"), "text": event.detail.get("text", ""),
                       "version_id": event.detail.get("version_id")} for c, event, name in rows[:limit]],
            "offset": offset, "limit": limit, "has_more": len(rows) > limit})


class DeleteTrack(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    command_id: str = Field(pattern=r"^[0-9a-fA-F-]{36}$")
    case_id: str = Field(pattern=r"^[0-9a-fA-F-]{36}$")
    expected_revision: int = Field(ge=0)
    expected_state: str = Field(pattern=r"^[0-9a-f]{64}$")
    reason: str = Field(min_length=8, max_length=500)
    acknowledged: Literal[True]


@router.post("/v1/admin/reported-tracks/{track_id}/delete")
def delete_track(track_id: UUID, body: DeleteTrack, request: Request, role: Access):
    owner(role)
    try:
        UUID(body.command_id)
        UUID(body.case_id)
    except ValueError:
        raise HTTPException(422, "INVALID_COMMAND_ID") from None
    reason = safe_text(body.reason, 500)
    if len(reason) < 8:
        raise HTTPException(422, "REASON_REQUIRED")
    identity, hashed = body.command_id, digest({"track_id": str(track_id), **body.model_dump()})
    with request.app.state.session_factory() as session:
        begin(session, identity)
        old = session.scalar(select(AdminAudit).where(AdminAudit.command_id == identity))
        if old:
            if old.request_hash != hashed:
                raise HTTPException(409, "COMMAND_ID_REUSED")
            return {"audit_id": old.id, "deleted": True}
        linked = session.scalar(select(StudioCase).where(StudioCase.id == body.case_id,
            StudioCase.track_id == str(track_id)).with_for_update())
        if linked is None or not session.scalar(select(StudioCaseEvent.id).where(
                StudioCaseEvent.case_id == linked.id, StudioCaseEvent.kind == "reported",
                StudioCaseEvent.actor == "player").limit(1)):
            raise HTTPException(404, "TRACK_REPORT_REQUIRED")
        track = session.scalar(select(Track).where(Track.id == str(track_id)).with_for_update())
        if linked.revision != body.expected_revision or state_token(session, track) != body.expected_state:
            raise HTTPException(409, "STATE_CHANGED_REFRESH_REQUIRED")
        if session.scalar(select(AdminAudit.id).where(AdminAudit.entity_id == track.id,
                AdminAudit.action == "track_deletion").limit(1)):
            raise HTTPException(409, "TRACK_ALREADY_DELETED")
        before = {"hidden": track.hidden, "archived": track.archived}
        track.hidden, track.archived = True, True
        audit = AdminAudit(command_id=identity, actor=role, action="track_deletion", entity_id=track.id,
            reason=reason, before=before, after={"hidden": True, "archived": True, "case_id": linked.id},
            request_hash=hashed, request_id=request.state.request_id)
        session.add(audit)
        session.flush()
        quarantine = session.get(StudioQuarantine, track.id)
        if quarantine is None:
            session.add(StudioQuarantine(track_id=track.id, case_id=linked.id, audit_id=audit.id))
        else:
            quarantine.case_id, quarantine.audit_id = linked.id, audit.id
        linked.revision += 1
        linked.updated_at = now()
        session.add(StudioCaseEvent(id=identity, case_id=linked.id, actor=role, kind="track_deleted",
            revision=linked.revision, detail={"track_id": track.id, "audit_id": audit.id, "reason": reason}, request_hash=hashed))
        try:
            session.commit()
        except IntegrityError:
            session.rollback()
            raise HTTPException(409, "COMMAND_CONFLICT") from None
        return {"audit_id": audit.id, "deleted": True}
