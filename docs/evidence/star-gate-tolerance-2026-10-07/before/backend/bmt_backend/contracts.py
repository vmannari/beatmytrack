"""Explicit compatibility upgrades for immutable track contracts.

Use the same full-manifest transformation at ticket issue and verification.
Board hashes include the resulting versions, retaining historical standings.
"""

BUILD_FIELDS = (
    "engine_version", "verifier_version", "physics_version", "rules_key",
    "compiler_version", "track_schema", "replay_schema", "tick_rate", "laps", "vehicles",
)


def build_contract(manifest: dict) -> dict:
    return {field: manifest.get(field) for field in BUILD_FIELDS}

def current_manifest(manifest: dict) -> dict:
    result = dict(manifest)
    if result.get("rules_key") in (
        "standing-5-road-gates-v12", "standing-5-road-gates-v13", "standing-5-road-gates-v14",
        "standing-5-road-gates-v15",
        "standing-5-road-gates-v16",
        "standing-5-road-gates-v17",
        "standing-5-road-gates-v18",
    ):
        result["rules_key"] = "standing-5-road-gates-v19"
    if result.get("physics_version") in {f"arcade-planar-0.{n}" for n in range(39, 52)}:
        result["physics_version"] = "arcade-planar-0.52"
    return result
