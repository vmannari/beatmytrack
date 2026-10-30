"""Match a pinned race to actual worker capability before spending an attempt."""
from sqlalchemy import and_, false, or_

FIELDS = ("engine_version", "verifier_version", "rules_key", "physics_version",
          "compiler_version", "track_schema", "replay_schema", "tick_rate")


def capability_matches(pinned, active):
    vehicle = active.get("vehicles", {}).get(pinned.get("vehicle_id"), {})
    return (all(pinned.get(f) == active.get(f) and active.get(f) is not None for f in FIELDS)
            and pinned.get("laps") == (1 if pinned.get("purpose") == "creator_test" else active.get("laps"))
            and pinned.get("handling_version") == vehicle.get("handling_version")
            and pinned.get("config_hash") == vehicle.get("config_hash") and bool(vehicle))


def pinned_filter(column, active):
    if any(active.get(f) is None for f in (*FIELDS, "laps")) or not active.get("vehicles"):
        return false()
    fields = [(column[f].as_integer() == active[f]) if f == "tick_rate"
              else column[f].as_string() == active[f] for f in FIELDS]
    laps = or_(column["laps"].as_integer() == active["laps"],
               and_(column["purpose"].as_string() == "creator_test", column["laps"].as_integer() == 1))
    vehicles = [and_(column["vehicle_id"].as_string() == vehicle_id,
                     column["handling_version"].as_string() == values["handling_version"],
                     column["config_hash"].as_string() == values["config_hash"])
                for vehicle_id, values in active["vehicles"].items()
                if values.get("handling_version") and values.get("config_hash")]
    return and_(*fields, laps, or_(*vehicles)) if vehicles else false()


def worker_filter(column, pinned):
    """Does a heartbeat's actual build support this exact pinned job?"""
    fields = [(column[f].as_integer() == pinned.get(f)) if f == "tick_rate"
              else column[f].as_string() == pinned.get(f) for f in FIELDS]
    vehicle = column["vehicles"][pinned.get("vehicle_id", "")]
    return and_(*fields, column["laps"].as_integer() == (5 if pinned.get("purpose") == "creator_test" else pinned.get("laps")),
                vehicle["handling_version"].as_string() == pinned.get("handling_version"),
                vehicle["config_hash"].as_string() == pinned.get("config_hash"))
