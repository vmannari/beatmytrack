"""Stable assignment and actual exposure; presentation settings never race rules."""

import math
import secrets
from statistics import NormalDist
from uuid import UUID

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import func, select

from .admin import Access
from .admin_models import AdminAudit
from .middleware import ParsedJSONRoute
from .studio_access import actor
from .studio_cases import begin, owner, safe_text
from .studio_platform_models import AnalysisDay, AnalysisState, StudioAssignment, StudioExperiment
from .studio_queries import read_snapshot
from .telemetry_models import ProductState
from .track_models import digest, now
from .tracks import DB, Auth

router = APIRouter(route_class=ParsedJSONRoute, tags=["Studio experiments"])
public_router = APIRouter(route_class=ParsedJSONRoute, tags=["Studio experiments"])
REGISTRY = {
    "onboarding_message": {"kind": "text", "maximum": 160},
    "offer_layout": {"kind": "enum", "values": ["standard", "compact", "expanded"]},
    "store_order": {"kind": "products", "maximum": 5},
}


def validate_variants(variants, allocation):
    import re

    from .commerce import CATALOG
    from .game_config_policy import REGISTRY as CONFIG_REGISTRY
    from .game_config_policy import validate_settings

    if not 2 <= len(variants) <= 4 or set(variants) != set(allocation):
        raise HTTPException(422, "REQUIRE_2_TO_4_VARIANTS")
    if any(not re.fullmatch(r"[a-z][a-z0-9_-]{0,23}", key) for key in variants):
        raise HTTPException(422, "INVALID_VARIANT_ID")
    if any(type(v) is not int or v < 1 for v in allocation.values()) or sum(allocation.values()) != 10000:
        raise HTTPException(422, "ALLOCATION_MUST_TOTAL_10000")
    for settings in variants.values():
        if not isinstance(settings, dict) or not settings or not set(settings) <= set(REGISTRY) | set(CONFIG_REGISTRY):
            raise HTTPException(422, "NONCANONICAL_SETTINGS_ONLY")
        validate_settings({k: v for k, v in settings.items() if k in CONFIG_REGISTRY and k != "store_order"}, partial=True, experimental=True)
        for key, value in settings.items():
            if key == "onboarding_message" and (not isinstance(value, str) or not 1 <= len(value) <= 160):
                raise HTTPException(422, "INVALID_PRESENTATION_SETTING")
            if key == "offer_layout" and value not in REGISTRY[key]["values"]:
                raise HTTPException(422, "INVALID_PRESENTATION_SETTING")
            if key == "store_order" and (
                not isinstance(value, list)
                or not 1 <= len(value) <= 5
                or any(not isinstance(v, str) or v not in CATALOG for v in value)
                or len(set(value)) != len(value)
            ):
                raise HTTPException(422, "INVALID_PRESENTATION_SETTING")


def assignment(experiment, player):
    slot = int(digest({"salt": experiment.salt, "player": player})[:16], 16) % 10000
    upto = 0
    for variant, weight in sorted(experiment.allocation.items()):
        upto += weight
        if slot < upto:
            return variant
    raise RuntimeError("INVALID_EXPERIMENT_ALLOCATION")


def srm(counts, allocation):
    total = sum(counts.values())
    if not total:
        return {"p_value": None, "failed": None, "statistic": None}
    expected = {k: total * w / 10000 for k, w in allocation.items()}
    if min(expected.values()) < 5:
        return {"p_value": None, "failed": None, "statistic": None}
    chi = sum((counts.get(k, 0) - expected[k]) ** 2 / expected[k] for k in expected)
    x = chi / 2
    df = len(expected) - 1
    p = (
        math.erfc(math.sqrt(x))
        if df == 1
        else math.exp(-x)
        if df == 2
        else math.erfc(math.sqrt(x)) + 2 * math.sqrt(x / math.pi) * math.exp(-x)
    )
    return {"p_value": p, "failed": p < 0.001, "statistic": chi}


