extends "res://tests/test_car_model_revert.gd"
const RFL_OUT: String="res://../docs/evidence/rally-lamp-style-2026-11-15"
func _initialize() -> void: verify_front.call_deferred()
func verify_front() -> void:
	var prepared: bool="--prepared" in OS.get_cmdline_user_args()
	Base.enabled=prepared;Kits.enabled=prepared;Cache.enabled=prepared;preload("res://ui/garage_car_cache.gd").enabled=false
	var baseline: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/rally_lamp_style_baseline.json"))
	var rows: Array=[]
	for id: String in ["compact","kart","forklift","electric","hovercraft","super_rally"]:
		if not prepared and id!="compact":continue
		for mode: String in (["stock","fitted","full"] if id=="compact" else ["stock","full"]):
			var car:=CarVisual.new();car.vehicle_id=id;car.simple_model=mode!="full";car.cache_rest_pose=false;car.livery=VehicleLivery.defaults(id);car.editable_kits=mode=="fitted";car.customisation=VehicleCustomisation.defaults()
			if mode=="fitted":
				for category: String in VehicleCustomisation.CATEGORIES:car.customisation[category]=VehicleCustomisation.options(category,id)[-1][0]
			var prior_hits: int=Base.hits;var prior_kits: int=Kits.hits
			root.add_child(car)
			while not car.model_ready:await process_frame
			var measured: Dictionary=inventory(car,false)
			if prepared:
				check(Base.hits==prior_hits+1,"actual prepared base "+id+mode)
				if mode=="fitted":check(Kits.hits==prior_kits+4,"all four actual Rally modules")
				if id!="compact":check(signature(car)==baseline.signatures[id+"_"+mode],"unaffected complete GPU/articulation/shadow master "+id+mode)
			if id=="compact" and mode=="stock":check(measured.triangles==16213,"classic optics retain approximately fifteen percent from the restored baseline")
			rows.append({"vehicle":id,"mode":mode,"inventory":measured})
			print("RALLY_FRONT_MODEL ",id," ",mode," ",measured.triangles)
			car.free();await process_frame
	var registry: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(RFL_OUT.path_join("frame-registry.json")))
	var migration: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(RFL_OUT.path_join("recipe-migration.json")))
	for path: String in migration:
		var row: Dictionary=migration[path];var prior: Dictionary=registry[row.key]
		var actual: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
		var expected: Dictionary={}
		for key: String in prior.recipe.parts:
			if not prior.parts[key].front:expected[key]=prior.recipe.parts[key]
		check(actual.parts==expected,"every retained non-front recipe row exact")
		check(actual.context==path.get_file().get_basename().trim_prefix("compact_"),"new complete-frame context remains exact")
	check(migration.size()==2,"both fixed and editable Rally body frames retained")
	FileAccess.open(RFL_OUT.path_join("prepared.json" if prepared else "source.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows},"  "))
	print("RALLY_FRONT_TESTS ",checks," checks, ",failures," failures");quit(1 if failures else 0)
