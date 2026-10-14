class_name SandDust
extends Node3D
## Presentation-only, wheel-driven sand spray and lingering dust. Particle state
## never feeds back into the fixed-step vehicle simulation.
const PRESENTATION_VERSION: String = "desert-dust-21"
const GRASS_PRESENTATION_VERSION: String = "grass-clippings-2"

const SAND_SURFACE: int = 2
const REAR_AXLE: float = -1.0
const FRONT_AXLE: float = 1.0
const MODE_DUST: int = 0
const MODE_SAND_SPRAY: int = 1
const MODE_CLIPPING: int = 2
const MODE_MUD: int = 3
const MODE_SMOKE: int = 4
const MODE_WATER: int = 5

const WINTER_PRESENTATION_VERSION: String = "winter-spray-6"
var snow_chips: Array[GPUParticles3D] = []
var snow_powder: Array[GPUParticles3D] = []
var snow_impacts: Array[GPUParticles3D] = []
var snow_push: Array[GPUParticles3D] = []
var snow_push_position := Vector2.INF
var _bank_visual_heights: Dictionary = {}
var snow_in_bank: bool = false
var snow_previous: Vector2
var snow_previous_valid: bool = false
var collision_radius: float = 1.55 * HandlingConfig.BODY_SCALE
var snow_impact_position: Vector2
var snow_last_burst: int = -1000
var snow_burst_count: int = 0
var desert_profile: bool = false

var wheelbase: float = 2.56 * HandlingConfig.BODY_SCALE
var track_width: float = 1.52 * HandlingConfig.BODY_SCALE
var dust_emitters: Array[GPUParticles3D] = []
var tyre_emitters: Array[GPUParticles3D] = []
var deck_dust_emitters: Array[GPUParticles3D] = []
var deck_tyre_emitters: Array[GPUParticles3D] = []
var _deck_cloud_sources: Dictionary = {}
var _bridge_count: int = 0
var _bridge_theme: String = ""
var _bridge_track: NativeTrack
var _bridge_axes := PackedVector4Array()
var _bridge_sizes := PackedVector4Array()
var _bridge_roof := Vector4(CreatorBridges.UNDERPASS_CLEARANCE,0.42,0.65,0.0)
# Explicit diagnostic comparison only; ordinary races retain bridge clipping.
var bridge_clipping_enabled: bool = true:
	set(value):
		bridge_clipping_enabled = value
		for emitter: GPUParticles3D in cloud_emitters(): _bind_cloud_bridge_material(emitter)
# Compare physical puff height with the nearest opaque surface. Private A/B
# control only; no car outline, radius, delayed opacity or altered geometry.
var height_occlusion_enabled: bool = true:
	set(value):
		height_occlusion_enabled = value
		for emitter: GPUParticles3D in cloud_emitters():
			(emitter.draw_pass_1.surface_get_material(0) as ShaderMaterial).set_shader_parameter("dust_height_occlusion",value)
var spray_emitters: Array[GPUParticles3D] = []
var clipping_emitters: Array[GPUParticles3D] = []
var mud_emitters: Array[GPUParticles3D] = []
var smoke_emitters: Array[GPUParticles3D] = []
var water_drops: Array[GPUParticles3D] = []
var water_paused: bool = false
var last_strengths := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])


func _ready() -> void:
	for wheel: int in range(4):
		var dust := _emitter("Dust%d" % wheel,360,5.20,Vector2(2.05,2.05),Color(0.82,0.70,0.50,0.48),MODE_DUST)
		dust_emitters.append(dust)
		add_child(dust)
		var tyre := _emitter("TyreDust%d" % wheel,48,1.1,Vector2(1.4,1.4),Color(0.80,0.72,0.57,0.65),MODE_DUST)
		var tyre_process: ParticleProcessMaterial = tyre.process_material
		tyre_process.scale_curve = _bounded_growth([0.8,1.1,1.4,1.7])
		tyre_process.angular_velocity_curve = _rotation_from_growth(tyre_process.scale_curve)
		(tyre.draw_pass_1.surface_get_material(0) as ShaderMaterial).set_shader_parameter("billowing",true)
		(tyre.draw_pass_1.surface_get_material(0) as ShaderMaterial).set_shader_parameter("intersection_fade",0.18)
		tyre.draw_pass_1 = _cloud_mesh(Vector2(1.4,1.4),tyre.draw_pass_1.surface_get_material(0))
		tyre_emitters.append(tyre)
		add_child(tyre)
		var clipping := _emitter("Clippings%d" % wheel,96,0.72,Vector2(0.045,0.24),Color("71834b"),MODE_CLIPPING)
		clipping_emitters.append(clipping)
		add_child(clipping)
		var smoke := _emitter("Smoke%d" % wheel,900,1.50,Vector2(0.72,0.72),Color(0.80,0.82,0.80,0.040),MODE_SMOKE)
		smoke_emitters.append(smoke)
		add_child(smoke)
	for wheel: int in range(2):
		var spray := _emitter("Spray%d" % wheel,72,0.65,Vector2(0.15,0.25),Color(0.52,0.37,0.19,0.68),MODE_SAND_SPRAY)
		spray_emitters.append(spray)
		add_child(spray)
		var mud := _emitter("Mud%d" % wheel,90,0.78,Vector2(0.14,0.22),Color(0.25,0.20,0.10,0.86),MODE_MUD)
		mud_emitters.append(mud)
		add_child(mud)


