"""Explicit compatibility upgrades for immutable track contracts.

Use the same full-manifest transformation at ticket issue and verification.
Board hashes include the resulting versions, retaining historical standings.
"""

BUILD_FIELDS = (
    "engine_version", "verifier_version", "physics_version", "rules_key",
    "compiler_version", "track_schema", "replay_schema", "tick_rate", "laps", "vehicles",
)

# .75 and .76 change only optional Electric handling. The other six integrators
# and configuration hashes retain .74 behavior.
# This is an explicit, symmetric compatibility declaration, not a version range.
# Car tuning belongs in its handling version/hash; reserve a shared physics bump
# for changes affecting shared simulation. Never infer equivalence by ordering.
ELECTRIC_ONLY_PHYSICS = ("arcade-planar-0.74", "arcade-planar-0.75", "arcade-planar-0.76")
UNCHANGED_VEHICLES = frozenset(("compact", "pickup", "classic", "formula", "kart", "forklift"))


def compatible_physics_versions(version, vehicle_id):
    if vehicle_id in UNCHANGED_VEHICLES and version in ELECTRIC_ONLY_PHYSICS:
        return (version, *(item for item in ELECTRIC_ONLY_PHYSICS if item != version))
    return (version,)


def build_contract(manifest: dict) -> dict:
    return {field: manifest.get(field) for field in BUILD_FIELDS}


def vehicle_build_contract(manifest: dict, vehicle_id: str) -> dict:
    vehicle = manifest.get("vehicles", {}).get(vehicle_id, {})
    return {**build_contract(manifest), "vehicle_id": vehicle_id,
            "vehicles": {vehicle_id: {field: vehicle.get(field) for field in ("handling_version", "config_hash")}}}


def current_manifest(manifest: dict) -> dict:
    result = dict(manifest)
    if result.get("rules_key") in (
        "standing-5-road-gates-v12", "standing-5-road-gates-v13", "standing-5-road-gates-v14",
        "standing-5-road-gates-v15",
        "standing-5-road-gates-v16",
        "standing-5-road-gates-v17",
        "standing-5-road-gates-v18",
        "standing-5-road-gates-v19",
        "standing-5-road-gates-v20",
        "standing-5-road-gates-v21",
        "standing-5-road-gates-v22",
        "standing-5-road-gates-v23",
    ):
        result["rules_key"] = "standing-5-road-gates-v24"
    if result.get("physics_version") in {f"arcade-planar-0.{n}" for n in range(39, 53)}:
        result["physics_version"] = "arcade-planar-0.53"
    return result
