class_name VehicleWeathering
extends RefCounted
## Cosmetic exposure and local wash volume. Never writes canonical simulation or livery.
const FINISH: Shader = preload("res://vehicle/vehicle_weathering.gdshader")
const COLORS: Dictionary = {"desert": Color("c7ae7c"), "winter": Color("dce8ed"), "pine": Color("463225"), "night_city": Color("735a43"), "storm": Color("625340")}
const HEIGHTS: Dictionary = {"compact": 1.5, "pickup": 1.95, "classic": 1.18, "formula": 0.65, "kart": 0.48}
const SLOW_RATE: float = 1.0 / 20.0
const SCRUB_RATE: float = 0.85
const MAX_SCRUB_RESISTANCE: float = 0.40
const GRIME_AGE_SECONDS: float = 900.0
const GRIME_AGE_STEP: float = GRIME_AGE_SECONDS / 255.0
static var toon_finish: Shader
var theme: String = ""
var dirt_amount: float = 0.0
var snow_amount: float = 0.0
var slow_dirt_amount: float = 0.0
var slow_snow_amount: float = 0.0
var amount: float:
	get: return 1.0 - (1.0 - dirt_amount) * (1.0 - snow_amount)
var deposit_color: Color = COLORS.pine
var mud_amount: float = 0.0
var smudge: float = 0.0
var wash_image: Image
var wash_texture: ImageTexture
var slow_wash_image: Image
var slow_wash_texture: ImageTexture
var bounds := AABB(Vector3(-2, 0, -4), Vector3(4, 3, 8))
var _mask_travel: float = 0.0
var _slow_mask_travel: float = 0.0
var grime_age := PackedByteArray()
var _grime_elapsed: float = 0.0
var _scrub_fraction := PackedFloat32Array()
var _slow_scrub_fraction := PackedFloat32Array()
var _body: Node3D
var _car: CarVisual
var _wheel_frames: Array[Dictionary] = []
var wetness: float = 0.0
var last_tick: int = -1
var bindings: Array[Dictionary] = []
var materials: Array[ShaderMaterial] = []
var contacts := SurfaceAudioModel.new()
var installed: bool = false
var axle_half: float = 1.28
var wheel_half_span: float = 0.83
var wheel_radius: float = 0.37
const FINISH_PARAMETERS: Array[String] = ["amount","snow","slow_amount","slow_snow","deposit_color","mud","smudge","wetness","wash_volume","slow_wash_volume","wash_min","wash_size"]
var _finish_values: Array = []
var parameter_uploads: int = 0

func configure(car: CarVisual, biome: String, config: HandlingConfig) -> void:
	var retained: Dictionary = snapshot()
	reset()
	bindings.clear()
	materials.clear()
	_wheel_frames.clear()
	_car = car
	_body = car.body
	theme = biome
	contacts.configure(config)
	axle_half = config.wheelbase / (2.0 * HandlingConfig.BODY_SCALE)
	wheel_half_span = config.track_width / (2.0 * HandlingConfig.BODY_SCALE)
	wheel_radius = float({"compact": 0.37, "pickup": 0.44, "classic": 0.34, "formula": 0.34, "kart": 0.22}.get(car.vehicle_id, 0.37))
	if not COLORS.has(theme): return
	deposit_color = COLORS[theme]
	var paints: Array[StandardMaterial3D] = []
	for surface: StandardMaterial3D in car.paint_materials.values(): paints.append(surface)
	if car.accent_roof != null: paints.append(car.accent_roof)
	for variant: Dictionary in car.paint_variants: paints.append(variant.material)
	_bind(car.body, car.body.global_transform.affine_inverse(), paints, float(HEIGHTS.get(car.vehicle_id, 1.5)), {})
	for index: int in range(car.rolling_wheels.size()):
		var rotor: Node3D = car.rolling_wheels[index]
		var rest := Transform3D(Basis.IDENTITY, car.wheel_rest_positions[index])
		_wheel_frames.append({"rotor": rotor, "rest": rest})
		_bind(rotor, rotor.global_transform.affine_inverse(), paints, float(HEIGHTS.get(car.vehicle_id, 1.5)), {}, true, rest)
	var first: bool = true
	for binding: Dictionary in bindings:
		# Keep the established body-volume mapping for existing saved wash
		# strokes. Rim points use the same bounded volume at the body edge.
		if binding.wheel: continue
		var node: MeshInstance3D = binding.node
		var box: AABB = (binding.wash_transform as Transform3D) * node.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	bounds = bounds.grow(0.08)
	restore(retained)

