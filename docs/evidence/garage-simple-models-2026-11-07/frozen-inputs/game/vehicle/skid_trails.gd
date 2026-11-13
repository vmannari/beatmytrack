class_name SkidTrails
extends Node3D
## Race-persistent fixed-size ring. Geometry and sampling belong to the shared
## tire-mark renderer; optional visibility compacts only offscreen draw groups.

const TRAIL_SHADER: Shader = preload("res://vehicle/skid_trails.gdshader")
const CAPACITY: int = 16384
const SAMPLE_DISTANCE: float = 0.32
const MAX_SEGMENT_LENGTH: float = 1.5
const GRASS_SOIL_PIGMENT: Color = Color(0.32, 0.205, 0.11, 1.0)
const ROAD_MUD_PIGMENT: Color = Color(0.43, 0.29, 0.15, 1.0)
var instances: MultiMesh
var trail_visibility: TrailVisibility
var mark_colors := PackedColorArray()
var mark_custom := PackedColorArray()
var mark_transforms: Array[Transform3D] = []
var _previous_marks := PackedInt32Array([-1,-1,-1,-1])
var _previous_sides := PackedVector3Array([Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO])
var _previous_ends := PackedVector3Array([Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO])
var _previous_types := PackedInt32Array([-1,-1,-1,-1])
var wheelbase: float = 2.56 * HandlingConfig.BODY_SCALE
var track_width: float = 1.52 * HandlingConfig.BODY_SCALE
var cursor: int = 0
var previous_left: Vector3
var previous_right: Vector3
var previous_front_left: Vector3
var previous_front_right: Vector3
var previous_left_strength: float = 0.0
var previous_right_strength: float = 0.0
var previous_front_left_strength: float = 0.0
var previous_front_right_strength: float = 0.0
var active: bool = false
var desert_sand: bool = false:
	set(value):
		if desert_sand == value: return
		desert_sand = value
		if _bridge_material != null: _bridge_material.set_shader_parameter("desert_sand_trails",value)
var _bridge_track: NativeTrack
var _bridge_presentation: BridgePresentation
var _bridge_material: ShaderMaterial
var _previous_elevated: bool = false
# Private device comparison; normal play always retains bridge protection.
var bridge_clipping_enabled: bool = true:
	set(value):
		bridge_clipping_enabled = value
		if _bridge_material != null:
			_bridge_material.set_shader_parameter("dust_bridge_count",_bridge_track.creator_bridges.size() if value and _bridge_track != null else 0)


func _ready() -> void:
	mark_colors.resize(CAPACITY)
	mark_custom.resize(CAPACITY)
	mark_transforms.resize(CAPACITY)
	var surface: ShaderMaterial = _trail_material()
	_bridge_material = surface
	var mesh: ArrayMesh = _trail_mesh(surface)
	instances = MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.use_custom_data = true
	instances.mesh = mesh
	instances.instance_count = CAPACITY
	instances.visible_instance_count = 0
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = instances
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(batch)
	trail_visibility = TrailVisibility.new(instances,mark_transforms)

func _process(_delta: float) -> void:
	if visible: trail_visibility.present(get_viewport().get_camera_3d(),mark_colors,mark_custom,global_transform)


func _trail_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = TRAIL_SHADER
	material.set_shader_parameter("desert_sand_trails",desert_sand)
	material.set_shader_parameter("desert_sand_pigment",TrackTheme.DESERT[0])
	material.set_shader_parameter("grass_soil_pigment",GRASS_SOIL_PIGMENT)
	material.set_shader_parameter("road_mud_pigment",ROAD_MUD_PIGMENT)
	return material


func _trail_mesh(surface: Material) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.5,0,-0.5),Vector3(0.5,0,-0.5),Vector3(-0.5,0,0.5),Vector3(0.5,0,0.5)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP,Vector3.UP,Vector3.UP,Vector3.UP])
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray([Color.WHITE,Color.WHITE,Color.WHITE,Color.WHITE])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0,3,1,0,2,3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.surface_set_material(0,surface)
	# The shader interpolates both side columns; include the second column in
	# CPU bounds even though the authored quad has zero local Y.
	mesh.custom_aabb = AABB(Vector3(-0.5,-0.5,-0.5),Vector3.ONE)
	return mesh


