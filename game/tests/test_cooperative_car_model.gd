extends SceneTree
## Exact CPU geometry/material parity; construction scheduling is the only change.
const Cache = preload("res://vehicle/prepared_car_cache.gd")
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func value_signature(value: Variant) -> Variant:
	if value is Texture2D:
		var image: Image = value.get_image()
		return [value.get_class(),value.resource_path,image.get_data().hex_encode().sha256_text() if image != null else "no backing image"]
	if value is Resource: return [value.get_class(),value.resource_path]
	return value
func material_signature(material: Material) -> Array:
	if material == null: return []
	var result: Array = [material.get_class()]
	if material is ShaderMaterial:
		result.append(material.shader.code)
		for uniform: Dictionary in material.shader.get_shader_uniform_list(): result.append([uniform.name,value_signature(material.get_shader_parameter(uniform.name))])
	else:
		for property: Dictionary in material.get_property_list():
			if int(property.usage)&PROPERTY_USAGE_STORAGE and not str(property.name).begins_with("resource_"):
				result.append([property.name,value_signature(material.get(property.name))])
	return result
func signature(node: Node) -> Array:
	var result: Array = [node.get_class(),node.name,node.get_groups()]
	if node is Node3D: result.append([node.transform,node.visible])
	if node is MeshInstance3D and node.mesh != null:
		result.append([node.cast_shadow,node.layers,node.mesh.get_aabb()])
		for surface: int in range(node.mesh.get_surface_count()):
			result.append([var_to_bytes(node.mesh.surface_get_arrays(surface)).hex_encode().sha256_text(),material_signature(node.get_active_material(surface))])
	for child: Node in node.get_children(): result.append(signature(child))
	return result
func difference(a: Variant, b: Variant, path: String = "model") -> String:
	if a is Array and b is Array:
		if a.size()!=b.size(): return path+" sizes "+str(a.size())+" / "+str(b.size())
		for index: int in range(a.size()):
			if a[index]!=b[index]: return difference(a[index],b[index],path+"/"+str(index))
	return path+" "+str(a).left(140)+" -> "+str(b).left(140)
func run() -> void:
	for vehicle: String in VehicleCatalog.IDS:
		Cache.entries.clear()
		var original := CarVisual.new()
		original.vehicle_id = vehicle; original.name = "Car"; original.process_mode = Node.PROCESS_MODE_DISABLED
		root.add_child(original)
		check(original.model_ready,"synchronous consumers remain immediately ready "+vehicle)
		var expected: Array = signature(original)
		Cache.entries.clear()
		var sliced := CarVisual.new()
		sliced.vehicle_id = vehicle; sliced.name = "SlicedCar"; sliced.cooperative_build = true; sliced.process_mode = Node.PROCESS_MODE_DISABLED
		root.add_child(sliced)
		var frames: int = 0
		while not sliced.model_ready: frames += 1; await process_frame
		sliced.name = "Car" # Different parents would be needed for equal sibling names.
		var actual: Array = signature(sliced)
		actual[1] = expected[1]
		check(frames>0,"cold construction yields "+vehicle)
		if actual!=expected: print("MODEL_DIFFERENCE ",vehicle," ",difference(expected,actual))
		check(actual==expected,"all meshes, normals, indices, transforms, materials and articulation remain exact "+vehicle)
		original.free(); sliced.free(); await process_frame
	print("COOPERATIVE_CAR_MODEL: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