func _bind(node: Node3D, inverse: Transform3D, paints: Array[StandardMaterial3D], height: float, cache: Dictionary, wheel: bool = false, wheel_rest: Transform3D = Transform3D.IDENTITY) -> void:
	if node is MeshInstance3D and node.mesh != null:
		for index: int in range(node.mesh.get_surface_count()):
			var active: Material = node.get_active_material(index)
			var source: StandardMaterial3D = active.get_meta("livery_source") if active is ShaderMaterial and active.has_meta("livery_source") else active as StandardMaterial3D
			if source == null: continue
			var rear_trim: bool = not wheel and source not in paints
			# Bumpers can share a static batch with front trim. Only matte dark
			# plastics qualify; the shader restricts their deposit to rear faces.
			if rear_trim and (source.roughness < 0.7 or source.metallic > 0.2 or source.emission_enabled or source.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED or source.albedo_texture != null or maxf(source.albedo_color.r, maxf(source.albedo_color.g, source.albedo_color.b)) > 0.20): continue
			var local_transform: Transform3D = inverse * node.global_transform
			var transform: Transform3D = wheel_rest * local_transform if wheel else local_transform
			var key: String = str(source.get_instance_id()) + str(transform)
			if not cache.has(key):
				var surface := ShaderMaterial.new()
				if source.diffuse_mode == BaseMaterial3D.DIFFUSE_TOON:
					if toon_finish == null:
						toon_finish = Shader.new()
						toon_finish.code = FINISH.code.replace("diffuse_burley, specular_schlick_ggx", "diffuse_toon, specular_schlick_ggx")
					surface.shader = toon_finish
				else: surface.shader = FINISH
				surface.set_meta("weathering_finish",true)
				LiveryGraphics.uniforms(surface,_car.livery,_car.vehicle_id,source in paints and not wheel)
				surface.set_shader_parameter("paint_color", source.albedo_color)
				surface.set_shader_parameter("paint_roughness", source.roughness)
				surface.set_shader_parameter("paint_metallic", source.metallic)
				surface.set_shader_parameter("paint_specular", 0.0 if source.specular_mode == BaseMaterial3D.SPECULAR_DISABLED else source.metallic_specular)
				surface.set_shader_parameter("paint_clearcoat", source.clearcoat if source.clearcoat_enabled else 0.0)
				surface.set_shader_parameter("paint_clearcoat_roughness", source.clearcoat_roughness)
				surface.set_shader_parameter("deposit_color", COLORS[theme])
				surface.set_shader_parameter("snow", snow_amount)
				surface.set_shader_parameter("mud", 1.0 if theme in ["pine", "night_city", "storm"] else 0.0)
				surface.set_shader_parameter("roof_height", height)
				surface.set_shader_parameter("axle_half", axle_half)
				surface.set_shader_parameter("wheel_half_span", wheel_half_span)
				surface.set_shader_parameter("wheel_radius", wheel_radius)
				surface.set_shader_parameter("rear_only", 1.0 if rear_trim else 0.0)
				surface.set_shader_parameter("wheel_surface", 1.0 if wheel else 0.0)
				surface.set_shader_parameter("mesh_to_wheel", local_transform if wheel else Transform3D.IDENTITY)
				surface.set_shader_parameter("mesh_to_body", transform)
				materials.append(surface)
				cache[key] = surface
			bindings.append({"node": node, "index": index, "override": node.material_override != null, "original": node.material_override if node.material_override != null else node.get_surface_override_material(index), "finish": cache[key], "source": source, "wheel": wheel, "wash_transform": transform})
	for child: Node in node.get_children():
		if child is Node3D: _bind(child, inverse, paints, height, cache, wheel, wheel_rest)

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
	if travel > 0.0 and maxf(dirt_amount, slow_dirt_amount) > 0.02:
		_age_grime(seconds)
	var off_road: float = clampf(contacts.grass + contacts.sand + contacts.gravel + contacts.water, 0.0, 1.0)
	var exposure: float = 0.0
	match theme:
		"desert": exposure = travel * 0.0013 * contacts.sand
		"winter": exposure = travel * 0.0011
		"pine", "night_city": exposure = travel * 0.0040 * off_road
		"storm":
			exposure = travel * (0.00075 + off_road * 0.0030)
			wetness = 1.0 - (1.0 - wetness) * exp(-seconds / 18.0)
	if theme == "winter":
		snow_amount = 1.0 - (1.0 - snow_amount) * exp(-exposure)
		slow_snow_amount = 1.0 - (1.0 - slow_snow_amount) * exp(-exposure * SLOW_RATE)
	else:
		_melt_state(seconds)
		slow_dirt_amount = 1.0 - (1.0 - slow_dirt_amount) * exp(-exposure * SLOW_RATE)
		var added: float = (1.0 - dirt_amount) * (1.0 - exp(-exposure))
		if added > 0.0:
			deposit_color = deposit_color.lerp(COLORS.get(theme, COLORS.pine), added / maxf(dirt_amount + added, 0.00001))
			mud_amount = lerpf(mud_amount, 1.0 if theme in ["pine", "night_city", "storm"] else 0.0, added / maxf(dirt_amount + added, 0.00001))
			dirt_amount += added
	# New road exposure gradually coats previously washed spots again.
	_mask_travel += exposure
	_slow_mask_travel += exposure * SLOW_RATE
	if _mask_travel >= 0.02:
		var bytes: PackedByteArray = wash_image.get_data()
		for index: int in range(bytes.size()): bytes[index] = roundi(bytes[index] * exp(-_mask_travel * 4.0))
		wash_image = Image.create_from_data(VehicleCondition.GRID * VehicleCondition.GRID, VehicleCondition.GRID, false, Image.FORMAT_R8, bytes)
		wash_texture.update(wash_image)
		_scrub_fraction.fill(0.0)
		_mask_travel = 0.0
	if _slow_mask_travel >= 0.02:
		var bytes: PackedByteArray = slow_wash_image.get_data()
		for index: int in range(bytes.size()): bytes[index] = roundi(bytes[index] * exp(-_slow_mask_travel * 4.0))
		slow_wash_image = Image.create_from_data(VehicleCondition.GRID * VehicleCondition.GRID, VehicleCondition.GRID, false, Image.FORMAT_R8, bytes)
		slow_wash_texture.update(slow_wash_image)
		_slow_scrub_fraction.fill(0.0)
		_slow_mask_travel = 0.0
	_update_finish()

