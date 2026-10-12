class_name CarVisual
extends Node3D
## Base 4.25 x 1.8 m compact scaled by HandlingConfig.BODY_SCALE; +Z rear, -Z nose. Presentation only.

var underside_material: StandardMaterial3D = VisualGeometry.material(Color.BLACK)
var vehicle_id: String = "compact"
var headlights: Node3D
var road_headlight: SpotLight3D
var night_lights_enabled: bool = false
var rear_braking: bool = false


func set_night_headlights(enabled: bool) -> void:
	night_lights_enabled = enabled
	_update_rear_lights()
	if headlights != null:
		headlights.visible = enabled
		if road_headlight != null: road_headlight.shadow_enabled = false
		return
	if not enabled: return
	headlights = Node3D.new()
	headlights.name = "NightHeadlights"
	body.add_child(headlights)
	# One bounded light for both lamps; no shadow maps, volumetrics or frame work.
	var mount: Vector3 = {"compact":Vector3(0.60,0.80,-2.14),"pickup":Vector3(0.66,1.12,-2.71),"classic":Vector3(0.68,0.75,-1.94),"formula":Vector3(0.32,0.31,-2.20),"kart":Vector3(0.33,0.25,-1.38)}.get(vehicle_id,Vector3(0.60,0.80,-2.14))
	var beam := SpotLight3D.new()
	beam.name = "SharedHeadlightBeam"
	# Keep the entire hood behind the cone. A higher, wider short-range beam
	# spreads across the road just ahead of the bumper without lighting the body.
	beam.position = Vector3(0,maxf(mount.y,0.8)+0.35,mount.z-0.18)
	beam.rotation_degrees.x = -12.0
	beam.light_color = Color("fff0d2")
	beam.light_energy = 5.0
	beam.spot_range = 20.4
	beam.spot_angle = 42.0
	beam.spot_angle_attenuation = 1.2
	beam.spot_attenuation = 0.7
	beam.shadow_enabled = false
	beam.light_cull_mask = 3 # Ordinary world (1) plus bridge-only geometry (2).
	beam.light_bake_mode = Light3D.BAKE_DISABLED
	headlights.add_child(beam)
	road_headlight = beam
	var lens := StandardMaterial3D.new()
	lens.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lens.albedo_color = Color("fff0d2")
	for side: float in [-1.0,1.0]:
		if vehicle_id == "compact":
			for offset: float in [0.405,0.651]:
				var x: float = side*offset
				var round_lens: MeshInstance3D = VisualGeometry.cylinder(headlights,0.071,0.018,Vector3(x,0.798,CompactDetail._nose_z(x)-0.04),lens)
				round_lens.rotation = Vector3(PI*0.5,-atan(0.40625*x),0)
				round_lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			continue
		if vehicle_id == "classic":
			var round_lens: MeshInstance3D = VisualGeometry.cylinder(headlights,0.14,0.012,Vector3(side*mount.x,mount.y,mount.z),lens)
			round_lens.rotation.x = PI*0.38
			round_lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			continue
		var mesh: MeshInstance3D = VisualGeometry.box(headlights,Vector3(0.24,0.13,0.025),Vector3(side*mount.x,mount.y,mount.z),lens)
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	VisualGeometry.batch_static_parts(headlights)


func set_headlight_bridge_occlusion(enabled: bool) -> void:
	if road_headlight != null:
		# Compatibility shadows do not reliably stop a light below a two-sided
		# procedural deck from shading its top face. Bridge meshes use visual layer
		# 2, so exclude that layer throughout ground-level travel (including the
		# approach and exit) and restore it only when driving on the deck.
		road_headlight.light_cull_mask = 1 if enabled else 3
var batch_parts: bool = true
var front_wheels: Array[Node3D] = []
var rolling_wheels: Array[Node3D] = []
var wheel_radii: Array[float] = []
var wheel_rest_positions: Array[Vector3] = []
var wheel_last_point := Vector2.ZERO
var wheel_last_tick: int = -1
var brake_lights: Array[MeshInstance3D] = []
var body: Node3D
var brake_material: StandardMaterial3D
var suspension := Vector3.ZERO # heave, pitch, roll
var suspension_speed := Vector3.ZERO
var last_tick: int = -1
var last_velocity := Vector2.ZERO
var last_jump_velocity: float = 0.0
var was_airborne: bool = false
var was_rolling: bool = false
var last_slope: float = 0.0
var spark_cooldown: float = 0.0
var sparks: Array[Dictionary] = []
var spark_cursor: int = 0
var ramp_tick: int = -1
var ramp_support: float = 0.0
var ramp_lift: float = 0.0
var ramp_velocity: float = 0.0
var ramp_pitch: float = 0.0
var ramp_pitch_speed: float = 0.0
var ramp_body_pitch: float = 0.0

