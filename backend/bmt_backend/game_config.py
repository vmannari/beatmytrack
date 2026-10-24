"""Atomic owner-controlled noncanonical policy publication, preview and delivery."""
import secrets
from copy import deepcopy
from typing import Annotated
from uuid import NAMESPACE_URL, UUID, uuid4, uuid5

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response
from fastapi.security import HTTPAuthorizationCredentials
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import func, select

from .admin import Access
from .admin_models import AdminAudit
from .commerce import simulator_allowed
from .commerce_models import Entitlements
from .game_config_models import GameConfigControl, GameConfigDelivery, GameConfigDraft, GameConfigRelease
from .game_config_policy import (
    CAPABILITIES,
    DEFAULTS,
    REGISTRY,
    bucket,
    matches,
    protect,
    resolve,
    validate_audiences,
    validate_settings,
)
from .middleware import ParsedJSONRoute
from .security import bearer, current_player
from .studio_access import actor
from .studio_cases import begin, owner, safe_text
from .studio_platform_models import StudioAssignment, StudioExperiment
from .studio_queries import read_snapshot
from .track_models import digest, now
from .tracks import DB

router = APIRouter(route_class=ParsedJSONRoute, tags=["Game configuration"])
public_router = APIRouter(route_class=ParsedJSONRoute, tags=["Game configuration"])
LOCK = str(UUID(digest({"control": "experiments"})[:32]))


def control(db, write=False):
    row = db.get(GameConfigControl, 1)
    if row is None:
        row = GameConfigControl(id=1, revision=0, active_generation=0, emergency={})
        if write:
            db.add(row)
            db.flush()
    return row


def current(db):
    return db.get(GameConfigRelease, control(db).active_generation)


def release_value(row):
    if row is None:
        return {"generation": 0, "name": "Built-in safe defaults", "policy": deepcopy(DEFAULTS), "audiences": [],
            "rollout": 10000, "internal_players": [], "state": "active", "created_at": None, "base_generation": 0, "scheduled_at": 0}
    return {key: deepcopy(getattr(row, key)) for key in ("generation", "name", "policy", "audiences", "rollout",
        "internal_players", "state", "created_at", "base_generation", "scheduled_at")}


def draft_value(row):
    return {key: deepcopy(getattr(row, key)) for key in ("id", "name", "revision", "base_generation", "policy", "audiences", "updated_at")}


def replay(db, command_id, fingerprint):
    row = db.scalar(select(AdminAudit).where(AdminAudit.command_id == str(command_id)))
    if row:
        if row.request_hash != fingerprint:
            raise HTTPException(409, "COMMAND_ID_CONFLICT")
        return deepcopy(row.after)


def audit(db, request, role, command_id, fingerprint, action, identity, reason, before, after):
    db.add(AdminAudit(command_id=str(command_id), request_hash=fingerprint, actor=actor(role),
        action=action, entity_id=str(identity), reason=safe_text(reason, 500), before=before,
        after=after, request_id=request.state.request_id))
    db.commit()
    return after


def check_revision(row, expected):
    if row.revision != expected:
        if isinstance(row, GameConfigDraft):
            raise HTTPException(409, {"code": "CONFIG_REVISION_CHANGED", "current_revision": row.revision,
                "current_policy": row.policy})
        raise HTTPException(409, "CONFIG_REVISION_CHANGED")


def check_experiments(db, policy, audiences):
    for experiment in db.scalars(select(StudioExperiment).where(StudioExperiment.state == "active").limit(16)):
        meta = experiment.configuration or {}
        if not meta:
            continue
        keys = meta["protected_keys"]
        if any(policy[key] != meta["baseline_policy"][key] for key in keys) or any(
            set(item["settings"]) & set(keys) for item in audiences):
            raise HTTPException(409, "PAUSE_CONFLICTING_EXPERIMENT_FIRST")


def publish_snapshot(db, name, policy, audiences, *, rollout=10000, internal_players=None,
                     scheduled_at=0, salt=None, fallback=None, who="owner"):
    ctrl = control(db, True)
    previous = current(db)
    generation = (db.scalar(select(func.max(GameConfigRelease.generation))) or 0) + 1
    row = GameConfigRelease(generation=generation, name=name, policy=deepcopy(policy), audiences=deepcopy(audiences),
        fallback=deepcopy(fallback or {"policy": release_value(previous)["policy"], "audiences": release_value(previous)["audiences"]}),
        rollout=rollout, internal_players=internal_players or [], salt=salt or secrets.token_hex(32),
        state="scheduled" if scheduled_at else "active", base_generation=ctrl.active_generation,
        scheduled_at=scheduled_at, actor=who)
    db.add(row)
    db.flush()
    if not scheduled_at:
        if previous is not None:
            previous.state = "superseded"
        ctrl.active_generation = row.generation
    ctrl.revision += 1
    return row


