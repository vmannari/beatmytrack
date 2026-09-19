class_name CarVisual
extends Node3D
## Base 4.25 x 1.8 m compact scaled by HandlingConfig.BODY_SCALE; +Z rear, -Z nose. Presentation only.

var vehicle_id: String = "compact"
var batch_parts: bool = true
var front_wheels: Array[Node3D] = []
var rolling_wheels: Array[Node3D] = []
var wheel_radii: Array[float] = []
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


func _ready() -> void:
	scale = Vector3.ONE * HandlingConfig.BODY_SCALE
	if vehicle_id != "compact":
		VehicleModels.build(self, vehicle_id)
		if batch_parts: VisualGeometry.batch_static_parts(self)
		return
	var paint := VisualGeometry.material(Color("c8c1ab"))
	VisualGeometry.ink(paint)
	var blue := VisualGeometry.material(Color("244d69"))
	VisualGeometry.ink(blue)
	var trim := VisualGeometry.material(Color("171e21"))
	var glass := VisualGeometry.material(Color("293b43"))
	var rim := VisualGeometry.material(Color("657177"))
	var lamps := VisualGeometry.material(Color("e4dfc5"))
	brake_material = VisualGeometry.material(Color("802d2b"))
	body = Node3D.new()
	add_child(body)
	_shell(body, [Vector3(0.82,0.32,2.00),Vector3(0.90,0.40,2.125),Vector3(0.88,0.52,2.08)], trim)
	_shell(body, [Vector3(0.86, 0.5, 2.03), Vector3(0.88, 0.86, 1.98), Vector3(0.76, 1.02, 1.8)], blue)
	_shell(body, [Vector3(0.875, 0.85, 1.98), Vector3(0.76, 1.02, 1.8)], paint)
	# Three-door hatch: the cabin reaches the tail, with no sedan boot deck.
	_hatchback(paint, glass, trim)
	for side: float in [-1.0, 1.0]:
		_seam(body,Vector3(side*0.55,1.025,-1.73),Vector3(side*0.58,1.025,-1.05),0.012,trim)
		# One long front door, then a fixed rear quarter window.
		_seam(body,Vector3(side*0.88,0.87,0.47),Vector3(side*0.88,0.58,0.47),0.012,trim)
		VisualGeometry.box(body,Vector3(0.025,0.055,0.20),Vector3(side*0.88,0.85,0.32),trim)
		_seam(body,Vector3(side*0.89,0.64,-0.90),Vector3(side*0.89,0.64,0.78),0.024,trim)
		# Painted sill stripe and swept rear-quarter cream motif from the menu.
		_panel([Vector3(side*0.884,0.83,0.78),Vector3(side*0.884,0.83,1.35),Vector3(side*0.884,0.59,1.05),Vector3(side*0.884,0.59,0.90)],Vector3(side,0,0),paint)
	VisualGeometry.box(body,Vector3(1.26,0.19,0.04),Vector3(0,0.79,-2.035),trim)
	for slat: int in range(3):
		VisualGeometry.box(body,Vector3(0.72,0.013,0.025),Vector3(0,0.73+slat*0.055,-2.065),rim)
	for side: float in [-1.0, 1.0]:
		for offset: float in [0.43,0.65]:
			var lamp := VisualGeometry.cylinder(body,0.10,0.04,Vector3(side*offset,0.80,-2.055),lamps)
			lamp.rotation.x = PI*0.5
		VisualGeometry.box(body,Vector3(0.14,0.13,0.045),Vector3(side*0.77,0.77,-2.02),VisualGeometry.material(Color("b77929")))
		brake_lights.append(VisualGeometry.box(body, Vector3(0.16, 0.27, 0.07), Vector3(side * 0.73, 0.84, 2.01), brake_material))
		VisualGeometry.box(body, Vector3(0.18, 0.12, 0.28), Vector3(side * 0.93, 1.03, -0.48), trim)
		for axle: float in [-1.28, 1.28]:
			for segment: int in range(12):
				var a0: float = PI*segment/12.0
				var a1: float = PI*(segment+1)/12.0
				_panel([Vector3(side*0.893,0.37+sin(a0)*0.39,axle+cos(a0)*0.39),Vector3(side*0.893,0.37+sin(a1)*0.39,axle+cos(a1)*0.39),Vector3(side*0.895,0.37+sin(a1)*0.46,axle+cos(a1)*0.46),Vector3(side*0.895,0.37+sin(a0)*0.46,axle+cos(a0)*0.46)],Vector3(side,0,0),blue)
			var pivot := Node3D.new()
			pivot.position = Vector3(side * 0.83, 0.37, axle)
			add_child(pivot)
			var tire := VisualGeometry.cylinder(pivot, 0.36, 0.24, Vector3.ZERO, trim)
			tire.rotation.z = PI * 0.5
			var hub := VisualGeometry.cylinder(pivot, 0.2, 0.25, Vector3.ZERO, rim)
			hub.rotation.z = PI * 0.5
			for spoke: int in range(8):
				var a: float = spoke*TAU/8.0
				_seam(pivot,Vector3(side*0.132,sin(a)*0.08,cos(a)*0.08),Vector3(side*0.132,sin(a)*0.185,cos(a)*0.185),0.024,lamps)
			if axle < 0:
				front_wheels.append(pivot)
			register_rolling_wheel(pivot, 0.36)
	VisualGeometry.box(body, Vector3(1.0, 0.14, 0.08), Vector3(0, 0.49, -2.13), trim)
	VisualGeometry.box(body, Vector3(0.4, 0.13, 0.045), Vector3(0, 0.64, 2.15), lamps)
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
	brake_material.albedo_color = Color("f17158") if frame.brake > 0 else Color("802d2b")


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


