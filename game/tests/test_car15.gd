extends "res://tests/test_car_model_revert.gd"
const CAR15_OUT: String="res://../docs/evidence/car15-2026-11-15"
const CAR15_WORK: String="res://../build/car15-2026-11-15"
func _initialize() -> void: verify_car15.call_deferred()
func verify_car15() -> void:
	var prepared: bool="--prepared" in OS.get_cmdline_user_args()
	Base.enabled=prepared;Kits.enabled=prepared;Cache.enabled=prepared;preload("res://ui/garage_car_cache.gd").enabled=false
	var plan: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CAR15_OUT.path_join("selected-plan.json")))
	var expected: Dictionary={}
	for row: Dictionary in plan.rows: expected[row.vehicle]=int(row.after)
	for id: String in expected:
		for mode: String in ["stock","fitted","full"]:
			var car:=CarVisual.new();car.vehicle_id=id;car.simple_model=mode!="full";car.cache_rest_pose=false;car.livery=VehicleLivery.defaults(id);car.editable_kits=mode=="fitted";car.customisation=VehicleCustomisation.defaults()
			if mode=="fitted":
				for category: String in VehicleCustomisation.CATEGORIES: car.customisation[category]=VehicleCustomisation.options(category,id)[-1][0]
			var base_hits: int=Base.hits;var kit_hits: int=Kits.hits
			root.add_child(car)
			while not car.model_ready: await process_frame
			if prepared:
				check(Base.hits==base_hits+1,"actual prepared base "+id+mode)
				if mode=="fitted": check(Kits.hits==kit_hits+4,"four actual modules "+id)
			var measured: Dictionary=inventory(car,false)
			if mode=="stock": check(measured.triangles==int(expected[id]),"reviewed stock budget "+id)
			if prepared and mode=="full":
				var baseline: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/car15_baseline.json"))
				check(signature(car)==baseline.signatures[id+"_full"],"exact full master GPU streams and articulation "+id)
			results.append({"vehicle":id,"mode":mode,"inventory":measured,"base_hits":Base.hits-base_hits,"kit_hits":Kits.hits-kit_hits})
			print("CAR15_MODEL ",id," ",mode," triangles=",measured.triangles)
			car.free();await process_frame
	FileAccess.open(CAR15_OUT.path_join("prepared.json" if prepared else "source.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":results},"  "))
	print("CAR15_TESTS ",checks," checks, ",failures," failures");quit(1 if failures else 0)