class Command(BaseModel):
    model_config = ConfigDict(extra="forbid")
    command_id: UUID
    expected_revision: int = Field(ge=0)
    reason: str = Field(min_length=3, max_length=500)


class DraftCreate(Command):
    name: str = Field(min_length=3, max_length=100)
    source_generation: int | None = Field(default=None, ge=0)


@router.get("/v1/admin/game-config/parameters")
def parameters(role: Access):
    return {"registry": REGISTRY, "capabilities": sorted(CAPABILITIES), "locked_categories": [
        "Reward amounts and multipliers require an approved server policy.",
        "Monthly publishing allowances remain unapproved.",
        "Prices, purchases, race rules and existing competition terms remain authoritative."]}


@router.get("/v1/admin/game-config")
def overview(request: Request, role: Access, before: int | None = Query(default=None, ge=1)):
    with request.app.state.session_factory() as db:
        read_snapshot(db)
        ctrl = control(db)
        query = select(GameConfigRelease).order_by(GameConfigRelease.generation.desc()).limit(26)
        if before is not None:
            query = query.where(GameConfigRelease.generation < before)
        history = db.scalars(query).all()
        deliveries = db.execute(select(GameConfigDelivery.status, func.count()).where(
            GameConfigDelivery.observed_at >= now() - 86400).group_by(GameConfigDelivery.status)).all()
        return {"role": role, "environment": request.app.state.settings.environment, "revision": ctrl.revision,
            "active": release_value(current(db)), "emergency": ctrl.emergency,
            "drafts": [draft_value(r) for r in db.scalars(select(GameConfigDraft).order_by(
                GameConfigDraft.updated_at.desc(), GameConfigDraft.id).limit(25))],
            "history": [release_value(r) for r in history[:25]], "next_cursor": history[24].generation if len(history) > 25 else None,
            "deliveries": dict(deliveries), "delivery_scope": "Latest signed-in reporting-account observation in the past 24 hours; guest/offline coverage unavailable."}


@router.post("/v1/admin/game-config/drafts")
def create_draft(body: DraftCreate, request: Request, role: Access):
    owner(role)
    fingerprint = digest(body.model_dump(mode="json"))
    with request.app.state.session_factory() as db:
        begin(db, LOCK)
        old = replay(db, body.command_id, fingerprint)
        if old is not None:
            return old
        ctrl = control(db, True)
        check_revision(ctrl, body.expected_revision)
        source = ctrl.active_generation if body.source_generation is None else body.source_generation
        release = db.get(GameConfigRelease, source) if source else None
        if source and release is None:
            raise HTTPException(404, "CONFIG_VERSION_NOT_FOUND")
        baseline = release_value(release)
        row = GameConfigDraft(id=str(body.command_id), name=safe_text(body.name, 100), revision=0,
            base_generation=ctrl.active_generation, policy=baseline["policy"], audiences=baseline["audiences"])
        db.add(row)
        db.flush()
        return audit(db, request, role, body.command_id, fingerprint, "config_draft_create", row.id, body.reason, {}, draft_value(row))


class DraftEdit(Command):
    policy: dict
    audiences: list = Field(default_factory=list, max_length=16)


@router.get("/v1/admin/game-config/drafts/{identity}")
def get_draft(identity: UUID, request: Request, role: Access):
    with request.app.state.session_factory() as db:
        row = db.get(GameConfigDraft, str(identity))
        if row is None:
            raise HTTPException(404, "CONFIG_DRAFT_NOT_FOUND")
        return draft_value(row)


