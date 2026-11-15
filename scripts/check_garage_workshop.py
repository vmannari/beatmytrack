"""Read-only export gate for the packaged workshop and all declared inputs."""

import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GENERATOR = "tests/bake_garage_architecture.gd"
SCENE = "assets/garage/workshop_v1.scn"
RECIPE = "assets/garage/workshop_v1.reduction.json"
SCHEMA = "garage-mesh-reduction-1"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check(root=ROOT):
    game = root / "game"
    receipt = json.loads(
        (game / "assets/garage/workshop_v1.provenance.json").read_text(encoding="utf-8")
    )
    if receipt.get("generator") != "res://" + GENERATOR:
        raise ValueError("Unknown workshop generator")
    match = re.search(
        r"const SOURCES: Array\[String\]\s*=\s*\[([^\]]+)\]",
        (game / GENERATOR).read_text(encoding="utf-8"),
    )
    if not match:
        raise ValueError("Cannot read workshop source dependencies")
    expected = set(re.findall(r'"([^"]+)"', match.group(1)))
    sources = receipt.get("sources", {})
    if not expected or set(sources) != expected:
        raise ValueError("Workshop provenance must cover every declared input")
    for source, recorded in sources.items():
        path = (game / source).resolve()
        if not path.is_relative_to(game.resolve()) or digest(path) != recorded:
            raise ValueError(f"Stale workshop source: {source}; rebake architecture")
    if digest(game / SCENE) != receipt.get("scene_sha256"):
        raise ValueError("Changed workshop scene; rebake architecture")
    reduction = receipt.get("reduction", {})
    if (reduction.get("path") != RECIPE or reduction.get("schema") != SCHEMA
            or reduction.get("sha256") != digest(game / RECIPE)):
        raise ValueError("Changed or missing workshop reduction plan; rebake architecture")
    plan = json.loads((game / RECIPE).read_text(encoding="utf-8"))
    if (plan.get("schema") != SCHEMA or plan.get("engine") != receipt.get("engine")
            or plan.get("sources") != sources or not plan.get("meshes")):
        raise ValueError("Stale workshop reduction plan; rebake architecture")
    print(f"GARAGE_WORKSHOP: exact scene and reduction plan, {len(sources)} current source hashes")


if __name__ == "__main__":
    import sys

    try:
        check()
    except (OSError, ValueError, TypeError, AttributeError) as error:
        print(f"GARAGE_WORKSHOP: {error}", file=sys.stderr)
        sys.exit(1)
