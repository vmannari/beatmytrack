extends "res://tests/test_car_model_revert.gd"
const VSR_OUT: String="res://../docs/evidence/volt-reflection-smoothing-2026-11-15"
func _initialize() -> void: verify.call_deferred()
func protected_streams(car: Node3D) -> Array:
	var result: Array=[]
	for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if part.mesh.get_meta("car_keep_master",false) and part.mesh.get_faces().size()/3==926:
			result.append(preload("res://vehicle/car_detail_reduction.gd").mesh_key(part.mesh))
	result.sort();return result
func verify() -> void:
	var prepared: bool="--prepared" in OS.get_cmdline_user_args()
	Base.enabled=prepared;Kits.enabled=prepared;Cache.enabled=prepared
	preload("res://ui/garage_car_cache.gd").enabled=false
	var baseline: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/volt_smooth_baseline.json"))
	for mode: String in ["stock","fitted","full"]:
		var car:=CarVisual.new();car.vehicle_id="electric";car.simple_model=mode!="full";car.cache_rest_pose=false;car.editable_kits=mode=="fitted";car.livery=VehicleLivery.defaults("electric");car.customisation=VehicleCustomisation.defaults()
		if mode=="fitted":
			for category: String in VehicleCustomisation.CATEGORIES:car.customisation[category]=VehicleCustomisation.options(category,"electric")[-1][0]
		var before_hits: int=Base.hits;var before_kits: int=Kits.hits
		root.add_child(car)
		while not car.model_ready:await process_frame
		if prepared:
			check(Base.hits==before_hits+1,"actual prepared "+mode)
			if mode=="fitted":check(Kits.hits==before_kits+4,"four actual fitted modules")
		var measured: Dictionary=inventory(car,false)
		check(measured.triangles==int({"stock":21309,"fitted":27033,"full":114648}[mode]),"repair geometry budget "+mode)
		var old: Node3D=load("res://../build/volt-reflection-smoothing-2026-11-15/electric-"+mode+"-before.scn").instantiate();root.add_child(old)
		check(car.transform==old.transform,"unchanged root scale "+mode)
		if mode=="full":check(signature(car)==baseline.signatures.electric_full,"full master GPU streams and articulation exact")
		else:
			check(not protected_streams(old).is_empty(),"baseline contour stream observed "+mode)
			check(protected_streams(car).size()==protected_streams(old).size(),"refitted seam and handle aggregate retained "+mode)
		results.append({"mode":mode,"inventory":measured});print("VOLT_CORNER_MODEL ",mode," ",measured.triangles)
		old.free();car.free();await process_frame
	FileAccess.open(VSR_OUT.path_join("prepared.json" if prepared else "source.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":results},"  "))
	print("VOLT_CORNER_TESTS ",checks," checks, ",failures," failures");quit(1 if failures else 0)
