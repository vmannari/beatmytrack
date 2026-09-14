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
