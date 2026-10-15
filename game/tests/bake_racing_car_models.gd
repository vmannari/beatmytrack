extends SceneTree
## Explicit offline bake from the original authored car shapes, using the pinned engine.
func _initialize() -> void: _bake.call_deferred()

func _bake() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RacingCarModels.COACH_ROOT))
	CompactCoachwork.use_baked = false
	CompactCoachwork.meshes.clear()
	var glazing = preload("res://vehicle/compact_glazing.gd")
	glazing.use_baked = false
	glazing.sheets.clear()
	var report: Dictionary = {"engine":Engine.get_version_info().string,"provenance":"Reduced sampling of original authored car shapes; offline positions-only shadow LODs.","cars":{}}
	var front_only: bool = "--compact-front-only" in OS.get_cmdline_user_args()
	if front_only: report = JSON.parse_string(FileAccess.get_file_as_string(RacingCarModels.ASSET_ROOT.path_join("manifest.json")))
	for id: String in VehicleCatalog.IDS:
		if front_only and id!="compact": continue
		var car := CarVisual.new()
		car.vehicle_id = id
		car.simple_model = true
		root.add_child(car)
		var frames: Array[Node3D] = [car.body]
		frames.append_array(car.rolling_wheels)
		var details: Array[Dictionary] = []
		if front_only: details.assign(report.cars.compact)
		for index: int in range(frames.size()):
			if front_only and index!=0: continue
			var source: ArrayMesh = RacingCarModels.shadow_source(frames[index])
			var arrays: Array = source.surface_get_arrays(0)
			var original_count: int = arrays[Mesh.ARRAY_INDEX].size()/3
			var importer := ImporterMesh.new()
			importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays)
			importer.generate_lods(60.0,0.0,[])
			var target: int = 1800 if index == 0 else 160
			var chosen: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var error: float = 0.0
			for lod: int in range(importer.get_surface_lod_count(0)):
				if chosen.size()/3 <= target: break
				var candidate: PackedInt32Array = importer.get_surface_lod_indices(0,lod)
				if candidate.size() < chosen.size():
					chosen = candidate
					error = importer.get_surface_lod_size(0,lod)
				if chosen.size()/3 <= target: break
			# Compact unused vertices in the exported shadow mesh, rather than
			# retaining the large authored buffer behind a shorter index array.
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
			var path: String = RacingCarModels.ASSET_ROOT.path_join(id+"_shadow_"+str(index)+".res")
			assert(ResourceSaver.save(mesh,path,ResourceSaver.FLAG_COMPRESS) == OK)
			var detail: Dictionary = {"frame":index,"source_triangles":original_count,"triangles":chosen.size()/3,"lod_error":error,"vertices":compact.size()}
			if front_only: details[index] = detail
			else: details.append(detail)
		report.cars[id] = details
		print("RACING_SHADOW_BAKE ",id," ",details)
		car.queue_free()
		await process_frame
	var resources: Dictionary = CompactCoachwork.meshes.duplicate()
	resources.merge(glazing.sheets)
	var bytes: int = 0
	var count: int = 0
	for key: String in resources:
		if not key.ends_with("_simple"): continue
		var path: String = RacingCarModels.COACH_ROOT.path_join(key+".res")
		if not front_only or key=="front_coachwork_simple": assert(ResourceSaver.save(resources[key],path,ResourceSaver.FLAG_COMPRESS) == OK)
		bytes += FileAccess.get_file_as_bytes(path).size()
		count += 1
	report.compact_meshes = count
	report.compact_mesh_bytes = bytes
	FileAccess.open(RacingCarModels.ASSET_ROOT.path_join("manifest.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("RACING_MODEL_BAKE ",count," compact resources, ",bytes," bytes")
	quit()