func _set_desert_profile(enabled: bool) -> void:
	if desert_profile == enabled: return
	desert_profile = enabled
	for emitter: GPUParticles3D in spray_emitters:
		# Small flattened grains form a low ballistic fan beneath the soft plume.
		# Reuse the rear spray budget rather than adding flying grass substitutes.
		var grain: SphereMesh = emitter.draw_pass_1
		grain.radius = 0.045 if enabled else 0.075
		grain.height = 0.065 if enabled else 0.25
		var grit: ParticleProcessMaterial = emitter.process_material
		grit.color = Color("b69a70") if enabled else Color(0.52,0.37,0.19)
		grit.direction = Vector3(0,0.24 if enabled else 0.42,-1).normalized()
		grit.spread = 58.0 if enabled else 42.0
		grit.scale_min = 0.40 if enabled else 0.72
		grit.scale_max = 1.15 if enabled else 1.28
	for emitter: GPUParticles3D in dust_emitters+deck_dust_emitters:
		_apply_desert_cloud(emitter,enabled)
	for emitter: GPUParticles3D in deck_tyre_emitters: _sync_deck_cloud_process(emitter)


func _apply_desert_cloud(emitter: GPUParticles3D, enabled: bool) -> void:
	emitter.lifetime = 9.0 if enabled else 5.2
	emitter.amount = 64 if enabled else 360
	var cloud_material: ShaderMaterial = emitter.draw_pass_1.surface_get_material(0)
	if enabled:
		emitter.draw_pass_1 = _cloud_mesh(Vector2(4.0,4.0),cloud_material)
	else:
		var quad := QuadMesh.new()
		quad.size = Vector2(2.05,2.05)
		quad.material = cloud_material
		emitter.draw_pass_1 = quad
	var material: ParticleProcessMaterial = _deck_cloud_sources.get(emitter,emitter.process_material)
	material.color = Color("d3c19f") if enabled else Color(0.82,0.70,0.50)
	material.color_ramp = _desert_alpha() if enabled else _alpha_ramp(0.48,MODE_DUST)
	material.scale_curve = _scale_curve(MODE_DUST)
	material.spread = 110.0 if enabled else 72.0
	material.initial_velocity_max = 2.2 if enabled else 1.65
	material.damping_min = 0.30 if enabled else 0.75
	material.damping_max = 0.65 if enabled else 1.25
	material.gravity = Vector3(0,0.24 if enabled else 0.06,0)
	cloud_material.set_shader_parameter("billowing",enabled)
	if enabled:
		material.scale_curve = _bounded_growth([0.65,1.4,2.1,2.5])
		(material.scale_curve as CurveTexture).curve.set_point_offset(1,0.025)
	material.angular_velocity_curve = _rotation_from_growth(material.scale_curve) if enabled else null
	if _deck_cloud_sources.has(emitter): _sync_deck_cloud_process(emitter)


func _bounded_growth(values: Array[float]) -> CurveTexture:
	var curve := Curve.new()
	curve.max_value = 3.0
	for i: int in range(4):
		curve.add_point(Vector2([0.0,0.12,0.42,1.0][i],values[i]))
	var texture := CurveTexture.new()
	texture.curve = curve
	return texture


func _rotation_from_growth(growth: CurveTexture) -> CurveTexture:
	# Angular speed decreases with the cloud's authored size over its lifetime.
	# Apply this in particle simulation: dividing the displayed angle by size
	# would unwind rotation as a cloud expands.
	var curve := Curve.new()
	var initial_size: float = growth.curve.get_point_position(0).y
	for i: int in range(growth.curve.point_count):
		var point: Vector2 = growth.curve.get_point_position(i)
		# Pinned Godot 4.7 curve branch integrates directly into CUSTOM.x
		# (radians), unlike its constant-speed degrees-to-radians branch.
		# Convert here, then slow proportionally as the cloud expands.
		var ratio: float = initial_size / maxf(point.y,0.01)
		curve.add_point(Vector2(point.x,deg_to_rad(1.0) * ratio))
	var texture := CurveTexture.new()
	texture.curve = curve
	return texture


func _desert_alpha() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0,0.012,0.35,0.72,1.0])
	gradient.colors = PackedColorArray([Color(1,1,1,0),Color(1,1,1,0.88),Color(1,1,1,0.82),Color(1,1,1,0.55),Color(1,1,1,0)])
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture


func clear() -> void:
	snow_push_position = Vector2.INF
	snow_in_bank = false
	snow_previous_valid = false
	snow_last_burst = -1000
	snow_burst_count = 0
	last_strengths.fill(0.0)
	for emitter: GPUParticles3D in dust_emitters + tyre_emitters + deck_dust_emitters + deck_tyre_emitters + spray_emitters + clipping_emitters + mud_emitters + smoke_emitters + snow_chips + snow_powder + snow_impacts + snow_push + water_drops:
		emitter.restart()
		emitter.emitting = false


