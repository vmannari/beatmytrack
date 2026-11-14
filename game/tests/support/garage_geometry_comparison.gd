extends RefCounted
## Compare authored workshop geometry, ignoring only engine allocation numbers.
static func comparison_name(node: Node) -> String:
	var value: String = str(node.name)
	var prefix: String = "@" + node.get_class() + "@"
	# Godot reserves @ for its own generated names. Retain the class and every
	# authored name; only the process-global allocation number is irrelevant.
	if value.begins_with(prefix) and value.trim_prefix(prefix).is_valid_int(): return prefix
	return value

static func geometry(node: Node, result: Array) -> void:
	if node is Node3D: result.append([comparison_name(node),node.transform])
	if node is MeshInstance3D:
		var mesh: Mesh=node.mesh
		result.append([node.layers,node.cast_shadow,mesh.get_surface_count()])
		for index: int in range(mesh.get_surface_count()):
			result.append(mesh.surface_get_arrays(index))
		var material: Material=node.material_override
		if material is ShaderMaterial:
			var params: Array=[]
			for property: Dictionary in material.get_property_list():
				if str(property.name).begins_with("shader_parameter/"): params.append([property.name,material.get(property.name)])
			result.append([material.shader.code,params])
		elif material is StandardMaterial3D:
			result.append([material.albedo_color,material.metallic,material.roughness,material.emission_enabled,material.emission,material.emission_energy_multiplier])
	for child: Node in node.get_children(): geometry(child,result)
