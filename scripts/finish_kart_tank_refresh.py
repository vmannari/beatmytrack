"""Repair only revisions changed by the concurrent Challenger writer."""
import json
import fnmatch
import subprocess
import sys
from rebuild_kart_tank_clearance import ROOT, OUT, sources, identity, run


def main():
    previous = json.loads((OUT / "identity-final-before.json").read_text())
    before = sources()
    current = identity("identity-repair-before")
    changed = [car for car, revision in current["modular_car_sha256"].items()
               if revision != previous["modular_car_sha256"].get(car)]
    original_inputs = json.loads((OUT / "refresh-inputs.json").read_text())
    changed_inputs = [p for p in original_inputs.keys() | before.keys() if original_inputs.get(p) != before.get(p)]
    manifest = json.loads((ROOT / "game/vehicle/prepared_asset_dependencies.json").read_text())
    # Generated native bytes can change without an authored-source revision.
    # Rebuild their consumers as well; never restamp their source receipt.
    for path in changed_inputs:
        # Native vehicle buffers require their consumers to be rebuilt even
        # when semantic source revisions coincide. Garage scenery scripts
        # affect pictures, not the native car scenes; identity already routes
        # any UI sources that really do contribute to prepared car geometry.
        if not path.startswith("game/assets/vehicles/"): continue
        matched = next((rule["vehicles"] for rule in manifest["rules"] if fnmatch.fnmatchcase(path, rule["pattern"])), manifest["vehicles"])
        changed.extend(car for car in matched if car not in changed)
    assert set(changed) <= {"super_rally"}, changed
    (OUT / "repair-inputs.json").write_text(json.dumps(before, indent=2))
    for car in changed:
        for stage, script in (("bases", "bake_modular_car_bases"), ("kits", "bake_modular_car_kits"),
                              ("garage", "bake_garage_cars")):
            run("repair-" + car + "-" + stage, "res://tests/" + script + ".gd", "--headless", "--", "--vehicle=" + car)
    run("repair-garage-pictures", "res://../scripts/bake_garage_previews.gd", "--rendering-method", "gl_compatibility")
    after = sources()
    drift = [p for p in before.keys() | after.keys() if before.get(p) != after.get(p)]
    final = identity("identity-repair-after")
    stable = not drift and final["modular_car_sha256"] == current["modular_car_sha256"]
    (OUT / "repair-source-receipt.json").write_text(json.dumps({"input_count": len(before), "rebuilt_cars": changed,
        "reused_cars": [car for car in current["modular_car_sha256"] if car not in changed], "drift": drift,
        "revisions_stable": stable}, indent=2))
    assert stable, "Sources changed during repair"
    run("prepared-preflight", "res://tests/check_prepared_assets.gd", "--headless")
    with (OUT / "picture-preflight.log").open("w", encoding="utf-8") as log:
        subprocess.run([sys.executable, "scripts/check_garage_previews.py"], cwd=ROOT, check=True, stdout=log, stderr=subprocess.STDOUT)
    print("KART_DRIVER_REFRESH: exact unchanged revisions reused; both final preflights passed", flush=True)


if __name__ == "__main__":
    main()
