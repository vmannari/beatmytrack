extends "res://tests/test_car_model_revert.gd"
## CI01-CI03: one small step, exact other models and full-detail controls.
const ITERATION_OUT: String="res://../docs/evidence/car-iteration-01-2026-11-15"
const CURRENT: Dictionary={"compact":19074,"kart":24223,"forklift":23370,"electric":19826,"hovercraft":22068}

func _initialize() -> void: verify_iteration.call_deferred()

func verify_iteration() -> void:
	var prepared: bool="--prepared" in OS.get_cmdline_user_args()
	var baseline: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/car_iteration_01_baseline.json")) if prepared else {}
	Base.enabled=prepared;Kits.enabled=prepared;Cache.enabled=prepared
	preload("res://ui/garage_car_cache.gd").enabled=false
	for id: String in CURRENT:
		for mode: String in ["stock","fitted","full"]:
			var car:=CarVisual.new();car.vehicle_id=id;car.simple_model=mode!="full";car.cache_rest_pose=false;car.livery=VehicleLivery.defaults(id);car.editable_kits=mode=="fitted";car.customisation=VehicleCustomisation.defaults()
			if mode=="fitted":
				for category: String in VehicleCustomisation.CATEGORIES: car.customisation[category]=VehicleCustomisation.options(category,id)[-1][0]
			var base_hits: int=Base.hits;var kit_hits: int=Kits.hits
			root.add_child(car)
			while not car.model_ready: await process_frame
			if prepared:
				check(Base.hits==base_hits+1,"actual prepared base "+id+mode)
				if mode=="fitted": check(Kits.hits==kit_hits+4,"actual four fitted modules "+id)
			var measured: Dictionary=inventory(car,false)
			if mode=="stock":
				check(measured.triangles==int(CURRENT[id]),"reviewed stock count "+id)
				if id=="forklift":
					var reduction: float=1.0-float(measured.triangles)/float(EXPECTED[id])
					check(reduction>=0.10 and reduction<=0.20,"first iteration stays within 10-20 percent")
			if prepared and (id!="forklift" or mode=="full"):
				check(signature(car)==baseline.signatures[id+"_"+mode],"exact other-car/full master GPU streams and poses "+id+mode)
			results.append({"vehicle":id,"mode":mode,"inventory":measured,"base_hits":Base.hits-base_hits,"kit_hits":Kits.hits-kit_hits})
			print("ITERATION_MODEL ",id," ",mode," triangles=",measured.triangles)
			car.free();await process_frame
	FileAccess.open(ITERATION_OUT.path_join("prepared.json" if prepared else "source.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":results},"  "))
	print("CAR_ITERATION ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
