extends SceneTree
## Offline original full/racing meshes and matching articulated shadow proxies.
const G = preload("res://vehicle/kart_geometry.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	G.use_baked = false
	G.meshes.clear()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(G.ROOT))
	var shadows: Array[Dictionary] = []
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "kart"
		car.simple_model = simple
		car.batch_parts = false
		root.add_child(car)
		if simple:
			var frames: Array[Node3D] = [car.body]
			frames.append_array(car.rolling_wheels)
			for index: int in range(frames.size()):
				var source: ArrayMesh = RacingCarModels.shadow_source(frames[index])
				var arrays: Array = source.surface_get_arrays(0)
				var importer := ImporterMesh.new()
				importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays)
				importer.generate_lods(60,0,[])
				var chosen: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				for lod: int in range(importer.get_surface_lod_count(0)):
					if chosen.size()/3 <= (1800 if index == 0 else 160): break
					var candidate: PackedInt32Array = importer.get_surface_lod_indices(0,lod)
					if candidate.size()<chosen.size(): chosen=candidate
				var compact := PackedVector3Array()
				var mapping: Dictionary = {}
				var original: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				for corner: int in range(chosen.size()):
					var vertex: int = chosen[corner]
					if not mapping.has(vertex):
						mapping[vertex] = compact.size()
						compact.append(original[vertex])
					chosen[corner] = mapping[vertex]
				arrays[Mesh.ARRAY_VERTEX] = compact
				arrays[Mesh.ARRAY_INDEX] = chosen
				var mesh := ArrayMesh.new()
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
				mesh.custom_aabb = source.get_aabb()
				var path: String = RacingCarModels.ASSET_ROOT.path_join("kart_shadow_"+str(index)+".res")
				assert(ResourceSaver.save(mesh,path,ResourceSaver.FLAG_COMPRESS) == OK)
				shadows.append({"frame":index,"triangles":chosen.size()/3,"source_triangles":source.get_faces().size()/3})
		car.free()
	var entries: Array[Dictionary] = []
	for key: String in G.meshes:
		var file: String = key.sha256_text().left(24)+".res"
		assert(ResourceSaver.save(G.meshes[key],G.ROOT.path_join(file),ResourceSaver.FLAG_COMPRESS) == OK)
		entries.append({"key":key,"file":file,"triangles":G.meshes[key].get_faces().size()/3})
	FileAccess.open(G.ROOT+"/manifest.json",FileAccess.WRITE).store_string(JSON.stringify({"provenance":"Original authored unbranded Beat my track kart; shared CompactFinish materials. No external or generated model.","geometry_sha256":FileAccess.get_sha256("res://vehicle/kart_geometry.gd"),"model_sha256":FileAccess.get_sha256("res://vehicle/kart_model.gd"),"helmet_sha256":FileAccess.get_sha256("res://vehicle/kart_helmet.gd"),"shadows":shadows,"meshes":entries},"\t"))
	print("KART_BAKE: ",entries.size()," meshes; matching shadows ",JSON.stringify(shadows))
	quit()
