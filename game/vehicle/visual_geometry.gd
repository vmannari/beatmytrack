class_name VisualGeometry
extends RefCounted
## Original procedural stand-ins. Geometry never supplies simulation collisions.

static func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 1.0
	result.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	result.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return result


static func batch_static_parts(parent: Node3D) -> void:
	# Keep body suspension, steering pivots and wheel-spin transforms separate.
	# Only siblings with the same material and shadow mode are combined.
	var groups: Dictionary = {}
	for child: Node in parent.get_children():
		if child is Node3D: batch_static_parts(child)
		if not child is MeshInstance3D or child.get_child_count() != 0: continue
		var part := child as MeshInstance3D
		if not part.visible or part.mesh == null or part.mesh.get_surface_count() != 1: continue
		var surface: Material = part.get_active_material(0)
		if surface == null: continue
		# Indexed and non-indexed surfaces cannot share one append stream:
		# otherwise existing indices omit the appended non-indexed triangles.
		var arrays: Array = part.mesh.surface_get_arrays(0)
		var format_key: String = ""
		for attribute: Variant in arrays:
			format_key += "0" if attribute == null else "1"
		var key: String = "%d:%d:%s" % [surface.get_instance_id(),part.cast_shadow,format_key]
		if not groups.has(key): groups[key] = []
		groups[key].append(part)
	for key: String in groups:
		var parts: Array = groups[key]
		if parts.size() < 2: continue
		var first := parts[0] as MeshInstance3D
		var tool := SurfaceTool.new()
		for part: MeshInstance3D in parts:
			tool.append_from(part.mesh,0,part.transform)
		var combined := MeshInstance3D.new()
		combined.name = "BatchedParts"
		combined.mesh = tool.commit()
		combined.material_override = first.get_active_material(0)
		combined.cast_shadow = first.cast_shadow
		parent.add_child(combined)
		for part: MeshInstance3D in parts:
			parent.remove_child(part)
			part.queue_free()


static func ink(surface: Material) -> void:
	var outline := ShaderMaterial.new()
	outline.shader = preload("res://track/ink.gdshader")
	surface.next_pass = outline


static func box(parent: Node3D, dimensions: Vector3, center: Vector3, surface: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	node.mesh = mesh
	node.material_override = surface
	node.position = center
	parent.add_child(node)
	return node


static func cylinder(parent: Node3D, radius: float, height: float, center: Vector3, surface: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	node.mesh = mesh
	node.material_override = surface
	node.position = center
	parent.add_child(node)
	return node


static func ring(parent: Node3D, center: Vector3, radius: float, width: float, surface: Material) -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, surface)
	for index: int in range(96):
		var a: float = TAU * index / 96.0
		var b: float = TAU * (index + 1) / 96.0
		var inner_a: Vector3 = center + Vector3(sin(a), 0, cos(a)) * (radius - width * 0.5)
		var outer_a: Vector3 = center + Vector3(sin(a), 0, cos(a)) * (radius + width * 0.5)
		var inner_b: Vector3 = center + Vector3(sin(b), 0, cos(b)) * (radius - width * 0.5)
		var outer_b: Vector3 = center + Vector3(sin(b), 0, cos(b)) * (radius + width * 0.5)
		for vertex: Vector3 in [inner_a, outer_b, outer_a, inner_a, inner_b, outer_b]:
			mesh.surface_set_normal(Vector3.UP)
			mesh.surface_add_vertex(vertex)
	mesh.surface_end()
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	parent.add_child(instance)


static func world(point: Vector2) -> Vector3:
	return Vector3(point.x, 0.0, -point.y)