def value(row):
    return {
        k: getattr(row, k)
        for k in (
            "id",
            "name",
            "state",
            "revision",
            "primary_metric",
            "followup_days",
            "minimum_per_variant",
            "allocation",
            "variants",
            "configuration",
            "created_at",
            "started_at",
            "stopped_at",
            "actor",
        )
    }


class Experiment(BaseModel):
    model_config = ConfigDict(extra="forbid")
    command_id: UUID
    name: str = Field(min_length=3, max_length=100)
    reason: str = Field(min_length=3, max_length=500)
    primary_metric: str = Field(default="return_on_target_day", pattern="^return_on_target_day$")
    followup_days: int = Field(default=7, ge=1, le=30)
    minimum_per_variant: int = Field(default=500, ge=100, le=100000)
    allocation: dict[str, int]
    variants: dict[str, dict]
    configuration: dict = Field(default_factory=dict)


@router.get("/v1/admin/experiments")
def listing(request: Request, role: Access):
    with request.app.state.session_factory() as db:
        read_snapshot(db)
        rows = db.scalars(
            select(StudioExperiment)
            .order_by(StudioExperiment.created_at.desc(), StudioExperiment.id)
            .limit(101)
        ).all()
        return {
            "role": role,
            "registry": REGISTRY,
            "items": [value(r) for r in rows[:100]],
            "truncated": len(rows) > 100,
            "scope": "Signed-in explicit exposures; assignments alone are excluded. No client implementation is assumed from an active registry entry. No automatic winner or rollout.",
        }


@router.post("/v1/admin/experiments")
def create(body: Experiment, request: Request, role: Access):
    owner(role)
    validate_variants(body.variants, body.allocation)
    identity = str(body.command_id)
    fingerprint = digest(body.model_dump(mode="json"))
    with request.app.state.session_factory() as db:
        begin(db, str(UUID(digest({"control": "experiments"})[:32])))
        old = db.scalar(select(AdminAudit).where(AdminAudit.command_id == identity))
        if old:
            if old.request_hash != fingerprint:
                raise HTTPException(409, "COMMAND_ID_CONFLICT")
            return value(db.get(StudioExperiment, old.entity_id))
        configuration = {}
        if body.configuration:
            from .game_config import control, current, release_value
            from .game_config_policy import REGISTRY as CONFIG_REGISTRY
            from .game_config_policy import validate_conditions, validate_settings

            meta = body.configuration
            if not set(meta) <= {"hypothesis", "audience", "enrollment", "layer", "control", "baseline_generation"}:
                raise HTTPException(422, "INVALID_EXPERIMENT_CONFIGURATION")
            if not isinstance(meta.get("hypothesis", body.name), str) or not isinstance(meta.get("control", "control"), str):
                raise HTTPException(422, "INVALID_EXPERIMENT_CONFIGURATION")
            layer = meta.get("layer", "ads")
            keys = set().union(*(set(v) for v in body.variants.values()))
            if not keys <= set(CONFIG_REGISTRY) or layer not in ("ads", "presentation"):
                raise HTTPException(422, "UNSUPPORTED_EXPERIMENT_KEYS")
            for settings in body.variants.values():
                validate_settings(settings, partial=True, experimental=True)
            if any((key.startswith("ads.")) != (layer == "ads") for key in keys):
                raise HTTPException(422, "EXPERIMENT_LAYER_MISMATCH")
            enrollment = meta.get("enrollment", 10000)
            if type(enrollment) is not int or not 1 <= enrollment <= 10000:
                raise HTTPException(422, "INVALID_EXPERIMENT_ENROLLMENT")
            if meta.get("baseline_generation") != control(db).active_generation:
                raise HTTPException(409, "CONFIG_BASE_GENERATION_CHANGED")
            baseline = release_value(current(db))
            if baseline["rollout"] < 10000 or any(set(a["settings"]) & keys for a in baseline["audiences"]):
                raise HTTPException(409, "EXPERIMENT_REQUIRES_STABLE_BASELINE")
            control_variant = meta.get("control", "control")
            if control_variant not in body.variants:
                raise HTTPException(422, "CONTROL_VARIANT_REQUIRED")
            protected = [k for k in CONFIG_REGISTRY if k.startswith("ads.")] if layer == "ads" else sorted(keys)
            boundaries = {CONFIG_REGISTRY[k]["boundary"] for k in keys}
            if len(boundaries) != 1:
                raise HTTPException(422, "EXPERIMENT_REQUIRES_ONE_EXPOSURE_BOUNDARY")
            configuration = {"hypothesis": safe_text(meta.get("hypothesis", body.name), 500),
                "audience": validate_conditions(meta.get("audience", {})), "enrollment": enrollment, "layer": layer,
                "control": control_variant, "baseline_generation": baseline["generation"], "baseline_policy": baseline["policy"],
                "protected_keys": protected, "boundary": next(iter(boundaries)), "capabilities": sorted({CONFIG_REGISTRY[k]["capability"] for k in keys})}
        elif any(key.startswith(("ads.", "features.", "notice.")) for v in body.variants.values() for key in v):
            raise HTTPException(422, "CONFIG_EXPERIMENT_CONTEXT_REQUIRED")
        row = StudioExperiment(
            id=identity,
            name=safe_text(body.name, 100),
            primary_metric=body.primary_metric,
            followup_days=body.followup_days,
            minimum_per_variant=body.minimum_per_variant,
            allocation=body.allocation,
            variants=body.variants,
            configuration=configuration,
            salt=secrets.token_hex(32),
            actor=actor(role),
            state="draft",
            revision=0,
        )
        db.add(row)
        db.flush()
        db.add(
            AdminAudit(
                command_id=identity,
                actor=actor(role),
                action="experiment_create",
                entity_id=row.id,
                reason=safe_text(body.reason, 500),
                before={},
                after=value(row),
                request_hash=fingerprint,
                request_id=request.state.request_id,
            )
        )
        db.commit()
        return value(row)


