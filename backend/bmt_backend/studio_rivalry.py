"""Studio calendar, eligible metric search and audited future-week edits."""
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, Request
from pydantic import BaseModel, ConfigDict, Field, field_validator
from sqlalchemy import select, text, update

from .admin import Access
from .admin_models import AdminAudit
from .middleware import ParsedJSONRoute
from .rivalry import active_contract, eligible_query, week_window
from .rivalry_models import RivalryWeekPlan
from .rivalry_planning import HORIZON, WEEK, ensure_vehicle, metric, plan_contract, planning_lock
from .studio_access import actor
from .track_models import Track, TrackVersion, digest, now

router = APIRouter(route_class=ParsedJSONRoute, tags=["studio rivalry planning"])


def projection(plan, timestamp):
    return {"id": plan.id, "week_start": plan.week_start, "ends_at": plan.week_start + WEEK,
        "vehicle_id": plan.vehicle_id, "revision": plan.revision, "source": plan.source,
        "tracks": plan.tracks, "updated_at": plan.updated_at, "editable": timestamp < plan.week_start}


def begin_write(db):
    if db.bind.dialect.name == "sqlite":
        db.execute(text("BEGIN IMMEDIATE"))


def command_lock(db, command_id):
    if db.bind.dialect.name == "postgresql":
        key = int(digest({"rivalry_command": str(command_id)})[:16], 16) % (2**63)
        db.execute(text("SELECT pg_advisory_xact_lock(:key)"), {"key": key})


def owner(role):
    if role != "owner":
        raise HTTPException(403, "OWNER_REQUIRED")


@router.get("/v1/admin/rivalry-plans")
def calendar(request: Request, role: Access, vehicle_id: str = Query("compact", max_length=80)):
    active, contract = active_contract(request, vehicle_id)
    timestamp = now()
    start = week_window(timestamp)[0]
    with request.app.state.session_factory() as db:
        plans = list(db.scalars(select(RivalryWeekPlan).where(RivalryWeekPlan.contract_key == contract,
            RivalryWeekPlan.week_start >= start, RivalryWeekPlan.week_start <= start + HORIZON * WEEK)
            .order_by(RivalryWeekPlan.week_start).limit(HORIZON + 1)))
        by_week = {p.week_start: p for p in plans}
        weeks = [projection(by_week[start + n * WEEK], timestamp) if start + n * WEEK in by_week else
            {"week_start": start + n * WEEK, "ends_at": start + (n + 1) * WEEK, "tracks": [],
             "source": "missing", "editable": False} for n in range(1, HORIZON + 1)]
        selected = {t["version_id"] for w in weeks for t in w["tracks"]}
        valid = set(db.scalars(eligible_query(active, vehicle_id).with_only_columns(TrackVersion.id)
            .where(TrackVersion.id.in_(selected), Track.archived.is_(False))))
        for week in weeks:
            week["unavailable_version_ids"] = [t["version_id"] for t in week["tracks"] if t["version_id"] not in valid]
        recent = list(db.scalars(select(AdminAudit).where(AdminAudit.action.in_(
            ("rivalry_plan_edit", "rivalry_plan_fill"))).order_by(AdminAudit.created_at.desc(), AdminAudit.id).limit(20)))
        return {"vehicle_id": vehicle_id, "vehicles": sorted(active["vehicles"]), "as_of": timestamp,
            "current": projection(by_week[start], timestamp) if start in by_week else None,
            "weeks": weeks, "ready_weeks": sum(len(w["tracks"]) == 5 and not w["unavailable_version_ids"] for w in weeks),
            "role": role, "timezone": "UTC", "horizon": HORIZON,
            "policy": "Five eligible tracks per week. Ratings and verified finishers weight a random draw; "
                "recent use and biome variety spread selections. Existing plans stay fixed until edited or an unavailable future track is repaired.",
            "history": [{"command_id": r.command_id, "actor": r.actor, "reason": r.reason,
                "created_at": r.created_at, "action": r.action, "plan_id": r.entity_id} for r in recent]}


@router.get("/v1/admin/rivalry-plans/candidates")
def list_candidates(request: Request, role: Access, vehicle_id: str = Query("compact", max_length=80),
        q: str = Query("", max_length=80), offset: int = Query(0, ge=0, le=10000)):
    active, _ = active_contract(request, vehicle_id)
    with request.app.state.session_factory() as db:
        query = eligible_query(active, vehicle_id).where(Track.archived.is_(False))
        if q:
            query = query.where(TrackVersion.name.icontains(q, autoescape=True))
        rows = list(db.scalars(query.order_by(TrackVersion.name, TrackVersion.id).offset(offset).limit(51)))
        return {"items": [metric(v) for v in rows[:50]], "offset": offset,
            "next_offset": offset + 50 if len(rows) > 50 and offset < 10000 else None,
            "eligibility": "Published compatible latest versions, available owner and track. Official tracks, "
                "or community rating above 4.0 with more than 100 distinct verified finishers."}


class Fill(BaseModel):
    model_config = ConfigDict(extra="forbid")
    command_id: UUID
    reason: str = Field(min_length=3, max_length=500)

    @field_validator("reason")
    @classmethod
    def reason_required(cls, value):
        if len(value.strip()) < 3:
            raise ValueError("Explain the schedule change")
        return value.strip()


class Edit(Fill):
    expected_revision: int = Field(strict=True, ge=0)
    version_ids: list[UUID] = Field(min_length=5, max_length=5)