@router.patch("/v1/admin/game-config/drafts/{identity}")
@router.post("/v1/admin/game-config/drafts/{identity}/edit")
def edit_draft(identity: UUID, body: DraftEdit, request: Request, role: Access):
    owner(role)
    policy, audiences = validate_settings(body.policy), validate_audiences(body.audiences)
    fingerprint = digest({"id": str(identity), **body.model_dump(mode="json")})
    with request.app.state.session_factory() as db:
        begin(db, LOCK)
        old = replay(db, body.command_id, fingerprint)
        if old is not None:
            return old
        row = db.get(GameConfigDraft, str(identity))
        if row is None:
            raise HTTPException(404, "CONFIG_DRAFT_NOT_FOUND")
        check_revision(row, body.expected_revision)
        before = draft_value(row)
        row.policy, row.audiences, row.updated_at = policy, audiences, now()
        row.revision += 1
        return audit(db, request, role, body.command_id, fingerprint, "config_draft_edit", row.id, body.reason, before, draft_value(row))


@router.post("/v1/admin/game-config/drafts/{identity}/validate")
def validate_draft(identity: UUID, request: Request, role: Access):
    with request.app.state.session_factory() as db:
        row = db.get(GameConfigDraft, str(identity))
        if row is None:
            raise HTTPException(404, "CONFIG_DRAFT_NOT_FOUND")
        validate_settings(row.policy)
        validate_audiences(row.audiences)
        check_experiments(db, row.policy, row.audiences)
        return {"valid": row.base_generation == control(db).active_generation,
            "base_generation": row.base_generation, "active_generation": control(db).active_generation,
            "draft_revision": row.revision, "reach": None, "reach_reason": "No complete eligible-device census is available."}


class Publish(Command):
    rollout: int = Field(default=10000, ge=0, le=10000)
    internal_players: list[UUID] = Field(default_factory=list, max_length=100)
    scheduled_at: int = Field(default=0, ge=0)


@router.post("/v1/admin/game-config/drafts/{identity}/publish")
def publish(identity: UUID, body: Publish, request: Request, role: Access):
    owner(role)
    fingerprint = digest({"draft": str(identity), **body.model_dump(mode="json")})
    with request.app.state.session_factory() as db:
        begin(db, LOCK)
        old = replay(db, body.command_id, fingerprint)
        if old is not None:
            return old
        draft = db.get(GameConfigDraft, str(identity))
        if draft is None:
            raise HTTPException(404, "CONFIG_DRAFT_NOT_FOUND")
        check_revision(draft, body.expected_revision)
        ctrl, previous = control(db, True), current(db)
        if draft.base_generation != ctrl.active_generation:
            raise HTTPException(409, "CONFIG_BASE_GENERATION_CHANGED")
        if previous and previous.rollout < 10000:
            raise HTTPException(409, "FINISH_OR_RESTORE_ACTIVE_ROLLOUT")
        if body.scheduled_at and not now() < body.scheduled_at <= now() + 365 * 86400:
            raise HTTPException(422, "INVALID_CONFIG_SCHEDULE")
        if body.rollout == 0 and not body.internal_players:
            raise HTTPException(422, "INTERNAL_ROLLOUT_REQUIRES_ACCOUNTS")
        pending = db.scalar(select(func.count()).select_from(GameConfigRelease).where(GameConfigRelease.state == "scheduled"))
        if pending >= 32:
            raise HTTPException(409, "CONFIG_SCHEDULE_LIMIT")
        validate_settings(draft.policy)
        validate_audiences(draft.audiences)
        check_experiments(db, draft.policy, draft.audiences)
        row = publish_snapshot(db, draft.name, draft.policy, draft.audiences, rollout=body.rollout,
            internal_players=[str(v) for v in body.internal_players], scheduled_at=body.scheduled_at, who=actor(role))
        return audit(db, request, role, body.command_id, fingerprint, "config_publish", row.generation,
            body.reason, release_value(previous), {"release": release_value(row), "revision": ctrl.revision})


@router.post("/v1/admin/game-config/releases/{generation}/{action}")
def release_command(generation: int, action: str, body: Command, request: Request, role: Access):
    owner(role)
    if action not in ("advance", "pause", "cancel-schedule"):
        raise HTTPException(404, "CONFIG_ACTION_NOT_FOUND")
    fingerprint = digest({"generation": generation, "action": action, **body.model_dump(mode="json")})
    with request.app.state.session_factory() as db:
        begin(db, LOCK)
        old = replay(db, body.command_id, fingerprint)
        if old is not None:
            return old
        ctrl = control(db, True)
        check_revision(ctrl, body.expected_revision)
        row = db.get(GameConfigRelease, generation)
        if row is None:
            raise HTTPException(404, "CONFIG_VERSION_NOT_FOUND")
        before = release_value(row)
        if action == "cancel-schedule":
            if row.state != "scheduled":
                raise HTTPException(409, "CONFIG_NOT_SCHEDULED")
            row.state = "cancelled"
            ctrl.revision += 1
        else:
            if generation != ctrl.active_generation or row.rollout >= 10000:
                raise HTTPException(409, "CONFIG_NOT_ROLLING_OUT")
            if action == "pause":
                row.state = "paused"
                ctrl.revision += 1
            else:
                next_stage = next(v for v in (500, 2500, 10000) if v > row.rollout)
                row = publish_snapshot(db, row.name, row.policy, row.audiences, rollout=next_stage,
                    internal_players=row.internal_players, salt=row.salt, fallback=row.fallback, who=actor(role))
        return audit(db, request, role, body.command_id, fingerprint, "config_" + action.replace("-", "_"),
            row.generation, body.reason, before, {"release": release_value(row), "revision": ctrl.revision})