class Transition(BaseModel):
    model_config = ConfigDict(extra="forbid")
    command_id: UUID
    expected_revision: int = Field(ge=0)
    state: str = Field(pattern="^(active|paused|stopped)$")
    reason: str = Field(min_length=3, max_length=500)


class Promotion(BaseModel):
    model_config = ConfigDict(extra="forbid")
    command_id: UUID
    expected_revision: int = Field(ge=0)
    reason: str = Field(min_length=3, max_length=500)
    variant: str = Field(min_length=1, max_length=24)


@router.post("/v1/admin/experiments/{identity}/promote")
def promote(identity: UUID, body: Promotion, request: Request, role: Access):
    from copy import deepcopy

    from .game_config import LOCK, audit, control, current, draft_value, release_value, replay
    from .game_config_models import GameConfigDraft

    owner(role)
    fingerprint = digest({"experiment": str(identity), **body.model_dump(mode="json")})
    with request.app.state.session_factory() as db:
        begin(db, LOCK)
        previous = replay(db, body.command_id, fingerprint)
        if previous is not None:
            return previous
        row = db.get(StudioExperiment, str(identity))
        if row is None or not row.configuration or body.variant not in row.variants:
            raise HTTPException(404, "CONFIGURATION_VARIANT_NOT_FOUND")
        if row.revision != body.expected_revision:
            raise HTTPException(409, "EXPERIMENT_REVISION_CHANGED")
        baseline = release_value(current(db))
        policy = deepcopy(baseline["policy"])
        for key in row.configuration["protected_keys"]:
            policy[key] = deepcopy(row.configuration["baseline_policy"][key])
        policy.update(deepcopy(row.variants[body.variant]))
        if row.state == "active":
            row.state = "paused"
        row.revision += 1
        ctrl = control(db, True)
        ctrl.revision += 1
        draft = GameConfigDraft(id=str(body.command_id), name=(row.name + ": " + body.variant)[:100],
            revision=0, base_generation=ctrl.active_generation, policy=policy, audiences=deepcopy(baseline["audiences"]))
        db.add(draft)
        db.flush()
        return audit(db, request, role, body.command_id, fingerprint, "experiment_promote", row.id,
            body.reason, {"variant": body.variant}, draft_value(draft))


