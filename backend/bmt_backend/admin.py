"""Same-origin administrative console with bounded queries and explicit commands."""

import hmac
from pathlib import Path
from typing import Annotated, Literal
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from fastapi.responses import FileResponse
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import func, or_, select, update
from sqlalchemy.exc import IntegrityError

from .admin_models import AdminAudit
from .admin_ranges import calendar_range, during, time_range
from .commerce import entitlement_payload
from .commerce_models import Entitlements
from .identity_models import Identity, Player, SessionFamily
from .middleware import ParsedJSONRoute
from .migrate import SCHEMA_HEAD
from .operations import competition_health
from .resume_models import ResumeGrant, ResumeWallet
from .track_models import Board, PersonalBest, Run, Track, TrackVersion, digest, now

router = APIRouter(route_class=ParsedJSONRoute, tags=["administration"])
UI = Path(__file__).with_name("admin_ui")


def access(request: Request):
    settings = request.app.state.settings
    supplied = request.headers.get("authorization", "").removeprefix("Bearer ")
    for role, key in (("owner", settings.admin_owner_key), ("analyst", settings.admin_analyst_key)):
        if key and hmac.compare_digest(supplied.encode(), key.encode()):
            return role
    raise HTTPException(401, "ADMIN_AUTH_REQUIRED")


Access = Annotated[str, Depends(access)]
Window = Annotated[tuple[int, int] | None, Depends(time_range)]


@router.get("/v1/admin/competition-health")
def competition(request: Request, role: Access):
    return competition_health(request.app)


@router.get("/admin", include_in_schema=False)
@router.get("/admin/", include_in_schema=False)
def console():
    return FileResponse(
        UI / "index.html",
        headers={
            "Content-Security-Policy": "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; frame-ancestors 'none'; base-uri 'none'; form-action 'self'",
            "Referrer-Policy": "no-referrer",
        },
    )


@router.get("/admin/assets/{name}", include_in_schema=False)
def asset(name: str):
    if name not in ("app.js", "commerce.js", "support.js", "studio.js", "product_analytics.js", "operations.js", "style.css", "catalogue.js", "catalogue.css", "monitor.js", "network.js", "monitor.css", "monitor_views.js", "monitor_views.css"):
        raise HTTPException(404)
    return FileResponse(UI / name)


# Explicit projections exclude provider subjects, session secrets and worker lease tokens.
FIELDS = {
    "players": (Player, "id display_name disabled deleted_at analytics_enabled needs_username is_test_driver created_at"),
    "tracks": (
        TrackVersion,
        "id track_id number name content_hash state created_at published_at rating_sum rating_count",
    ),
    "races": (
        Run,
        "id player_id board_id status created_at finished_at attempts time_ticks lap_ticks failure_code replay_hash",
    ),
    "jobs": (Run, "id player_id status attempts created_at finished_at failure_code"),
    "audit": (AdminAudit, "id command_id actor action entity_id reason before after request_id created_at"),
    "grants": (ResumeGrant, "id player_id source quantity created_at"),
}


def record(kind, row):
    return {key: getattr(row, key) for key in FIELDS[kind][1].split()}