func sample(state: VehicleState, frame: DriveFrame, track: NativeTrack, bridge: BridgePresentation = null) -> void:
	if track != null:
		_bind_bridges(track)
		_set_desert_profile(str(track.metadata.get("theme","pine")) == "desert")
	var winter: bool = track != null and track.metadata.get("theme","pine") == "winter"
	if track == null or state.jump_height > 0.0 or state.roll_ticks > 0 or state.velocity.length() < (0.06 if winter else 0.8):
		_stop()
		return
	var storm: bool = track.metadata.get("theme","pine") == "storm"
	if storm: _ensure_water()
	if winter: _ensure_snow()
	elif not snow_chips.is_empty():
		for emitter: GPUParticles3D in snow_chips+snow_powder+snow_impacts+snow_push: emitter.emitting = false
		snow_push_position = Vector2.INF
		snow_in_bank = false
		snow_previous_valid = false
	if winter: _sample_bank_impact(state,track)
	var forward: Vector2 = state.forward()
	var right: Vector2 = state.right()
	var rear: Vector2 = state.position - forward * wheelbase * 0.5
	var front: Vector2 = state.position + forward * wheelbase * 0.5
	var contacts: Array[Vector2] = [rear-right*track_width*0.5,rear+right*track_width*0.5,front-right*track_width*0.5,front+right*track_width*0.5]
	var axle_values := PackedFloat32Array([REAR_AXLE,REAR_AXLE,FRONT_AXLE,FRONT_AXLE])
	for wheel: int in range(4):
		var world_position: Vector3 = VisualGeometry.world(contacts[wheel]) + Vector3(0,0.025,0)
		if bridge != null:
			world_position.y += bridge.height_at(contacts[wheel],state.route_index,1 if state.track_elevated else 0)
		var kind: int = SkidTrails.surface_at(track,world_position,state.track_elevated)
		var side: float = -1.0 if wheel % 2 == 0 else 1.0
		var on_sand: bool = kind == SAND_SURFACE
		if on_sand and state.track_elevated: _ensure_deck_clouds()
		var strengths: Vector2 = emission_strengths(state,frame,side,axle_values[wheel]) if on_sand else Vector2(-1.0,-1.0)
		if on_sand and desert_profile:
			strengths.x = maxf(strengths.x,lerpf(0.28,1.0,smoothstep(0.8,12.0,state.velocity.length())))
			if track.cell_at(contacts[wheel],state.track_elevated) in [1,2]:
				strengths.y = maxf(strengths.y,0.30*smoothstep(0.8,12.0,state.velocity.length()))
		last_strengths[wheel] = maxf(0.0,strengths.x)
		var wheel_velocity: Vector2 = state.velocity + right * (state.yaw_rate * axle_values[wheel] * wheelbase * 0.5) - forward * (state.yaw_rate * side * track_width * 0.5)
		if not water_drops.is_empty():
			var water_strength: float = 0.60*smoothstep(3.0,26.0,wheel_velocity.length()) if storm and kind == 9 else 0.0
			_configure(water_drops[wheel],world_position+Vector3.UP*0.07,wheel_velocity,water_strength)
			if water_strength > 0.012:
				var fan: Vector3 = VisualGeometry.world(-wheel_velocity.normalized()+right*side*0.18)+Vector3.UP*0.15
				var local_fan: Vector3 = (water_drops[wheel].basis.inverse()*fan).normalized()
				var process: ParticleProcessMaterial = water_drops[wheel].process_material
				if not process.direction.is_equal_approx(local_fan): process.direction = local_fan
		if winter:
			_sample_snow(wheel,contacts[wheel],world_position,wheel_velocity,kind,state,frame,track)
		_configure(dust_emitters[wheel],world_position,wheel_velocity,strengths.x if not state.track_elevated else -1.0)
		_configure(tyre_emitters[wheel],world_position,wheel_velocity,strengths.x if desert_profile and not state.track_elevated else -1.0)
		if not deck_dust_emitters.is_empty():
			_configure(deck_dust_emitters[wheel],world_position,wheel_velocity,strengths.x if state.track_elevated else -1.0)
			_configure(deck_tyre_emitters[wheel],world_position,wheel_velocity,strengths.x if desert_profile and state.track_elevated else -1.0)
		if wheel < 2:
			_configure(spray_emitters[wheel],world_position+Vector3(0,0.035,0),wheel_velocity,strengths.y)
		var grass_strengths: Vector2 = grass_emission_strengths(state,frame,side,axle_values[wheel]) if kind == 1 else Vector2(-1.0,-1.0)
		_configure(clipping_emitters[wheel],world_position+Vector3(0,0.02,0),wheel_velocity,grass_strengths.x)
		if wheel < 2: _configure(mud_emitters[wheel],world_position+Vector3(0,0.025,0),wheel_velocity,grass_strengths.y)
		var smoke_strength: float = asphalt_smoke_strength(state,frame,axle_values[wheel]) if kind in [0,5] else -1.0
		_configure(smoke_emitters[wheel],world_position+Vector3(0,0.04,0),wheel_velocity,smoke_strength)


static func emission_strengths(state: VehicleState, frame: DriveFrame, wheel_side: float, axle: float) -> Vector2:
	var speed: float = state.velocity.length()
	var speed_factor: float = smoothstep(1.5,18.0,speed)
	var lateral: float = smoothstep(0.45,9.0,absf(state.velocity.dot(state.right())))
	var slip: float = smoothstep(0.025,0.58,absf(state.slip_angle()))
	var yaw: float = smoothstep(0.12,1.45,absf(state.yaw_rate)) * smoothstep(3.0,14.0,speed)
	var braking: float = frame.brake/255.0 * smoothstep(2.0,15.0,speed)
	var dynamic: float = maxf(maxf(lateral,slip),maxf(yaw,braking))
	if axle > 0.0: dynamic *= 0.58
	var load: float = clampf(1.0+wheel_side*state.yaw_rate*signf(state.velocity.dot(state.forward()))*0.14,0.78,1.22)
	var dust: float = speed_factor * lerpf(0.16,1.0,dynamic) * load
	var spray: float = speed_factor * pow(dynamic,1.45) * load
	return Vector2(clampf(dust,0.0,1.0),clampf(spray,0.0,1.0))


static func grass_emission_strengths(state: VehicleState, frame: DriveFrame, wheel_side: float, axle: float) -> Vector2:
	var speed: float = state.velocity.length()
	var speed_factor: float = smoothstep(1.0,16.0,speed)
	var lateral: float = smoothstep(0.4,8.0,absf(state.velocity.dot(state.right())))
	var slip: float = smoothstep(0.035,0.55,absf(state.slip_angle()))
	var braking: float = frame.brake/255.0*smoothstep(2.0,14.0,speed)
	var dynamic: float = maxf(lateral,maxf(slip,braking))
	if axle > 0.0: dynamic *= 0.64
	var load: float = clampf(1.0+wheel_side*state.yaw_rate*0.12,0.82,1.18)
	var clipping: float = speed_factor*lerpf(0.14,1.0,dynamic)*load
	var mud: float = speed_factor*pow(dynamic,1.35)*load
	return Vector2(clampf(clipping,0.0,1.0),clampf(mud,0.0,1.0))


static func asphalt_smoke_strength(state: VehicleState, frame: DriveFrame, axle: float) -> float:
	var speed: float = state.velocity.length()
	var slip: float = smoothstep(0.16,0.62,absf(state.slip_angle()))
	var lateral: float = smoothstep(3.2,10.5,absf(state.velocity.dot(state.right())))
	var braking: float = frame.brake/255.0*smoothstep(8.0,22.0,speed)
	var strength: float = maxf(maxf(slip,lateral),braking)*smoothstep(5.0,18.0,speed)
	if axle > 0.0: strength *= 0.52
	return clampf(strength,0.0,0.48)


