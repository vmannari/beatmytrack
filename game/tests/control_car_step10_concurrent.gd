extends "res://tests/test_car_model_revert.gd"
const OriginalSource=preload("res://tests/support/car_step10_control_source.gd")
func _initialize() -> void: run_control.call_deferred()
func run_control() -> void:
	Base.enabled=false;Kits.enabled=false;Cache.enabled=false
	var saved: Dictionary={"signatures":{},"counts":{}}
	for id: String in VehicleCatalog.IDS:
		for mode: String in (["stock","fitted","full"] if id=="super_rally" else ["full"]):
			var pair: Array=[]
			for original: bool in [true,false]:
				var car: CarVisual=OriginalSource.new() if original else CarVisual.new()
				car.vehicle_id=id;car.simple_model=mode!="full";car.cache_rest_pose=false;car.editable_kits=mode=="fitted";car.livery=VehicleLivery.defaults(id);car.customisation=VehicleCustomisation.defaults()
				if mode=="fitted":
					for category: String in VehicleCustomisation.CATEGORIES:car.customisation[category]=VehicleCustomisation.options(category,id)[-1][0]
				root.add_child(car)
				while not car.model_ready:await process_frame
				pair.append(signature(car))
				saved.counts[id+"_"+mode]=inventory(car,false).triangles
				car.free();await process_frame
			check(pair[0]==pair[1],"task-start batching exact for current "+id+mode)
			saved.signatures[id+"_"+mode]=pair[0]
	saved.checks=checks;saved.failures=failures
	FileAccess.open("res://tests/fixtures/car_step10_current_controls.json",FileAccess.WRITE).store_string(JSON.stringify(saved,"  "))
	print("STEP10_UNCHANGED_CONTROLS ",checks," checks, ",failures," failures");quit(1 if failures else 0)
