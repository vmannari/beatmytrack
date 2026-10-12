"""Automatic development fields, driven through ordinary authenticated race APIs.

No score is written here. The idle verifier worker records one real drive at a
time, uploads it, and gives normal player verification jobs priority. Reboots
recover the same memberships and upload keys; older build/week data is retained.
"""
from __future__ import annotations

import logging
import time
import uuid
from pathlib import Path

from sqlalchemy import select, update

from .background_work import BackgroundControl, BackgroundYielded
from .countries import test_country
from .identity_models import Identity, Player
from .rivalry_models import RivalryGroup, RivalryMember
from .test_driver_models import TestDriverProfile
from .track_models import Board, digest, now

logger = logging.getLogger("bmt.test_drivers")
TARGET = 14


def enroll(session, group_id):
    """Reserve a bounded persistent field inside the human join transaction."""
    from .test_drivers import profile

    group = session.scalar(select(RivalryGroup).where(RivalryGroup.id == group_id).with_for_update())
    if not group.test_population or group.ends_at <= now():
        return
    group.tracks = [{**slot, "automatic_test_drivers": True} for slot in group.tracks]
    seed = int(digest({"automatic_group": group.id})[:8], 16) & 0x7FFFFFFF
    for ordinal in range(TARGET - 1):
        if group.member_count >= TARGET:
            break
        subject = f"bmt-test-auto-{group.id}-{ordinal}"
        driver = session.scalar(select(TestDriverProfile).where(TestDriverProfile.subject == subject))
        if driver is None:
            _, name, traits = profile(seed, ordinal, TARGET - 1, 0.42, 0.58)
            player = Player(id=str(uuid.uuid5(uuid.NAMESPACE_URL, subject)),
                            display_name=name.split(" T")[0]+" #"+group.id.replace("-", "")[:20]+str(ordinal), is_test_driver=True)
            player.country_code = test_country(player.id)
            session.add(player)
            session.flush()
            session.add(Identity(player_id=player.id, provider="development", subject=subject))
            driver = TestDriverProfile(player_id=player.id, fleet="auto-" + group.id,
                                       ordinal=ordinal, subject=subject, traits=traits)
            session.add(driver)
            session.flush()
        if session.get(RivalryMember, (group.id, driver.player_id)) is not None:
            continue
        reserved = session.execute(update(RivalryGroup).where(
            RivalryGroup.id == group.id, RivalryGroup.member_count < TARGET
        ).values(member_count=RivalryGroup.member_count + 1)).rowcount
        if reserved:
            session.add(RivalryMember(group_id=group.id, player_id=driver.player_id,
                                     week_start=group.week_start, contract_key=group.contract_key, skill=None))
            session.flush()
            session.refresh(group)


def plan_for(app, group_id, api):
    from .rivalry import snapshot
    from .test_population_tool import SCHEMA, add_jobs

    with app.state.session_factory() as session:
        group = session.get(RivalryGroup, group_id)
        profiles = [{"player_id": player.id, "subject": driver.subject,
                     "display_name": player.display_name, "is_test_driver": True, "traits": driver.traits}
                    for driver, player in session.execute(select(TestDriverProfile, Player).join(Player).join(
                        RivalryMember, RivalryMember.player_id == Player.id
                    ).where(RivalryMember.group_id == group.id, Player.disabled.is_(False)).order_by(
                        TestDriverProfile.subject)).all()]
        if not profiles:
            return None
        field = snapshot(session, group, profiles[0]["player_id"])
        board = session.get(Board,
                            group.tracks[0]["board_id"])
        manifest = app.state.verifier.manifest()
        from .runs import PINNED_FIELDS
        if any(board.manifest.get(field) != manifest.get(field) for field in PINNED_FIELDS):
            return None
        vehicle = manifest.get("vehicles", {}).get(group.vehicle_id, {})
        if board.manifest.get("config_hash") != vehicle.get("config_hash"):
            return None
        plan = {"schema": SCHEMA, "api": api.url, "fleet": "auto-" + group.id,
                "profiles": profiles, "vehicle_id": group.vehicle_id, "mode": "automatic",
                "week_start": group.week_start, "ends_at": group.ends_at,
                "server_now": group.created_at, "manifest": manifest, "jobs": [],
                "joined": [], "pace_scales": {}, "instant": True}
        for driver in profiles:
            add_jobs(plan, driver, [track["entry"] for track in field["tracks"]], group.id, instant=True)
        return plan


def drive_idle(app):
    """One bounded attempt when no normal verification or track work is waiting."""
    settings = app.state.settings
    if not (settings.environment == "development" and settings.test_drivers_enabled
            and settings.dev_auth_enabled and settings.godot_bin):
        return False
    if time.monotonic() < getattr(app.state, "next_automatic_drive", 0):
        return False
    app.state.next_automatic_drive = time.monotonic() + 3
    from .test_driver_generator import generate
    from .test_population_tool import API, acquire_plan_lock, atomic_save, load_plan, tick
    from .worker_lifecycle import stopping

    with app.state.session_factory() as session:
        groups = session.scalars(select(RivalryGroup.id).where(
            RivalryGroup.test_population.is_(True), RivalryGroup.ends_at > now(),
            RivalryGroup.tracks[0]["automatic_test_drivers"].as_boolean().is_(True)
        ).order_by(RivalryGroup.created_at).limit(100)).all()
    if not groups or stopping(app):
        return False
    api = getattr(app.state, "automatic_driver_api", None)
    if api is None:
        api = app.state.automatic_driver_api = API(
            settings.test_driver_api_url or settings.public_base_url, settings.dev_auth_key, internal=True)
    folder = Path(settings.object_dir).parent / "automatic-test-drivers"
    cursor = getattr(app.state, "automatic_driver_cursor", 0) % len(groups)
    app.state.automatic_driver_cursor = cursor + 1
    group_id = groups[cursor]
    path = folder / (group_id + ".json")
    try:
        with acquire_plan_lock(path):
            plan = load_plan(path, api) if path.exists() else plan_for(app, group_id, api)
            if plan is None:
                return False
            atomic_save(path, plan)
            if not any(job["status"] == "submitted" or job["status"] == "waiting" and job["due"] <= now()
                       for job in plan["jobs"]):
                return False
            # Generation observes the same cooperative shutdown event as the
            # verifier, then uploads ordinary input data for later verification.
            def generator(*args, **kwargs):
                if stopping(app):
                    raise RuntimeError("Test driver worker is draining")
                return generate(*args, **kwargs, stop_event=BackgroundControl(app))

            before = sum(job["status"] == "waiting" for job in plan["jobs"])
            tick(api, plan, settings, path, maximum=1, generator=generator)
            after = sum(job["status"] == "waiting" for job in plan["jobs"])
            return before != after
    except BackgroundYielded:
        return False
    except RuntimeError:
        if not stopping(app):
            logger.exception("automatic_test_driver_pass_failed", extra={"group_id": group_id})
        return False