@router.post("/v1/admin/experiments/{identity}/state")
def transition(identity: UUID, body: Transition, request: Request, role: Access):
    owner(role)
    fingerprint = digest({"id": str(identity), **body.model_dump(mode="json")})
    with request.app.state.session_factory() as db:
        begin(db, str(UUID(digest({"control": "experiments"})[:32])))
        old = db.scalar(select(AdminAudit).where(AdminAudit.command_id == str(body.command_id)))
        if old:
            if old.request_hash != fingerprint:
                raise HTTPException(409, "COMMAND_ID_CONFLICT")
            return value(db.get(StudioExperiment, str(identity)))
        row = db.scalar(
            select(StudioExperiment).where(StudioExperiment.id == str(identity)).with_for_update()
        )
        if not row:
            raise HTTPException(404, "EXPERIMENT_NOT_FOUND")
        if row.revision != body.expected_revision:
            raise HTTPException(409, "EXPERIMENT_REVISION_CHANGED")
        if row.state == "stopped" or row.state == body.state:
            raise HTTPException(409, "INVALID_EXPERIMENT_TRANSITION")
        if row.state == "draft" and body.state == "paused":
            raise HTTPException(409, "INVALID_EXPERIMENT_TRANSITION")
        if body.state == "active":
            layer = (row.configuration or {}).get("layer", "presentation")
            active = db.scalars(select(StudioExperiment).where(StudioExperiment.state == "active").limit(16)).all()
            if any((r.configuration or {}).get("layer", "presentation") == layer for r in active):
                raise HTTPException(409, "ONE_ACTIVE_EXPERIMENT_AT_A_TIME")
            if row.configuration:
                from .game_config import control, current, release_value
                meta = row.configuration
                baseline = release_value(current(db))
                if not request.app.state.settings.telemetry_enabled:
                    raise HTTPException(409, "EXPOSURE_AND_PRIMARY_METRIC_FEED_REQUIRED")
                if baseline["rollout"] < 10000 or any(baseline["policy"][k] != meta["baseline_policy"][k] for k in meta["protected_keys"]):
                    raise HTTPException(409, "EXPERIMENT_BASELINE_CHANGED")
                if any(set(a["settings"]) & set(meta["protected_keys"]) for a in baseline["audiences"]):
                    raise HTTPException(409, "EXPERIMENT_AUDIENCE_CONFLICT")
        before = value(row)
        row.state, row.revision = body.state, row.revision + 1
        if row.state == "active" and row.started_at is None:
            row.started_at = now()
        if row.state == "stopped":
            row.stopped_at = now()
        if row.configuration:
            from .game_config import control
            control(db, True).revision += 1
        db.add(
            AdminAudit(
                command_id=str(body.command_id),
                actor=actor(role),
                action="experiment_state",
                entity_id=row.id,
                reason=safe_text(body.reason, 500),
                before=before,
                after=value(row),
                request_hash=fingerprint,
                request_id=request.state.request_id,
            )
        )
        db.commit()
        return value(row)