const MAX_SURFACE_HEAVE: float = 0.028
const MAX_SURFACE_ROLL: float = 0.009
const MAX_COLLISION_SUSPENSION_SPEED: float = 1.25


func add_collision_impact(state: VehicleState, resolved_velocity_change: Vector2) -> void:
	var impulse: float = resolved_velocity_change.length()
	var strength: float = smoothstep(2.0,20.0,impulse)
	if strength <= 0.0:
		return
	# The resolved velocity change points away from the contact. Compress the
	# body and tip it along that direction, then let the existing spring settle.
	var direction: Vector2 = resolved_velocity_change / impulse
	suspension_speed.x -= lerpf(0.08,0.42,strength)
	suspension_speed.y += direction.dot(state.forward()) * lerpf(0.16,0.72,strength)
	suspension_speed.z += direction.dot(state.right()) * lerpf(0.20,0.90,strength)
	suspension_speed = suspension_speed.limit_length(MAX_COLLISION_SUSPENSION_SPEED)


func add_scrape(state: VehicleState) -> void:
	# Sustained, quiet body loading; no crash spring kick or camera trauma.
	var strength: float = clampf(state.scrape_strength,0.0,1.0)
	suspension_speed.x -= strength*0.06*VehicleSimulation.STEP
	suspension_speed.y += state.scrape_normal.dot(state.forward())*strength*0.10*VehicleSimulation.STEP
	suspension_speed.z += state.scrape_normal.dot(state.right())*strength*0.28*VehicleSimulation.STEP
	suspension_speed = suspension_speed.limit_length(MAX_COLLISION_SUSPENSION_SPEED)


func present_ramp(state: VehicleState, support: float, pitch: float, enabled: bool) -> void:
	# Small visual unloading at crests, followed by gravity and a damped
	# landing. This never grants canonical airtime or collision immunity.
	if not enabled or ramp_tick < 0 or state.tick < ramp_tick or state.tick-ramp_tick > 30:
		ramp_support = support
		ramp_lift = 0.0
		ramp_velocity = 0.0
		ramp_pitch = pitch
		ramp_pitch_speed = 0.0
		ramp_body_pitch = 0.0
		ramp_tick = state.tick
	if state.tick > ramp_tick:
		var ticks: int = state.tick-ramp_tick
		var rise: float = (support-ramp_support)/ticks
		var height: float = ramp_support+ramp_lift
		for i: int in range(ticks):
			var floor_height: float = ramp_support+rise*(i+1)
			ramp_velocity -= 22.0/120.0
			height += ramp_velocity/120.0
			if height <= floor_height:
				if ramp_lift > 0.005 and ramp_velocity < -1.0:
					suspension_speed.x -= minf(-ramp_velocity*0.10,0.7)
				height = floor_height
				ramp_velocity = minf(rise*120.0,4.5)
			if height > floor_height+0.55:
				height = floor_height+0.55
				ramp_velocity = minf(ramp_velocity,0.0)
			ramp_lift = maxf(0.0,height-floor_height)
			var travel_sign: float = -1.0 if state.velocity.dot(state.forward()) < 0.0 else 1.0
			var flight_pitch: float = atan2(ramp_velocity*travel_sign,maxf(5.0,state.velocity.length()))
			var target: float = lerp_angle(pitch,flight_pitch,smoothstep(0.0,0.12,ramp_lift))
			# Retain angular velocity through touchdown and onto flat road.
			# A damped spring gives a small diminishing rebound instead of a
			# one-way lerp followed by an abrupt return to the road angle.
			ramp_pitch_speed += ((target-ramp_pitch)*100.0-ramp_pitch_speed*10.0)/120.0
			ramp_pitch += ramp_pitch_speed/120.0
		ramp_support = support
		ramp_tick = state.tick
	position.y += ramp_lift
	# Wheel support remains on the road; the sprung body follows slope changes
	# with inertia. During unloading the whole car follows its vertical travel.
	rotation.x = lerp_angle(pitch,ramp_pitch,smoothstep(0.0,0.12,ramp_lift))
	ramp_body_pitch = clampf(ramp_pitch-rotation.x,-0.10,0.10) if enabled else 0.0


