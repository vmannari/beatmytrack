extends "res://race/world_render_preparation.gd"
## Diagnostic-only override of prepare(); hold() and the cache key are original.
var group_samples: Array[Dictionary] = []
var captured_pending: int = 0

func prepare(draw: Callable, current: Callable) -> bool:
	while not pending.is_empty():
		if not current.call(): return false
		while not pending.has(_pending_keys[_key_cursor]): _key_cursor += 1
		var key: String = _pending_keys[_key_cursor]
		var bucket: Array = pending[key]
		var original_count: int = bucket.size()
		var shown: int = 0
		var margins: Array[Dictionary] = []
		var descriptors: Array = []
		var camera: Camera3D = get_parent().get("camera")
		while not bucket.is_empty() and shown < 8:
			var node: Object = bucket.pop_back().get_ref()
			if is_instance_valid(node):
				descriptors.append(describe(node))
				if node is MeshInstance3D and camera != null:
					margins.append({"node":weakref(node),"margin":node.extra_cull_margin})
					var bounds: AABB = node.get_aabb()
					var distance: Vector3 = (node.to_local(camera.global_position)-bounds.get_center()).abs()
					node.extra_cull_margin = maxf(node.extra_cull_margin,maxf(distance.x,maxf(distance.y,distance.z))+camera.near+1.0)
				node.show()
				shown += 1
		if bucket.is_empty(): pending.erase(key)
		if shown == 0: continue
		var began: int = Time.get_ticks_usec()
		var drawn: bool = await draw.call()
		for entry: Dictionary in margins:
			var node: Object = entry.node.get_ref()
			if is_instance_valid(node): node.extra_cull_margin = entry.margin
		if not current.is_valid() or not current.call(): return false
		var elapsed: int = Time.get_ticks_usec()-began
		draw_us_max = maxi(draw_us_max,elapsed)
		frame_groups += 1
		group_samples.append({"key":key,"total_nodes":original_count,"shown":shown,"wait_us":elapsed,"drawn":drawn,"nodes":descriptors})
		if drawn:
			if warmed.size() >= 512: warmed.clear()
			warmed[key] = true
			while not bucket.is_empty():
				var node: Object = bucket.pop_back().get_ref()
				if is_instance_valid(node): node.show()
			pending.erase(key)
	_material_keys.clear()
	_pending_keys.clear()
	_key_cursor = 0
	return current.call()

func describe(node: GeometryInstance3D) -> Dictionary:
	var mesh: Mesh = node.mesh if node is MeshInstance3D else node.multimesh.mesh if node is MultiMeshInstance3D and node.multimesh != null else null
	var data: Dictionary = {"name":node.name,"path":str(node.get_path()),"class":node.get_class(),"shadow":node.cast_shadow,"layers":node.layers,"materials":[]}
	if mesh == null: return data
	data.mesh_class = mesh.get_class()
	data.mesh_path = mesh.resource_path
	for surface: int in range(mesh.get_surface_count()):
		var mat: Material = node.get_active_material(surface) if node is MeshInstance3D else node.material_override if node.material_override != null else mesh.surface_get_material(surface)
		var info: Dictionary = {"class":mat.get_class() if mat != null else "none","path":mat.resource_path if mat != null else ""}
		info.mesh_format = mesh.surface_get_format(surface) if mesh is ArrayMesh else mesh.get_class()
		if mat is ShaderMaterial and mat.shader != null:
			info.shader_path = mat.shader.resource_path
			info.shader_sha256 = mat.shader.code.sha256_text()
			info.shader_instance = mat.shader.get_instance_id()
		data.materials.append(info)
	return data