func _stop() -> void:
	snow_push_position = Vector2.INF
	snow_previous_valid = false
	snow_in_bank = false
	last_strengths.fill(0.0)
	for emitter: GPUParticles3D in dust_emitters + tyre_emitters + deck_dust_emitters + deck_tyre_emitters + spray_emitters + clipping_emitters + mud_emitters + smoke_emitters + snow_chips + snow_powder + snow_impacts + snow_push + water_drops:
		emitter.emitting = false
		emitter.amount_ratio = 0.0


func _configure(emitter: GPUParticles3D, at: Vector3, wheel_velocity: Vector2, strength: float) -> void:
	var amount: float = clampf(strength,0.0,1.0)
	# World-space particles already emitted keep their trajectory. Inactive
	# wheels need no transform uploads, and unchanged values need no server writes.
	if emitter.amount_ratio != amount: emitter.amount_ratio = amount
	var emitting: bool = amount > 0.012
	if emitter.emitting != emitting: emitter.emitting = emitting
	if not emitting:
		return
	emitter.position = at
	if wheel_velocity.length_squared() > 0.01:
		var backwards := Vector3(-wheel_velocity.x,0.0,wheel_velocity.y).normalized()
		emitter.look_at(at+backwards,Vector3.UP)


func _emitter(label: String, amount: int, lifetime: float, size: Vector2, tint: Color, mode: int) -> GPUParticles3D:
	var spray: bool = mode in [MODE_SAND_SPRAY,MODE_CLIPPING,MODE_MUD]
	var particles := GPUParticles3D.new()
	particles.name = label
	particles.amount = amount
	particles.lifetime = lifetime
	particles.randomness = 0.58
	# Smoke must sample the moving wheel at the canonical 120 Hz rate. At 30 Hz
	# a fast car deposits dense batches a metre apart, visibly forming dots even
	# with a high particle count. Other debris benefits from the cheaper cadence.
	particles.fixed_fps = VehicleSimulation.TICK_RATE if mode in [MODE_SMOKE,MODE_WATER] else 30
	particles.interpolate = true
	particles.fract_delta = true
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-30,-4,-30),Vector3(60,14,60))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0,0.48 if mode in [MODE_DUST,MODE_SMOKE] else 0.42,-1).normalized()
	process.spread = 72.0 if mode in [MODE_DUST,MODE_SMOKE] else 42.0
	process.initial_velocity_min = 0.45 if mode in [MODE_DUST,MODE_SMOKE] else 3.0
	process.initial_velocity_max = 1.65 if mode in [MODE_DUST,MODE_SMOKE] else 7.0
	process.gravity = Vector3(0,0.060 if mode == MODE_DUST else 0.025,0) if mode in [MODE_DUST,MODE_SMOKE] else Vector3(0,-5.0 if mode != MODE_CLIPPING else -7.0,0)
	process.damping_min = 0.75 if mode in [MODE_DUST,MODE_SMOKE] else 3.5
	process.damping_max = 1.25 if mode in [MODE_DUST,MODE_SMOKE] else 6.0
	process.angular_velocity_min = 10.0 if mode == MODE_DUST else -110.0
	process.angular_velocity_max = 14.0 if mode == MODE_DUST else 110.0
	process.scale_min = 0.72
	process.scale_max = 1.28
	process.color = Color(tint.r,tint.g,tint.b,1.0)
	process.color_ramp = _alpha_ramp(tint.a,mode)
	process.scale_curve = _scale_curve(mode)
	if mode == MODE_CLIPPING:
		process.direction = Vector3(0,0.55,-1).normalized()
		process.spread = 48.0
		process.initial_velocity_min = 1.8
		process.initial_velocity_max = 4.8
		process.damping_min = 1.8
		process.damping_max = 3.2
		process.scale_min = 0.55
		process.scale_max = 1.35
		process.angle_min = -180.0
		process.angle_max = 180.0
		process.angular_velocity_min = -260.0
		process.angular_velocity_max = 260.0
		process.scale_curve = null
	particles.process_material = process
	var mesh: Mesh
	if mode == MODE_CLIPPING:
		mesh = _clipping_mesh(size)
	elif mode in [MODE_MUD,MODE_SAND_SPRAY]:
		var grain_mesh := SphereMesh.new()
		grain_mesh.radius = size.x*0.5
		grain_mesh.height = size.y
		grain_mesh.radial_segments = 5
		grain_mesh.rings = 3
		mesh = grain_mesh
	else:
		var quad := QuadMesh.new()
		quad.size = size
		quad.orientation = PlaneMesh.FACE_Z
		mesh = quad
	mesh.surface_set_material(0,_particle_material(mode))
	particles.draw_pass_1 = mesh
	particles.emitting = false
	return particles


func _clipping_mesh(size: Vector2) -> ArrayMesh:
	# Five triangles: torn base, folded ridge and asymmetric tapered tip.
	# Actual geometry keeps a fine silhouette without transparent texture cards.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[Vector3] = [Vector3(-0.36,0,-0.5),Vector3(0.42,0,-0.43),Vector3(-0.5,0,0.08),Vector3(0,0.24,0.02),Vector3(0.40,0,0.14),Vector3(0.19,0.12,0.5)]
	for index: int in [0,2,3,0,3,1,1,3,4,2,5,3,3,5,4]:
		var point: Vector3 = points[index]
		tool.set_uv(Vector2(point.x+0.5,point.z+0.5))
		tool.add_vertex(Vector3(point.x*size.x,point.y*size.x,point.z*size.y))
	tool.generate_normals()
	return tool.commit()