func _ready() -> void:
	scale = Vector3.ONE * HandlingConfig.BODY_SCALE
	if vehicle_id != "compact":
		VehicleModels.build(self, vehicle_id)
		_update_rear_lights()
		if batch_parts: VisualGeometry.batch_static_parts(self)
		return
	var paint := VisualGeometry.material(Color("e0d5b5"))
	var blue := VisualGeometry.material(Color("30627d"))
	var trim := VisualGeometry.material(Color("171e21"))
	var glass := VisualGeometry.material(Color("1e3036"))
	var rim := VisualGeometry.material(Color("657177"))
	var lamps := VisualGeometry.material(Color("e4dfc5"))
	brake_material = VisualGeometry.material(Color("802d2b"))
	body = Node3D.new()
	add_child(body)
	_shell(body, [Vector3(0.82,0.32,2.00),Vector3(0.90,0.40,2.125),Vector3(0.88,0.52,2.08)], blue)
	_shell(body, [Vector3(0.86, 0.5, 2.03), Vector3(0.88, 0.86, 1.98), Vector3(0.76, 1.02, 1.8)], blue)
	# Three-door hatch: the cabin reaches the tail, with no sedan boot deck.
	_hatchback(paint, glass, trim, blue)
	for side: float in [-1.0, 1.0]:
		VisualGeometry.box(body,Vector3(0.055,0.22,0.035),Vector3(side*0.806,0.798,-2.005),VisualGeometry.material(Color("b77929")))
		for axle: float in [-1.28, 1.28]:
			var pivot := Node3D.new()
			pivot.position = Vector3(side * 0.83, 0.37, axle)
			add_child(pivot)
			CompactDetail.tire(pivot, trim)
			var hub := VisualGeometry.cylinder(pivot, 0.228, 0.16, Vector3.ZERO, trim)
			hub.rotation.z = PI * 0.5
			for spoke: int in range(8):
				var a: float = spoke*TAU/8.0
				_seam(pivot,Vector3(side*0.085,sin(a)*0.08,cos(a)*0.08),Vector3(side*0.148,sin(a)*0.222,cos(a)*0.222),0.032,rim)
			if axle < 0:
				front_wheels.append(pivot)
			register_rolling_wheel(pivot, 0.37)
	VisualGeometry.box(body, Vector3(0.4, 0.13, 0.045), Vector3(0, 0.64, 2.15), lamps)
	CompactDetail.build(self, blue, paint, trim, rim)
	_update_rear_lights()
	if batch_parts: VisualGeometry.batch_static_parts(self)


func present(point: Vector2, angle: float, state: VehicleState, frame: DriveFrame) -> void:
	# Use interpolated travel, so repeated redraws cannot spin stationary tires.
	var travel := Vector2.ZERO
	if wheel_last_tick >= 0 and state.tick >= wheel_last_tick and state.tick - wheel_last_tick <= 30:
		travel = point - wheel_last_point
	else:
		for rotor: Node3D in rolling_wheels:
			rotor.rotation.x = 0.0
	wheel_last_point = point
	wheel_last_tick = state.tick
	position = VisualGeometry.world(point)
	rotation.y = -angle
	for wheel: Node3D in front_wheels:
		wheel.rotation.y = -state.steering * (0.60 if vehicle_id == "kart" else 0.4)
	for i: int in range(rolling_wheels.size()):
		var rotor: Node3D = rolling_wheels[i]
		var pivot: Node3D = rotor.get_parent() as Node3D
		var heading: float = angle - pivot.rotation.y
		var distance: float = travel.dot(Vector2(sin(heading), cos(heading)))
		rotor.rotation.x = wrapf(rotor.rotation.x - distance / wheel_radii[i], -PI, PI)
	var braking: bool = frame.brake > 0
	if braking != rear_braking:
		rear_braking = braking
		_update_rear_lights()


func _update_rear_lights() -> void:
	# Self-lit lenses reuse the existing material/batch: no extra Light3D or pass.
	brake_material.albedo_color = Color("f17158") if rear_braking else Color("802d2b")
	brake_material.emission_enabled = true
	brake_material.emission = Color("e02b1d")
	brake_material.emission_energy_multiplier = 2.2 if rear_braking else 0.65


