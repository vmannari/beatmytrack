"""Rebuild shared prepared dependencies after the livery photograph update."""
import json
import subprocess
import sys
from refresh_forklift_front_panel import sources
from run_forklift_operator_supports import OUT, ROOT, run

before = sources()
(OUT / "dependency-inputs.json").write_text(json.dumps(before, indent=2), encoding="utf-8")
run("dependency-bases", "res://tests/bake_modular_car_bases.gd")
for vehicle in ("compact", "kart", "forklift", "electric", "hovercraft", "super_rally"):
    run("dependency-kits-"+vehicle, "res://tests/bake_modular_car_kits.gd",
        "-TestArgument", "--vehicle="+vehicle)
run("dependency-garage", "res://tests/bake_garage_cars.gd")
run("dependency-header", "res://tests/bake_header_simple_compact.gd")
after = sources()
drift = sorted(p for p in before.keys() | after.keys() if before.get(p) != after.get(p))
(OUT / "dependency-source-receipt.json").write_text(json.dumps(
    {"inputs":len(before), "changed":drift}, indent=2), encoding="utf-8")
assert not drift, "Source changes during prepared refresh; retained rather than overwritten"
run("final-catalogue", "res://tests/bake_forklift_front_catalogue.gd", "-Graphical",
    "-RenderingMethod", "gl_compatibility")
run("full-preflight", "res://tests/check_prepared_assets.gd")
with (OUT / "picture-preflight.log").open("w", encoding="utf-8") as log:
    subprocess.run([sys.executable, "scripts/check_garage_previews.py"],cwd=ROOT,
                   stdout=log,stderr=subprocess.STDOUT,check=True)
