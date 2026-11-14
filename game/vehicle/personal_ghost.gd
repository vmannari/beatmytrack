class_name PersonalGhost
extends MeshInstance3D
## One non-colliding mesh, with the rewind silhouette treatment in neutral grey.
const MAX_BYTES: int = 16 * 1024 * 1024
static var prepared_meshes: Array[Dictionary] = []
static var _finish_shader: Shader

static func finish_shader() -> Shader:
	# Keep the native program alive between race owners. Materials stay private.
	if _finish_shader == null:
		_finish_shader = Shader.new()
		_finish_shader.code = "shader_type spatial; render_mode unshaded, blend_mix, cull_back; void fragment(){ float edge=pow(1.0-abs(dot(NORMAL,VIEW)),2.0); ALBEDO=mix(vec3(0.30,0.32,0.34),vec3(0.78,0.80,0.82),edge); ALPHA=0.18+edge*0.43; }"
	return _finish_shader

func configure(car: CarVisual, prepare_mesh: bool = true) -> void:
	if prepare_mesh: _prepare_mesh(car)
	scale = car.scale
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var surface := ShaderMaterial.new()
	surface.shader = finish_shader()
	material_override = surface
	hide()

func _prepare_mesh(car: CarVisual) -> void:
	var key: Array = ["indexed-ghost-1"]
	key.append_array(preload("res://vehicle/prepared_car_cache.gd").key_for(car))
	for index: int in range(prepared_meshes.size()):
		if prepared_meshes[index].key != key: continue
		var entry: Dictionary = prepared_meshes.pop_at(index)
		prepared_meshes.append(entry)
		mesh = entry.mesh
		break
	if mesh == null:
		var rest: Node3D = preload("res://vehicle/prepared_car_cache.gd").rest_scene(car)
		if rest == null: rest = _modular_rest_scene(car)
		if rest == null: mesh = mesh_for(car)
		else:
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			# Reproduce the construction-time model scale without using the live
			# car's position or rotation. This also preserves the original order of
			# floating-point operations when flattening the rest-pose geometry.
			var canonical := Transform3D(Basis.from_scale(car.scale),Vector3.ZERO)
			_append_local(rest,canonical,canonical.affine_inverse(),tool)
			tool.generate_normals()
			tool.index()
			mesh = tool.commit()
			rest.free()
		var bytes: int = (mesh as ArrayMesh).surface_get_array_len(0)*24+(mesh as ArrayMesh).surface_get_array_index_len(0)*4
		if bytes <= MAX_BYTES:
			var total: int = bytes
			for entry: Dictionary in prepared_meshes: total += int(entry.bytes)
			while not prepared_meshes.is_empty() and (prepared_meshes.size() >= 4 or total > MAX_BYTES): total -= int(prepared_meshes.pop_front().bytes)
			prepared_meshes.append({"key":key,"mesh":mesh,"bytes":bytes})

static func _modular_rest_scene(car: CarVisual) -> Node3D:
	# Modular cars bypass the in-memory rest template. Build a detached copy from
	# the same immutable modules so late ghost activation cannot capture the
	# live car's steering, suspension, wheel rotation or world transform.
	var rest := CarVisual.new()
	rest.vehicle_id = car.vehicle_id
	rest.simple_model = car.simple_model
	rest.editable_kits = car.editable_kits
	rest.batch_parts = car.batch_parts
	rest.customisation = car.customisation.duplicate(true)
	if rest._restore_modular_model(): return rest
	rest.free()
	return null

func present(pose: Array) -> void:
	visible = not pose.is_empty()
	if not visible: return
	position = Vector3(pose[1], pose[3] + 0.05, -pose[2])
	rotation = Vector3(pose[5], -pose[4], pose[6])

static func mesh_for(car: CarVisual) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_meshes(car, car.global_transform.affine_inverse(), tool)
	tool.generate_normals()
	tool.index()
	return tool.commit()

static func _append_local(node: Node3D, transform: Transform3D, inverse: Transform3D, tool: SurfaceTool) -> void:
	if not node.visible: return
	if node is MeshInstance3D and node.mesh != null and node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
		var relative: Transform3D = inverse*transform
		for surface: int in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if indices.is_empty():
				for vertex: Vector3 in vertices: tool.add_vertex(relative*vertex)
			else:
				for index: int in indices: tool.add_vertex(relative*vertices[index])
	for child: Node3D in node.get_children(): _append_local(child,transform*child.transform,inverse,tool)

static func _append_meshes(node: Node, inverse: Transform3D, tool: SurfaceTool) -> void:
	if node is MeshInstance3D and node.is_visible_in_tree() and node.mesh != null and node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
		for surface: int in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var transform: Transform3D = inverse * node.global_transform
			if indices.is_empty():
				for vertex: Vector3 in vertices: tool.add_vertex(transform * vertex)
			else:
				for index: int in indices: tool.add_vertex(transform * vertices[index])
	for child: Node in node.get_children(): _append_meshes(child, inverse, tool)
