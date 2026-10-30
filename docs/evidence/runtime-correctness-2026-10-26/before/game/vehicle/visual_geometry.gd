class_name VisualGeometry
extends RefCounted
## Original procedural stand-ins. Geometry never supplies simulation collisions.
static var optimize_model_geometry: bool = true
static var cylinder_meshes: Dictionary = {}

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
		if optimize_model_geometry:tool.index()
		var combined := MeshInstance3D.new()
		combined.name = "BatchedParts"
		combined.mesh = tool.commit()
		combined.material_override = first.get_active_material(0)
		combined.cast_shadow = first.cast_shadow
		parent.add_child(combined)
		for part: MeshInstance3D in parts:
			parent.remove_child(part)
			part.queue_free()


static func batch_car_parts(car: CarVisual) -> void:
	# Merge matching fixed parts in each existing GPU transform frame. Steering,
	# sprung body, wheel rolling and positioned details keep their live nodes.
	var frames: Array[Node3D] = [car,car.body]
	for category: String in car.kit_frames:
		for frame: Node3D in car.kit_frames[category]: frames.append(frame)
	for rotor: Node3D in car.rolling_wheels:
		frames.append(rotor.get_parent())
		frames.append(rotor)
	_collect_transform_frames(car,frames)
	var protected: Array[Material] = [car.brake_material,car.accent_roof]
	for material: Material in car.paint_materials.values(): protected.append(material)
	for variant: Dictionary in car.paint_variants: protected.append(variant.material)
	var fixed_materials: Dictionary = {}
	for frame: Node3D in frames:
		var parts: Array[MeshInstance3D] = []
		_collect_fixed_parts(frame,frames,parts)
		var groups: Dictionary = {}
		for part: MeshInstance3D in parts:
			var surface: Material = part.get_active_material(0)
			if surface is StandardMaterial3D and surface not in protected:
				var values: Array = []
				for property: Dictionary in surface.get_property_list():
					if not (int(property.usage)&PROPERTY_USAGE_STORAGE) or str(property.name).begins_with("resource_"): continue
					values.append([property.name,surface.get(property.name)])
				var material_key: String = var_to_bytes(values).hex_encode()
				if not fixed_materials.has(material_key): fixed_materials[material_key] = surface
				surface = fixed_materials[material_key]
			var arrays: Array = part.mesh.surface_get_arrays(0)
			var normalize_uv: bool = _untextured_standard(surface)
			var format_key: String = ""
			for index: int in range(Mesh.ARRAY_INDEX):
				format_key += "1" if normalize_uv and index in [Mesh.ARRAY_TANGENT,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2] else "0" if arrays[index] == null else "1"
			var key: String = "%d:%d:%d:%s" % [surface.get_instance_id(),part.cast_shadow,part.layers,format_key]
			if not groups.has(key): groups[key] = {"material":surface,"parts":[],"normalize_uv":normalize_uv}
			groups[key].parts.append(part)
		for group: Dictionary in groups.values():
			if group.parts.size() < 2: continue
			var first: MeshInstance3D = group.parts[0]
			var tool := SurfaceTool.new()
			var bounds := AABB()
			var initial: bool = true
			for part: MeshInstance3D in group.parts:
				var pose: Transform3D = part.transform
				var ancestor: Node3D = part.get_parent()
				while ancestor != frame:
					pose = ancestor.transform*pose
					ancestor = ancestor.get_parent()
				tool.append_from(indexed_surface(part.mesh,group.normalize_uv),0,pose)
				var box: AABB = pose*part.mesh.get_aabb()
				bounds = box if initial else bounds.merge(box)
				initial = false
			if optimize_model_geometry: tool.index()
			var combined := MeshInstance3D.new()
			combined.name = "BatchedParts"
			combined.mesh = tool.commit()
			(combined.mesh as ArrayMesh).custom_aabb = bounds
			combined.material_override = group.material
			combined.cast_shadow = first.cast_shadow
			combined.layers = first.layers
			frame.add_child(combined)
			for part: MeshInstance3D in group.parts:
				part.get_parent().remove_child(part)
				part.queue_free()


static func _collect_fixed_parts(parent: Node3D, frames: Array[Node3D], result: Array[MeshInstance3D]) -> void:
	for child: Node in parent.get_children():
		if not child is Node3D or child in frames or not child.is_visible_in_tree(): continue
		if child is MeshInstance3D and child.transform != Transform3D.IDENTITY: continue
		if child is MeshInstance3D and child.get_child_count() == 0 and child.mesh != null and child.mesh.get_surface_count() == 1 and child.get_active_material(0) != null:
			result.append(child)
		else: _collect_fixed_parts(child,frames,result)

static func _collect_transform_frames(parent: Node3D, frames: Array[Node3D]) -> void:
	for child: Node in parent.get_children():
		if not child is Node3D or child is MeshInstance3D: continue
		# Keep GPU model-matrix arithmetic for existing transformed parts. Baking
		# it into vertices can change silhouette samples by a floating-point ULP.
		if child.transform != Transform3D.IDENTITY and child not in frames: frames.append(child)
		_collect_transform_frames(child,frames)


static func _untextured_standard(surface: Material) -> bool:
	if not surface is StandardMaterial3D or surface.next_pass != null: return false
	for property: Dictionary in surface.get_property_list():
		if str(property.name).ends_with("_texture") and surface.get(property.name) is Texture: return false
	return true


static func indexed_surface(mesh: Mesh, normalize_uv: bool = false) -> Mesh:
	# SurfaceTool cannot safely append indexed and non-indexed streams together.
	# Give the latter sequential indices without changing any vertex attributes.
	var arrays: Array = mesh.surface_get_arrays(0)
	if not normalize_uv and arrays[Mesh.ARRAY_INDEX] != null and not arrays[Mesh.ARRAY_INDEX].is_empty(): return mesh
	var count: int = arrays[Mesh.ARRAY_VERTEX].size()
	if arrays[Mesh.ARRAY_INDEX] == null or arrays[Mesh.ARRAY_INDEX].is_empty():
		var indices := PackedInt32Array()
		indices.resize(count)
		for index: int in range(indices.size()): indices[index] = index
		arrays[Mesh.ARRAY_INDEX] = indices
	if normalize_uv:
		# UVs/tangents do not affect these untextured material finishes. Retain
		# authored values and fill absent attributes instead of splitting draws.
		for attribute: int in [Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2]:
			if arrays[attribute] == null:
				var uv := PackedVector2Array()
				uv.resize(count)
				arrays[attribute] = uv
		if arrays[Mesh.ARRAY_TANGENT] == null:
			var tangents := PackedFloat32Array()
			tangents.resize(count*4)
			for index: int in range(count): tangents[index*4] = 1.0; tangents[index*4+3] = 1.0
			arrays[Mesh.ARRAY_TANGENT] = tangents
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
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


static func cylinder(parent: Node3D, radius: float, height: float, center: Vector3, surface: Material, shared_model_mesh: bool = false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var key:=Vector2(radius,height)
	var mesh: CylinderMesh=cylinder_meshes.get(key) if shared_model_mesh and optimize_model_geometry else null
	if mesh==null:
		mesh=CylinderMesh.new()
		mesh.top_radius=radius
		mesh.bottom_radius=radius
		mesh.height=height
		mesh.radial_segments=24
		if shared_model_mesh and optimize_model_geometry:cylinder_meshes[key]=mesh
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
