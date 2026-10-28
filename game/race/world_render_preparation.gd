extends Node
## Stage first use of actual material/mesh combinations under the loading cover.
## Lifetime belongs to Game, so navigation cannot leave hidden surviving meshes.
static var warmed: Dictionary = {}
var pending: Array[Dictionary] = []
var frame_groups: int = 0
var draw_us_max: int = 0

func hold(world: Node) -> void:
	for geometry: GeometryInstance3D in world.find_children("*","GeometryInstance3D",true,false):
		if not geometry.is_visible_in_tree(): continue
		var key: String = _key(geometry)
		if warmed.has(key): continue
		pending.append({"node":weakref(geometry),"key":key})
		geometry.hide()

func prepare(draw: Callable, current: Callable) -> bool:
	while not pending.is_empty():
		if not current.call(): return false
		var key: String = str(pending[0].key)
		var shown: int = 0
		var margins: Array[Dictionary] = []
		var camera: Camera3D = get_parent().get("camera")
		for index: int in range(pending.size()-1,-1,-1):
			if pending[index].key != key or shown >= 8: continue
			var node: Object = pending[index].node.get_ref()
			if is_instance_valid(node):
				if node is MeshInstance3D and camera != null:
					margins.append({"node":weakref(node),"margin":node.extra_cull_margin})
					var bounds: AABB = node.get_aabb()
					var distance: Vector3 = (node.to_local(camera.global_position)-bounds.get_center()).abs()
					node.extra_cull_margin = maxf(node.extra_cull_margin,maxf(distance.x,maxf(distance.y,distance.z))+camera.near+1.0)
				node.show()
			pending.remove_at(index); shown += 1
		var began: int = Time.get_ticks_usec()
		var drawn: bool = await draw.call()
		for entry: Dictionary in margins:
			var node: Object = entry.node.get_ref()
			if is_instance_valid(node): node.extra_cull_margin = entry.margin
		if not current.is_valid() or not current.call(): return false
		draw_us_max = maxi(draw_us_max,Time.get_ticks_usec()-began)
		frame_groups += 1
		if drawn:
			if warmed.size() >= 512: warmed.clear()
			warmed[key] = true
	return current.call()

static func _key(node: GeometryInstance3D) -> String:
	var mesh: Mesh = node.mesh if node is MeshInstance3D else node.multimesh.mesh if node is MultiMeshInstance3D and node.multimesh != null else null
	var parts: Array = [node.get_class(),node.cast_shadow]
	if mesh != null:
		for surface: int in range(mesh.get_surface_count()):
			var material: Material = node.get_active_material(surface) if node is MeshInstance3D else node.material_override if node.material_override != null else mesh.surface_get_material(surface)
			# Identity inspection must not force lazy backend shader creation here.
			parts.append(material.shader.get_instance_id() if material is ShaderMaterial and material.shader != null else material.get_instance_id() if material != null else 0)
			parts.append(mesh.surface_get_format(surface) if mesh is ArrayMesh else mesh.get_class())
	return str(parts)

func _exit_tree() -> void:
	for entry: Dictionary in pending:
		var node: Object = entry.node.get_ref()
		if is_instance_valid(node): node.show()
	pending.clear()
