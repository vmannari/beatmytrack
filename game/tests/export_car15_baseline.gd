extends "res://tests/test_car_model_revert.gd"
## C1502: retain portable signatures of the owner-reviewed starting geometry.
func _initialize() -> void: export_signatures.call_deferred()
func export_signatures() -> void:
	var values: Dictionary={}
	for id: String in EXPECTED:
		for mode: String in ["stock","fitted","full"]:
			var reference: Node3D=load("res://../build/car15-2026-11-15/"+id+"-"+mode+"-before.scn").instantiate()
			root.add_child(reference);values[id+"_"+mode]=signature(reference);reference.free()
	FileAccess.open("res://tests/fixtures/car15_baseline.json",FileAccess.WRITE).store_string(JSON.stringify({"provenance":"Owner-reviewed task-start prepared master snapshots, Godot 4.7.2; Forklift already has iteration 1. GPU streams, articulation transforms and shadow modes.","signatures":values},"  "))
	print("CAR15_BASELINE_SIGNATURES ",values.size());quit()
