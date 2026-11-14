"""Refresh only the forklift dependency scope through the pinned dev entry."""
import subprocess
import sys
from run_forklift_operator_supports import ROOT, run

for label, script in (
    ("shadows", "bake_forklift_racing_shadows"),
):
    run(label, "res://tests/"+script+".gd", "-TestArgument", "--vehicle=forklift")
for label, script in (
    ("profile-art", "bake_model_refinement_art"),
    ("livery-art", "bake_livery_previews"),
    ("news-art", "bake_news_car_photos"),
):
    args = ["--vehicle=forklift"]
    if label == "news-art":
        args.append("--evidence-root=res://../docs/evidence/forklift-operator-supports-2026-11-13/news")
    run(label, "res://tests/"+script+".gd", "-Graphical",
        "-RenderingMethod", "gl_compatibility", "-TestArgument", *args)
subprocess.run([sys.executable, "scripts/refresh_forklift_support_dependencies.py"],
               cwd=ROOT, check=True)
run("prepared-kits", "res://tests/test_forklift_prepared_kits.gd")
run("garage-race", "res://tests/test_forklift_garage.gd")