class Restore(Command):
    generation: int = Field(ge=0)


@router.post("/v1/admin/game-config/restore")
def restore(body: Restore, request: Request, role: Access):
    owner(role)
    fingerprint = digest(body.model_dump(mode="json"))
    with request.app.state.session_factory() as db:
        begin(db, LOCK)
        old = replay(db, body.command_id, fingerprint)
        if old is not None:
            return old
        ctrl = control(db, True)
        check_revision(ctrl, body.expected_revision)
        source = db.get(GameConfigRelease, body.generation) if body.generation else None
        if body.generation and source is None:
            raise HTTPException(404, "CONFIG_VERSION_NOT_FOUND")
        target = release_value(source)
        check_experiments(db, target["policy"], target["audiences"])
        before = release_value(current(db))
        row = publish_snapshot(db, "Restore: " + target["name"][:90], target["policy"], target["audiences"], who=actor(role))
        return audit(db, request, role, body.command_id, fingerprint, "config_restore", row.generation,
            body.reason, before, {"release": release_value(row), "revision": ctrl.revision})


class Emergency(Command):
    restrictions: dict


@router.post("/v1/admin/game-config/emergency")
def emergency(body: Emergency, request: Request, role: Access):
    owner(role)
    allowed = {"ads.permitted", "ads.interstitial_enabled", "ads.rewarded_resume_enabled"}
    if not set(body.restrictions) <= allowed or any(v is not False for v in body.restrictions.values()):
        raise HTTPException(422, "EMERGENCY_RESTRICTIONS_ONLY")
    fingerprint = digest(body.model_dump(mode="json"))
    with request.app.state.session_factory() as db:
        begin(db, LOCK)
        old = replay(db, body.command_id, fingerprint)
        if old is not None:
            return old
        ctrl = control(db, True)
        check_revision(ctrl, body.expected_revision)
        before = deepcopy(ctrl.emergency)
        ctrl.emergency = deepcopy(body.restrictions)
        ctrl.revision += 1
        return audit(db, request, role, body.command_id, fingerprint, "config_emergency", 1, body.reason,
            before, {"emergency": ctrl.emergency, "revision": ctrl.revision})


def optional_player(request: Request, session: DB,
                    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)]):
    return current_player(request, credentials, session) if request.headers.get("authorization") else None


OptionalPlayer = Annotated[object, Depends(optional_player)]


def player_context(db, settings, player, context):
    result = deepcopy(context)
    result.update(authenticated=player is not None, player_id=player.id if player else "", ad_free=False)
    if player:
        row = db.get(Entitlements, player.id)
        if row:
            result["ad_free"] = row.forever or row.ad_free_until > now()
            if simulator_allowed(db, settings, player.id):
                result["ad_free"] |= row.simulated_forever or row.simulated_ad_free_until > now()
    return result


