extends "res://tests/test_challenger_hellcat.gd"
func run() -> void:
    preload("res://vehicle/car_coarse_reduction.gd").enabled = false
    var prefix: String = "res://../build/challenger-panel-corrections-2026-11-14/native/"
    var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(prefix+"manifest.json"))
    (load(SuperRallyModel.ROOT+"manifest.json") as JSON).data = manifest
    SuperRallyModel.hood_profile = JSON.parse_string(FileAccess.get_file_as_string(prefix+"hood_profile.json"))
    for tier: String in ["simple","full"]:
        for entry: Dictionary in manifest.tiers[tier]:
            var mesh: ArrayMesh = load(prefix+str(entry.mesh))
            mesh.take_over_path(SuperRallyModel.ROOT+str(entry.mesh))
            SuperRallyModel.assets[SuperRallyModel.ROOT+str(entry.mesh)] = mesh
    await super.run()
