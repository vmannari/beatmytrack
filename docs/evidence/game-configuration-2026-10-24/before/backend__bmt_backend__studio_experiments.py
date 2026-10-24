"""Stable assignment and actual exposure; presentation settings never race rules."""

import math
import secrets
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
REGISTRY = {
    "onboarding_message": {"kind": "text", "maximum": 160},
    "offer_layout": {"kind": "enum", "values": ["standard", "compact", "expanded"]},
    "store_order": {"kind": "products", "maximum": 5},
}


def validate_variants(variants, allocation):
    import re

    from .commerce import CATALOG

    if not 2 <= len(variants) <= 4 or set(variants) != set(allocation):
        raise HTTPException(422, "REQUIRE_2_TO_4_VARIANTS")
    if any(not re.fullmatch(r"[a-z][a-z0-9_-]{0,23}", key) for key in variants):
        raise HTTPException(422, "INVALID_VARIANT_ID")
    if any(type(v) is not int or v < 1 for v in allocation.values()) or sum(allocation.values()) != 10000:
        raise HTTPException(422, "ALLOCATION_MUST_TOTAL_10000")
    for settings in variants.values():
        if not isinstance(settings, dict) or not settings or not set(settings) <= set(REGISTRY):
            raise HTTPException(422, "NONCANONICAL_SETTINGS_ONLY")
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
        begin(db, identity)
        old = db.scalar(select(AdminAudit).where(AdminAudit.command_id == identity))
        if old:
            if old.request_hash != fingerprint:
                raise HTTPException(409, "COMMAND_ID_CONFLICT")
            return value(db.get(StudioExperiment, old.entity_id))
        row = StudioExperiment(
            id=identity,
            name=safe_text(body.name, 100),
            primary_metric=body.primary_metric,
            followup_days=body.followup_days,
            minimum_per_variant=body.minimum_per_variant,
            allocation=body.allocation,
            variants=body.variants,
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
        if (
            body.state == "active"
            and db.scalar(
                select(func.count()).select_from(StudioExperiment).where(StudioExperiment.state == "active")
            )
            >= 1
        ):
            raise HTTPException(409, "ONE_ACTIVE_EXPERIMENT_AT_A_TIME")
        before = value(row)
        row.state, row.revision = body.state, row.revision + 1
        if row.state == "active" and row.started_at is None:
            row.started_at = now()
        if row.state == "stopped":
            row.stopped_at = now()
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


@router.post("/v1/experiments/assignments")
def assignments(player: Auth, session: DB):
    player = locked_analysis_player(session, player.id)
    if not player.analytics_enabled:
        return {"items": [], "reason": "ANALYTICS_CONSENT_REQUIRED"}
    # Player owns all competing assignment writers.

    rows = session.scalars(
        select(StudioExperiment)
        .where(StudioExperiment.state == "active")
        .order_by(StudioExperiment.id)
        .limit(1)
    ).all()
    result = []
    for row in rows:
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
            }
        )
    session.commit()
    return {"items": result, "exposure_required": True}


class Exposure(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    event_id: str = Field(min_length=36, max_length=36)
    variant: str = Field(max_length=24)
    revision: int = Field(ge=0)


@router.post("/v1/experiments/{identity}/exposures")
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
        return {
            "role": role,
            "experiment": value(row),
            "sample_ratio": check,
            "enough_mature_players": enough,
            "expired_followups": expired,
            "variants": [
                {
                    "id": v,
                    "exposed": exposed.get(v, 0),
                    "eligible": mature.get(v, 0),
                    "returned": returned.get(v, 0) if not expired else None,
                    "rate": returned.get(v, 0) / mature[v] if mature.get(v) and not expired else None,
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
