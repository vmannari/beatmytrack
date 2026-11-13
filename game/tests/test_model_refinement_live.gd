extends "res://tests/test_model_refinement.gd"
## Final integration accepts concurrent cloth authoring, while independently
## retaining the helmet, memory, source-guard, steering and physical contracts.
func run() -> void:
	var sources: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("task-start-hashes.json")))
	for path: String in sources:
		if path.begins_with("game/resources/cars/") or path in ["game/vehicle/vehicle_simulation.gd","game/vehicle/vehicle_state.gd",".git/index"]:
			check(FileAccess.get_sha256("res://../"+path)==sources[path],"unchanged canonical/control source "+path)
	var original: ArrayMesh = load(OUT+"/before/game/assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver.res")
	var helmet: ArrayMesh = load("res://assets/vehicles/kart_refined_v1/tomkart_driver_v1/helmet_static.res")
	check(helmet.get_blend_shape_count()==0 and helmet.get_surface_count()==4,"helmet has four static finishes and no morph data")
	var omitted: int = 0
	for surface: int in range(4):
		check(helmet.surface_get_arrays(surface)==original.surface_get_arrays(surface+2),"unchanged complete helmet surface "+str(surface))
		omitted += original.get("_surfaces")[surface+2].blend_shapes.size()
		check(helmet.get("_surfaces")[surface].get("blend_shapes",PackedByteArray()).is_empty(),"static surface omits all redundant steering copies "+str(surface))
	check(omitted==495720,"exact 495720-byte omitted helmet morph allocation")
	var before_driver: String = FileAccess.get_sha256("res://assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver.res")
	var prepared: bool = "--prepared" in OS.get_cmdline_user_args()
	var base = preload("res://vehicle/modular_car_base.gd")
	base.enabled = prepared
	preload("res://vehicle/prepared_car_cache.gd").enabled = prepared
	preload("res://ui/garage_car_cache.gd").enabled = false
	for id: String in ["compact","kart","forklift","electric","hovercraft"]:
		preload("res://vehicle/prepared_car_cache.gd").entries.clear()
		var car := CarVisual.new()
		car.vehicle_id = id
		car.simple_model = true
		var before_hits: int = base.hits
		root.add_child(car)
		while not car.model_ready: await process_frame
		if prepared: check(base.hits==before_hits+1,"strict current prepared-base hit "+id)
		var triangles: int = 0
		var surfaces: int = 0
		var size: int = 0
		var unique: Dictionary = {}
		for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
			if part.mesh==null: continue
			if part.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY and part.is_visible_in_tree():
				triangles += part.mesh.get_faces().size()/3
				surfaces += part.mesh.get_surface_count()
			if part.mesh is ArrayMesh and not unique.has(part.mesh):
				size += bytes(part.mesh)
				unique[part.mesh] = true
				if prepared and id in ["compact","forklift"]:
					var packed: ArrayMesh = preload("res://rendering/mesh_vertex_packing.gd").pack(part.mesh)
					check(bytes(packed)==bytes(part.mesh),"published mesh has no remaining profitable encoded duplicates "+id+"/"+str(part.name))
		check(triangles>10000 and triangles<55000,"bounded complete production geometry "+id)
		if id=="kart":
			var driver: MeshInstance3D = car.find_child("TomkartDriver",true,false)
			var fixed: MeshInstance3D = driver.find_child("HelmetStatic",true,false)
			check(driver.mesh.get_surface_count()==2 and driver.mesh.get_blend_shape_count()==6,"live driver retains six glove/sleeve poses")
			check(fixed!=null and fixed.mesh.get_surface_count()==4,"live complete helmet remains attached")
			check(fixed.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"helmet keeps its live shadow")
			var state := VehicleState.new()
			for input: float in [-1.0,-0.5,0.0,0.5,1.0,0.0]:
				state.steering = input
				state.tick += 1
				car.present(Vector2.ZERO,0,state,DriveFrame.new())
				check(fixed.transform==Transform3D.IDENTITY,"steering leaves helmet position unchanged")
				var weight: float = 0
				for shape: int in range(6): weight += driver.get_blend_shape_value(shape)
				check(is_equal_approx(weight,minf(absf(input)*preload("res://vehicle/kart_steering.gd").STEPS,1.0)),"gloves/sleeves interpolate and centre")
		rows.append({"id":id,"triangles":triangles,"visible_surfaces":surfaces,"array_mesh_bytes":size})
		car.free()
		await process_frame
	check(before_driver==FileAccess.get_sha256("res://assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver.res"),"driver input remained stable through the integration check")
	FileAccess.open(OUT.path_join("live-prepared.json" if prepared else "live-direct.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows},"\t"))
	print("MODEL_REFINEMENT_LIVE ",checks," checks, ",failures," failures ",JSON.stringify(rows))
	quit(1 if failures else 0)
