"""Focused existing regressions and prepared native comparison captures."""
from run_forklift_front_panel import run


if __name__ == "__main__":
    run("import", "IMPORT")
    for label, method, folder in (("native-gl", "gl_compatibility", "after"),
                                  ("native-mobile", "mobile", "mobile")):
        run(label, "res://tests/capture_forklift_front_panel.gd", "-Graphical",
            "-RenderingMethod", method, "-TestArgument", "--prepared",
            "--output=res://../docs/evidence/forklift-front-panel-2026-11-12/"+folder)
    run("prepared-comparison", "res://tests/test_forklift_prepared_kits.gd")
    run("garage-race", "res://tests/test_forklift_garage.gd")
    run("driving", "res://tests/test_driving.gd")
    run("wash", "res://tests/test_car_wash.gd")
    run("production-parse", "res://tests/check_model_refinement_parse.gd")
