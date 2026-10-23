extends "res://editor/placed_object_batches.gd"

func _model(kit: NativeTrackVisual, object: Dictionary, key: String) -> Dictionary:
	if models.has(key): return models[key]
	var prototype := BeforePropTrackVisual.new()
	prototype.theme_id = kit.theme_id
	prototype.colors = kit.colors
	prototype.editor_preview = true
	prototype.ground_support = kit.ground_support if key != "tyres" else null
	prototype._capture_editor_prop_arrays = true
	var track := NativeTrack.new()
	track.metadata = {"creator_document":{"objects":[object]},"scenery_objects":[]}
	track.tyre_origins = LooseTyres.positions(track.metadata.creator_document)
	prototype._build_placed_objects(track)
	var parts: Array = []
	var bytes: int = 0
	for child: Node in prototype.get_children():
		if child.is_in_group("contact_lighting"): continue
		var mesh: Mesh
		var pose: Transform3D
		if child is MeshInstance3D:
			mesh = child.mesh
			pose = child.transform
		elif child is MultiMeshInstance3D and child.multimesh.instance_count == 1:
			mesh = child.multimesh.mesh
			pose = child.transform*child.multimesh.get_instance_transform(0)
		else: continue
		for surface: int in range(mesh.get_surface_count()):
			bytes += mesh.surface_get_array_len(surface)*64+mesh.surface_get_array_index_len(surface)*4
		var baked: bool = child is MeshInstance3D
		if baked and child.has_meta("editor_prop_hidden"):
			bytes += child.get_meta("editor_prop_hidden").size()*16
		# Keep pre-upload normals. Decoding/re-encoding a compressed ArrayMesh
		# introduces an extra quantization step, visible in Mobile lighting.
		parts.append({"mesh":null if baked else mesh,"arrays":_baked_arrays(child) if baked else [],"hidden":child.get_meta("editor_prop_hidden",PackedInt32Array()),"bounds":mesh.get_aabb(),"baked":baked,"pose":pose,"material":child.material_override,"cast_shadow":child.cast_shadow,"layers":child.layers,"name":str(child.name),"contact":false})
	prototype.free()
	var result: Dictionary = {"parts":parts,"bytes":bytes}
	if bytes <= MODEL_BUDGET:
		while not models.is_empty() and (models.size() >= MODEL_LIMIT or model_bytes+bytes > MODEL_BUDGET):
			var expired: String = models.keys()[0]
			model_bytes -= int(models[expired].bytes)
			models.erase(expired)
		models[key] = result
		model_bytes += bytes
	return result
