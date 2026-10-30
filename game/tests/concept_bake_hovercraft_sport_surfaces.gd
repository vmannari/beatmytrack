extends SceneTree
## Native offline bake with exact round-trip verification of every authored mesh.
const Surface = preload("res://vehicle/hovercraft_sport_surface.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	preload("res://ui/garage_car_cache.gd").enabled = false
	Surface.use_baked = false
	Surface.meshes.clear()
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "hovercraft"
		car.simple_model = simple
		car.cache_rest_pose = false
		root.add_child(car)
		while not car.model_ready: await process_frame
		car.free()
	DirAccess.make_dir_recursive_absolute(Surface.ASSET_ROOT)
	var expected: Dictionary = Surface.meshes.duplicate()
	var rows: Array = []
	for key: String in expected:
		var mesh: ArrayMesh = expected[key]
		mesh.set_meta("hovercraft_sources",Surface.signature())
		var path: String = Surface.ASSET_ROOT.path_join(key+".res")
		assert(ResourceSaver.save(mesh,path,ResourceSaver.FLAG_COMPRESS) == OK)
		rows.append({"path":path,"sha256":FileAccess.get_sha256(path)})
	Surface.meshes.clear()
	Surface.use_baked = true
	for key: String in expected:
		var saved: ArrayMesh = Surface._cached(key)
		assert(saved != null and saved.get_meta("hovercraft_sources") == Surface.signature())
		assert(saved.get_surface_count() == 1 and saved.surface_get_material(0) == null)
		assert(saved.surface_get_arrays(0) == expected[key].surface_get_arrays(0))
	var file := FileAccess.open("res://../docs/evidence/hovercraft-concept-2026-10-29/surfaces.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"arrays_exact":rows.size(),"sources":Surface.signature(),"resources":rows},"\t"))
	file.close()
	print("HOVERCRAFT_SPORT_SURFACES: ",rows.size()," exact saved resources with private material slots")
	quit()