func _age_grime(seconds: float) -> void:
	_grime_elapsed += seconds
	if _grime_elapsed + 0.00000001 < GRIME_AGE_STEP: return
	var steps: int = floori((_grime_elapsed + 0.00000001) / GRIME_AGE_STEP)
	_grime_elapsed = maxf(0.0, _grime_elapsed - steps * GRIME_AGE_STEP)
	var primary: PackedByteArray = wash_image.get_data()
	var slow: PackedByteArray = slow_wash_image.get_data()
	for index: int in range(grime_age.size()):
		if (dirt_amount > 0.02 and primary[index] < 255) or (slow_dirt_amount > 0.02 and slow[index] < 255):
			grime_age[index] = mini(255, grime_age[index] + steps)

func melt(seconds: float) -> void:
	_melt_state(seconds)
	_update_finish()

func _melt_state(seconds: float) -> void:
	var before: float = snow_amount
	snow_amount = maxf(0.0, snow_amount - maxf(seconds, 0.0) / 8.0)
	slow_snow_amount = maxf(0.0, slow_snow_amount - maxf(seconds, 0.0) / 8.0)
	if dirt_amount > 0.0:
		smudge = clampf(smudge + (before - snow_amount) * 0.75, 0.0, 1.0)

func _update_finish() -> void:
	if amount <= 0.00001 and wetness <= 0.00001 and slow_dirt_amount <= 0.00001 and slow_snow_amount <= 0.00001:
		if installed:
			for binding: Dictionary in bindings:
				if not is_instance_valid(binding.node): continue
				if is_instance_valid(_car) and _car.graphics.restore_surface(binding.node,binding.index): continue
				if binding.override: binding.node.material_override = binding.original
				else: binding.node.set_surface_override_material(binding.index, binding.original)
		installed = false
		return
	if not installed:
		for binding: Dictionary in bindings:
			if binding.override: binding.node.material_override = binding.finish
			else: binding.node.set_surface_override_material(binding.index, binding.finish)
		installed = true
		_finish_values.clear()
	var values: Array = [dirt_amount,snow_amount,slow_dirt_amount,slow_snow_amount,deposit_color,mud_amount,smudge,wetness,wash_texture,slow_wash_texture,bounds.position,bounds.size]
	if values == _finish_values: return
	for index: int in range(values.size()):
		if _finish_values.size() == values.size() and values[index] == _finish_values[index]: continue
		for material: ShaderMaterial in materials:
			material.set_shader_parameter(FINISH_PARAMETERS[index],values[index])
			parameter_uploads += 1
	_finish_values = values

