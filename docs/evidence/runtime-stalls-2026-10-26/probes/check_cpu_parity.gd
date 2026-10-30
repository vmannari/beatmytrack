extends SceneTree
const ProbeCar = preload("res://../build/runtime-stall-investigation-2026-10-26/cpu_car.gd")
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func span(_name: String, _start: int, _facts: Dictionary = {}) -> void: pass
func signature(node: Node) -> Array:
	var row: Array = [node.get_class()]
	if node is Node3D: row.append([node.transform,node.visible])
	if node is MeshInstance3D and node.mesh != null:
		row.append([node.cast_shadow,node.mesh.get_aabb()])
		for surface: int in range(node.mesh.get_surface_count()):
			var material: Material = node.get_active_material(surface)
			var values: Array = [material.get_class()]
			if material is ShaderMaterial:
				values.append(material.shader.code)
			else:
				for property: Dictionary in material.get_property_list():
					if int(property.usage)&PROPERTY_USAGE_STORAGE and not str(property.name).begins_with("resource_"): values.append([property.name,material.get(property.name)])
			row.append([var_to_bytes(node.mesh.surface_get_arrays(surface)).hex_encode().sha256_text(),values])
	for child: Node in node.get_children(): row.append(signature(child))
	return row
func run() -> void:
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	for simple: bool in [false,true]:
		var original := CarVisual.new(); original.simple_model = simple
		original.process_mode = Node.PROCESS_MODE_DISABLED; root.add_child(original)
		var expected: Array = signature(original)
		var probe := ProbeCar.new(); probe.simple_model = simple
		probe.process_mode = Node.PROCESS_MODE_DISABLED; root.add_child(probe)
		var actual: Array = signature(probe)
		var exact: bool = expected==actual
		if not exact: failures += 1
		print("CPU_GRID_PARITY simple=",simple," exact=",exact," original=",var_to_bytes(expected).hex_encode().sha256_text()," memo=",var_to_bytes(actual).hex_encode().sha256_text())
		original.free(); probe.free(); await process_frame
	print("CPU_GRID_PARITY_RESULT 2 modes, ",failures," failures")
	quit(1 if failures else 0)
