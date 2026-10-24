"""Staff-owned saved views, case assignment, releases and bounded CSV exports."""

import csv
import io
from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, Request
from fastapi.responses import Response
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import case, event, func, select

from .admin import Access, Window
from .admin_models import AdminAudit
from .admin_ranges import calendar_range
from .middleware import ParsedJSONRoute
from .studio_access import actor
from .studio_case_models import StudioCase, StudioCaseEvent
from .studio_cases import begin, owner, safe_text
from .studio_platform_models import (
    AnalysisDay,
    StudioCaseTriage,
    StudioIncident,
    StudioRelease,
    StudioSavedView,
    StudioStaff,
)
from .studio_queries import read_snapshot
from .track_models import digest, now

router = APIRouter(route_class=ParsedJSONRoute, tags=["Studio governance"])
ROUTES = {
    "overview",
    "product",
    "quality",
    "economy",
    "tracks",
    "publications",
    "competitions",
    "alarms",
    "system",
    "players",
    "cases",
    "studio",
}
FILTERS = {
    "since",
    "until",
    "build_id",
    "baseline",
    "platform",
    "mode",
    "population",
    "tab",
    "q",
    "state",
    "kind",
    "failure_code",
}


def value(row, names):
    return {k: getattr(row, k) for k in names.split()}


def audited(db, request, role, identity, action, entity, reason, before, after, fingerprint):
    db.add(
        AdminAudit(
            command_id=str(identity),
            actor=actor(role),
            action=action,
            entity_id=entity,
            reason=safe_text(reason, 500),
            before=before,
            after=after,
            request_hash=fingerprint,
            request_id=request.state.request_id,
        )
    )


def replay(db, identity, fingerprint):
    old = db.scalar(select(AdminAudit).where(AdminAudit.command_id == str(identity)))
    if old and old.request_hash != fingerprint:
        raise HTTPException(409, "COMMAND_ID_CONFLICT")
    return old.after if old else None


@router.get("/v1/admin/staff")
def staff(request: Request, role: Access):
    with request.app.state.session_factory() as db:
        read_snapshot(db)
        rows = db.scalars(
            select(StudioStaff).order_by(StudioStaff.display_name, StudioStaff.id).limit(100)
        ).all()
        return {
            "role": role,
            "actor": actor(role),
            "display_name": getattr(role, "display_name", str(role)),
            "named_signin_configured": bool(request.app.state.settings.studio_staff_audiences),
            "legacy_keys_enabled": request.app.state.settings.studio_legacy_keys_enabled,
            "mfa_required": request.app.state.settings.studio_staff_require_mfa,
            "items": [value(r, "id display_name role enabled last_seen_at") for r in rows],
        }


class Saved(BaseModel):
    model_config = ConfigDict(extra="forbid")
    command_id: UUID
    id: UUID
    expected_revision: int = Field(ge=0)
    name: str = Field(min_length=1, max_length=100)
    route: str = Field(max_length=40)
    filters: dict[str, str]


@router.get("/v1/admin/saved-views")
def saved(request: Request, role: Access):
    with request.app.state.session_factory() as db:
        read_snapshot(db)
        return {
            "items": [
                value(r, "id name route filters revision updated_at")
                for r in db.scalars(
                    select(StudioSavedView)
                    .where(StudioSavedView.owner == actor(role))
                    .order_by(StudioSavedView.name)
                    .limit(50)
                )
            ]
        }


