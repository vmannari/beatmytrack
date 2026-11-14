"""Publish a source-fenced forklift scope after concurrent shared-source writes."""
import json
import time
from refresh_forklift_front_panel import sources
from run_forklift_operator_supports import OUT, run

before = sources()
time.sleep(15)
assert before == sources(), "Shared sources still changing; no scoped bake started"
(OUT / "repair-inputs.json").write_text(json.dumps(before,indent=2),encoding="utf-8")
for label, script in (("bases","bake_modular_car_bases"),
                      ("kits","bake_modular_car_kits"),
                      ("garage","bake_garage_cars")):
    run("repair-"+label,"res://tests/"+script+".gd","-TestArgument","--vehicle=forklift")
after = sources()
drift = sorted(p for p in before.keys() | after.keys() if before.get(p) != after.get(p))
(OUT / "repair-source-receipt.json").write_text(json.dumps(
    {"inputs":len(before),"changed":drift},indent=2),encoding="utf-8")
assert not drift, "Concurrent sources changed; validation remains unqualified"
run("repair-preflight","res://tests/check_prepared_assets.gd","-TestArgument",
    *["--exclude-vehicle="+v for v in ("compact","kart","electric","hovercraft","super_rally")])
run("repair-prepared-kits","res://tests/test_forklift_prepared_kits.gd")
run("repair-garage-race","res://tests/test_forklift_garage.gd")
run("repair-parse","res://tests/check_model_refinement_parse.gd")
run("repair-catalogue","res://tests/bake_forklift_front_catalogue.gd","-Graphical",
    "-RenderingMethod","gl_compatibility")
run("repair-close","res://tests/capture_forklift_operator_supports.gd","-Graphical",
    "-RenderingMethod","gl_compatibility","-TestArgument","--prepared",
    "--output=res://../docs/evidence/forklift-operator-supports-2026-11-13/prepared-close")