func clear() -> void:
	active = false
	cursor = 0
	instances.visible_instance_count = 0
	trail_visibility.clear()
	_previous_marks.fill(-1)


func sample(state: VehicleState, frame: DriveFrame, bridge: BridgePresentation = null, track: NativeTrack = null) -> void:
	_bind_bridges(track,bridge)
	desert_sand = track != null and track.metadata.get("theme","pine") == "desert"
	if state.jump_height > 0.0 or state.roll_ticks > 0 or state.velocity.length() < 1.0:
		active = false
		return
	# A mark cannot connect independent ground/deck layers at an underpass.
	if active and state.track_elevated != _previous_elevated: active = false
	_previous_elevated = state.track_elevated
	var rear_axle: Vector2 = state.position - state.forward() * (wheelbase * 0.5)
	var front_axle: Vector2 = state.position + state.forward() * (wheelbase * 0.5)
	var left: Vector3 = VisualGeometry.world(rear_axle - state.right() * (track_width * 0.5)) + Vector3(0, 0.028, 0)
	if bridge != null:
		left.y += bridge.visual_height_at(Vector2(left.x,-left.z),state.route_index,1 if state.track_elevated else 0)
	# Reject unchanged/sub-spacing samples before querying the other contacts
	# and calculating intensities. Use the same bridge-adjusted 3D distance.
	if active and left.distance_to(previous_left) < SAMPLE_DISTANCE: return
	var right: Vector3 = VisualGeometry.world(rear_axle + state.right() * (track_width * 0.5)) + Vector3(0, 0.028, 0)
	var front_left: Vector3 = VisualGeometry.world(front_axle - state.right() * (track_width * 0.5)) + Vector3(0, 0.028, 0)
	var front_right: Vector3 = VisualGeometry.world(front_axle + state.right() * (track_width * 0.5)) + Vector3(0, 0.028, 0)
	if bridge != null:
		var layer: int = 1 if state.track_elevated else 0
		right.y += bridge.visual_height_at(Vector2(right.x,-right.z),state.route_index,layer)
		front_left.y += bridge.visual_height_at(Vector2(front_left.x,-front_left.z),state.route_index,layer)
		front_right.y += bridge.visual_height_at(Vector2(front_right.x,-front_right.z),state.route_index,layer)
	if track != null and track.metadata.get("theme","pine") == "winter" and not state.track_elevated:
		left.y += track.snow_banks.height_at(Vector2(left.x,-left.z))
		right.y += track.snow_banks.height_at(Vector2(right.x,-right.z))
		front_left.y += track.snow_banks.height_at(Vector2(front_left.x,-front_left.z))
		front_right.y += track.snow_banks.height_at(Vector2(front_right.x,-front_right.z))
	var left_kind: int = surface_at(track, left, state.track_elevated)
	var right_kind: int = surface_at(track, right, state.track_elevated)
	var front_left_kind: int = surface_at(track, front_left, state.track_elevated)
	var front_right_kind: int = surface_at(track, front_right, state.track_elevated)
	var strengths: PackedFloat64Array = _four_intensities(state, frame, left_kind, right_kind, front_left_kind, front_right_kind)
	var left_strength: float = strengths[0]
	var right_strength: float = strengths[1]
	var front_left_strength: float = strengths[2]
	var front_right_strength: float = strengths[3]
	var strongest: float = maxf(maxf(left_strength,right_strength),maxf(front_left_strength,front_right_strength))
	if not active and strongest < 0.035: return
	if not active:
		_previous_marks.fill(-1)
		previous_left = left
		previous_right = right
		previous_front_left = front_left
		previous_front_right = front_right
		previous_left_strength = 0.0
		previous_right_strength = 0.0
		previous_front_left_strength = 0.0
		previous_front_right_strength = 0.0
		active = true
		return
	if active:
		var distance: float = left.distance_to(previous_left)
		var fade_distance: float = 0.32 if strongest > maxf(previous_left_strength,previous_right_strength) else 0.50
		var blend: float = clampf(distance/fade_distance,0.0,1.0)
		left_strength = lerpf(previous_left_strength,left_strength,blend)
		right_strength = lerpf(previous_right_strength,right_strength,blend)
		front_left_strength = lerpf(previous_front_left_strength,front_left_strength,blend)
		front_right_strength = lerpf(previous_front_right_strength,front_right_strength,blend)
		if distance <= MAX_SEGMENT_LENGTH:
			_mark(previous_left,left,state.tire_dirt,surface_at(track,previous_left,state.track_elevated),(previous_left_strength+left_strength)*0.5,0,previous_left_strength,left_strength)
			_mark(previous_right,right,state.tire_dirt,surface_at(track,previous_right,state.track_elevated),(previous_right_strength+right_strength)*0.5,1,previous_right_strength,right_strength)
			_mark(previous_front_left,front_left,state.tire_dirt,surface_at(track,previous_front_left,state.track_elevated),(previous_front_left_strength+front_left_strength)*0.5,2,previous_front_left_strength,front_left_strength)
			_mark(previous_front_right,front_right,state.tire_dirt,surface_at(track,previous_front_right,state.track_elevated),(previous_front_right_strength+front_right_strength)*0.5,3,previous_front_right_strength,front_right_strength)
		else:
			_previous_marks.fill(-1)
	previous_left = left
	previous_right = right
	previous_front_left = front_left
	previous_front_right = front_right
	previous_left_strength = left_strength
	previous_right_strength = right_strength
	previous_front_left_strength = front_left_strength
	previous_front_right_strength = front_right_strength
	active = maxf(strongest,maxf(maxf(left_strength,right_strength),maxf(front_left_strength,front_right_strength))) >= 0.012


