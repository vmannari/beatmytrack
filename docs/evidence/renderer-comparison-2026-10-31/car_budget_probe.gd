extends SceneTree
## Offline desktop/headless scheduling experiment against the frozen project.
const Cache = preload("res://vehicle/prepared_car_cache.gd")
var timestamps: Array[int] = []
var sampling := false

func _initialize() -> void: run.call_deferred()
func frame_sample() -> void:
	if sampling: timestamps.append(Time.get_ticks_usec())

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

func run() -> void:
	Engine.max_fps = 50
	process_frame.connect(frame_sample)
	var reference: Array = []
	var results: Array = []
	for budget: int in [4000,8000,8000,4000]:
		Cache.entries.clear()
		CompactDetail.trim_front_cache()
		CompactGrille.meshes.clear()
		CompactCoachwork.meshes.clear()
		VisualGeometry.cylinder_meshes.clear()
		var car := CarVisual.new()
		car.name = "ProbeCar"
		car.cooperative_build = true
		car.build_budget_us = budget
		car.process_mode = Node.PROCESS_MODE_DISABLED
		timestamps.clear(); sampling = true
		var began: int = Time.get_ticks_usec()
		root.add_child(car)
		var frames := 0
		while not car.model_ready and frames < 3000:
			frames += 1
			await process_frame
		var wall: int = Time.get_ticks_usec()-began
		sampling = false
		if not car.model_ready:
			print("CAR_BUDGET_TIMEOUT ",budget)
			quit(1); return
		var gaps: Array[int] = []
		for i: int in range(1,timestamps.size()): gaps.append(timestamps[i]-timestamps[i-1])
		gaps.sort()
		var actual: Array = signature(car)
		if reference.is_empty(): reference = actual
		var same: bool = actual == reference
		results.append({"budget_us":budget,"wall_us":wall,"yields":car.model_yields,
			"slice_max_us":car.model_max_slice_us,"slice_at":car.model_slice_at,
			"frame_intervals":gaps.size(),"frame_p95_us":gaps[ceili(gaps.size()*0.95)-1] if not gaps.is_empty() else null,
			"frame_max_us":gaps.back() if not gaps.is_empty() else null,"exact_geometry_materials":same})
		car.free()
		await process_frame
	print("CAR_BUDGET_PROBE ",JSON.stringify(results))
	quit(0 if results.all(func(item: Dictionary) -> bool: return item.exact_geometry_materials) else 1)