func _cloud_mesh(size: Vector2, material: Material) -> ArrayMesh:
	# The billowing shader has zero alpha outside the unit UV circle. This
	# circumscribed octagon keeps every visible pixel while avoiding 17.16% of
	# the square's rasterized area, especially valuable for overlapping clouds.
	var corner: float = (sqrt(2.0)-1.0)*0.5
	var outline := PackedVector2Array([
		Vector2(-corner,-0.5),Vector2(corner,-0.5),
		Vector2(0.5,-corner),Vector2(0.5,corner),
		Vector2(corner,0.5),Vector2(-corner,0.5),
		Vector2(-0.5,corner),Vector2(-0.5,-corner)])
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for point: Vector2 in outline:
		vertices.append(Vector3(point.x*size.x,-point.y*size.y,0.0))
		uvs.append(point+Vector2(0.5,0.5))
	for i: int in range(1,outline.size()-1):
		indices.append_array(PackedInt32Array([0,i,i+1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.surface_set_material(0,material)
	return mesh


func _alpha_ramp(maximum: float, mode: int) -> GradientTexture1D:
	var cloud: bool = mode in [MODE_DUST,MODE_SMOKE]
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0,0.025 if cloud else 0.08,0.72,1.0])
	gradient.colors = PackedColorArray([Color(1,1,1,0),Color(1,1,1,maximum),Color(1,1,1,maximum*(0.70 if cloud else 0.42)),Color(1,1,1,0)])
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture


func _scale_curve(mode: int) -> CurveTexture:
	var cloud: bool = mode in [MODE_DUST,MODE_SMOKE]
	var curve := Curve.new()
	curve.add_point(Vector2(0.0,0.24 if cloud else 0.55))
	curve.add_point(Vector2(0.12 if cloud else 0.18,0.62 if cloud else 0.9))
	if cloud: curve.add_point(Vector2(0.42,1.60 if mode == MODE_DUST else 1.05))
	curve.add_point(Vector2(1.0,3.65 if mode == MODE_DUST else (1.6 if mode == MODE_SMOKE else 0.78)))
	var texture := CurveTexture.new()
	texture.curve = curve
	return texture


func _particle_material(mode: int) -> ShaderMaterial:
	var cloud: bool = mode in [MODE_DUST,MODE_SMOKE]
	var shader := Shader.new()
	if mode == MODE_CLIPPING:
		shader = preload("res://vehicle/grass_clipping.gdshader")
	elif mode == MODE_WATER:
		shader = preload("res://vehicle/water_drop.gdshader")
	elif mode in [MODE_MUD,MODE_SAND_SPRAY]:
		shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
	ALPHA = COLOR.a;
}
"""
	elif mode == MODE_SMOKE:
		shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
void vertex() {
	vec3 particle_scale = vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0]*particle_scale.x,INV_VIEW_MATRIX[1]*particle_scale.y,INV_VIEW_MATRIX[2]*particle_scale.z,MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = UV*2.0-1.0;
	float radius = length(p);
	float haze = 1.0-smoothstep(0.12,1.0,radius);
	haze *= haze;
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
	ALPHA = COLOR.a*haze;
}
"""
	else:
		shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
