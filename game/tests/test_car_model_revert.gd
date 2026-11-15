extends "res://tests/measure_car_simplification.gd"
## CRV01-CRV03: the restored models must match the actual pre-10k snapshots.
const OUTPUT: String="res://../docs/evidence/car-model-revert-2026-11-15"
const BASELINE: String="res://../build/car-10k-models-2026-11-14"
const EXPECTED: Dictionary={"compact":19074,"kart":24223,"forklift":26472,"electric":19826,"hovercraft":22068}
var results: Array=[]

func _initialize() -> void: review.call_deferred()

func signature(holder: Node3D) -> Array:
	var values: Array=[]
	for part: MeshInstance3D in holder.find_children("*","MeshInstance3D",true,false):
		if part.mesh==null: continue
		var streams: Array=[]
		for surface: int in range(part.mesh.get_surface_count()):
			var packet: Dictionary=RenderingServer.mesh_get_surface(part.mesh.get_rid(),surface)
			for field: String in ["format","vertex_count","index_count","vertex_data","attribute_data","skin_data","index_data","blend_shapes"]: streams.append(packet.get(field))
		values.append(var_to_bytes([holder.global_transform.affine_inverse()*part.global_transform,part.cast_shadow,streams]).hex_encode().sha256_text())
	values.sort();return values

func review() -> void:
	var prepared: bool="--prepared" in OS.get_cmdline_user_args()
	Base.enabled=prepared;Kits.enabled=prepared;Cache.enabled=prepared
	preload("res://ui/garage_car_cache.gd").enabled=false
	check(not preload("res://vehicle/car_budget_reduction.gd").enabled,"10k experiment is archived")
	for id: String in EXPECTED:
		for mode: String in ["stock","fitted","full"]:
			var car:=CarVisual.new();car.vehicle_id=id;car.simple_model=mode!="full";car.cache_rest_pose=false;car.livery=VehicleLivery.defaults(id);car.editable_kits=mode=="fitted"
			car.customisation=VehicleCustomisation.defaults()
			if mode=="fitted":
				for category: String in VehicleCustomisation.CATEGORIES: car.customisation[category]=VehicleCustomisation.options(category,id)[-1][0]
			var base_hits: int=Base.hits;var kit_hits: int=Kits.hits
			root.add_child(car)
			while not car.model_ready: await process_frame
			if prepared:
				check(Base.hits==base_hits+1,"actual restored prepared base "+id+mode)
				if mode=="fitted": check(Kits.hits==kit_hits+4,"all four restored prepared modules "+id)
			var measured: Dictionary=inventory(car,false)
			if mode=="stock": check(measured.triangles==int(EXPECTED[id]),"exact pre-10k stock triangle count "+id)
			if prepared:
				var reference: Node3D=(load(BASELINE.path_join(id+"-"+mode+"-before.scn")) as PackedScene).instantiate()
				root.add_child(reference)
				check(signature(car)==signature(reference),"exact pre-10k master GPU data and transforms "+id+mode)
				reference.free()
			results.append({"vehicle":id,"mode":mode,"inventory":measured,"base_hits":Base.hits-base_hits,"kit_hits":Kits.hits-kit_hits})
			print("RESTORED_MODEL ",id," ",mode," triangles=",measured.triangles)
			car.free();await process_frame
	FileAccess.open(OUTPUT.path_join("prepared.json" if prepared else "source.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":results},"  "))
	print("CAR_MODEL_REVERT ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
