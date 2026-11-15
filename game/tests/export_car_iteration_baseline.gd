extends "res://tests/test_car_model_revert.gd"
## Preserve small original GPU signatures; disposable scenes need not be retained.
func _initialize() -> void: export_signatures.call_deferred()
func export_signatures() -> void:
	var values: Dictionary={}
	for id: String in EXPECTED:
		for mode: String in ["stock","fitted","full"]:
			var reference: Node3D=(load(BASELINE.path_join(id+"-"+mode+"-before.scn")) as PackedScene).instantiate();root.add_child(reference)
			values[id+"_"+mode]=signature(reference)
			reference.free()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/fixtures"))
	FileAccess.open("res://tests/fixtures/car_iteration_01_baseline.json",FileAccess.WRITE).store_string(JSON.stringify({"provenance":"Pre-10k detached stock/fitted/full snapshots; exact master GPU streams, articulation transforms and shadow modes. Pinned Godot 4.7.2.","signatures":values},"  "))
	print("ITERATION_BASELINE_SIGNATURES ",values.size());quit()