@router.get("/v1/admin/overview")
def overview(request: Request, role: Access, window: Window, days: int = Query(7, ge=1, le=90)):
    from .publication_models import PublicationIntent
    window = window or calendar_range(days)
    with request.app.state.session_factory() as db:
        count = lambda model, *where: db.scalar(select(func.count()).select_from(model).where(*where))
        states = dict(
            db.execute(
                select(Run.status, func.count()).where(*during(Run.created_at, window)).group_by(Run.status)
            ).all()
        )
        utc_day = func.floor(Run.created_at / 86400)
        daily = db.execute(
            select(utc_day, func.count()).where(*during(Run.created_at, window)).group_by(utc_day)
        ).all()
        publication_failed = db.scalar(select(func.count()).select_from(select(PublicationIntent.id)
            .where(PublicationIntent.status == "failed").limit(5001).subquery()))
        return {
            "role": role,
            "environment": request.app.state.settings.environment,
            "as_of": now(),
            "days": days,
            "since": window[0],
            "until": window[1],
            "players": count(Player),
            "tracks": count(Track, select(TrackVersion.id).where(TrackVersion.track_id == Track.id,
                TrackVersion.state == "published").exists()) if request.app.state.settings.local_drafts_only else count(Track),
            "versions": count(TrackVersion, TrackVersion.state == "published") if request.app.state.settings.local_drafts_only else count(TrackVersion),
            "racers": db.scalar(
                select(func.count(func.distinct(Run.player_id))).where(*during(Run.created_at, window))
            ),
            "states": states,
            "daily": [{"day": int(day), "count": n} for day, n in daily],
            "pending": count(Run, Run.status.in_(["queued", "verifying"])),
            "publications": {"pending": count(PublicationIntent, PublicationIntent.status.in_(("queued", "verifying"))),
                "failed": min(publication_failed, 5000), "failed_count_capped": publication_failed > 5000},
            "disabled": count(Player, Player.disabled.is_(True)),
            "database": "reachable",
            "schema": SCHEMA_HEAD,
        }


@router.get("/v1/admin/entities/{kind}")
def entities(
    kind: str,
    request: Request,
    role: Access,
    window: Window,
    q: str = Query("", max_length=100),
    state: str = Query("", max_length=32),
    offset: int = Query(0, ge=0, le=1000000),
    limit: int = Query(25, ge=1, le=100),
):
    if kind not in FIELDS:
        raise HTTPException(404)
    model, fields = FIELDS[kind]
    conditions = during(model.created_at, window)
    if kind == "tracks" and request.app.state.settings.local_drafts_only:
        conditions.append(TrackVersion.state == "published")
    if q:
        search_fields = [
            getattr(model, key)
            for key in fields.split()
            if key in ("id", "display_name", "name", "player_id", "entity_id", "command_id", "request_id")
        ]
        conditions.append(or_(*(field.icontains(q, autoescape=True) for field in search_fields)))
    if state:
        if kind == "players":
            if state not in ("active", "disabled", "removed"):
                raise HTTPException(422, "INVALID_STATE")
            conditions.append(Player.deleted_at.is_not(None) if state == "removed" else Player.deleted_at.is_(None))
            if state != "removed": conditions.append(Player.disabled == (state == "disabled"))
        elif kind in ("races", "jobs", "tracks"):
            conditions.append(getattr(model, "state" if kind == "tracks" else "status") == state)
    with request.app.state.session_factory() as db:
        total = db.scalar(select(func.count()).select_from(model).where(*conditions))
        rows = db.scalars(
            select(model)
            .where(*conditions)
            .order_by(model.created_at.desc(), model.id)
            .offset(offset)
            .limit(limit)
        ).all()
        items = [record(kind, row) for row in rows]
        if kind == "tracks":
            tracks = {
                t.id: t for t in db.scalars(select(Track).where(Track.id.in_([r.track_id for r in rows])))
            }
            for item in items:
                parent = tracks[item["track_id"]]
                item.update(hidden=parent.hidden, owner_id=parent.owner_id)
        return {"items": items, "total": total, "offset": offset, "limit": limit}