func present_suspension(state: VehicleState, road_pitch: float, dry_contact: bool = true) -> void:
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
			target.x = -minf(absf(slope_rate) * state.velocity.length() * 0.0015, 0.07)
			target.y -= clampf(slope_rate * 0.018, -0.045, 0.045)
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
			suspension_speed += ((target - suspension) * 150.0 - suspension_speed * 15.0) / 120.0
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
	body.position.y = suspension.x * compliance / HandlingConfig.BODY_SCALE
	body.rotation.x = suspension.y * compliance
	body.rotation.z = suspension.z * compliance


# Conservative cross-section of the wheels, body, mirrors and roof in model metres.
const ROLL_OUTLINE: Array[Vector2] = [Vector2(-0.95,0.01), Vector2(0.95,0.01),
	Vector2(-0.95,0.73), Vector2(0.95,0.73), Vector2(-1.02,1.09), Vector2(1.02,1.09),
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


func _seam(parent: Node3D, start: Vector3, end: Vector3, width: float, surface: Material) -> void:
	var stroke := VisualGeometry.box(parent,Vector3(width,width,start.distance_to(end)),(start+end)*0.5,surface)
	var up: Vector3 = Vector3.RIGHT if absf((end-start).normalized().dot(Vector3.UP)) > 0.99 else Vector3.UP
	stroke.basis = Basis.looking_at(end-start,up)


func _hatchback(paint: Material, glass: Material, trim: Material) -> void:
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
	_panel([tlf,trf,trr,tlr],Vector3.UP,paint)
	_panel([Vector3(-0.68,1.065,-0.95),Vector3(0.68,1.065,-0.95),Vector3(0.57,1.445,-0.46),Vector3(-0.57,1.445,-0.46)],Vector3(0,0.79,-0.61),glass)
	_panel([Vector3(-0.67,1.075,1.83),Vector3(0.67,1.075,1.83),Vector3(0.57,1.435,1.27),Vector3(-0.57,1.435,1.27)],Vector3(0,0.84,0.54),glass)
	for side: float in [-1.0,1.0]:
		_panel([Vector3(side*0.76,1.01,-1.0),Vector3(side*0.76,1.01,1.91),Vector3(side*0.63,1.48,1.18),Vector3(side*0.63,1.48,-0.4)],Vector3(side,0.277,0),paint)
		# Window corners lie on the sloped cabin side, just outside its paint.
		_panel([Vector3(side*0.748,1.07,-0.85),Vector3(side*0.748,1.07,0.42),Vector3(side*0.651,1.425,0.42),Vector3(side*0.651,1.425,-0.35)],Vector3(side,0.277,0),glass)
		_panel([Vector3(side*0.748,1.07,0.52),Vector3(side*0.748,1.07,1.68),Vector3(side*0.651,1.425,1.14),Vector3(side*0.651,1.425,0.52)],Vector3(side,0.277,0),glass)
		_panel([Vector3(side*0.749,1.07,0.42),Vector3(side*0.749,1.07,0.52),Vector3(side*0.652,1.425,0.52),Vector3(side*0.652,1.425,0.42)],Vector3(side,0.277,0),trim)
		_seam(body,Vector3(side*0.750,1.065,-0.88),Vector3(side*0.750,1.065,1.70),0.018,trim)
		_seam(body,Vector3(side*0.70,1.02,-0.92),Vector3(side*0.12,1.04,-0.93),0.022,trim)
	var reflection := VisualGeometry.material(Color("4d6673"))
	_panel([Vector3(-0.52,1.074,-0.944),Vector3(-0.34,1.074,-0.944),Vector3(0.10,1.44,-0.471),Vector3(-0.13,1.44,-0.471)],Vector3(0,0.79,-0.61),reflection)
	# Hatch seam and rear wiper make the short tail readable from overhead.
	_seam(body,Vector3(-0.68,1.05,1.87),Vector3(0.68,1.05,1.87),0.018,trim)
	_seam(body,Vector3(0,1.10,1.80),Vector3(0.36,1.17,1.69),0.020,trim)


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