func register_rolling_wheel(pivot: Node3D, radius: float) -> void:
	# Steering remains on the parent; tires, hubs and spokes roll around local X.
	var rotor := Node3D.new()
	rotor.name = "WheelSpin"
	var meshes: Array[Node] = pivot.get_children()
	pivot.add_child(rotor)
	for mesh: Node in meshes:
		mesh.reparent(rotor, false)
	rolling_wheels.append(rotor)
	wheel_radii.append(radius * HandlingConfig.BODY_SCALE)
	wheel_rest_positions.append(pivot.position)


func present_suspension(state: VehicleState, road_pitch: float, dry_contact: bool = true, surface_rumble: float = 0.0, kerb_heights: Vector4 = Vector4.ZERO) -> void:
	# Consume snapshots once, independent of display rate; never write to simulation.
	if last_tick < 0 or state.tick < last_tick or state.tick - last_tick > 30:
		suspension = Vector3.ZERO
		suspension_speed = Vector3.ZERO
		spark_cooldown = 0.0
		for spark: Dictionary in sparks:
			spark.life = 0.0
			spark.mesh.visible = false
		last_tick = state.tick
		last_velocity = state.velocity
		last_slope = road_pitch
		was_rolling = state.roll_ticks > 0
		was_airborne = state.jump_height > 0.0
		last_jump_velocity = state.jump_velocity
	if state.tick > last_tick:
		var dt: float = (state.tick - last_tick) / 120.0
		var acceleration: Vector2 = (state.velocity - last_velocity) / dt
		var airborne: bool = state.jump_height > 0.0
		var slope_rate: float = (road_pitch - last_slope) / dt
		var impact: float = maxf(0.0, -last_jump_velocity) if was_airborne and not airborne else 0.0
		var target := Vector3(0.0, clampf(acceleration.dot(state.forward()) * 0.004, -0.085, 0.065), clampf(acceleration.dot(state.right()) * 0.005, -0.10, 0.10))
		if airborne:
			target = Vector3(0.035, 0.0, 0.0)
		elif not was_airborne:
			target.x = clampf(-slope_rate * state.velocity.dot(state.forward()) * 0.002, -0.075, 0.05)
			target.y -= clampf(slope_rate * 0.012, -0.035, 0.035)
		if was_rolling and state.roll_ticks == 0:
			suspension_speed.x -= 0.85
			suspension_speed.z += state.roll_direction * 0.24
		if state.roll_ticks > 0:
			target = Vector3.ZERO
			suspension = Vector3.ZERO
			suspension_speed = Vector3.ZERO
		if impact > 0.0:
			suspension_speed.x -= minf(impact * 0.16, 1.2)
			suspension_speed.y -= minf(impact * 0.035, 0.20)
		spark_cooldown = maxf(0.0, spark_cooldown - dt)
		_update_sparks(dt)
		for step: int in range(state.tick - last_tick):
			# Heave/pitch settle over more than one diminishing movement;
			# lateral roll retains its accepted steering response.
			suspension_speed += ((target - suspension) * Vector3(90.0,110.0,150.0) - suspension_speed * Vector3(9.0,10.0,15.0)) / 120.0
			suspension += suspension_speed / 120.0
			suspension.x = clampf(suspension.x, -0.11, 0.06)
			suspension.y = clampf(suspension.y, -0.12, 0.12)
			suspension.z = clampf(suspension.z, -0.12, 0.12)
		var hard_ramp: bool = not was_airborne and absf(road_pitch) > 0.12 and absf(slope_rate) * state.velocity.length() > 16.0
		if dry_contact and not airborne and state.velocity.length() > 9.0 and spark_cooldown == 0.0 and (impact > 3.0 or hard_ramp):
			_emit_sparks(state, road_pitch)
			spark_cooldown = 0.4
		last_tick = state.tick
		last_velocity = state.velocity
		last_jump_velocity = state.jump_velocity
		was_rolling = state.roll_ticks > 0
		was_airborne = airborne
		last_slope = road_pitch
	var compliance: float = 0.30 if vehicle_id == "kart" else 1.0
	# Loose ground agitates the sprung body without changing the canonical pose.
	# Tick-derived phases keep the result independent of render frame rate.
	var rumble: float = clampf(surface_rumble, 0.0, 1.0)
	var phase: float = state.tick / 120.0
	var surface_heave: float = (sin(phase * 55.0) + sin(phase * 31.0) * 0.35) * MAX_SURFACE_HEAVE * rumble
	var surface_roll: float = (sin(phase * 43.0) + cos(phase * 29.0) * 0.30) * MAX_SURFACE_ROLL * rumble
	body.position.y = suspension.x * compliance / HandlingConfig.BODY_SCALE + surface_heave
	body.rotation.x = (suspension.y + ramp_body_pitch) * compliance
	body.rotation.z = suspension.z * compliance + surface_roll
	# The canonical spring moves the chassis; each tyre follows its own contact
	# instead of inheriting that rigid plane. Keep diagonal/single-wheel contact.
	var kerb_pose: Vector3 = state.kerb_offset if state.jump_height == 0.0 and state.roll_ticks == 0 else Vector3.ZERO
	var kerb_basis := Basis.from_euler(Vector3(kerb_pose.y,0.0,kerb_pose.z))
	for i: int in range(rolling_wheels.size()):
		var rest: Vector3 = wheel_rest_positions[i]
		var wheel: Node3D = rolling_wheels[i].get_parent() as Node3D
		var contact_index: int = (0 if rest.z < 0.0 else 2) + (0 if rest.x < 0.0 else 1)
		var height: float = kerb_heights[contact_index] if state.jump_height == 0.0 and state.roll_ticks == 0 else 0.0
		wheel.position.y = (rest.y + (height-kerb_pose.x)/HandlingConfig.BODY_SCALE - kerb_basis.x.y*rest.x - kerb_basis.z.y*rest.z)/kerb_basis.y.y
	# Accentuate the existing damped response, preserving the contacted side and
	# axle. The kart retains its stiffer chassis; canonical handling is untouched.
	body.rotation.x += kerb_pose.y * 0.70 * compliance
	body.rotation.z += kerb_pose.z * 0.70 * compliance


