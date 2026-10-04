"""Development operator tools. These routes create identities, never race results."""

from __future__ import annotations

import hashlib
import random
import secrets
import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select, update
from sqlalchemy.exc import IntegrityError

from .identity_models import Identity, Player
from .middleware import ParsedJSONRoute
from .rivalry import GROUP_CAPACITY, active_contract, eligible_versions, require_member, snapshot
from .rivalry_models import RivalryGroup, RivalryMember
from .test_driver_models import TestDriverProfile
from .test_population import require_enabled
from .track_models import Track, now
from .tracks import DB, Auth, track_payload

router = APIRouter(route_class=ParsedJSONRoute, include_in_schema=False)
PROFILE_VERSION = "test-driver-1"
THEMES = ("pine", "winter", "desert", "night_city", "storm")


def operator(request: Request, x_dev_auth_key: Annotated[str | None, Header()] = None):
    require_enabled(request)
    if x_dev_auth_key is None or not secrets.compare_digest(
        x_dev_auth_key.encode(), request.app.state.settings.dev_auth_key.encode()
    ):
        raise HTTPException(401, "INVALID_DEVELOPMENT_KEY")


Operator = Annotated[None, Depends(operator)]


@router.get("/dev/test-drivers/tracks")
def tracks(vehicle_id: str, request: Request, session: DB, _operator: Operator):
    active, _ = active_contract(request, vehicle_id)
    entries = []
    for version in eligible_versions(session, active, vehicle_id):
        track = session.get(Track, version.track_id)
        entries.append(
            track_payload(
                version,
                track,
                session.get(Player, track.owner_id).display_name,
                request.app.state.settings.public_base_url,
            )
        )
    return {"manifest": active, "server_now": now(), "tracks": entries}


