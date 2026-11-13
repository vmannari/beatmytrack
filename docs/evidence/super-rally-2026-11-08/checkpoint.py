"""Task-only source patch, without writing the shared Git index or changing HEAD."""
import difflib
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
BEFORE = OUT / "before"
owned = [
    "backend/bmt_backend/achievements.py", "backend/bmt_backend/appearance_authorization.py",
    "backend/bmt_backend/profile_statistics.py", "backend/bmt_backend/shader_profiles.py",
    "backend/bmt_backend/telemetry.py", "backend/bmt_backend/vehicle_appearance.py",
    "backend/bmt_backend/world_ranking_car_rules.py", "game/vehicle/vehicle_catalog.gd",
    "game/vehicle/car_visual.gd", "game/vehicle/livery_catalog.gd", "game/vehicle/modular_car_base.gd",
    "game/vehicle/modular_car_kits.gd", "game/vehicle/prepared_asset_sources.gd",
    "game/vehicle/prepared_car_cache.gd", "game/vehicle/racing_car_models.gd",
    "game/vehicle/vehicle_audio.gd", "game/vehicle/vehicle_customisation.gd",
    "game/vehicle/vehicle_livery.gd", "game/vehicle/vehicle_weathering.gd",
    "game/ui/car_showroom.gd", "game/ui/garage_car_cache.gd", "game/ui/garage_page.gd",
    "game/ui/header_simple_cache.gd", "game/ui/profile_car_renderer.gd", "game/ui/rivalry_podium_studio.gd",
    "game/tests/test_cars.gd", "game/tests/test_world_ranking_cars.gd",
]
inverses = {
    "game/backend/world_ranking_client.gd": [('"hovercraft", "super_rally"', '"hovercraft"')],
    "game/persistence/cosmetic_catalog.gd": [("VehicleCatalog.model_id(car)", "car")],
    "game/tests/bake_modular_car_bases.gd": [("\t\tif VehicleCatalog.model_id(id) != id: continue # Shared chassis is baked once.\n", "")],
    "game/tests/bake_garage_cars.gd": [("\t\tif VehicleCatalog.model_id(id) != id: continue # Shared chassis is baked once.\n", "")],
    "game/tests/check_prepared_assets.gd": [('Garage.DIRECTORY+car.model_id+".scn"', 'Garage.DIRECTORY+id+".scn"')],
    "scripts/build_identity.ps1": [("        $modularHashes['super_rally'] = $modularHashes['compact']\n", "")],
    "scripts/garage_preview_identity.ps1": [(", 'super_rally'", ""), ("|super_rally", ""),
        ("        if ($Matches[2] -eq 'compact') { return @('compact', 'super_rally') }\n", "")],
    "scripts/check_garage_previews.py": [(
        '    aliases = re.search(r"const MODEL_ALIASES: Dictionary = (\\{[^\\n]+\\})", catalog)\n    model_aliases = json.loads(aliases.group(1)) if aliases else {}\n', ""),
        ("{model_aliases.get(vehicle, vehicle)}_simple_editable.scn", "{vehicle}_simple_editable.scn")],
}
for name, changes in inverses.items():
    # Reverse the most specific expressions before their contained tokens.
    source = (ROOT / name).read_text(encoding="utf-8-sig")
    for old, new in sorted(changes, key=lambda item: -len(item[0])):
        assert old in source, (name, old)
        source = source.replace(old, new)
    target = BEFORE / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(source, encoding="utf-8", newline="\n")
    owned.append(name)
for path in (ROOT / "game/localization").glob("*.po"):
    source = path.read_text(encoding="utf-8")
    for msg in ("Super rally", "Rally's agile, forgiving handling with stronger acceleration and a higher top speed."):
        pattern = r'\n#: game/vehicle/vehicle_catalog\.gd\nmsgid "' + re.escape(msg) + r'"\nmsgstr "[^\n]*"\n'
        source, count = re.subn(pattern, "", source)
        assert count == 1, (path, msg, count)
    name = path.relative_to(ROOT).as_posix()
    target = BEFORE / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(source, encoding="utf-8", newline="\n")
    owned.append(name)
added = ["game/resources/cars/super_rally.tres", "backend/tests/test_super_rally.py",
    "game/tests/test_super_rally.gd", "game/tests/test_super_rally_ui.gd", "game/tests/bake_super_rally_art.gd"]
for name in added[:]:
    uid = ROOT / (name + ".uid")
    if uid.exists(): added.append(name + ".uid")
patch = []
receipt = []
for name in sorted(owned + added):
    current = (ROOT / name).read_text(encoding="utf-8-sig")
    before = "" if name in added else (BEFORE / name).read_text(encoding="utf-8-sig")
    assert before != current, name
    patch.extend(difflib.unified_diff(before.splitlines(True), current.splitlines(True),
        fromfile="/dev/null" if name in added else "a/"+name, tofile="b/"+name))
    receipt.append({"path": name, "before_sha256": None if name in added else hashlib.sha256((BEFORE/name).read_bytes()).hexdigest(),
        "after_sha256": hashlib.sha256((ROOT/name).read_bytes()).hexdigest()})
(OUT / "source-only.patch").write_text("".join(patch), encoding="utf-8", newline="\n")
(OUT / "source-receipt.json").write_text(json.dumps(receipt, indent=2), encoding="utf-8")
print("Task source checkpoint:", len(receipt), "files; Git index and HEAD untouched")