@public_router.post("/v1/experiments/assignments")
def assignments(player: Auth, session: DB, request: Request, platform: str = "android", build_id: str = "unknown", capabilities: str = "", experiments_enabled: bool = True):
    player = locked_analysis_player(session, player.id)
    if not player.analytics_enabled:
        return {"items": [], "reason": "ANALYTICS_CONSENT_REQUIRED"}
    # Player owns all competing assignment writers.

    rows = session.scalars(
        select(StudioExperiment)
        .where(StudioExperiment.state == "active")
        .order_by(StudioExperiment.id)
        .limit(16)
    ).all()
    result = []
    for row in rows:
        if row.configuration:
            if not experiments_enabled or not request.app.state.settings.telemetry_enabled:
                continue
            from .game_config import player_context
            from .game_config_policy import bucket, matches
            context = player_context(session, request.app.state.settings, player,
                {"platform": platform, "build_id": build_id, "capabilities": capabilities.split(",")})
            meta = row.configuration
            if (not matches(meta["audience"], context) or not set(meta["capabilities"]) <= set(context["capabilities"])
                or bucket(player.id, row.salt + ":enrollment") >= meta["enrollment"]):
                continue
        bound = session.get(StudioAssignment, (row.id, player.id))
        if bound is None:
            bound = StudioAssignment(
                experiment_id=row.id,
                player_id=player.id,
                variant=assignment(row, player.id),
                revision=row.revision,
            )
            session.add(bound)
        result.append(
            {
                "experiment_id": row.id,
                "variant": bound.variant,
                "revision": bound.revision,
                "settings": row.variants[bound.variant],
                "layer": (row.configuration or {}).get("layer", "presentation"),
            }
        )
    session.commit()
    return {"items": result, "exposure_required": True}