@router.post("/v1/admin/saved-views")
def save(body: Saved, request: Request, role: Access):
    if (
        body.route not in ROUTES
        or not set(body.filters) <= FILTERS
        or any(len(v) > 160 for v in body.filters.values())
    ):
        raise HTTPException(422, "INVALID_SAVED_VIEW")
    fingerprint = digest(body.model_dump(mode="json"))
    with request.app.state.session_factory() as db:
        begin(db, str(UUID(digest({"saved_owner": actor(role)})[:32])))
        old = replay(db, body.command_id, fingerprint)
        if old is not None:
            return old
        row = db.get(StudioSavedView, str(body.id))
        if row and row.owner != actor(role):
            raise HTTPException(404, "SAVED_VIEW_NOT_FOUND")
        if row is None:
            if body.expected_revision != 0:
                raise HTTPException(409, "VIEW_REVISION_CHANGED")
            if (
                db.scalar(
                    select(func.count())
                    .select_from(StudioSavedView)
                    .where(StudioSavedView.owner == actor(role))
                )
                >= 50
            ):
                raise HTTPException(409, "SAVED_VIEW_LIMIT")
            row = StudioSavedView(
                id=str(body.id),
                owner=actor(role),
                name=body.name,
                route=body.route,
                filters=body.filters,
                revision=0,
            )
            db.add(row)
        if row.revision != body.expected_revision:
            raise HTTPException(409, "VIEW_REVISION_CHANGED")
        before = value(row, "id name route filters revision")
        row.name, row.route, row.filters, row.updated_at, row.revision = (
            safe_text(body.name, 100),
            body.route,
            body.filters,
            now(),
            row.revision + 1,
        )
        after = value(row, "id name route filters revision updated_at")
        audited(
            db,
            request,
            role,
            body.command_id,
            "saved_view",
            row.id,
            "Save reporting view",
            before,
            after,
            fingerprint,
        )
        db.commit()
        return after


class Release(BaseModel):
    model_config = ConfigDict(extra="forbid")
    command_id: UUID
    build_id: str = Field(min_length=1, max_length=80)
    name: str = Field(min_length=1, max_length=100)
    state: str = Field(pattern="^(testing|canary|production|rolled_back)$")
    notes: str = Field(default="", max_length=500)
    expected_revision: int = Field(ge=0)
    reason: str = Field(min_length=3, max_length=500)


@router.get("/v1/admin/releases")
def releases(request: Request, role: Access):
    with request.app.state.session_factory() as db:
        read_snapshot(db)
        rows = db.scalars(
            select(StudioRelease).order_by(StudioRelease.created_at.desc(), StudioRelease.id).limit(101)
        ).all()
        return {
            "items": [value(r, "id build_id name state notes revision created_at actor") for r in rows[:100]],
            "truncated": len(rows) > 100,
        }


@router.post("/v1/admin/releases")
def release(body: Release, request: Request, role: Access):
    owner(role)
    fingerprint = digest(body.model_dump(mode="json"))
    with request.app.state.session_factory() as db:
        begin(db, str(UUID(digest({"release_build": body.build_id})[:32])))
        old = replay(db, body.command_id, fingerprint)
        if old is not None:
            return old
        row = db.scalar(
            select(StudioRelease).where(StudioRelease.build_id == body.build_id).with_for_update()
        )
        if row is None:
            if body.expected_revision != 0:
                raise HTTPException(409, "RELEASE_REVISION_CHANGED")
            row = StudioRelease(
                id=str(body.command_id),
                build_id=body.build_id,
                name=body.name,
                state=body.state,
                actor=actor(role),
                revision=0,
            )
            db.add(row)
        if row.revision != body.expected_revision:
            raise HTTPException(409, "RELEASE_REVISION_CHANGED")
        before = value(row, "id name state notes revision")
        row.name, row.state, row.notes, row.revision = (
            safe_text(body.name, 100),
            body.state,
            body.notes,
            row.revision + 1,
        )
        db.flush()
        after = value(row, "id build_id name state notes revision created_at actor")
        audited(
            db,
            request,
            role,
            body.command_id,
            "release_record",
            row.id,
            body.reason,
            before,
            after,
            fingerprint,
        )
        db.commit()
        return after


class Triage(BaseModel):
    model_config = ConfigDict(extra="forbid")
    command_id: UUID
    expected_revision: int = Field(ge=0)
    assignee: str = Field(default="", max_length=24)
    priority: str = Field(pattern="^(normal|high|urgent)$")
    due_at: int | None = Field(default=None, ge=0)
    incident_id: UUID | None = None
    reason: str = Field(min_length=3, max_length=500)


@router.get("/v1/admin/cases/{identity}/triage")
def triage_detail(identity: UUID, request: Request, role: Access):
    with request.app.state.session_factory() as db:
        read_snapshot(db)
        if not db.get(StudioCase, str(identity)):
            raise HTTPException(404, "CASE_NOT_FOUND")
        row = db.get(StudioCaseTriage, str(identity))
        return (
            value(row, "case_id assignee priority due_at incident_id revision")
            if row
            else {
                "case_id": str(identity),
                "assignee": "",
                "priority": "normal",
                "due_at": None,
                "incident_id": None,
                "revision": 0,
            }
        )


