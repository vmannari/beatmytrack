class_name PersonalGhost
extends MeshInstance3D
## One non-colliding mesh, with the rewind silhouette treatment in neutral grey.
const MAX_BYTES: int = 16 * 1024 * 1024
static var prepared_meshes: Array[Dictionary] = []
func configure(car: CarVisual, prepare_mesh: bool = true) -> void:
	if prepare_mesh: _prepare_mesh(car)
	scale = car.scale
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var surface := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded, blend_mix, cull_back; void fragment(){ float edge=pow(1.0-abs(dot(NORMAL,VIEW)),2.0); ALBEDO=mix(vec3(0.30,0.32,0.34),vec3(0.78,0.80,0.82),edge); ALPHA=0.18+edge*0.43; }"
	surface.shader = shader
	material_override = surface
	hide()

func _prepare_mesh(car: CarVisual) -> void:
	var key: Array = preload("res://vehicle/prepared_car_cache.gd").key_for(car)
	for index: int in range(prepared_meshes.size()):
		if prepared_meshes[index].key != key: continue
		var entry: Dictionary = prepared_meshes.pop_at(index)
		prepared_meshes.append(entry)
		mesh = entry.mesh
		break
	if mesh == null:
		var rest: Node3D = preload("res://vehicle/prepared_car_cache.gd").rest_scene(car)
		if rest == null: mesh = mesh_for(car)
		else:
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			_append_local(rest,car.global_transform,car.global_transform.affine_inverse(),tool)
			tool.generate_normals()
			mesh = tool.commit()
			rest.free()
		var bytes: int = (mesh as ArrayMesh).surface_get_array_len(0)*24
		if bytes <= MAX_BYTES:
			var total: int = bytes
			for entry: Dictionary in prepared_meshes: total += int(entry.bytes)
			while not prepared_meshes.is_empty() and (prepared_meshes.size() >= 4 or total > MAX_BYTES): total -= int(prepared_meshes.pop_front().bytes)
			prepared_meshes.append({"key":key,"mesh":mesh,"bytes":bytes})

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