class Exposure(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    event_id: str = Field(min_length=36, max_length=36)
    variant: str = Field(max_length=24)
    revision: int = Field(ge=0)


@public_router.post("/v1/experiments/{identity}/exposures")
def expose(identity: UUID, body: Exposure, player: Auth, session: DB):
    try:
        event_id = str(UUID(body.event_id))
    except ValueError:
        raise HTTPException(422, "INVALID_EXPOSURE_ID") from None
    player = locked_analysis_player(session, player.id)
    if not player.analytics_enabled:
        raise HTTPException(409, "ANALYTICS_CONSENT_REQUIRED")
    row = session.scalar(
        select(StudioExperiment).where(StudioExperiment.id == str(identity)).with_for_update()
    )
    if not row or row.state != "active":
        raise HTTPException(409, "EXPERIMENT_NOT_ACTIVE")
    bound = session.get(StudioAssignment, (row.id, player.id))
    if not bound or (bound.variant, bound.revision) != (body.variant, body.revision):
        raise HTTPException(409, "EXPOSURE_ASSIGNMENT_MISMATCH")
    if bound.exposed_at is None:
        bound.exposed_at, bound.exposure_id = now(), event_id
    session.commit()
    return {"exposed_at": bound.exposed_at}


def locked_analysis_player(session, identity):
    from sqlalchemy import update

    from .identity_models import Player

    if session.bind.dialect.name == "sqlite":
        session.execute(update(Player).where(Player.id == identity).values(id=Player.id))
    row = session.scalar(
        select(Player)
        .where(Player.id == identity)
        .with_for_update()
        .execution_options(populate_existing=True)
    )
    if row is None or row.disabled or row.deleted_at is not None:
        raise HTTPException(401, "INVALID_SESSION")
    return row


@router.get("/v1/admin/experiments/{identity}/scorecard")
def scorecard(identity: UUID, request: Request, role: Access):
    with request.app.state.session_factory() as db:
        read_snapshot(db)
        row = db.get(StudioExperiment, str(identity))
        if not row:
            raise HTTPException(404, "EXPERIMENT_NOT_FOUND")
        state = db.get(AnalysisState, 1)
        watermark = state.processed_through or 0
        exposed = dict(
            db.execute(
                select(StudioAssignment.variant, func.count())
                .where(StudioAssignment.experiment_id == row.id, StudioAssignment.exposed_at.is_not(None))
                .group_by(StudioAssignment.variant)
            ).all()
        )
        eligible = [
            StudioAssignment.experiment_id == row.id,
            StudioAssignment.exposed_at.is_not(None),
            (func.floor(StudioAssignment.exposed_at / 86400) + row.followup_days + 1) * 86400
            <= min(now(), watermark),
        ]
        product = db.get(ProductState, 1)
        retained_floor = max(
            now() // 86400 - (product.fact_days if product else 180),
            (product.retained_from_day or 0) if product else 0,
        )
        expired = db.scalar(
            select(func.count())
            .select_from(StudioAssignment)
            .where(
                *eligible,
                func.floor(StudioAssignment.exposed_at / 86400) + row.followup_days < retained_floor,
            )
        )
        mature = dict(
            db.execute(
                select(StudioAssignment.variant, func.count())
                .where(*eligible)
                .group_by(StudioAssignment.variant)
            ).all()
        )
        returned = dict(
            db.execute(
                select(StudioAssignment.variant, func.count(func.distinct(StudioAssignment.player_id)))
                .join(
                    AnalysisDay,
                    (AnalysisDay.player_id == StudioAssignment.player_id)
                    & (
                        AnalysisDay.day == func.floor(StudioAssignment.exposed_at / 86400) + row.followup_days
                    ),
                )
                .where(*eligible, AnalysisDay.counters["active"].as_integer() > 0)
                .group_by(StudioAssignment.variant)
            ).all()
        )
        check = srm(exposed, row.allocation)
        enough = not expired and all(mature.get(v, 0) >= row.minimum_per_variant for v in row.variants)
        assigned = dict(db.execute(select(StudioAssignment.variant, func.count()).where(
            StudioAssignment.experiment_id == row.id).group_by(StudioAssignment.variant)).all())
        metrics = {}
        for variant, shown, suppressed, unavailable, errors in db.execute(select(StudioAssignment.variant,
            *[func.sum(func.coalesce(StudioAssignment.observed_counters[key].as_integer(), 0))
                for key in ("shown", "suppressed", "unavailable", "error")]).where(
                    StudioAssignment.experiment_id == row.id).group_by(StudioAssignment.variant)):
            metrics[variant] = {"shown": shown, "suppressed": suppressed, "unavailable": unavailable, "errors": errors}
        control_variant = (row.configuration or {}).get("control", "control")
        if control_variant not in row.variants:
            control_variant = min(row.variants)
        control_n = mature.get(control_variant, 0)
        control_rate = returned.get(control_variant, 0) / control_n if control_n and not expired else None
        z = NormalDist().inv_cdf(1 - 0.05 / (2 * max(1, len(row.variants) - 1)))

        def comparison(variant):
            n = mature.get(variant, 0)
            rate = returned.get(variant, 0) / n if n and not expired else None
            if rate is None:
                return {"rate": None, "absolute_difference": None, "relative_difference": None, "interval": None}
            denominator = 1 + z * z / n
            center = (rate + z * z / (2 * n)) / denominator
            radius = z * math.sqrt(rate * (1 - rate) / n + z * z / (4 * n * n)) / denominator
            return {"rate": rate, "absolute_difference": rate - control_rate if control_rate is not None else None,
                "relative_difference": (rate / control_rate - 1) if control_rate else None,
                "interval": [max(0, center - radius), min(1, center + radius)]}
        return {
            "role": role,
            "experiment": value(row),
            "sample_ratio": check,
            "assignment_ratio": srm(assigned, row.allocation),
            "control_variant": control_variant,
            "uncertainty_method": "Wilson return-rate intervals; family-wise 95% Bonferroni adjustment. Fixed-horizon manual decision only.",
            "enough_mature_players": enough,
            "expired_followups": expired,
            "variants": [
                {
                    "id": v,
                    "assigned": assigned.get(v, 0),
                    "ad_observations": metrics.get(v, {"shown": 0, "suppressed": 0, "unavailable": 0, "errors": 0}),
                    "exposed": exposed.get(v, 0),
                    "eligible": mature.get(v, 0),
                    "returned": returned.get(v, 0) if not expired else None,
                    **comparison(v),
                }
                for v in sorted(row.variants)
            ],
            "winner": None,
            "decision": (
                "Hold: some follow-up facts have expired; complete historical return rates are unavailable."
                if expired
                else "Hold: validate actual client exposures, A/A behaviour, guardrail coverage and fixed-horizon results before a manual decision."
            ),
            "guardrails": {
                "crash_free_players": "unavailable",
                "verified_revenue": "unavailable",
                "canonical_changes": "forbidden",
            },
            "processed_through": watermark,
            "late_arrivals": "Returns can restate for seven additional days",
        }
