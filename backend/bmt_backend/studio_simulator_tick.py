"""Refresh an existing development population with a short, deduplicated live tick."""

import argparse
import json

from sqlalchemy import select

from .config import Settings
from .db import make_engine, make_session_factory
from .identity_models import Player
from .studio_incidents import Observation, record
from .studio_platform_models import StudioObservation
from .studio_simulator import BUILDS, DEVICES, Plan, Simulator, identity, network_package
from .telemetry import insert_for, properties
from .telemetry_models import ProductEvent
from .track_models import OperationState, digest, now


def tick(factory, settings, dataset, *, at=None):
    if settings.environment not in ("development", "test"):
        raise ValueError("Studio simulator is restricted to development/test environments")
    at = now() if at is None else at
    if at > now() or at < now() - 3600:
        raise ValueError("Live ticks must use the current hour")
    bucket = at // 300 * 300
    key = "studio-simulator:" + dataset
    with factory() as db:
        journal = db.get(OperationState, key)
        if not journal or not journal.details.get("workspaces_done"):
            raise ValueError("Complete the historical dataset before running live ticks")
        plan = Plan(**journal.details["plan"]).validate()
        people = [plan.person(i) for i in range(plan.players)]
        permitted = set(
            db.scalars(
                select(Player.id).where(
                    Player.id.in_([p["id"] for p in people]),
                    Player.analytics_enabled.is_(True),
                    Player.disabled.is_(False),
                    Player.deleted_at.is_(None),
                    Player.is_test_driver.is_(False),
                )
            )
        )
        people = sorted(
            (p for p in people if p["kind"] != "tourist" and p["id"] in permitted),
            key=lambda p: digest({"bucket": bucket, "player": p["id"]}),
        )[:24]
        events = []
        for person in people:
            device = DEVICES[person["device"]]
            session = identity(dataset, "live-session", bucket, person["id"])
            observations = [
                ("session_started", {"reason": "resume"}, bucket - 65),
                ("menu_ready", {}, bucket - 64),
                ("network_summary", network_package(device, "discovery", False), bucket - 10),
                ("session_heartbeat", {"foreground_ms": 60000}, bucket - 1),
            ]
            for seq, (name, values, occurred) in enumerate(observations):
                reference = identity(dataset, "live-event", bucket, person["id"], seq)
                row = {
                    "id": reference,
                    "client_id": reference,
                    "entity_id": None,
                    "player_id": person["id"],
                    "is_test_driver": False,
                    "source": "client",
                    "name": name,
                    "occurred_at": occurred,
                    "received_at": at,
                    "session_id": session,
                    "install_id": identity(dataset, person["id"], "install"),
                    "seq": seq,
                    "monotonic_ms": (occurred - bucket + 65) * 1000,
                    "build_id": BUILDS[2],
                    "platform": device[0],
                    "clock_quality": "server_estimate",
                    "properties": properties(name, values),
                    "processed_at": None,
                    "compacted": False,
                }
                row["payload_hash"] = digest({k: v for k, v in row.items() if k != "received_at"})
                events.append(row)
        inserted = (
            db.execute(
                insert_for(db, ProductEvent)
                .values(events)
                .on_conflict_do_nothing(index_elements=["id"])
                .returning(ProductEvent.id)
            )
            .scalars()
            .all()
            if events
            else []
        )
        from .telemetry_queue import register_ids
        register_ids(db, inserted)
        source = journal.details.get("monitor_source")
        db.commit()
    if source:
        with factory() as db:
            latest = db.scalar(
                select(StudioObservation)
                .where(StudioObservation.source == source)
                .order_by(StudioObservation.observed_at.desc())
                .limit(1)
            )
            body = (
                {**latest.values, "id": identity(dataset, "live-monitor", at), "observed_at": at}
                if latest
                else None
            )
        if body:
            for signal in body["signals"]:
                if signal["key"] == "frame_pacing":
                    signal["target"] = "quality?build_id=0.59.1&baseline=0.59.0"
                elif signal["key"] == "store_delivery":
                    signal["target"] = "economy?tab=delivery"
            with factory() as db:
                record(db, settings, source, Observation(**body), notify=False)
    Simulator(factory, settings, plan).project()
    return {
        "dataset": dataset,
        "bucket": bucket,
        "inserted_events": len(inserted),
        "selected_players": len(people),
        "duplicates": len(events) - len(inserted),
        "external_calls": 0,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dataset", default="studio-october")
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    settings = Settings.from_env()
    if settings.environment not in ("development", "test"):
        parser.error("Development/test environment required")
    if not args.apply:
        print(json.dumps({"dataset": args.dataset, "apply": False, "interval_seconds": 300}))
        return
    engine = make_engine(settings.database_url, settings)
    try:
        print(
            "STUDIO_SIMULATOR_TICK=" + json.dumps(tick(make_session_factory(engine), settings, args.dataset))
        )
    finally:
        engine.dispose()


if __name__ == "__main__":
    main()