func _bind_bridges(track: NativeTrack, bridge: BridgePresentation = null) -> void:
	if _bridge_material == null or (_bridge_track == track and _bridge_presentation == bridge): return
	_bridge_track = track
	_bridge_presentation = bridge
	var height_offset: float = 0.0
	if bridge != null:
		height_offset = bridge.road_surface.lift
		# The immutable relief lowers every bridge footprint by the same amount.
		# An empty (over-budget) field leaves the original presentation intact.
		if bridge.visual_relief != null and not bridge.visual_relief.field.is_empty():
			height_offset -= preload("res://track/desert_road_relief.gd").DEPTH
	_bridge_material.set_shader_parameter("trail_bridge_height_offset",height_offset)
	var count: int = 0 if track == null else track.creator_bridges.size()
	assert(count <= 16,"Bridge trails require the validated sixteen-span contract")
	var axes := PackedVector4Array()
	var sizes := PackedVector4Array()
	axes.resize(16)
	sizes.resize(16)
	for index: int in range(count):
		var span: Dictionary = track.creator_bridges[index]
		var angle: float = deg_to_rad(float(span.heading))
		axes[index] = Vector4(float(span.position[0]),-float(span.position[1]),cos(angle),-sin(angle))
		sizes[index] = Vector4(float(span.length),float(span.width)*0.5+CreatorBridges.RAIL,CreatorBridges.HEIGHT,CreatorBridges.RAMP)
	_bridge_material.set_shader_parameter("dust_bridge_count",count if bridge_clipping_enabled else 0)
	_bridge_material.set_shader_parameter("dust_bridge_axes",axes)
	_bridge_material.set_shader_parameter("dust_bridge_sizes",sizes)
	# Each fragment's actual mark height selects its layer; deck marks remain.
	_bridge_material.set_shader_parameter("dust_upper_layer",true)