@router.post("/v1/admin/cases/{identity}/triage")
def triage(identity: UUID, body: Triage, request: Request, role: Access):
    owner(role)
    fingerprint = digest({"case": str(identity), **body.model_dump(mode="json")})
    with request.app.state.session_factory() as db:
        begin(db, str(identity))
        old = replay(db, body.command_id, fingerprint)
        if old is not None:
            return old
        if not db.scalar(select(StudioCase).where(StudioCase.id == str(identity)).with_for_update()):
            raise HTTPException(404, "CASE_NOT_FOUND")
        if body.assignee and not db.get(StudioStaff, body.assignee):
            raise HTTPException(422, "UNKNOWN_STAFF")
        if body.incident_id and not db.get(StudioIncident, str(body.incident_id)):
            raise HTTPException(422, "INCIDENT_NOT_FOUND")
        row = db.get(StudioCaseTriage, str(identity))
        if row is None:
            row = StudioCaseTriage(case_id=str(identity), revision=0, assignee="", priority="normal")
            db.add(row)
        if row.revision != body.expected_revision:
            raise HTTPException(409, "CASE_TRIAGE_REVISION_CHANGED")
        before = value(row, "case_id assignee priority due_at incident_id revision")
        row.assignee, row.priority, row.due_at, row.incident_id, row.revision = (
            body.assignee,
            body.priority,
            body.due_at,
            str(body.incident_id) if body.incident_id else None,
            row.revision + 1,
        )
        after = value(row, "case_id assignee priority due_at incident_id revision")
        audited(
            db,
            request,
            role,
            body.command_id,
            "case_triage",
            row.case_id,
            body.reason,
            before,
            after,
            fingerprint,
        )
        db.commit()
        return after


def csv_cell(value):
    text = str(value)
    return (
        "'" + text
        if text.lstrip().startswith(("=", "+", "-", "@")) or text.startswith(("\t", "\r", "\n"))
        else text
    )


@router.get("/v1/admin/exports/activity.csv")
def export(
    request: Request,
    role: Access,
    window: Window,
    build_id: str = Query("", max_length=80),
    platform: str = Query("", max_length=12),
    mode: str = Query("", max_length=24),
    population: str = "all",
):
    first, until = window or calendar_range(7)
    from .studio_analysis import population_conditions

    conditions = [
        AnalysisDay.day >= first // 86400,
        AnalysisDay.day <= (until - 1) // 86400,
        *population_conditions(request.app.state.settings, AnalysisDay, population),
    ]
    for field, value_ in (("build_id", build_id), ("platform", platform), ("mode", mode)):
        if value_:
            conditions.append(getattr(AnalysisDay, field) == value_)
    with request.app.state.session_factory() as db:
        read_snapshot(db)
        fields = (AnalysisDay.day, AnalysisDay.build_id, AnalysisDay.platform)
        rows = db.execute(
            select(
                *fields,
                func.count(
                    func.distinct(
                        case((AnalysisDay.counters["active"].as_integer() > 0, AnalysisDay.player_id))
                    )
                ),
                func.coalesce(func.sum(AnalysisDay.counters["race_started"].as_integer()), 0),
            )
            .where(*conditions)
            .group_by(*fields)
            .order_by(*fields)
            .limit(1001)
        ).all()
        if len(rows) > 1000:
            raise HTTPException(422, "EXPORT_TOO_LARGE_NARROW_DATES")
        stream = io.StringIO(newline="")
        writer = csv.writer(stream)
        writer.writerow(("utc_day", "build_id", "platform", "active_players", "race_starts"))
        writer.writerows(
            [
                [
                    datetime.fromtimestamp(row[0] * 86400, timezone.utc).date().isoformat(),
                    *[csv_cell(v) for v in row[1:]],
                ]
                for row in rows
            ]
        )
        return Response(
            stream.getvalue(),
            media_type="text/csv",
            headers={
                "Content-Disposition": 'attachment; filename="observed-activity.csv"',
                "Cache-Control": "no-store",
            },
        )


# Existing case commands also retain the named actor in their append-only history.
@event.listens_for(StudioCaseEvent, "before_insert")
def named_case_actor(_mapper, _connection, target):
    target.actor = actor(target.actor)