def effective(db, context, at=None):
    at = now() if at is None else at
    ctrl, row = control(db), current(db)
    snapshot = release_value(row)
    selected = True
    if row and row.rollout < 10000:
        selected = bool(context.get("authenticated")) and (context["player_id"] in row.internal_players or
            bucket(context["player_id"], row.salt) < row.rollout)
        if not selected:
            snapshot = row.fallback
    policy, sources = resolve(snapshot["policy"], snapshot["audiences"], context)
    applied, refresh = [], False
    active = db.scalars(select(StudioExperiment).where(StudioExperiment.state == "active").order_by(StudioExperiment.id).limit(16)).all()
    for experiment in active:
        meta = experiment.configuration or {}
        if not meta or not context.get("analytics_enabled") or not matches(meta["audience"], context):
            continue
        if bucket(context["player_id"], experiment.salt + ":enrollment") >= meta["enrollment"]:
            continue
        if not set(meta["capabilities"]) <= set(context.get("capabilities", [])):
            continue
        bound = db.get(StudioAssignment, (experiment.id, context["player_id"]))
        if bound is None:
            refresh = True
            continue
        for key in meta["protected_keys"]:
            policy[key] = deepcopy(meta["baseline_policy"][key])
        policy.update(deepcopy(experiment.variants[bound.variant]))
        sources.update({key: "experiment:" + experiment.id + ":" + bound.variant for key in meta["protected_keys"]})
        applied.append({"experiment_id": experiment.id, "variant": bound.variant, "revision": bound.revision,
            "layer": meta["layer"], "boundary": meta.get("boundary", "race_result" if meta["layer"] == "ads" else "menu_entry")})
    policy, restrictions = protect(policy, context, ctrl.emergency, at)
    resolution = digest({"generation": ctrl.active_generation, "revision": ctrl.revision,
        "policy": policy, "assignments": applied})
    return {"schema_version": 1, "generation": ctrl.active_generation, "control_revision": ctrl.revision,
        "content_version": digest(policy), "resolution_id": resolution, "server_now": at, "refresh_seconds": 1800,
        "expires_at": at + 7 * 86400, "emergency_valid_seconds": 120, "settings": policy, "sources": sources,
        "assignments": applied, "assignment_refresh_required": refresh, "restrictions": restrictions, "selected": selected}


@public_router.get("/v1/game-config")
def fetch(request: Request, response: Response, session: DB, player: OptionalPlayer,
          schema_version: int = Query(default=1, ge=1, le=1),
          platform: str = Query(default="android", pattern="^(android|windows|linux|ios)$"),
          build_id: str = Query(default="unknown", pattern=r"^[A-Za-z0-9._:-]{1,80}$"),
          capabilities: str = Query(default="", max_length=100), experiments_enabled: bool = True):
    caps = capabilities.split(",") if capabilities else []
    if not set(caps) <= CAPABILITIES:
        raise HTTPException(422, "UNSUPPORTED_CONFIG_CAPABILITY")
    # Authentication/rate leasing has finished. Read policy, audience and
    # assignment generations together instead of mixing READ COMMITTED views.
    session.commit()
    read_snapshot(session)
    context = player_context(session, request.app.state.settings, player, {"platform": platform, "build_id": build_id,
        "capabilities": caps, "analytics_enabled": bool(player and player.analytics_enabled and experiments_enabled
            and request.app.state.settings.telemetry_enabled)})
    result = effective(session, context)
    # Rule names/internal audiences remain private administrative evidence.
    result.pop("sources")
    result.pop("selected")
    result["scope"] = player.id if player else "guest"
    response.headers["Cache-Control"] = "private, no-store"
    response.headers["ETag"] = '"' + result["resolution_id"] + '"'
    if request.headers.get("if-none-match") == response.headers["ETag"]:
        return Response(status_code=304, headers={"Cache-Control": "private, no-store", "ETag": response.headers["ETag"],
            "X-Server-Time": str(result["server_now"]), "X-Config-Emergency-Seconds": "120"})
    return result


@public_router.get("/v1/game-config/emergency")
def emergency_status(response: Response, session: DB):
    ctrl = control(session)
    response.headers["Cache-Control"] = "no-store"
    return {"revision": ctrl.revision, "restrictions": ctrl.emergency, "valid_seconds": 120, "server_now": now()}


class Preview(BaseModel):
    model_config = ConfigDict(extra="forbid")
    platform: str = Field(default="android", pattern="^(android|windows|linux|ios)$")
    build_id: str = Field(default="unknown", min_length=1, max_length=80)
    capabilities: list[str] = Field(default_factory=lambda: sorted(CAPABILITIES), max_length=2)
    player_id: UUID | None = None
    draft_id: UUID | None = None
    settings: dict | None = None
    races: int = Field(default=0, ge=0, le=100)
    active_seconds: int = Field(default=0, ge=0, le=86400)
    session_seconds: int = Field(default=0, ge=0, le=86400)
    session_races: int = Field(default=0, ge=0, le=100)
    shown: int = Field(default=0, ge=0, le=100)
    rewarded_elapsed: int | None = Field(default=None, ge=0, le=86400)