static func surface_at(track: NativeTrack, point: Vector3, elevated: bool) -> int:
	if track == null: return -1
	var kind: int = track.cell_at(Vector2(point.x, -point.z), elevated)
	# Desert shoulders retain canonical kerb cells, but the sandy apron must
	# leave the same sand grooves as the road and ground, never black rubber.
	if str(track.metadata.get("theme", "pine")) == "desert" and kind in [0, 1, 2, 5]:
		return 2
	if str(track.metadata.get("theme","pine")) == "winter":
		if kind in [1,5,7]: return 7
		if kind == 2: return 10
		if kind in [3,6]: return 11
	if kind == 0:
		var theme: String = str(track.metadata.get("theme", "pine"))
		if theme == "desert": return 2
		if theme == "winter": return 8
		if theme == "storm": return 9
	return kind


static func physics_intensity(state: VehicleState, frame: DriveFrame, surface_kind: int, wheel_side: float, axle: float = -1.0) -> float:
	var speed: float = state.velocity.length()
	var lateral_speed: float = absf(state.velocity.dot(state.right()))
	var slip: float = smoothstep(0.035, 0.62, absf(state.slip_angle()))
	var scrub: float = smoothstep(0.4, 11.0, lateral_speed)
	var braking: float = frame.brake / 255.0 * smoothstep(2.0, 18.0, speed)
	var rotation: float = smoothstep(0.15, 1.8, absf(state.yaw_rate)) * smoothstep(3.0, 16.0, speed) * 0.55
	var rolling_surface: float = 0.0
	if surface_kind in [1, 2, 7, 10]: rolling_surface = smoothstep(1.0, 16.0, speed) * 0.34
	elif surface_kind == 8: rolling_surface = smoothstep(2.0,18.0,speed)*0.18
	elif surface_kind in [3, 6, 9, 11]: rolling_surface = smoothstep(2.0, 18.0, speed) * 0.20
	var contamination: float = state.tire_dirt * smoothstep(1.0, 12.0, speed) * 0.82
	var dynamic: float
	if axle > 0.0:
		dynamic = maxf(maxf(slip*0.38,scrub*0.45),maxf(braking*0.78,rotation*0.32))
	else:
		dynamic = maxf(maxf(slip,scrub),maxf(braking,rotation))
	var strength: float = maxf(dynamic,maxf(rolling_surface,contamination))
	# Cornering load makes the outside rear track slightly stronger. This also
	# prevents mechanically identical left/right ribbons during a sustained arc.
	var longitudinal_sign: float = signf(state.velocity.dot(state.forward()))
	var load_bias: float = clampf(1.0 + wheel_side * state.yaw_rate * longitudinal_sign * 0.16, 0.72, 1.28)
	return clampf(strength * load_bias, 0.0, 1.0)


static func _four_intensities(state: VehicleState, frame: DriveFrame, left_kind: int, right_kind: int, front_left_kind: int, front_right_kind: int) -> PackedFloat64Array:
	# All four contact points share velocity, slip, braking, dirt and yaw. Keep
	# the same arithmetic as physics_intensity while calculating these once.
	var speed: float = state.velocity.length()
	var lateral_speed: float = absf(state.velocity.dot(state.right()))
	var slip: float = smoothstep(0.035, 0.62, absf(state.slip_angle()))
	var scrub: float = smoothstep(0.4, 11.0, lateral_speed)
	var braking: float = frame.brake / 255.0 * smoothstep(2.0, 18.0, speed)
	var rotation: float = smoothstep(0.15, 1.8, absf(state.yaw_rate)) * smoothstep(3.0, 16.0, speed) * 0.55
	var contamination: float = state.tire_dirt * smoothstep(1.0, 12.0, speed) * 0.82
	var rear_dynamic: float = maxf(maxf(slip,scrub),maxf(braking,rotation))
	var front_dynamic: float = maxf(maxf(slip*0.38,scrub*0.45),maxf(braking*0.78,rotation*0.32))
	var longitudinal_sign: float = signf(state.velocity.dot(state.forward()))
	return PackedFloat64Array([
		_intensity_from_shared(speed,rear_dynamic,contamination,state.yaw_rate,longitudinal_sign,left_kind,-1.0),
		_intensity_from_shared(speed,rear_dynamic,contamination,state.yaw_rate,longitudinal_sign,right_kind,1.0),
		_intensity_from_shared(speed,front_dynamic,contamination,state.yaw_rate,longitudinal_sign,front_left_kind,-1.0),
		_intensity_from_shared(speed,front_dynamic,contamination,state.yaw_rate,longitudinal_sign,front_right_kind,1.0)])


