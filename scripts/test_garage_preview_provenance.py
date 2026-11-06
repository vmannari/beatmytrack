"""Exercise photograph provenance rejection using an owned copy of real inputs."""

import importlib.util
import json
import re
import shutil
import time
from pathlib import Path

root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "preview_checker", root / "scripts/check_garage_previews.py"
)
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)
fixture = root / "build" / ("prepared-picture-fixture-" + str(time.time_ns()))
fixture.mkdir(parents=True)
assert fixture.resolve().is_relative_to((root / "build").resolve())
provenance = json.loads(
    (root / "game/assets/garage/previews_v1/provenance.json").read_text(
        encoding="utf-8"
    )
)
paths = set(provenance["sources"]) | {
    "game/core/build_identity.gd",
    "game/vehicle/vehicle_catalog.gd",
    "game/assets/garage/previews_v1/provenance.json",
}
for vehicle in provenance["hashes"]:
    paths.update(
        {
            f"game/assets/garage/cars_v1/{vehicle}.scn",
            f"game/assets/garage/previews_v1/{vehicle}.png",
        }
    )
for path in paths:
    target = fixture / path
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(root / path, target)
checker.ROOT = fixture
checker.check()
checks = 1


def rejects(path, mutate):
    global checks
    target = fixture / path
    original = target.read_bytes()
    target.write_bytes(mutate(original))
    try:
        checker.check()
    except ValueError:
        checks += 1
    else:
        raise AssertionError("Stale photograph was accepted: " + path)
    finally:
        target.write_bytes(original)


rejects(
    "game/assets/garage/cars_v1/compact.scn", lambda value: value + b"changed-scene"
)


def changed_revision(value):
    text = value.decode("utf-8")
    found = re.search(r"MODULAR_CAR_SHA256: Dictionary = (\{[^\n]+\})", text)
    revisions = json.loads(found.group(1))
    revisions["compact"] = "0" * 64
    return text.replace(found.group(1), json.dumps(revisions)).encode("utf-8")


rejects("game/core/build_identity.gd", changed_revision)
rejects(
    "game/vehicle/electric_car_model.gd", lambda value: value + b"\n# changed source\n"
)
rejects(
    "game/assets/garage/previews_v1/compact.png", lambda value: value + b"changed-image"
)
print(
    f"GARAGE_PREVIEW_PROVENANCE: {checks} positive/invalidation checks passed; owned fixture retained."
)