@router.post("/v1/admin/game-config/preview")
def preview(body: Preview, request: Request, role: Access):
    from .identity_models import Player
    with request.app.state.session_factory() as db:
        person = db.get(Player, str(body.player_id)) if body.player_id else None
        if body.player_id and (person is None or person.deleted_at is not None):
            raise HTTPException(404, "PLAYER_NOT_FOUND")
        context = player_context(db, request.app.state.settings, person, {"platform": body.platform, "build_id": body.build_id,
            "capabilities": body.capabilities, "analytics_enabled": bool(person and person.analytics_enabled)})
        result = effective(db, context)
        if body.draft_id:
            draft = db.get(GameConfigDraft, str(body.draft_id))
            if draft is None:
                raise HTTPException(404, "CONFIG_DRAFT_NOT_FOUND")
            result["settings"], result["sources"] = resolve(draft.policy, draft.audiences, context)
        if body.settings:
            result["settings"].update(validate_settings(body.settings, partial=True))
        policy, restrictions = protect(result["settings"], context, control(db).emergency, now())
        result["settings"], result["restrictions"] = policy, restrictions
        due_race, due_time = body.races >= policy["ads.races"], body.active_seconds >= policy["ads.active_seconds"]
        due = (due_race or due_time) if policy["ads.trigger"] == "either" else due_race and due_time
        reasons = []
        if not policy["ads.permitted"] or not policy["ads.interstitial_enabled"]:
            reasons.append("Automatic advertising disabled")
        if not due:
            reasons.append("Due thresholds not met")
        if body.session_races == 0:
            reasons.append("Complete the first race of this session")
        if body.session_seconds < policy["ads.first_delay_seconds"]:
            reasons.append("First-ad delay")
        if body.races < policy["ads.min_races"] or body.active_seconds < policy["ads.min_seconds"]:
            reasons.append("Hard minimum spacing")
        if policy["ads.session_cap"] is not None and body.shown >= policy["ads.session_cap"]:
            reasons.append("Session cap")
        if body.rewarded_elapsed is not None and body.rewarded_elapsed < policy["ads.rewarded_cooldown_seconds"]:
            reasons.append("Rewarded-ad cooldown")
        result["ad_decision"] = {"due": due, "eligible": not reasons, "reasons": reasons,
            "remaining_checks": "Native provider availability, fresh emergency permission and the exact visible result are checked on the client."}
        result["last_reported"] = None
        if person:
            observation = db.get(GameConfigDelivery, person.id)
            if observation:
                result["last_reported"] = {k: getattr(observation, k) for k in ("generation", "status", "observed_at", "platform", "build_id", "applied_groups")}
            # Preview does not materialize game balances or assignment rows.
            db.add(AdminAudit(command_id=str(uuid4()), actor=actor(role), action="config_player_preview", entity_id=person.id,
                reason="Inspect effective noncanonical configuration", before={}, after={"generation": result["generation"]},
                request_hash=digest({"player": person.id, "generation": result["generation"]}), request_id=request.state.request_id))
            db.commit()
        return result


def activate_schedules(factory, at=None):
    at = now() if at is None else at
    with factory() as db:
        begin(db, LOCK)
        # The restricted worker can activate existing schedules, not create
        # administrator-owned control records before the first owner command.
        ctrl = db.get(GameConfigControl, 1)
        if ctrl is None:
            return 0
        rows = db.scalars(select(GameConfigRelease).where(GameConfigRelease.state == "scheduled",
            GameConfigRelease.scheduled_at <= at).order_by(GameConfigRelease.scheduled_at, GameConfigRelease.generation).limit(8)).all()
        for row in rows:
            valid = row.base_generation == ctrl.active_generation
            try:
                validate_settings(row.policy)
                validate_audiences(row.audiences)
                check_experiments(db, row.policy, row.audiences)
            except HTTPException:
                valid = False
            row.state = "active" if valid else "blocked"
            if valid:
                previous = current(db)
                if previous is not None:
                    previous.state = "superseded"
                ctrl.active_generation = row.generation
            ctrl.revision += 1
            db.add(AdminAudit(command_id=str(uuid5(NAMESPACE_URL, "bmt-config-schedule:" + str(row.generation))),
                actor="scheduler", action="config_schedule", entity_id=str(row.generation), reason="Scheduled policy activation revalidation",
                before={"base_generation": row.base_generation}, after={"state": row.state, "generation": row.generation},
                request_hash=digest({"generation": row.generation}), request_id=str(uuid4())))
        db.commit()
        return len(rows)
