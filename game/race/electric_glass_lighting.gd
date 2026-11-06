extends RefCounted
## Race-owned glass context. Never mutate shared/prepared or showroom materials.
const GLASS: Shader = preload("res://vehicle/electric_glass.gdshader")
const NIGHT_TINT := Vector3(0.026, 0.043, 0.055)
var _bindings: Array[Dictionary] = []
var _car: WeakRef
var _night: bool = false

func configure(car: CarVisual, theme: String) -> void:
	var night: bool = car.vehicle_id == "electric" and theme == "night_city"
	if _car != null and _car.get_ref() == car and _night == night: return
	reset()
	_car = weakref(car)
	_night = night
	if not night: return
	var copies: Dictionary = {}
	for mesh: MeshInstance3D in car.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null: continue
		var overridden: bool = mesh.material_override != null
		for index: int in range(1 if overridden else mesh.mesh.get_surface_count()):
			var source: ShaderMaterial = mesh.get_active_material(index) as ShaderMaterial
			if source == null or source.shader != GLASS: continue
			if not copies.has(source):
				var copy: ShaderMaterial = source.duplicate() as ShaderMaterial
				copy.set_shader_parameter("night_mode", true)
				# Keep the brighter window pigment at the panoramic roof's Night level.
				var tint: Vector3 = source.get_shader_parameter("glass_tint_srgb")
				copy.set_shader_parameter("glass_tint_srgb", Vector3(minf(tint.x, NIGHT_TINT.x), minf(tint.y, NIGHT_TINT.y), minf(tint.z, NIGHT_TINT.z)))
				copies[source] = copy
			_bindings.append({"node":weakref(mesh), "index":index, "override":overridden,
				"original":mesh.material_override if overridden else mesh.get_surface_override_material(index),
				"applied":copies[source]})
			if overridden: mesh.material_override = copies[source]
			else: mesh.set_surface_override_material(index, copies[source])

func reset() -> void:
	for binding: Dictionary in _bindings:
		var mesh: MeshInstance3D = binding.node.get_ref() as MeshInstance3D
		if not is_instance_valid(mesh): continue
		if binding.override:
			if mesh.material_override == binding.applied: mesh.material_override = binding.original
		elif mesh.mesh != null and int(binding.index) < mesh.mesh.get_surface_count():
			if mesh.get_surface_override_material(binding.index) == binding.applied:
				mesh.set_surface_override_material(binding.index, binding.original)
	_bindings.clear()
	_car = null
	_night = false