class Confirm(Edit):
    preview_at: int = Field(strict=True, ge=0)
    preview_hash: str = Field(pattern=r"^[a-f0-9]{64}$")


def replay(db, body, identity, role):
    prior = db.scalar(select(AdminAudit).where(AdminAudit.command_id == str(body.command_id)))
    if prior:
        if (prior.request_hash != digest(body.model_dump(mode="json")) or prior.entity_id != identity
                or prior.actor != actor(role)):
            raise HTTPException(409, "COMMAND_ID_REUSED")
        return prior.after


def audit(db, body, identity, role, action, before, after, request):
    db.add(AdminAudit(command_id=str(body.command_id), actor=actor(role), action=action,
        entity_id=identity, reason=body.reason, before=before, after=after,
        request_hash=digest(body.model_dump(mode="json")),
        request_id=getattr(request.state, "request_id", str(body.command_id))))


@router.post("/v1/admin/rivalry-plans/prepare")
def prepare(body: Fill, request: Request, role: Access):
    owner(role)
    active = request.app.state.verifier.manifest()
    with request.app.state.session_factory() as db:
        begin_write(db)
        command_lock(db, body.command_id)
        # Serialize retry and all per-contract changes through the same locks.
        for vehicle in sorted(active["vehicles"]):
            planning_lock(db, plan_contract(active, vehicle))
        identity = "weekly-calendar"
        prior = replay(db, body, identity, role)
        if prior is not None:
            return prior
        changes = sum(ensure_vehicle(db, active, v, now()) for v in sorted(active["vehicles"]))
        result = {"plans_changed": changes, "as_of": now()}
        audit(db, body, identity, role, "rivalry_plan_fill", {}, result, request)
        db.commit()
        return result


def checked_plan(db, identity, body, request, timestamp):
    plan = db.get(RivalryWeekPlan, str(identity))
    if plan is None:
        raise HTTPException(404, "PLAN_NOT_FOUND")
    active, contract = active_contract(request, plan.vehicle_id)
    if plan.contract_key != contract:
        raise HTTPException(409, "RIVALRY_BUILD_CHANGED")
    if timestamp >= plan.week_start:
        raise HTTPException(409, "RIVALRY_WEEK_LOCKED")
    if plan.revision != body.expected_revision:
        raise HTTPException(409, "PLAN_CHANGED_REFRESH_REQUIRED")
    ids = [str(v) for v in body.version_ids]
    if len(set(ids)) != 5:
        raise HTTPException(422, "FIVE_DISTINCT_TRACKS_REQUIRED")
    rows = {v.id: v for v in db.scalars(eligible_query(active, plan.vehicle_id)
        .where(TrackVersion.id.in_(ids), Track.archived.is_(False)))}
    if len(rows) != 5 or len({v.track_id for v in rows.values()}) != 5:
        raise HTTPException(409, "SELECTED_TRACK_NOT_ELIGIBLE")
    return plan, [metric(rows[vid]) for vid in ids]


def preview_hash(plan, body, after, timestamp):
    return digest({"plan_id": plan.id, "revision": plan.revision, "before": plan.tracks,
        "after": after, "body": body.model_dump(mode="json", exclude={"preview_at", "preview_hash"}),
        "preview_at": timestamp})


@router.post("/v1/admin/rivalry-plans/{identity}/preview")
def preview(identity: UUID, body: Edit, request: Request, role: Access):
    owner(role)
    with request.app.state.session_factory() as db:
        timestamp = now()
        plan, after = checked_plan(db, identity, body, request, timestamp)
        return {"before": plan.tracks, "after": after, "week_start": plan.week_start,
            "preview_at": timestamp, "preview_hash": preview_hash(plan, body, after, timestamp)}


@router.post("/v1/admin/rivalry-plans/{identity}/commands")
def execute(identity: UUID, body: Confirm, request: Request, role: Access):
    owner(role)
    with request.app.state.session_factory() as db:
        begin_write(db)
        command_lock(db, body.command_id)
        # Fetch only the lock identity; refresh plan state after acquiring its lock.
        contract = db.scalar(select(RivalryWeekPlan.contract_key).where(RivalryWeekPlan.id == str(identity)))
        if contract is None:
            raise HTTPException(404, "PLAN_NOT_FOUND")
        planning_lock(db, contract)
        prior = replay(db, body, str(identity), role)
        if prior is not None:
            return prior
        timestamp = now()
        plan, after = checked_plan(db, identity, body, request, timestamp)
        if not 0 <= timestamp - body.preview_at <= 300:
            raise HTTPException(409, "PREVIEW_EXPIRED")
        if body.preview_hash != preview_hash(plan, body, after, body.preview_at):
            raise HTTPException(409, "PREVIEW_CHANGED_REFRESH_REQUIRED")
        before = projection(plan, timestamp)
        # Deadline in the write predicate closes a week-boundary race after validation.
        changed = db.execute(update(RivalryWeekPlan).where(RivalryWeekPlan.id == plan.id,
            RivalryWeekPlan.revision == body.expected_revision, RivalryWeekPlan.week_start > now())
            .values(tracks=after, revision=plan.revision + 1, source="manual", updated_at=timestamp)).rowcount
        if not changed:
            raise HTTPException(409, "PLAN_CHANGED_OR_WEEK_LOCKED")
        db.refresh(plan)
        result = projection(plan, timestamp)
        audit(db, body, plan.id, role, "rivalry_plan_edit", before, result, request)
        db.commit()
        return result
