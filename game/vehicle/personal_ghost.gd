class_name PersonalGhost
extends MeshInstance3D
## One non-colliding mesh, with the rewind silhouette treatment in neutral grey.
func configure(car: CarVisual) -> void:
	mesh = mesh_for(car)
	scale = car.scale
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var surface := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded, blend_mix, cull_back; void fragment(){ float edge=pow(1.0-abs(dot(NORMAL,VIEW)),2.0); ALBEDO=mix(vec3(0.30,0.32,0.34),vec3(0.78,0.80,0.82),edge); ALPHA=0.18+edge*0.43; }"
	surface.shader = shader
	material_override = surface
	hide()

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

static func _append_meshes(node: Node, inverse: Transform3D, tool: SurfaceTool) -> void:
	if node is MeshInstance3D and node.is_visible_in_tree() and node.mesh != null:
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