@router.get("/v1/admin/entities/{kind}/{entity_id}")
def detail(kind: str, entity_id: str, request: Request, role: Access):
    if kind not in FIELDS:
        raise HTTPException(404)
    with request.app.state.session_factory() as db:
        row = db.get(FIELDS[kind][0], entity_id)
        if row is None:
            raise HTTPException(404, "ENTITY_NOT_FOUND")
        if kind == "tracks" and request.app.state.settings.local_drafts_only and row.state != "published":
            raise HTTPException(404, "ENTITY_NOT_FOUND")
        result = record(kind, row)
        if kind == "players":
            result["providers"] = list(
                db.scalars(select(Identity.provider).where(Identity.player_id == row.id))
            )
            wallet = db.get(ResumeWallet, row.id)
            result["permanent_resume_balance"] = wallet.balance if wallet else 0
            owned = db.get(Entitlements, row.id)
            result["entitlements"] = ({"initialized":True, "real_slots":owned.slots,
                "simulated_slots":owned.simulated_slots, "real_ad_free_until":owned.ad_free_until,
                "simulated_ad_free_until":owned.simulated_ad_free_until, "real_forever":owned.forever,
                "simulated_forever":owned.simulated_forever,
                "effective":entitlement_payload(db, request.app.state.settings, owned)}
                if owned else {"initialized":False,"initial_publishing_allowance":1})
            result["recent_races"] = [
                record("races", r)
                for r in db.scalars(
                    select(Run)
                    .where(Run.player_id == row.id)
                    .order_by(Run.created_at.desc(), Run.id)
                    .limit(20)
                )
            ]
        if kind == "tracks":
            parent = db.get(Track, row.track_id)
            try:
                document = request.app.state.blobs.get_json(row.content_hash)
                result["route_preview"] = {
                    "theme": document.get("theme"),
                    "points": document.get("points", []),
                }
            except (OSError, ValueError):
                result["route_preview"] = {"unavailable": True}
            result.update(
                owner_id=parent.owner_id,
                hidden=parent.hidden,
                manifest=row.manifest,
                creator_test_run_id=row.creator_test_run_id,
            )
        if kind == "races":
            board = db.get(Board, row.board_id)
            result.update(
                manifest=board.manifest,
                vehicle_id=board.vehicle_id,
                version_id=board.version_id,
                is_personal_best=db.scalar(
                    select(func.count()).select_from(PersonalBest).where(PersonalBest.run_id == row.id)
                )
                > 0,
            )
        return result


class Command(BaseModel):
    model_config = ConfigDict(extra="forbid")
    command_id: UUID
    action: Literal["player_restriction", "track_visibility"]
    entity_id: UUID
    expected: bool
    value: bool
    reason: str = Field(min_length=8, max_length=500)
    acknowledged: Literal[True]


@router.post("/v1/admin/commands")
def command(body: Command, request: Request, role: Access):
    if role != "owner":
        raise HTTPException(403, "OWNER_REQUIRED")
    if len(body.reason.strip()) < 8:
        raise HTTPException(422, "REASON_REQUIRED")
    entity_id, command_id = str(body.entity_id), str(body.command_id)
    hashed = digest(body.model_dump(mode="json"))
    model, field = (Player, "disabled") if body.action == "player_restriction" else (Track, "hidden")
    with request.app.state.session_factory() as db:
        prior = db.scalar(select(AdminAudit).where(AdminAudit.command_id == command_id))
        if prior:
            if prior.request_hash != hashed:
                raise HTTPException(409, "COMMAND_ID_REUSED")
            return {"audit_id": prior.id, "after": prior.after}
        changed = db.execute(
            update(model)
            .where(model.id == entity_id, getattr(model, field) == body.expected,
                Player.deleted_at.is_(None) if model == Player else True)
            .values(**{field: body.value})
        )
        if changed.rowcount != 1:
            prior = db.scalar(select(AdminAudit).where(AdminAudit.command_id == command_id))
            if prior and prior.request_hash == hashed:
                return {"audit_id": prior.id, "after": prior.after}
            raise HTTPException(409, "STATE_CHANGED_REFRESH_REQUIRED")
        if model == Player and body.value:
            db.execute(update(SessionFamily).where(SessionFamily.player_id == entity_id).values(revoked=True))
        audit = AdminAudit(
            command_id=command_id,
            actor=role,
            action=body.action,
            entity_id=entity_id,
            reason=body.reason.strip(),
            before={field: body.expected},
            after={field: body.value},
            request_hash=hashed,
            request_id=request.state.request_id,
        )
        db.add(audit)
        try:
            db.commit()
        except IntegrityError:
            db.rollback()
            prior = db.scalar(select(AdminAudit).where(AdminAudit.command_id == command_id))
            if prior and prior.request_hash == hashed:
                return {"audit_id": prior.id, "after": prior.after}
            raise HTTPException(409, "COMMAND_CONFLICT") from None
        return {"audit_id": audit.id, "after": audit.after}
