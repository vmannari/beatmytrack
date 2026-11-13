"""Refresh the front panel, native art and dependent prepared assemblies."""
import hashlib
import json
import subprocess
import sys
import time

from run_forklift_front_panel import OUT, ROOT, run


def sources():
    files = []
    for folder in ("game/vehicle", "game/resources", "game/ui", "game/track"):
        files.extend(p for p in (ROOT / folder).rglob("*")
                     if p.suffix in (".gd", ".tres", ".json", ".gdshader", ".gdshaderinc"))
    files.extend(p for p in (ROOT / "game/assets/vehicles").rglob("*")
                 if p.is_file() and p.suffix in (".res", ".png")
                 and "modular_car_bases_v1" not in p.parts and "modular_kits_v1" not in p.parts)
    files.extend(p for p in (ROOT / "game/assets/liveries").rglob("*")
                 if p.suffix in (".png", ".svg", ".json"))
    return {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    run("shadow-bake", "res://tests/bake_forklift_racing_shadows.gd")
    run("profile-art", "res://tests/bake_model_refinement_art.gd", "-Graphical",
        "-RenderingMethod", "gl_compatibility", "-TestArgument", "--vehicle=forklift")
    run("livery-art", "res://tests/bake_livery_previews.gd", "-Graphical",
        "-RenderingMethod", "gl_compatibility", "-TestArgument", "--vehicle=forklift")
    run("news-art", "res://tests/bake_news_car_photos.gd", "-Graphical",
        "-RenderingMethod", "gl_compatibility", "-TestArgument", "--vehicle=forklift",
        "--evidence-root=res://../docs/evidence/forklift-front-panel-2026-11-12/news")
    before = sources()
    (OUT / "refresh-inputs.json").write_text(json.dumps(before, indent=2), encoding="utf-8")
    run("all-bases", "res://tests/bake_modular_car_bases.gd")
    for car in ("compact", "kart", "forklift", "electric", "hovercraft", "super_rally"):
        run("kits-"+car, "res://tests/bake_modular_car_kits.gd", "-TestArgument", "--vehicle="+car)
    run("all-garage", "res://tests/bake_garage_cars.gd")
    run("header-template", "res://tests/bake_header_simple_compact.gd")
    run("garage-pictures", "res://tests/bake_forklift_front_catalogue.gd", "-Graphical",
        "-RenderingMethod", "gl_compatibility")
    after = sources()
    changed = [p for p in before.keys() | after.keys() if before.get(p) != after.get(p)]
    (OUT / "refresh-source-receipt.json").write_text(
        json.dumps({"input_count": len(before), "changed": changed}, indent=2), encoding="utf-8")
    assert not changed, "Authored sources changed during the prepared refresh"
    run("prepared-preflight", "res://tests/check_prepared_assets.gd")
    with (OUT / "picture-preflight.log").open("w", encoding="utf-8") as log:
        subprocess.run([sys.executable, "scripts/check_garage_previews.py"], cwd=ROOT,
                       check=True, stdout=log, stderr=subprocess.STDOUT)
    print("FORKLIFT_FRONT_REFRESH: stable sources and both preflights passed", flush=True)


def repair():
    before = sources()
    stable_samples = 0
    for attempt in range(15):
        time.sleep(20)
        current = sources()
        stable_samples = stable_samples+1 if before == current else 0
        before = current
        print("REPAIR_INPUT_STABILITY", stable_samples, flush=True)
        if stable_samples >= 2: break
    assert stable_samples >= 2, "Concurrent model sources are still changing"
    prior = json.loads((OUT / "refresh-inputs.json").read_text())
    changed = {p for p in before.keys() | prior.keys() if before.get(p) != prior.get(p)}
    (OUT / "repair-input-diff.json").write_text(json.dumps(sorted(changed), indent=2), encoding="utf-8")
    assert all(p.startswith("game/assets/vehicles/challenger_hellcat_v1/")
               or p == "game/ui/rivalry_simple_car.gd" for p in changed), changed
    (OUT / "repair-inputs.json").write_text(json.dumps(before, indent=2), encoding="utf-8")
    for stage, script in (("bases", "bake_modular_car_bases"), ("kits", "bake_modular_car_kits"),
                          ("garage", "bake_garage_cars")):
        run("repair-super-"+stage, "res://tests/"+script+".gd", "-TestArgument", "--vehicle=super_rally")
    run("repair-profile-art", "res://tests/bake_model_refinement_art.gd", "-Graphical",
        "-RenderingMethod", "gl_compatibility", "-TestArgument", "--vehicle=forklift")
    run("repair-news-art", "res://tests/bake_news_car_photos.gd", "-Graphical",
        "-RenderingMethod", "gl_compatibility", "-TestArgument", "--vehicle=forklift",
        "--evidence-root=res://../docs/evidence/forklift-front-panel-2026-11-12/news")
    run("repair-garage-pictures", "res://tests/bake_forklift_front_catalogue.gd", "-Graphical",
        "-RenderingMethod", "gl_compatibility")
    after = sources()
    drift = [p for p in before.keys() | after.keys() if before.get(p) != after.get(p)]
    (OUT / "repair-source-receipt.json").write_text(json.dumps(
        {"input_count": len(before), "rebuilt_cars": ["super_rally"], "changed": drift}, indent=2), encoding="utf-8")
    assert not drift, "Authored sources changed during repair"
    run("prepared-preflight", "res://tests/check_prepared_assets.gd")
    with (OUT / "picture-preflight.log").open("w", encoding="utf-8") as log:
        subprocess.run([sys.executable, "scripts/check_garage_previews.py"], cwd=ROOT,
                       check=True, stdout=log, stderr=subprocess.STDOUT)
    print("FORKLIFT_FRONT_REPAIR: preserved concurrent sources; both preflights passed", flush=True)


if __name__ == "__main__":
    repair() if "--repair" in sys.argv else main()
