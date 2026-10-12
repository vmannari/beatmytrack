class_name VehicleWeathering
extends RefCounted
## Race-owned cosmetic exposure. Never writes simulation, livery or records.
const FINISH: Shader = preload("res://vehicle/vehicle_weathering.gdshader")
const COLORS: Dictionary = {"desert": Color("c7ae7c"), "winter": Color("dce8ed"), "pine": Color("806247"), "night_city": Color("735a43"), "storm": Color("625340")}
const HEIGHTS: Dictionary = {"compact": 1.5, "pickup": 1.95, "classic": 1.18, "formula": 0.65, "kart": 0.48}
static var toon_finish: Shader
var theme: String = ""
var amount: float = 0.0
var wetness: float = 0.0
var last_tick: int = -1
var bindings: Array[Dictionary] = []
var materials: Array[ShaderMaterial] = []
var contacts := SurfaceAudioModel.new()
var installed: bool = false
var axle_half: float = 1.28
var wheel_half_span: float = 0.83
var wheel_radius: float = 0.37

func configure(car: CarVisual, biome: String, config: HandlingConfig) -> void:
	reset()
	bindings.clear()
	materials.clear()
	theme = biome
	contacts.configure(config)
	axle_half = config.wheelbase / (2.0 * HandlingConfig.BODY_SCALE)
	wheel_half_span = config.track_width / (2.0 * HandlingConfig.BODY_SCALE)
	wheel_radius = float({"compact": 0.37, "pickup": 0.44, "classic": 0.34, "formula": 0.34, "kart": 0.22}.get(car.vehicle_id, 0.37))
	if not COLORS.has(theme): return
	var paints: Array[StandardMaterial3D] = []
	for surface: StandardMaterial3D in car.paint_materials.values(): paints.append(surface)
	if car.accent_roof != null: paints.append(car.accent_roof)
	for variant: Dictionary in car.paint_variants: paints.append(variant.material)
	_bind(car.body, car.body.global_transform.affine_inverse(), paints, float(HEIGHTS.get(car.vehicle_id, 1.5)), {})

func _bind(node: Node3D, inverse: Transform3D, paints: Array[StandardMaterial3D], height: float, cache: Dictionary) -> void:
	if node is MeshInstance3D and node.mesh != null:
		for index: int in range(node.mesh.get_surface_count()):
			var source: StandardMaterial3D = node.get_active_material(index) as StandardMaterial3D
			if source == null or source not in paints: continue
			var transform: Transform3D = inverse * node.global_transform
			var key: String = str(source.get_instance_id()) + str(transform)
			if not cache.has(key):
				var surface := ShaderMaterial.new()
				if source.diffuse_mode == BaseMaterial3D.DIFFUSE_TOON:
					if toon_finish == null:
						toon_finish = Shader.new()
						toon_finish.code = FINISH.code.replace("diffuse_burley, specular_schlick_ggx", "diffuse_toon, specular_schlick_ggx")
					surface.shader = toon_finish
				else: surface.shader = FINISH
				surface.set_shader_parameter("paint_color", source.albedo_color)
				surface.set_shader_parameter("paint_roughness", source.roughness)
				surface.set_shader_parameter("paint_metallic", source.metallic)
				surface.set_shader_parameter("paint_specular", 0.0 if source.specular_mode == BaseMaterial3D.SPECULAR_DISABLED else source.metallic_specular)
				surface.set_shader_parameter("paint_clearcoat", source.clearcoat if source.clearcoat_enabled else 0.0)
				surface.set_shader_parameter("paint_clearcoat_roughness", source.clearcoat_roughness)
				surface.set_shader_parameter("deposit_color", COLORS[theme])
				surface.set_shader_parameter("snow", 1.0 if theme == "winter" else 0.0)
				surface.set_shader_parameter("mud", 1.0 if theme in ["pine", "night_city", "storm"] else 0.0)
				surface.set_shader_parameter("roof_height", height)
				surface.set_shader_parameter("axle_half", axle_half)
				surface.set_shader_parameter("wheel_half_span", wheel_half_span)
				surface.set_shader_parameter("wheel_radius", wheel_radius)
				surface.set_shader_parameter("mesh_to_body", transform)
				materials.append(surface)
				cache[key] = surface
			bindings.append({"node": node, "index": index, "override": node.material_override != null, "original": node.material_override if node.material_override != null else node.get_surface_override_material(index), "finish": cache[key]})
	for child: Node in node.get_children():
		if child is Node3D: _bind(child, inverse, paints, height, cache)

func present(state: VehicleState, track: NativeTrack, blocked: bool) -> void:
	var ticks: int = state.tick - last_tick if last_tick >= 0 else 0
	last_tick = state.tick
	if blocked or ticks <= 0 or ticks > 120 or materials.is_empty(): return
	var seconds: float = ticks * VehicleSimulation.STEP
	var grounded: bool = state.jump_height <= 0.01 and state.roll_ticks == 0
	var speed: float = state.velocity.length()
	if not is_finite(speed): return
	contacts.sample_contacts(state, track, grounded)
	var travel: float = minf(speed, 55.0) * seconds if grounded and speed > 0.5 else 0.0
	var off_road: float = clampf(contacts.grass + contacts.sand + contacts.gravel + contacts.water, 0.0, 1.0)
	var exposure: float = 0.0
	match theme:
		"desert": exposure = travel * 0.0013 * contacts.sand
		"winter": exposure = travel * 0.0011
		"pine", "night_city": exposure = travel * 0.0040 * off_road
		"storm":
			exposure = travel * (0.00075 + off_road * 0.0030)
			wetness = 1.0 - (1.0 - wetness) * exp(-seconds / 18.0)
	amount = 1.0 - (1.0 - amount) * exp(-exposure)
	if amount <= 0.00001 and wetness <= 0.00001: return
	if not installed:
		for binding: Dictionary in bindings:
			if binding.override: binding.node.material_override = binding.finish
			else: binding.node.set_surface_override_material(binding.index, binding.finish)
		installed = true
	for material: ShaderMaterial in materials:
		material.set_shader_parameter("amount", amount)
		material.set_shader_parameter("wetness", wetness)

func reset() -> void:
	if installed:
		for binding: Dictionary in bindings:
			if not is_instance_valid(binding.node): continue
			if binding.override: binding.node.material_override = binding.original
			else: binding.node.set_surface_override_material(binding.index, binding.original)
	installed = false
	amount = 0.0
	wetness = 0.0
	last_tick = -1