# Conservative cross-section of the wheels, body, mirrors and roof in model metres.
const ROLL_OUTLINE: Array[Vector2] = [Vector2(-0.975,0.0), Vector2(0.975,0.0),
	Vector2(-0.975,0.76), Vector2(0.975,0.76), Vector2(-1.02,1.09), Vector2(1.02,1.09),
	Vector2(-0.63,1.49), Vector2(0.63,1.49)]

func present_roll(state: VehicleState, interpolation: float = 1.0) -> void:
	if state.roll_ticks <= 0: return
	var elapsed: float = VehicleSimulation.ROLL_DURATION_TICKS - state.roll_ticks - (1.0 - interpolation)
	var phase: float = clampf(elapsed / VehicleSimulation.ROLL_DURATION_TICKS, 0.0, 1.0)
	# Load the outside tires before tipping, accelerate through the roll, then land.
	var turn: float = phase - 0.075 * sin(TAU * phase)
	var roll: float = state.roll_direction * TAU * turn
	var low: float = INF
	var outline: Array[Vector2] = ROLL_OUTLINE
	if vehicle_id != "compact":
		var half_width: float = 1.05 if vehicle_id == "pickup" else 1.16 if vehicle_id == "formula" else 0.96
		var height: float = 1.96 if vehicle_id == "pickup" else 0.91 if vehicle_id == "formula" else 1.36
		outline = [Vector2(-half_width,0),Vector2(half_width,0),Vector2(-half_width,0.75),Vector2(half_width,0.75),Vector2(-0.76,height),Vector2(0.76,height)]
	if vehicle_id == "kart":
		outline = [Vector2(-0.86,0),Vector2(0.86,0),Vector2(-0.86,0.44),Vector2(0.86,0.44),Vector2(-0.23,1.16),Vector2(0.23,1.16)]
	for point: Vector2 in outline:
		low = minf(low, sin(roll) * point.x + cos(roll) * point.y)
	var support: float = maxf(0.0, -low) * HandlingConfig.BODY_SCALE
	# Keep the mass center over its simulated path instead of orbiting the floor origin.
	var right_axis: Vector3 = basis.x.normalized()
	position += right_axis * sin(roll) * (0.40 if vehicle_id == "kart" else 0.70) * HandlingConfig.BODY_SCALE
	position.y += support + 0.06 * pow(sin(TAU * phase), 2.0)
	rotation.z = roll