static func _intensity_from_shared(speed: float, dynamic: float, contamination: float, yaw_rate: float, longitudinal_sign: float, surface_kind: int, wheel_side: float) -> float:
	var rolling_surface: float = 0.0
	if surface_kind in [1, 2, 7, 10]: rolling_surface = smoothstep(1.0, 16.0, speed) * 0.34
	elif surface_kind == 8: rolling_surface = smoothstep(2.0,18.0,speed)*0.18
	elif surface_kind in [3, 6, 9, 11]: rolling_surface = smoothstep(2.0, 18.0, speed) * 0.20
	var strength: float = maxf(dynamic,maxf(rolling_surface,contamination))
	var load_bias: float = clampf(1.0 + wheel_side * yaw_rate * longitudinal_sign * 0.16, 0.72, 1.28)
	return clampf(strength * load_bias, 0.0, 1.0)


func _mark(a: Vector3, b: Vector3, dirt: float, surface_kind: int = -1, strength: float = 1.0, wheel: int = -1, start_strength: float = -1.0, end_strength: float = -1.0) -> void:
	var style: Vector4 = _surface_style(surface_kind, dirt, strength, desert_sand)
	var tint := Color(style.x, style.y, style.z, style.w)
	var width: float = _surface_width(surface_kind, strength)
	var relief: float = _surface_relief(surface_kind, strength)
	var delta: Vector3 = b-a
	if delta.x*delta.x+delta.z*delta.z < 0.000001: return
	var side := Vector3(delta.z,0,-delta.x).normalized()
	var start_side: Vector3 = side*width
	if wheel >= 0:
		# Reuse the deposited endpoint directly. Each new segment owns its end;
		# the next consumes it, with no uploads or edits to older ring entries.
		var coated: bool = dirt > 0.0 if surface_kind in [0,9] else dirt > 0.025
		var material_type: int = surface_kind*4+int(coated)+(2 if desert_sand else 0)
		var old_side: Vector3 = _previous_sides[wheel]
		if _previous_marks[wheel] >= 0 and _previous_marks[wheel] != cursor and _previous_types[wheel] == material_type and _previous_ends[wheel].distance_squared_to(a) < 0.000001 and old_side.dot(side) > old_side.length()*0.25:
			start_side = old_side
		_previous_marks[wheel] = cursor
		_previous_sides[wheel] = side*width
		_previous_ends[wheel] = b
		_previous_types[wheel] = material_type
	# Columns X/Y hold the two shared cross-sections. Y.y stores analytic relief;
	# the shader supplies explicit contact normals and ignores it for position.
	var basis := Basis(start_side,Vector3(side.x*width,relief,side.z*width),delta)
	mark_transforms[cursor] = Transform3D(basis,(a+b)*0.5)
	mark_colors[cursor] = tint
	var loose: float = 1.0 if surface_kind in [1,2,7,10] else 0.0
	if surface_kind in [0,9]: loose = clampf(dirt,0.0,1.0)*0.49
	mark_custom[cursor] = Color(float(surface_kind)/10.0,strength if start_strength < 0.0 else start_strength,loose,strength if end_strength < 0.0 else end_strength)
	if trail_visibility.active:
		trail_visibility.record(cursor,mark_colors,mark_custom)
	else:
		instances.set_instance_transform(cursor,mark_transforms[cursor])
		instances.set_instance_color(cursor,mark_colors[cursor])
		instances.set_instance_custom_data(cursor,mark_custom[cursor])
		instances.visible_instance_count = mini(CAPACITY,instances.visible_instance_count+1)
	cursor = (cursor + 1) % CAPACITY


