"""Focused geometry, prepared-model and Garage/race regressions."""
from run_forklift_operator_supports import run

run("final-supports", "res://tests/test_forklift_operator_supports.gd")
run("final-garage-race", "res://tests/test_forklift_garage.gd")
run("final-parse", "res://tests/check_model_refinement_parse.gd")
run("final-operator-view", "res://tests/capture_forklift_operator_supports.gd",
    "-Graphical", "-RenderingMethod", "gl_compatibility", "-TestArgument",
    "--prepared", "--output=res://../docs/evidence/forklift-operator-supports-2026-11-13/prepared-close")
