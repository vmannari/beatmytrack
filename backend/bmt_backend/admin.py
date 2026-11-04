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
from sqlalchemy.orm import load_only

from .admin_models import AdminAudit
from .admin_ranges import calendar_range, during, time_range
from .commerce import entitlement_payload
from .commerce_models import Entitlements
from .identity_models import Identity, Player, SessionFamily
from .middleware import ParsedJSONRoute
from .migrate import SCHEMA_HEAD
from .operations import competition_health
from .resume_models import ResumeGrant, ResumeWallet
from .studio_paging import identifier, page
from .track_models import Board, PersonalBest, QueueCapacity, Run, Track, TrackVersion, digest, now

router = APIRouter(route_class=ParsedJSONRoute, tags=["administration"])
UI = Path(__file__).with_name("admin_ui")


def access(request: Request):
    settings = request.app.state.settings
    if settings.workload_role != "admin" and settings.environment == "production":
        raise HTTPException(404, "NOT_FOUND")
    supplied = request.headers.get("authorization", "").removeprefix("Bearer ")
    for role, key in (("owner", settings.admin_owner_key), ("analyst", settings.admin_analyst_key)):
        if settings.environment != "production" and settings.studio_legacy_keys_enabled and key and hmac.compare_digest(supplied.encode(), key.encode()):
            return role
    from .studio_access import named_access
    return named_access(request, supplied)


Access = Annotated[str, Depends(access)]
Window = Annotated[tuple[int, int] | None, Depends(time_range)]


@router.get("/v1/admin/competition-health")
def competition(request: Request, role: Access):
    return competition_health(request.app)


@router.get("/admin", include_in_schema=False)
@router.get("/admin/", include_in_schema=False)
def console(request: Request):
    settings = request.app.state.settings
    identity_policy = ""
    if settings.studio_identity_project:
        domain = "https://" + settings.studio_identity_auth_domain
        identity_policy = ("; connect-src 'self' https://identitytoolkit.googleapis.com "
            "https://securetoken.googleapis.com https://www.googleapis.com " + domain
            + "; frame-src " + domain + " https://accounts.google.com")
    return FileResponse(
        UI / "index.html",
        headers={
            "Content-Security-Policy": "default-src 'self'; script-src 'self'"
            + (" https://www.gstatic.com/firebasejs/12.4.0/ https://apis.google.com" if settings.studio_identity_project else "")
            + "; style-src 'self' 'unsafe-inline'; img-src 'self' data:; frame-ancestors 'none'; base-uri 'none'; form-action 'self'"
            + identity_policy,
            "Referrer-Policy": "strict-origin-when-cross-origin" if settings.studio_identity_project else "no-referrer",
            "Cross-Origin-Opener-Policy": "same-origin-allow-popups",
            "Cache-Control": "no-store",
        },
    )


@router.get("/admin/assets/{name}", include_in_schema=False)
def asset(name: str):
    if name in ("usage.js", "usage.css"):
        return FileResponse(UI / name)
    if name not in ("app.js", "signin.js", "commerce.js", "support.js", "studio.js", "product_analytics.js", "operations.js", "reported_tracks.js", "style.css", "catalogue.js", "catalogue.css", "monitor.js", "network.js", "monitor.css", "monitor_views.js", "monitor_views.css", "insights.js", "insights.css", "platform.js", "platform.css", "game_config.js", "game_config.css", "ranking.js"):
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
    """Current operating pulse; lifetime catalogue totals are retired."""
    window = window or calendar_range(days)
    stamp = now()
    with request.app.state.session_factory() as db:
        states = dict(db.execute(select(Run.status, func.count()).where(
            Run.status.in_(("verified", "skipped", "failed", "rejected")),
            Run.finished_at >= stamp - 300, Run.finished_at <= stamp).group_by(Run.status)).all())
        queue = db.get(QueueCapacity, 1)
        return {"role": role, "environment": request.app.state.settings.environment,
            "as_of": stamp, "days": days, "since": window[0], "until": window[1],
            "pending": queue.pending if queue else 0, "states": states,
            "pulse_since": stamp - 300, "pulse_until": stamp,
            "database": "reachable", "schema": SCHEMA_HEAD,
            "coverage": "Current shared verification queue and terminal results in the last five minutes; all player types. Lifetime account/content totals and raw submission-history charts are retired."}


@router.get("/v1/admin/entities/{kind}")
def entities(
    kind: str,
    request: Request,
    role: Access,
    window: Window,
    q: str = Query("", max_length=100),
    state: str = Query("", max_length=32),
    failure_code: str = Query("", max_length=64),
    time_field: str = "created_at",
    offset: int = Query(0, ge=0, le=1000000),
    limit: int = Query(25, ge=1, le=100),
    cursor: str = Query("", max_length=2048),
):
    if kind not in FIELDS:
        raise HTTPException(404)
    model, fields = FIELDS[kind]
    if time_field not in ("created_at", "finished_at") or (time_field == "finished_at" and kind not in ("races", "jobs")):
        raise HTTPException(422, "INVALID_TIME_FIELD")
    timestamp = getattr(model, time_field)
    conditions = during(timestamp, window)
    if time_field == "finished_at":
        conditions.append(timestamp.is_not(None))
    if kind == "tracks" and request.app.state.settings.local_drafts_only:
        conditions.append(TrackVersion.state == "published")
    if q:
        search_fields = [
            getattr(model, key)
            for key in fields.split()
            if key in ("id", "display_name", "name", "player_id", "entity_id", "command_id", "request_id", "failure_code")
        ]
        key = identifier(q)
        conditions.append(or_(*(field == key for field in search_fields)) if key else
                          or_(*(field.icontains(q, autoescape=True) for field in search_fields)))
    if failure_code:
        if kind not in ("races", "jobs"):
            raise HTTPException(422, "FAILURE_FILTER_REQUIRES_RACES")
        conditions.append(Run.failure_code == failure_code)
    if state:
        if kind == "players":
            if state not in ("active", "disabled", "removed"):
                raise HTTPException(422, "INVALID_STATE")
            conditions.append(Player.deleted_at.is_not(None) if state == "removed" else Player.deleted_at.is_(None))
            if state != "removed": conditions.append(Player.disabled == (state == "disabled"))
        elif kind in ("races", "jobs", "tracks"):
            conditions.append(getattr(model, "state" if kind == "tracks" else "status") == state)
    with request.app.state.session_factory() as db:
        selected, paging = page(db, select(model).where(*conditions).options(
            load_only(*(getattr(model, field) for field in fields.split()))), timestamp, model.id,
            scope=digest({"kind": kind, "window": window, "q": q, "state": state,
                          "failure": failure_code, "time_field": time_field,
                          "published": request.app.state.settings.local_drafts_only}),
            cursor=cursor, offset=offset, limit=limit, descending=True, numeric=True)
        rows = [row[0] for row in selected]
        items = [record(kind, row) for row in rows]
        if kind == "tracks":
            tracks = {
                t.id: t for t in db.scalars(select(Track).where(Track.id.in_([r.track_id for r in rows])))
            }
            for item in items:
                parent = tracks[item["track_id"]]
                item.update(hidden=parent.hidden, owner_id=parent.owner_id)
        return {"items": items, **paging}


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
        if model == Track and db.scalar(select(AdminAudit.id).where(
                AdminAudit.entity_id == entity_id, AdminAudit.action == "track_deletion").limit(1)):
            raise HTTPException(409, "TRACK_DELETED")
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