class Fleet(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    seed: int = Field(ge=0, le=2147483647)
    count: int = Field(default=14, ge=1, le=200)
    skill_min: float = Field(default=0.0, ge=0.0, le=1.0)
    skill_max: float = Field(default=1.0, ge=0.0, le=1.0)


class Fill(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    group_id: str = Field(min_length=36, max_length=36)
    total_drivers: int = Field(default=14, ge=2, le=GROUP_CAPACITY)


def profile(seed, ordinal, count, minimum, maximum):
    identity = f"bmt-test-{seed}-{ordinal}"
    stable_seed = int(hashlib.sha256(identity.encode()).hexdigest()[:8], 16) & 0x7FFFFFFF
    rng = random.Random(stable_seed)
    skill = minimum + (maximum - minimum) * ((ordinal + rng.uniform(0.15, 0.85)) / count)
    first = ("Ari", "Nova", "Kai", "Remi", "Rin", "Eden", "Sol", "Kit", "Ash", "Lumi")
    last = ("Vale", "Reed", "Stone", "Rowan", "Lane", "Quinn", "Lake", "Hart", "Fox", "Wren")
    name = f"{rng.choice(first)} {rng.choice(last)} T{seed % 10000:04d}-{ordinal + 1:03d}"
    traits = {
        "version": PROFILE_VERSION,
        "seed": stable_seed,
        "skill": round(skill, 5),
        "consistency": round(rng.uniform(0.35, 0.95), 4),
        "aggression": round(rng.uniform(0.15, 0.85), 4),
        "activity": round(rng.uniform(0.25, 1.0), 4),
        "utc_hour": rng.randrange(24),
        "learning": round(rng.uniform(0.3, 1.0), 4),
        "strengths": {theme: round(rng.uniform(-0.07, 0.07), 4) for theme in THEMES},
    }
    return identity, name, traits


def fleet_rows(session, fleet):
    rows = session.execute(
        select(TestDriverProfile, Player)
        .join(Player)
        .where(TestDriverProfile.fleet == fleet)
        .order_by(TestDriverProfile.ordinal)
    ).all()
    return [
        {
            "player_id": p.id,
            "subject": profile.subject,
            "display_name": p.display_name,
            "is_test_driver": True,
            "traits": profile.traits,
        }
        for profile, p in rows
    ]


@router.post("/dev/test-drivers/fleets")
def create_fleet(payload: Fleet, request: Request, session: DB, _operator: Operator):
    if payload.skill_min > payload.skill_max:
        raise HTTPException(422, "Invalid skill range")
    fleet = f"test-fleet-{payload.seed}"
    for ordinal in range(payload.count):
        subject, name, traits = profile(
            payload.seed, ordinal, payload.count, payload.skill_min, payload.skill_max
        )
        existing = session.scalar(select(TestDriverProfile).where(TestDriverProfile.subject == subject))
        if existing:
            if existing.traits != traits:
                raise HTTPException(409, "FLEET_PARAMETERS_CHANGED: use a new seed")
            continue
        # A reserved subject cannot silently convert a real account into a bot.
        if session.scalar(
            select(Identity.id).where(Identity.provider == "development", Identity.subject == subject)
        ):
            raise HTTPException(409, "TEST_IDENTITY_ALREADY_USED")
        try:
            with session.begin_nested():
                p = Player(
                    id=str(uuid.uuid5(uuid.NAMESPACE_URL, subject)), display_name=name, is_test_driver=True
                )
                session.add(p)
                session.flush()
                session.add(Identity(player_id=p.id, provider="development", subject=subject))
                session.add(
                    TestDriverProfile(
                        player_id=p.id, fleet=fleet, ordinal=ordinal, subject=subject, traits=traits
                    )
                )
                session.flush()
        except IntegrityError:
            existing = session.scalar(select(TestDriverProfile).where(TestDriverProfile.subject == subject))
            if existing is None or existing.traits != traits:
                raise HTTPException(409, "TEST_PROFILE_CONFLICT") from None
    rows = fleet_rows(session, fleet)
    if len(rows) != payload.count:
        raise HTTPException(409, "FLEET_PARAMETERS_CHANGED: use a new seed")
    session.commit()
    return {"fleet": fleet, "profiles": rows}


@router.get("/dev/test-drivers/fleets/{fleet}")
def get_fleet(fleet: str, session: DB, _operator: Operator):
    return {"fleet": fleet, "profiles": fleet_rows(session, fleet)}


@router.post("/dev/test-drivers/fleets/{fleet}/fill")
def fill(fleet: str, payload: Fill, request: Request, session: DB, player: Auth, _operator: Operator):
    group, _ = require_member(session, payload.group_id, player.id, request)
    if not group.test_population:
        raise HTTPException(403, "Only test rivalries can be filled")
    profiles = session.scalars(
        select(TestDriverProfile)
        .join(Player)
        .where(TestDriverProfile.fleet == fleet, Player.disabled.is_(False))
        .order_by(TestDriverProfile.ordinal)
    ).all()
    # Normal joins lock player before group. Keep that same order here so
    # fixture fills and concurrent matcher joins cannot form a lock cycle.
    for item in profiles:
        session.scalar(select(Player).where(Player.id == item.player_id).with_for_update())
    group = session.scalar(select(RivalryGroup).where(RivalryGroup.id == group.id).with_for_update())
    if group.ends_at <= now():
        raise HTTPException(410, "RIVALRY_WEEK_ENDED")
    for item in profiles:
        if group.member_count >= payload.total_drivers:
            break
        existing = session.scalar(
            select(RivalryMember).where(
                RivalryMember.player_id == item.player_id,
                RivalryMember.week_start == group.week_start,
                RivalryMember.contract_key == group.contract_key,
            )
        )
        if existing:
            continue
        reserved = session.execute(
            update(RivalryGroup)
            .where(RivalryGroup.id == group.id, RivalryGroup.member_count < payload.total_drivers)
            .values(member_count=RivalryGroup.member_count + 1)
        ).rowcount
        if reserved:
            session.add(
                RivalryMember(
                    group_id=group.id,
                    player_id=item.player_id,
                    week_start=group.week_start,
                    contract_key=group.contract_key,
                    skill=None,
                )
            )
            session.flush()
            session.refresh(group)
    result = snapshot(session, group, player.id)
    session.commit()
    return result