func _surface_style(kind: int, dirt: float, strength: float = 1.0, desert: bool = false) -> Vector4:
	# Colors describe the material displaced by a tyre, rather than painting the
	# same black stripe everywhere. Dirt carried onto a hard surface fades with
	# the canonical tire-cleaning state.
	var result: Vector4
	match kind:
		1: result = Vector4(GRASS_SOIL_PIGMENT.r, GRASS_SOIL_PIGMENT.g, GRASS_SOIL_PIGMENT.b, 0.60) # Warm brown soil exposed through crushed grass.
		2: result = Vector4(0.68, 0.53, 0.32, 0.52) # Compressed dirt or sand groove.
		3, 6: result = Vector4(0.12, 0.18, 0.19, 0.42) # Thin wet wake.
		5: result = Vector4(0.16, 0.17, 0.16, 0.50) # Rubber on painted kerb.
		7: result = Vector4(0.43, 0.56, 0.67, 0.66) # Disturbed snowbank.
		8: result = Vector4(0.82, 0.88, 0.94, 0.42) # Pale crystalline abrasion through frosty ice.
		10: result = Vector4(0.57,0.65,0.69,0.42) # Compressed snow on packed terrain.
		11: result = Vector4(0.38,0.51,0.59,0.32) # Wet slush wake.
		9: result = Vector4(0.07, 0.10, 0.105, 0.48) # Damp rubber on storm asphalt.
		0:
			result = Vector4(0.12, 0.115, 0.105, 0.46)
		_:
			result = Vector4(0.49, 0.34, 0.18, 0.78) if dirt > 0.025 else Vector4(0.10, 0.11, 0.105, 0.70)
	var muddy_road: bool = kind in [0,9] and dirt > 0.0
	if muddy_road:
		# Fresh deposits fade all the way to zero with the coating, including
		# during heavy braking/slip. Existing deposited marks remain immutable.
		result = Vector4(ROAD_MUD_PIGMENT.r,ROAD_MUD_PIGMENT.g,ROAD_MUD_PIGMENT.b,0.62*clampf(dirt,0.0,1.0))
	if kind == 2 and desert:
		var sand: Color = TrackTheme.DESERT[0]
		result = Vector4(sand.r,sand.g,sand.b,0.52) # Shared sand opacity in the exact desert road pigment.
	if kind in [0,5,8,9] and not muddy_road: result.w *= 0.02+0.98*pow(clampf(strength,0.0,1.0),1.7)
	else: result.w *= lerpf(0.12, 1.0, clampf(strength, 0.0, 1.0))
	return result


func _surface_width(kind: int, strength: float = 1.0) -> float:
	var base: float
	match kind:
		0: base = 0.25
		1: base = 0.29
		2: base = 0.30
		7: base = 0.31
		10: base = 0.27
		11: base = 0.23
		3, 6: base = 0.17
		5: base = 0.22
		8, 9: base = 0.24
		_: base = 0.20
	return base * HandlingConfig.BODY_SCALE * lerpf(0.78, 1.12, clampf(strength, 0.0, 1.0))


func _surface_relief(kind: int, strength: float = 1.0) -> float:
	var maximum: float
	match kind:
		1: maximum = 0.072 # Bent grass shoulders around a flattened center.
		2: maximum = 0.060 # Compressed dirt/sand rut.
		7: maximum = 0.055 # Restrained displaced snow.
		10: maximum = 0.025
		3, 6, 9, 11: maximum = 0.006
		_: maximum = 0.003
	return maximum * lerpf(0.38, 1.0, clampf(strength, 0.0, 1.0))
