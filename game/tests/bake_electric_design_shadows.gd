extends SceneTree
## Refresh only this model's five shadow proxies; preserve other cars' resources.
func _initialize() -> void: run.call_deferred()

func run() -> void:
	preload("res://ui/garage_car_cache.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	var car := CarVisual.new()
	car.vehicle_id = "electric"
	car.simple_model = true
	car.batch_parts = false
	car.cache_rest_pose = false
	root.add_child(car)
	while not car.model_ready: await process_frame
	var frames: Array[Node3D] = [car.body]
	frames.append_array(car.rolling_wheels)
	var details: Array[Dictionary] = []
	for index: int in range(frames.size()):
		var source: ArrayMesh = RacingCarModels.shadow_source(frames[index])
		var arrays: Array = source.surface_get_arrays(0)
		var original_count: int = arrays[Mesh.ARRAY_INDEX].size()/3
		var importer := ImporterMesh.new()
		importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays)
		importer.generate_lods(60.0,0.0,[])
		var target: int = 1800 if index == 0 else 160
		var chosen: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var error: float = 0
		for lod: int in range(importer.get_surface_lod_count(0)):
			if chosen.size()/3<=target: break
			var candidate: PackedInt32Array = importer.get_surface_lod_indices(0,lod)
			if candidate.size()<chosen.size():
				chosen = candidate
				error = importer.get_surface_lod_size(0,lod)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var compact := PackedVector3Array()
		var mapped: Dictionary = {}
		for corner: int in range(chosen.size()):
			var vertex: int = chosen[corner]
			if not mapped.has(vertex):
				mapped[vertex] = compact.size()
				compact.append(vertices[vertex])
			chosen[corner] = mapped[vertex]
		arrays[Mesh.ARRAY_VERTEX] = compact
		arrays[Mesh.ARRAY_INDEX] = chosen
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		mesh.custom_aabb = source.get_aabb()
		var path: String = RacingCarModels.ASSET_ROOT.path_join("electric_shadow_"+str(index)+".res")
		assert(ResourceSaver.save(mesh,path,ResourceSaver.FLAG_COMPRESS) == OK)
		details.append({"frame":index,"source_triangles":original_count,"triangles":chosen.size()/3,"lod_error":error,"vertices":compact.size()})
	var path: String = RacingCarModels.ASSET_ROOT.path_join("manifest.json")
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	report.cars.electric = details
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("ELECTRIC_DESIGN_SHADOWS: ",JSON.stringify(details))
	quit()
