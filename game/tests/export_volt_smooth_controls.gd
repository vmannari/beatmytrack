extends "res://tests/test_car_model_revert.gd"
func _initialize() -> void: export_controls.call_deferred()
func export_controls() -> void:
	var data: Dictionary={"signatures":{},"counts":{}}
	for id: String in ["electric"]:
		for mode: String in ["stock","fitted","full"]:
			var car: Node3D=load("res://../build/volt-reflection-smoothing-2026-11-15/"+id+"-"+mode+"-before.scn").instantiate()
			root.add_child(car)
			data.signatures[id+"_"+mode]=signature(car)
			data.counts[id+"_"+mode]=0
			car.free()
	FileAccess.open("res://tests/fixtures/volt_smooth_baseline.json",FileAccess.WRITE).store_string(JSON.stringify(data,"  "))
	print("STEP10_BASELINE_CONTROLS ",data.signatures.size());quit()