func _emit_sparks(state: VehicleState, slope: float) -> void:
	if sparks.is_empty():
		var material := VisualGeometry.material(Color("ffd078"))
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		for i: int in range(24):
			var mesh := VisualGeometry.box(self, Vector3(0.035, 0.035, 0.19), Vector3.ZERO, material)
			mesh.top_level = true
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh.visible = false
			sparks.append({"mesh":mesh, "life":0.0, "velocity":Vector3.ZERO})
	var travel: Vector3 = VisualGeometry.world(state.velocity).normalized()
	for i: int in range(8):
		var spark: Dictionary = sparks[spark_cursor]
		spark_cursor = (spark_cursor + 1) % sparks.size()
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var local := Vector3(side * 0.65, 0.07, -1.65 if slope >= 0.0 else 1.65)
		spark.mesh.global_position = global_transform * local
		spark.velocity = -travel * (2.0 + i * 0.45) + global_basis.x.normalized() * side * (0.6 + i * 0.13) + Vector3.UP * (1.0 + i * 0.13)
		spark.life = 0.22 + i * 0.018
		spark.mesh.visible = true
		spark.mesh.scale = Vector3.ONE
		spark.mesh.look_at(spark.mesh.global_position + spark.velocity)


func _update_sparks(dt: float) -> void:
	for spark: Dictionary in sparks:
		spark.life = maxf(0.0, spark.life - dt)
		spark.mesh.visible = spark.life > 0.0
		if spark.life > 0.0:
			spark.velocity += Vector3.DOWN * 9.8 * dt
			spark.mesh.global_position += spark.velocity * dt
			spark.mesh.scale = Vector3.ONE * minf(1.0, spark.life * 12.0)


func _shell(parent: Node3D, sections: Array[Vector3], surface: Material) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for section: Vector3 in sections:
		var w: float = section.x
		var y: float = section.y
		var length: float = section.z
		rings.append(PackedVector3Array([Vector3(-w + 0.16, y, -length), Vector3(w - 0.16, y, -length),
			Vector3(w, y, -length + 0.22), Vector3(w, y, length - 0.22), Vector3(w - 0.16, y, length),
			Vector3(-w + 0.16, y, length), Vector3(-w, y, length - 0.22), Vector3(-w, y, -length + 0.22)]))
	for row: int in range(rings.size() - 1):
		for i: int in range(8):
			var j: int = (i + 1) % 8
			for vertex: Vector3 in [rings[row][i], rings[row + 1][j], rings[row + 1][i], rings[row][i], rings[row][j], rings[row + 1][j]]:
				tool.add_vertex(vertex)
	var top: PackedVector3Array = rings.back()
	for i: int in range(1, 7):
		for vertex: Vector3 in [top[0], top[i], top[i + 1]]:
			tool.add_vertex(vertex)
	tool.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = tool.commit()
	instance.material_override = surface
	parent.add_child(instance)
	# Close the shell at its actual lower outline. Reversed top winding faces
	# downwards, so a rolling car cannot expose the backfaces of its bodywork.
	var bottom: PackedVector3Array = rings.front()
	var floor_tool := SurfaceTool.new()
	floor_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(1, 7):
		for vertex: Vector3 in [bottom[0], bottom[i + 1], bottom[i]]:
			floor_tool.set_normal(Vector3.DOWN)
			floor_tool.add_vertex(vertex)
	var underside := MeshInstance3D.new()
	underside.name = "BlackUnderside"
	underside.mesh = floor_tool.commit()
	underside.material_override = underside_material
	parent.add_child(underside)


func _seam(parent: Node3D, start: Vector3, end: Vector3, width: float, surface: Material) -> void:
	var stroke := VisualGeometry.box(parent,Vector3(width,width,start.distance_to(end)),(start+end)*0.5,surface)
	var up: Vector3 = Vector3.RIGHT if absf((end-start).normalized().dot(Vector3.UP)) > 0.99 else Vector3.UP
	stroke.basis = Basis.looking_at(end-start,up)