func snapshot() -> Dictionary:
	if wash_image == null:
		wash_image = Image.create(VehicleCondition.GRID * VehicleCondition.GRID, VehicleCondition.GRID, false, Image.FORMAT_R8)
		wash_image.fill(Color.BLACK)
	if slow_wash_image == null: slow_wash_image = wash_image.duplicate() as Image
	if grime_age.size() != VehicleCondition.CELLS:
		grime_age.resize(VehicleCondition.CELLS)
		grime_age.fill(0)
	return {"version": 1, "dirt": dirt_amount, "snow": snow_amount, "slow_dirt": slow_dirt_amount, "slow_snow": slow_snow_amount, "slow_recoat": _slow_mask_travel, "wetness": wetness, "color": deposit_color.to_html(false), "mud": mud_amount, "smudge": smudge, "wash": Marshalls.raw_to_base64(wash_image.get_data()), "slow_wash": Marshalls.raw_to_base64(slow_wash_image.get_data()), "grime_age": Marshalls.raw_to_base64(grime_age), "grime_elapsed": _grime_elapsed}

func restore(value: Dictionary) -> void:
	if value.is_empty(): value = snapshot()
	dirt_amount = float(value.get("dirt", 0.0))
	snow_amount = float(value.get("snow", 0.0))
	slow_dirt_amount = float(value.get("slow_dirt", 0.0))
	slow_snow_amount = float(value.get("slow_snow", 0.0))
	wetness = float(value.get("wetness", 0.0))
	deposit_color = Color(str(value.get("color", COLORS.get(theme, COLORS.pine).to_html(false))))
	mud_amount = float(value.get("mud", 0.0))
	smudge = float(value.get("smudge", 0.0))
	var bytes: PackedByteArray = Marshalls.base64_to_raw(str(value.get("wash", "")))
	if bytes.size() != VehicleCondition.CELLS:
		bytes.resize(VehicleCondition.CELLS)
		bytes.fill(0)
	wash_image = Image.create_from_data(VehicleCondition.GRID * VehicleCondition.GRID, VehicleCondition.GRID, false, Image.FORMAT_R8, bytes)
	wash_texture = ImageTexture.create_from_image(wash_image)
	var slow_bytes: PackedByteArray = Marshalls.base64_to_raw(str(value.get("slow_wash", value.get("wash", ""))))
	if slow_bytes.size() != VehicleCondition.CELLS:
		slow_bytes.resize(VehicleCondition.CELLS)
		slow_bytes.fill(0)
	slow_wash_image = Image.create_from_data(VehicleCondition.GRID * VehicleCondition.GRID, VehicleCondition.GRID, false, Image.FORMAT_R8, slow_bytes)
	slow_wash_texture = ImageTexture.create_from_image(slow_wash_image)
	_mask_travel = 0.0
	_slow_mask_travel = float(value.get("slow_recoat", 0.0))
	grime_age = Marshalls.base64_to_raw(str(value.get("grime_age", "")))
	if grime_age.size() != VehicleCondition.CELLS:
		grime_age.resize(VehicleCondition.CELLS)
		grime_age.fill(0)
	_grime_elapsed = float(value.get("grime_elapsed", 0.0))
	_scrub_fraction.resize(VehicleCondition.CELLS)
	_scrub_fraction.fill(0.0)
	_slow_scrub_fraction.resize(VehicleCondition.CELLS)
	_slow_scrub_fraction.fill(0.0)
	last_tick = -1
	_update_finish()