#include "res://vehicle/dust_bridge_clip.gdshaderinc"
uniform sampler2D dust_texture : source_color, filter_linear_mipmap;
uniform float alpha_softness = 0.42;
uniform bool billowing = false;
uniform float intersection_fade = 0.45;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform bool dust_birth_height_available = false;
uniform bool dust_height_occlusion = true;
varying highp float dust_density_height;
varying vec2 cloud_uv;
varying highp vec3 dust_world;
varying highp float dust_center_height;
void vertex() {
	// Each particle gets a stable engine-random speed magnitude at spawn.
	// Separate direction from magnitude so none receive near-zero spin.
	float turn_direction = (INSTANCE_ID % 2 == 0) ? -1.0 : 1.0;
	float puff_angle = INSTANCE_CUSTOM.x * turn_direction;
	cloud_uv = UV;
	if (billowing) {
		// Rotation is affine across the card. Evaluate trig per vertex instead
		// of repeating it for every transparent pixel in every overlapping puff.
		float c = cos(puff_angle);
		float s = sin(puff_angle);
		cloud_uv = mat2(vec2(c,-s),vec2(s,c)) * (UV-0.5) + 0.5;
	}
	vec3 particle_scale = vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0]*particle_scale.x,INV_VIEW_MATRIX[1]*particle_scale.y,INV_VIEW_MATRIX[2]*particle_scale.z,MODEL_MATRIX[3]);
	dust_world = (INV_VIEW_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX,1.0)).xyz;
	dust_center_height = dust_birth_height_available ? INSTANCE_CUSTOM.z : MODEL_MATRIX[3].y;
	dust_density_height = MODEL_MATRIX[3].y;
}
void fragment() {
	vec4 puff = texture(dust_texture,clamp(cloud_uv,vec2(0.0),vec2(1.0)));
	float alpha = smoothstep(0.02,alpha_softness,puff.a);
	float value = dot(puff.rgb,vec3(0.299,0.587,0.114));
	ALBEDO = COLOR.rgb * mix(0.72,1.12,value);
	ROUGHNESS = 1.0;
	if (billowing) {
		// Soft density with restrained texture variation, without baked dark lobes.
		vec2 p = UV * 2.0 - 1.0;
		alpha = (1.0-smoothstep(0.42,1.0,length(p))) * mix(0.80,1.0,puff.a);
		ALBEDO = COLOR.rgb * mix(0.94,1.04,value);
		// Soften intersections with the road/car instead of cutting a billboard in half.
		float depth = texture(scene_depth,SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		vec3 ndc = vec3(SCREEN_UV,depth) * 2.0 - 1.0;
#else
		vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0,depth);
#endif
		vec4 scene = INV_PROJECTION_MATRIX * vec4(ndc,1.0);
		alpha *= smoothstep(0.0,intersection_fade,VERTEX.z-scene.z/scene.w);
		// A low-ramp upper puff can also project across a higher bridge roof.
		vec4 opaque_world = INV_VIEW_MATRIX * scene;
		// The billboard is a drawing proxy. Its upper corners must not place
		// low tyre dust above taller solid surfaces. Use the actual particle
		// trajectory height without shrinking or postponing the original cloud.
		if (dust_height_occlusion) {
			alpha *= 1.0-smoothstep(dust_density_height,dust_density_height+0.06,opaque_world.y/opaque_world.w);
		}
		alpha *= dust_bridge_surface_visibility(opaque_world.xyz/opaque_world.w,dust_center_height);
	}
	alpha *= dust_bridge_visibility_at_height(dust_world,dust_center_height);
	vec3 camera_ray = PROJECTION_MATRIX[3].w>0.5 ? INV_VIEW_MATRIX[2].xyz : normalize(INV_VIEW_MATRIX[3].xyz-dust_world);
	alpha *= dust_bridge_projected_visibility(dust_world,camera_ray,dust_center_height);
	ALPHA = COLOR.a * alpha;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.render_priority = 4 if cloud else 1
	if mode == MODE_DUST:
		material.set_shader_parameter("dust_texture",load("res://assets/textures/dust_puff_v1.png"))
		material.set_shader_parameter("alpha_softness",0.42)
	return material


func set_water_paused(paused: bool) -> void:
	if water_paused == paused: return
	water_paused = paused
	for child: Node in get_children():
		if child is GPUParticles3D: child.speed_scale = 0.0 if paused else 1.0


func _ensure_water() -> void:
	if not water_drops.is_empty(): return
	for wheel: int in range(4):
		# Water is short ballistic droplets, never an expanding smoke/dust puff.
		var drops := _emitter("WaterDrops%d" % wheel,56,0.24,Vector2(0.04,0.10),Color(0.80,0.88,0.92,0.48),MODE_WATER)
		var process: ParticleProcessMaterial = drops.process_material
		process.direction = Vector3(0,0.15,-1.0).normalized()
		process.spread = 18.0
		process.initial_velocity_min = 1.2
		process.initial_velocity_max = 3.2
		process.gravity = Vector3(0,-9.8,0)
		process.damping_min = 0.6
		process.damping_max = 1.2
		process.scale_curve = null
		drops.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		drops.speed_scale = 0.0 if water_paused else 1.0
		add_child(drops)
		water_drops.append(drops)


func _ensure_snow() -> void:
	if not snow_chips.is_empty(): return
	for wheel: int in range(4):
		var chips: GPUParticles3D = _emitter("SnowChips%d" % wheel,64,0.70,Vector2(0.09,0.11),Color(0.88,0.94,1.0,0.90),MODE_SAND_SPRAY)
		var process: ParticleProcessMaterial = chips.process_material
		process.gravity = Vector3(0,-8.0,0)
		process.initial_velocity_min = 1.5
		process.initial_velocity_max = 4.5
		process.spread = 62.0
		process.damping_min = 0.7
		process.damping_max = 1.4
		snow_chips.append(chips)
		add_child(chips)
		var powder: GPUParticles3D = _emitter("SnowPowder%d" % wheel,28,1.15,Vector2(0.8,0.8),Color(0.87,0.94,1.0,0.24),MODE_DUST)
		(powder.draw_pass_1.surface_get_material(0) as ShaderMaterial).set_shader_parameter("billowing",true)
		(powder.process_material as ParticleProcessMaterial).scale_curve = _bounded_growth([0.35,0.6,1.0,1.2])
		snow_powder.append(powder)
		add_child(powder)
	for index: int in range(2):
		var burst: GPUParticles3D = _snow_cloud("SnowBankImpact%d" % index,12,0.42,Vector2(1.15,0.85),0.72)
		burst.one_shot = true
		burst.explosiveness = 1.0
		burst.randomness = 0.0
		burst.fixed_fps = VehicleSimulation.TICK_RATE
		var process: ParticleProcessMaterial = burst.process_material
		process.direction = Vector3.UP
		process.spread = 48.0
		process.emission_sphere_radius = 0.24
		snow_impacts.append(burst)
		add_child(burst)
	for index: int in range(2):
		# Compact powder rolls outward, then falls and thins. Reuse the textured
		# dust renderer with twenty total puffs instead of forty-eight solid clods.
		var push: GPUParticles3D = _snow_cloud("SnowBankPush%d" % index,10,0.62,Vector2(1.45,0.90),0.64)
		snow_push.append(push)
		add_child(push)

func _snow_cloud(label: String, amount: int, lifetime: float, size: Vector2, alpha: float) -> GPUParticles3D:
	var particles: GPUParticles3D = _emitter(label,amount,lifetime,size,Color(0.98,0.99,1.0,alpha),MODE_DUST)
	var material: ShaderMaterial = particles.draw_pass_1.surface_get_material(0)
	# Only this snow material changes: ordinary dust keeps its exact shader.
	var snow_shader := Shader.new()
	var original: String = material.shader.code
	var shape: String = "alpha = (1.0-smoothstep(0.42,1.0,length(p))) * mix(0.80,1.0,puff.a);"
	var tint: String = "ALBEDO = COLOR.rgb * mix(0.94,1.04,value);"
	assert(original.contains(shape) and original.contains(tint),"Snow powder requires the shared textured-cloud renderer")
	snow_shader.code = original.replace(shape,"alpha = (1.0-smoothstep(0.25,1.0,length(p))) * smoothstep(0.06,0.80,puff.a) * mix(0.55,1.0,smoothstep(0.16,0.72,value));").replace(tint,"ALBEDO = COLOR.rgb * mix(vec3(0.72,0.81,0.92),vec3(1.02),smoothstep(0.18,0.82,value));")
	material.shader = snow_shader
	material.set_shader_parameter("billowing",true)
	material.set_shader_parameter("intersection_fade",0.22)
	particles.draw_pass_1 = _cloud_mesh(size,material)
	_bind_cloud_bridge_material(particles)
	var process: ParticleProcessMaterial = particles.process_material
	process.gravity = Vector3(0,-4.0,0)
	process.damping_min = 2.0
	process.damping_max = 3.5
	process.spread = 38.0
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.12
	process.scale_curve = _bounded_growth([0.45,0.90,1.12,0.72])
	process.angular_velocity_min = 16.0
	process.angular_velocity_max = 42.0
	process.angular_velocity_curve = _rotation_from_growth(process.scale_curve)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0,0.10,0.50,1.0])
	gradient.colors = PackedColorArray([Color(1,1,1,alpha*0.65),Color(1,1,1,alpha),Color(1,1,1,alpha*0.70),Color(1,1,1,0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	process.color_ramp = ramp
	particles.speed_scale = 0.0 if water_paused else 1.0
	return particles


func _sample_snow(wheel: int, contact: Vector2, at: Vector3, velocity: Vector2, kind: int, state: VehicleState, frame: DriveFrame, track: NativeTrack) -> void:
	var speed: float = state.velocity.length()
	var loose: bool = kind in [7,10]
	var scrub: float = SkidTrails.physics_intensity(state,frame,kind,-1.0 if wheel%2 == 0 else 1.0)
	var moving: float = smoothstep(0.8,13.0,speed)
	var drifting: float = smoothstep(0.07,0.35,absf(state.slip_angle()))
	var chips: float = moving*(0.35+scrub*0.65) if loose else moving*(0.35+scrub*0.65)*drifting if kind == 8 else 0.0
	var powder: float = chips*0.62 if loose else moving*(0.045+drifting*0.12) if kind == 8 else 0.0
	var bank_height: float = 0.0 if state.track_elevated else track.snow_banks.height_at(contact)
	var origin: Vector3 = at+Vector3.UP*(_snow_surface_height(contact,bank_height)+0.04)
	_configure(snow_chips[wheel],origin,velocity,chips)
	_configure(snow_powder[wheel],origin,velocity,powder)

func _sample_bank_impact(state: VehicleState, track: NativeTrack) -> void:
	if state.track_elevated:
		_stop_bank_push()
		snow_previous_valid = false
		snow_in_bank = false
		return
	var start: Vector2 = snow_previous if snow_previous_valid else state.position
	var steps: int = clampi(ceili(start.distance_to(state.position)/0.25),1,8)
	var entry := Vector2.INF
	var push_at := Vector2.INF
	var push_height: float = 0.0
	var touching: bool = false
	var direction: float = state.velocity.angle()
	var half_length: float = maxf(collision_radius,wheelbase*0.5+0.80*HandlingConfig.BODY_SCALE)
	var half_width: float = track_width*0.5+0.12*HandlingConfig.BODY_SCALE
	var forward: Vector2 = state.forward()
	var right: Vector2 = state.right()
	var offsets := PackedVector2Array()
	for index: int in range(12):
		var offset: int = (index+1)/2 * (1 if index%2 == 1 else -1)
		var ray: Vector2 = Vector2.from_angle(direction+float(offset)*TAU/12.0)
		var along: float = ray.dot(forward)/half_length
		var across: float = ray.dot(right)/half_width
		offsets.append(ray/sqrt(along*along+across*across))
	# Sweep a body envelope with bumper overhang, leading edge first, not wheel positions.
	for step: int in range(1,steps+1):
		var center: Vector2 = start.lerp(state.position,float(step)/steps)
		touching = false
		push_at = Vector2.INF
		for offset: Vector2 in offsets:
			var point: Vector2 = center+offset
			var height: float = track.snow_banks.height_at(point)
			if height <= 0.035: continue
			touching = true
			push_at = point
			push_height = height
			if entry == Vector2.INF: entry = point
			# Only the first hit and whether this sweep position touches are needed.
			break
	if touching: _sample_bank_push(state,push_at,push_height,maxf(push_height,track.snow_banks.height_at(state.position)))
	else: _stop_bank_push()
	if entry != Vector2.INF and not snow_in_bank and state.velocity.length() > 2.5 and state.tick-snow_last_burst > 50:
		var burst: GPUParticles3D = snow_impacts[snow_burst_count%2]
		snow_impact_position = entry
		burst.position = VisualGeometry.world(entry)+Vector3.UP*(_snow_surface_height(entry,track.snow_banks.height_at(entry))+0.35)
		burst.amount_ratio = clampf(state.velocity.length()/12.0,0.25,1.0)
		var impact_process: ParticleProcessMaterial = burst.process_material
		var travel: Vector3 = VisualGeometry.world(state.velocity.normalized())
		impact_process.direction = (travel+Vector3.UP*0.22).normalized()
		impact_process.initial_velocity_min = clampf(state.velocity.length()*0.24,1.3,3.5)
		impact_process.initial_velocity_max = clampf(state.velocity.length()*0.42,2.0,5.0)
		burst.restart()
		burst.emitting = true
		snow_last_burst = state.tick
		snow_burst_count += 1
	snow_in_bank = touching
	snow_previous = state.position
	snow_previous_valid = true

func _stop_bank_push() -> void:
	snow_push_position = Vector2.INF
	for emitter: GPUParticles3D in snow_push:
		emitter.emitting = false
		emitter.amount_ratio = 0.0

func _sample_bank_push(state: VehicleState, at: Vector2, height: float, embedded_height: float) -> void:
	snow_push_position = at
	var speed: float = state.velocity.length()
	var travel: Vector2 = state.velocity.normalized()
	var sideways: Vector2 = travel.orthogonal()
	var pressure: float = clampf(embedded_height/SnowBanks.BANK_HEIGHT,0.0,1.0)
	var amount: float = pressure*(0.4+0.6*smoothstep(0.1,4.0,speed))
	for index: int in range(snow_push.size()):
		var emitter: GPUParticles3D = snow_push[index]
		var side: float = -1.0 if index == 0 else 1.0
		emitter.position = VisualGeometry.world(at+sideways*side*0.12)+Vector3.UP*(_snow_surface_height(at,height)+0.16)
		emitter.amount_ratio = amount
		emitter.emitting = amount > 0.012
		var process: ParticleProcessMaterial = emitter.process_material
		process.direction = (VisualGeometry.world(travel*0.40+sideways*side*0.85)+Vector3.UP*0.22).normalized()
		process.initial_velocity_min = 0.6+minf(speed,8.0)*0.10
		process.initial_velocity_max = 1.3+minf(speed,8.0)*0.25

func cloud_emitters() -> Array[GPUParticles3D]:
	return dust_emitters+tyre_emitters+deck_dust_emitters+deck_tyre_emitters+snow_push+snow_impacts

func configure_snow_surface(visual: Node3D) -> void:
	# Sparse half-metre heights baked once from the visible bank mesh, including
	# clumps and bridge tapers. Debris uses constant-time lookup, never a terrain
	# raycast or per-frame triangle search. Canonical contact geometry is untouched.
	_bank_visual_heights.clear()
	for node: Node in visual.get_children():
		if not node is MeshInstance3D or not node.material_override is ShaderMaterial: continue
		if node.material_override.shader != preload("res://track/winter_bank.gdshader"): continue
		for surface: int in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				var point: Vector3 = node.global_transform*vertex
				var key := Vector2i(roundi(point.x*2.0),roundi(-point.z*2.0))
				_bank_visual_heights[key] = maxf(float(_bank_visual_heights.get(key,-INF)),point.y)

func _snow_surface_height(at: Vector2, contact_height: float) -> float:
	if contact_height <= 0.0: return contact_height
	var key := Vector2i(roundi(at.x*2.0),roundi(at.y*2.0))
	# Include the nearest cells to cover gaps between mesh vertices; the small
	# conservative envelope keeps fragments above the irregular opaque snow.
	var height: float = contact_height
	for offset: Vector2i in [Vector2i.ZERO,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
		height = maxf(height,float(_bank_visual_heights.get(key+offset,contact_height)))
	return height

func _bind_bridges(track: NativeTrack) -> void:
	var theme: String = str(track.metadata.get("theme",""))
	if _bridge_track==track and _bridge_theme==theme: return
	assert(track.creator_bridges.size()<=16,"Bridge dust requires the validated sixteen-span contract")
	_bridge_track = track
	_bridge_theme = theme
	_bridge_count = track.creator_bridges.size()
	_bridge_axes.resize(16)
	_bridge_sizes.resize(16)
	for index: int in range(_bridge_count):
		var span: Dictionary = track.creator_bridges[index]
		var angle: float = deg_to_rad(float(span.heading))
		_bridge_axes[index] = Vector4(float(span.position[0]),-float(span.position[1]),cos(angle),-sin(angle))
		_bridge_sizes[index] = Vector4(float(span.length),float(span.width)*0.5+CreatorBridges.RAIL,CreatorBridges.HEIGHT,CreatorBridges.RAMP)
	_bridge_roof.w = 1.0 if theme=="desert" else 0.0
	for emitter: GPUParticles3D in cloud_emitters(): _bind_cloud_bridge_material(emitter)

func _bind_cloud_bridge_material(emitter: GPUParticles3D) -> void:
	(emitter.draw_pass_1.surface_get_material(0) as ShaderMaterial).set_shader_parameter("dust_height_occlusion",height_occlusion_enabled)
	var material: ShaderMaterial = emitter.draw_pass_1.surface_get_material(0)
	material.set_shader_parameter("dust_bridge_count",_bridge_count if bridge_clipping_enabled else 0)
	if not _bridge_axes.is_empty():
		material.set_shader_parameter("dust_bridge_axes",_bridge_axes)
		material.set_shader_parameter("dust_bridge_sizes",_bridge_sizes)
	material.set_shader_parameter("dust_bridge_roof",_bridge_roof)

func _ensure_deck_clouds() -> void:
	if not deck_dust_emitters.is_empty(): return
	for wheel: int in range(4):
		for bank: int in range(2):
			var source: GPUParticles3D = dust_emitters[wheel] if bank==0 else tyre_emitters[wheel]
			var emitter: GPUParticles3D = source.duplicate()
			emitter.name = "Deck"+str(source.name)
			emitter.process_material = source.process_material.duplicate()
			_deck_cloud_sources[emitter] = emitter.process_material
			emitter.draw_pass_1 = source.draw_pass_1.duplicate()
			var material: ShaderMaterial = source.draw_pass_1.surface_get_material(0).duplicate()
			material.set_shader_parameter("dust_upper_layer",true)
			emitter.draw_pass_1.surface_set_material(0,material)
			emitter.emitting = false
			emitter.amount_ratio = 0.0
			add_child(emitter)
			_bind_cloud_bridge_material(emitter)
			_sync_deck_cloud_process(emitter)
			if bank==0: deck_dust_emitters.append(emitter)
			else: deck_tyre_emitters.append(emitter)

func _sync_deck_cloud_process(emitter: GPUParticles3D) -> void:
	var source: ParticleProcessMaterial = _deck_cloud_sources[emitter]
	var draw: ShaderMaterial = emitter.draw_pass_1.surface_get_material(0)
	draw.set_shader_parameter("dust_birth_height_available",desert_profile)
	if not desert_profile:
		emitter.process_material = source
		return
	var process := ShaderMaterial.new()
	process.shader = preload("res://vehicle/dust_birth_process.gdshader")
	for uniform: Dictionary in process.shader.get_shader_uniform_list():
		var key: String = str(uniform.name)
		var value: Variant = RenderingServer.material_get_param(source.get_rid(),key)
		if key=="color_ramp": value = source.color_ramp
		elif key=="scale_curve": value = source.scale_curve
		elif key=="angular_velocity_texture": value = source.angular_velocity_curve
		elif key=="angular_curve_enabled": value = source.angular_velocity_curve!=null
		if value!=null: process.set_shader_parameter(key,value)
	emitter.process_material = process