func _hatchback(paint: Material, glass: Material, trim: Material, blue: Material) -> void:
	# Broad roof, long side glazing and a sloping rear hatch; +Z is the tail.
	var lf := Vector3(-0.76,1.01,-1.00)
	var rf := Vector3(0.76,1.01,-1.00)
	var lr := Vector3(-0.76,1.01,1.91)
	var rr := Vector3(0.76,1.01,1.91)
	var tlf := Vector3(-0.63,1.48,-0.40)
	var trf := Vector3(0.63,1.48,-0.40)
	var tlr := Vector3(-0.63,1.48,1.18)
	var trr := Vector3(0.63,1.48,1.18)
	_panel([lf,rf,trf,tlf],Vector3(0,0.79,-0.61),paint)
	_panel([lr,rr,trr,tlr],Vector3(0,0.84,0.54),paint)
	var roof_paint := VisualGeometry.material(Color("c5baa0"))
	_panel([tlf,trf,trr,tlr],Vector3.UP,roof_paint)
	var roof := Node3D.new()
	body.add_child(roof)
	roof.position.z = 0.39
	_shell(roof,[Vector3(0.63,1.474,0.79),Vector3(0.60,1.49,0.77)],roof_paint)
	preload("res://vehicle/compact_glazing.gd").window(self,[Vector3(-0.68,1.065,-0.95),Vector3(0.68,1.065,-0.95),Vector3(0.57,1.445,-0.46),Vector3(-0.57,1.445,-0.46)],Vector3(0,0.79,-0.61),trim,0.10)
	preload("res://vehicle/compact_glazing.gd").window(self,[Vector3(-0.67,1.075,1.83),Vector3(0.67,1.075,1.83),Vector3(0.57,1.435,1.27),Vector3(-0.57,1.435,1.27)],Vector3(0,0.84,0.54),trim,0.07)
	var quarter_surround := VisualGeometry.material(Color("a6b1aa"))
	for side: float in [-1.0,1.0]:
		_panel([Vector3(side*0.76,1.01,-1.0),Vector3(side*0.76,1.01,1.91),Vector3(side*0.63,1.48,1.18),Vector3(side*0.63,1.48,-0.4)],Vector3(side,0.277,0),blue)
		# Window corners lie on the sloped cabin side, just outside its paint.
		preload("res://vehicle/compact_glazing.gd").window(self,[Vector3(side*0.748,1.07,-0.85),Vector3(side*0.748,1.07,0.42),Vector3(side*0.651,1.425,0.42),Vector3(side*0.651,1.425,-0.35)],Vector3(side,0.277,0),trim,0.0)
		preload("res://vehicle/compact_glazing.gd").window(self,[Vector3(side*0.747,1.075,0.50),Vector3(side*0.733,1.125,1.53),Vector3(side*0.656,1.405,1.12),Vector3(side*0.651,1.425,0.50)],Vector3(side,0.277,0),trim,0.0,[0.035,0.15,0.095,0.035],quarter_surround)
		_seam(body,Vector3(side*0.70,1.02,-0.92),Vector3(side*0.12,1.04,-0.93),0.022,trim)
	# Hatch seam and rear wiper make the short tail readable from overhead.
	_seam(body,Vector3(-0.68,1.05,1.87),Vector3(0.68,1.05,1.87),0.018,trim)
	_seam(body,Vector3(0,1.10,1.80),Vector3(0.36,1.17,1.69),0.020,trim)
	# A fine inset perimeter crease defines the pressed roof's rolled edge.
	var roof_line := VisualGeometry.material(Color("b3aa95"))
	var roof_highlight := VisualGeometry.material(Color("dcd1b6"))
	var perimeter: Array[Vector2] = [Vector2(-0.44,-0.38),Vector2(0.44,-0.38),Vector2(0.60,-0.16),Vector2(0.60,0.94),Vector2(0.44,1.16),Vector2(-0.44,1.16),Vector2(-0.60,0.94),Vector2(-0.60,-0.16)]
	for i: int in range(perimeter.size()):
		var a: Vector2 = perimeter[i]
		var b: Vector2 = perimeter[(i+1)%perimeter.size()]
		_seam(body,Vector3(a.x,1.493,a.y),Vector3(b.x,1.493,b.y),0.008,roof_line)
		var inset_a: Vector2 = Vector2(0,0.39).lerp(a,0.986)
		var inset_b: Vector2 = Vector2(0,0.39).lerp(b,0.986)
		_seam(body,Vector3(inset_a.x,1.493,inset_a.y),Vector3(inset_b.x,1.493,inset_b.y),0.008,roof_highlight)


func _panel(points: Array[Vector3], normal: Vector3, surface: Material) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices: Array[int] = [0,1,2,0,2,3]
	if (points[1]-points[0]).cross(points[2]-points[0]).dot(normal) > 0:
		indices = [0,2,1,0,3,2]
	for index: int in indices:
		tool.set_normal(normal.normalized())
		tool.add_vertex(points[index])
	var node := MeshInstance3D.new()
	node.mesh = tool.commit()
	node.material_override = surface
	body.add_child(node)
