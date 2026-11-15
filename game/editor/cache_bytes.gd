extends RefCounted
## Conservative CPU/GPU stream estimates; never read back textures to count them.
static func mesh(value: Mesh) -> int:
	var bytes: int = 0
	for surface: int in range(value.get_surface_count()):
		if value is ArrayMesh:
			bytes += value.surface_get_array_len(surface)*128+value.surface_get_array_index_len(surface)*8
		else:
			var arrays: Array = value.surface_get_arrays(surface)
			bytes += arrays[Mesh.ARRAY_VERTEX].size()*128
			if arrays[Mesh.ARRAY_INDEX] != null: bytes += arrays[Mesh.ARRAY_INDEX].size()*8
	return bytes+int(value.get_meta("scenery_lod_bytes",0))+int(value.get_meta("scenery_lod_plan_bytes",0))

static func scene(node: Node, seen: Dictionary = {}, excluded: Dictionary = {}) -> int:
	if excluded.has(node.get_instance_id()): return 0
	var bytes: int = 256
	var value: Mesh = node.mesh if node is MeshInstance3D else node.multimesh.mesh if node is MultiMeshInstance3D and node.multimesh != null else null
	if value != null and not seen.has(value.get_instance_id()):
		seen[value.get_instance_id()] = true; bytes += mesh(value)
	if node is MultiMeshInstance3D and node.multimesh != null: bytes += node.multimesh.instance_count*96
	if "_editor_authored_batches" in node and node._editor_authored_batches != null:
		var batches: RefCounted = node._editor_authored_batches
		# Active models remain referenced when the idle LRU is trimmed.
		bytes += maxi(batches.model_bytes,batches.active_model_bytes)+batches.shared_vertex_bytes
	if node is GeometryInstance3D and node.material_override is ShaderMaterial and not seen.has(node.material_override.get_instance_id()):
		var material: ShaderMaterial = node.material_override
		seen[material.get_instance_id()] = true
		for uniform: Dictionary in material.shader.get_shader_uniform_list():
			var texture: Variant = material.get_shader_parameter(uniform.name)
			if texture is Texture2D and texture.resource_path.is_empty() and not seen.has(texture.get_instance_id()):
				seen[texture.get_instance_id()] = true; bytes += texture.get_width()*texture.get_height()*16
	for child: Node in node.get_children(): bytes += scene(child,seen,excluded)
	return bytes
