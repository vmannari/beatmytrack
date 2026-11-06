extends Node
## Stage first use of actual material/mesh combinations under the loading cover.
## Lifetime belongs to Game, so navigation cannot leave hidden surviving meshes.
static var warmed: Dictionary = {}
# Insertion order retains the original first-seen program order; each bucket
# is consumed from the end, just like the former reverse scan of all nodes.
var pending: Dictionary = {}
var _pending_keys: Array[String] = []
var _key_cursor: int = 0
var frame_groups: int = 0
var draw_us_max: int = 0
var _material_keys: Dictionary = {}

func hold(world: Node) -> void:
	for geometry: GeometryInstance3D in world.find_children("*","GeometryInstance3D",true,false):
		if not geometry.is_visible_in_tree(): continue
		var key: String = _key(geometry,_material_keys)
		if warmed.has(key): continue
		if not pending.has(key):
			pending[key] = []
			_pending_keys.append(key)
		pending[key].append(weakref(geometry))
		geometry.hide()

func prepare(draw: Callable, current: Callable) -> bool:
	while not pending.is_empty():
		if not current.call(): return false
		while not pending.has(_pending_keys[_key_cursor]): _key_cursor += 1
		var key: String = _pending_keys[_key_cursor]
		var bucket: Array = pending[key]
		var shown: int = 0
		var margins: Array[Dictionary] = []
		var camera: Camera3D = get_parent().get("camera")
		while not bucket.is_empty() and shown < 8:
			var node: Object = bucket.pop_back().get_ref()
			if is_instance_valid(node):
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
		draw_us_max = maxi(draw_us_max,Time.get_ticks_usec()-began)
		frame_groups += 1
		if drawn:
			if warmed.size() >= 512: warmed.clear()
			warmed[key] = true
			# One bounded batch has submitted this exact program/format/shadow
			# combination. Remaining instances need visibility, not another draw
			# of the same compiled program. The final covered world draw remains.
			while not bucket.is_empty():
				var node: Object = bucket.pop_back().get_ref()
				if is_instance_valid(node): node.show()
			pending.erase(key)
	_material_keys.clear()
	_pending_keys.clear()
	_key_cursor = 0
	return current.call()

static func _key(node: GeometryInstance3D, materials: Dictionary = {}) -> String:
	var mesh: Mesh = node.mesh if node is MeshInstance3D else node.multimesh.mesh if node is MultiMeshInstance3D and node.multimesh != null else null
	var parts: Array = [node.get_class(),node.cast_shadow,node.layers]
	if mesh != null:
		for surface: int in range(mesh.get_surface_count()):
			var material: Material = node.get_active_material(surface) if node is MeshInstance3D else node.material_override if node.material_override != null else mesh.surface_get_material(surface)
			# Identity inspection must not force lazy backend shader creation here.
			parts.append(_material_key(material,materials))
			parts.append(mesh.surface_get_format(surface) if mesh is ArrayMesh else mesh.get_class())
	return str(parts)

static func _material_key(material: Material, cache: Dictionary) -> String:
	if material == null: return "none"
	var id: int = material.get_instance_id()
	if cache.has(id): return cache[id]
	var features: Array = [material.get_class()]
	if material is ShaderMaterial:
		features.append(material.shader.get_instance_id() if material.shader != null else 0)
	elif material is BaseMaterial3D:
		for property: Dictionary in material.get_property_list():
			if not int(property.usage)&PROPERTY_USAGE_STORAGE: continue
			if property.name in ["resource_local_to_scene","resource_name","resource_path","next_pass"]: continue
			var value: Variant = material.get(property.name)
			if value is bool or value is int: features.append([property.name,value])
			elif property.hint == PROPERTY_HINT_RESOURCE_TYPE and "Texture" in str(property.hint_string): features.append([property.name,value != null])
	else: features.append(id)
	features.append(_material_key(material.next_pass,cache))
	var result: String = str(features).sha256_text()
	cache[id] = result
	return result

func _exit_tree() -> void:
	for bucket: Array in pending.values():
		for reference: WeakRef in bucket:
			var node: Object = reference.get_ref()
			if is_instance_valid(node): node.show()
	pending.clear()
	_pending_keys.clear()
	_key_cursor = 0
	_material_keys.clear()
