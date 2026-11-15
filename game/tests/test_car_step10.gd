extends "res://tests/test_car_model_revert.gd"
const STEP_OUT: String="res://../docs/evidence/car-step10-2026-11-15"
func _initialize() -> void: verify.call_deferred()
func verify() -> void:
	var prepared: bool="--prepared" in OS.get_cmdline_user_args()
	Base.enabled=prepared;Kits.enabled=prepared;Cache.enabled=prepared
	preload("res://ui/garage_car_cache.gd").enabled=false
	var plan: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(STEP_OUT.path_join("selected-plan.json")))
	var baseline: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/car_step10_baseline.json"))
	var current: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/car_step10_current_controls.json"))
	var expected: Dictionary={}
	for row: Dictionary in plan.rows: expected[row.vehicle]=int(row.after)
	for id: String in VehicleCatalog.IDS:
		if id=="super_rally" and "--exclude-vehicle=super_rally" in OS.get_cmdline_user_args():continue
		for mode: String in ["stock","fitted","full"]:
			var car:=CarVisual.new();car.vehicle_id=id;car.simple_model=mode!="full";car.cache_rest_pose=false;car.livery=VehicleLivery.defaults(id);car.editable_kits=mode=="fitted";car.customisation=VehicleCustomisation.defaults()
			if mode=="fitted":
				for category: String in VehicleCustomisation.CATEGORIES: car.customisation[category]=VehicleCustomisation.options(category,id)[-1][0]
			var base_hits: int=Base.hits;var kit_hits: int=Kits.hits
			root.add_child(car)
			while not car.model_ready: await process_frame
			if prepared:
				check(Base.hits==base_hits+1,"prepared base "+id+mode)
				if mode=="fitted": check(Kits.hits==kit_hits+4,"four prepared kits "+id)
			var measured: Dictionary=inventory(car,false)
			if mode=="stock" and expected.has(id): check(measured.triangles==expected[id],"reviewed budget "+id)
			if mode=="full" or id=="super_rally": check(signature(car)==(baseline.signatures[id+"_"+mode] if prepared and id!="super_rally" else current.signatures[id+"_"+mode]),"unchanged GPU streams/articulation "+id+mode)
			results.append({"vehicle":id,"mode":mode,"inventory":measured,"base_hits":Base.hits-base_hits,"kit_hits":Kits.hits-kit_hits})
			print("STEP10_MODEL ",id," ",mode," ",measured.triangles)
			car.free();await process_frame
	FileAccess.open(STEP_OUT.path_join("prepared.json" if prepared else "source.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":results},"  "))
	print("STEP10_MODELS ",checks," checks, ",failures," failures");quit(1 if failures else 0)