func wash(point: Vector3, seconds: float) -> void:
	if wash_image == null or seconds <= 0.0 or not is_finite(seconds): return
	var radius: float = 0.48
	var grid: int = VehicleCondition.GRID
	var bytes: PackedByteArray = wash_image.get_data()
	var slow_bytes: PackedByteArray = slow_wash_image.get_data()
	var touched: bool = false
	var lower: Vector3 = ((point - Vector3.ONE * radius - bounds.position) / bounds.size * (grid - 1)).floor().clamp(Vector3.ZERO, Vector3.ONE * (grid - 1))
	var upper: Vector3 = ((point + Vector3.ONE * radius - bounds.position) / bounds.size * (grid - 1)).ceil().clamp(Vector3.ZERO, Vector3.ONE * (grid - 1))
	for z: int in range(int(lower.z), int(upper.z) + 1):
		for y: int in range(int(lower.y), int(upper.y) + 1):
			for x: int in range(int(lower.x), int(upper.x) + 1):
				var centre: Vector3 = bounds.position + Vector3(float(x), float(y), float(z)) / float(grid - 1) * bounds.size
				var distance: float = centre.distance_to(point)
				if distance >= radius: continue
				touched = true
				var index: int = y * grid * grid + z * grid + x
				var resistance: float = 1.0 + MAX_SCRUB_RESISTANCE * float(grime_age[index]) / 255.0
				var progress: float = 255.0 * seconds * SCRUB_RATE * (1.0 - distance / radius) / resistance
				var primary_work: float = _scrub_fraction[index] + progress
				var slow_work: float = _slow_scrub_fraction[index] + progress
				var primary_steps: int = floori(primary_work)
				var slow_steps: int = floori(slow_work)
				bytes[index] = mini(255, bytes[index] + primary_steps)
				slow_bytes[index] = mini(255, slow_bytes[index] + slow_steps)
				_scrub_fraction[index] = primary_work - primary_steps if bytes[index] < 255 else 0.0
				_slow_scrub_fraction[index] = slow_work - slow_steps if slow_bytes[index] < 255 else 0.0
				if bytes[index] == 255 and slow_bytes[index] == 255: grime_age[index] = 0
	if not touched: return
	# Exposure earned before a fresh wash must not re-coat the new stroke.
	_mask_travel = 0.0
	_slow_mask_travel = 0.0
	_grime_elapsed = 0.0
	wash_image = Image.create_from_data(grid * grid, grid, false, Image.FORMAT_R8, bytes)
	wash_texture.update(wash_image)
	slow_wash_image = Image.create_from_data(grid * grid, grid, false, Image.FORMAT_R8, slow_bytes)
	slow_wash_texture.update(slow_wash_image)

func wash_point(node: MeshInstance3D, local_point: Vector3) -> Vector3:
	for frame: Dictionary in _wheel_frames:
		var rotor: Node3D = frame.rotor
		if rotor.is_ancestor_of(node):
			return (frame.rest as Transform3D) * (rotor.global_transform.affine_inverse() * node.global_transform) * local_point
	return _body.global_transform.affine_inverse() * node.global_transform * local_point

func reset() -> void:
	_finish_values.clear()
	if installed:
		for binding: Dictionary in bindings:
			if not is_instance_valid(binding.node): continue
			if is_instance_valid(_car) and _car.graphics.restore_surface(binding.node,binding.index): continue
			if binding.override: binding.node.material_override = binding.original
			else: binding.node.set_surface_override_material(binding.index, binding.original)
	installed = false
	dirt_amount = 0.0
	snow_amount = 0.0
	slow_dirt_amount = 0.0
	slow_snow_amount = 0.0
	smudge = 0.0
	mud_amount = 0.0
	wash_image = null
	wash_texture = null
	slow_wash_image = null
	slow_wash_texture = null
	wetness = 0.0
	grime_age.clear()
	_grime_elapsed = 0.0
	_scrub_fraction.clear()
	_slow_scrub_fraction.clear()
	_mask_travel = 0.0
	_slow_mask_travel = 0.0
	last_tick = -1

func refresh_paint() -> void:
	for binding: Dictionary in bindings:
		var source: StandardMaterial3D = binding.source
		(binding.finish as ShaderMaterial).set_shader_parameter("paint_color", source.albedo_color)
		LiveryGraphics.uniforms(binding.finish,_car.livery,_car.vehicle_id,not binding.wheel and source in _car.paint_materials.values() or source == _car.accent_roof or _car.paint_variants.any(func(item: Dictionary) -> bool: return item.material == source))
