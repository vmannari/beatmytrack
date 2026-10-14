class_name SkidTrails
extends Node3D
## Race-persistent fixed-size ring rendered in one instanced draw. Surface-aware
## color, width and opacity keep the trails legible without adding draw calls.

const CAPACITY: int = 16384
const SAMPLE_DISTANCE: float = 0.32
const MAX_SEGMENT_LENGTH: float = 1.5
var instances: MultiMesh
var mark_colors := PackedColorArray()
var mark_custom := PackedColorArray()
var mark_transforms: Array[Transform3D] = []
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
var desert_sand: bool = false
var _bridge_track: NativeTrack
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


func _trail_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;
#include "res://vehicle/dust_bridge_clip.gdshaderinc"

varying float loose_surface;
varying float mark_strength;
varying float pattern_phase;
varying float ice_scuff;
varying vec3 ice_contact_normal;
varying highp vec3 trail_world;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	loose_surface = INSTANCE_CUSTOM.b;
	mark_strength = INSTANCE_CUSTOM.g;
	pattern_phase = INSTANCE_CUSTOM.a;
	ice_scuff = 1.0-smoothstep(0.005,0.015,abs(INSTANCE_CUSTOM.r-0.8));
	// The instance follows the contact slope, including bridge ramps. Avoid
	// the shared groove normals and their almost-flat nonuniform scale.
	ice_contact_normal = normalize((MODEL_MATRIX * vec4(0.0,1.0,0.0,0.0)).xyz);
	trail_world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
}

void fragment() {
	float across = abs(UV.x - 0.5) * 2.0;
	float row = floor((UV.y + pattern_phase) * 13.0);
	float lane = floor(UV.x * 7.0);
	float grain = hash21(vec2(row, lane + pattern_phase * 19.0));
	float tread = smoothstep(0.38, 0.62, fract((UV.y + pattern_phase) * 13.0 + lane * 0.37));
	float center_press = 1.0 - smoothstep(0.05, 0.55, across);
	float shoulder = smoothstep(0.52, 0.82, across) * (1.0 - smoothstep(0.82, 1.0, across));
	float loose_tone = mix(0.78, 1.02, tread) - center_press * 0.09 + shoulder * 0.12;
	float asphalt_grain = hash21(vec2(floor((UV.y + pattern_phase) * 31.0), floor(UV.x * 17.0)));
	float asphalt_streaks = 0.82 + 0.18 * smoothstep(0.15, 0.85, sin(UV.x * 21.99 + pattern_phase * 6.28) * 0.5 + 0.5);
	float asphalt_tone = asphalt_streaks * mix(0.88, 1.08, asphalt_grain);
	float tone = mix(asphalt_tone, loose_tone, loose_surface);
	float chipped_edge = mix(1.0, smoothstep(0.18, 0.62, grain + (1.0 - across) * 0.72), loose_surface * smoothstep(0.76, 1.0, across));
	float feather = 1.0 - smoothstep(0.72, 1.0, across);
	ALBEDO = COLOR.rgb * tone;
	ROUGHNESS = 1.0;
	if (ice_scuff > 0.5) {
		NORMAL = normalize((VIEW_MATRIX * vec4(ice_contact_normal,0.0)).xyz);
		ROUGHNESS = 0.7;
	}
	vec3 camera_ray = PROJECTION_MATRIX[3].w>0.5 ? INV_VIEW_MATRIX[2].xyz : normalize(INV_VIEW_MATRIX[3].xyz-trail_world);
	float bridge_visibility = dust_bridge_projected_visibility(trail_world,camera_ray,trail_world.y);
	ALPHA = COLOR.a * chipped_edge * feather * bridge_visibility;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _trail_mesh(surface: Material) -> ArrayMesh:
	# A low-poly concave tread section catches the directional light in discrete
	# planes. Loose surfaces scale this profile up into a readable cel-shaded rut;
	# hard-surface rubber keeps it almost flat.
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder.set_material(surface)
	var across := PackedFloat32Array([-0.5, -0.36, -0.12, 0.12, 0.36, 0.5])
	# Broad low centre plus angular shoulders reads as a pressed groove rather
	# than a raised ribbon from the overhead camera.
	var heights := PackedFloat32Array([0.0, 0.82, 0.06, 0.06, 0.82, 0.0])
	for side: int in range(across.size()-1):
		var x0: float = across[side]
		var x1: float = across[side+1]
		var y0: float = heights[side]
		var y1: float = heights[side+1]
		var vertices: Array[Vector3] = [Vector3(x0,y0,-0.5),Vector3(x1,y1,0.5),Vector3(x1,y1,-0.5), Vector3(x0,y0,-0.5),Vector3(x0,y0,0.5),Vector3(x1,y1,0.5)]
		for vertex: Vector3 in vertices:
			builder.set_color(Color.WHITE)
			builder.set_uv(Vector2(vertex.x+0.5,vertex.z+0.5))
			builder.add_vertex(vertex)
	builder.generate_normals()
	return builder.commit()


func clear() -> void:
	active = false
	cursor = 0
	instances.visible_instance_count = 0


func sample(state: VehicleState, frame: DriveFrame, bridge: BridgePresentation = null, track: NativeTrack = null) -> void:
	_bind_bridges(track)
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
		left.y += bridge.height_at(Vector2(left.x,-left.z),state.route_index,1 if state.track_elevated else 0)
	# Reject unchanged/sub-spacing samples before querying the other contacts
	# and calculating intensities. Use the same bridge-adjusted 3D distance.
	if active and left.distance_to(previous_left) < SAMPLE_DISTANCE: return
	var right: Vector3 = VisualGeometry.world(rear_axle + state.right() * (track_width * 0.5)) + Vector3(0, 0.028, 0)
	var front_left: Vector3 = VisualGeometry.world(front_axle - state.right() * (track_width * 0.5)) + Vector3(0, 0.028, 0)
	var front_right: Vector3 = VisualGeometry.world(front_axle + state.right() * (track_width * 0.5)) + Vector3(0, 0.028, 0)
	if bridge != null:
		var layer: int = 1 if state.track_elevated else 0
		right.y += bridge.height_at(Vector2(right.x,-right.z),state.route_index,layer)
		front_left.y += bridge.height_at(Vector2(front_left.x,-front_left.z),state.route_index,layer)
		front_right.y += bridge.height_at(Vector2(front_right.x,-front_right.z),state.route_index,layer)
	if track != null and track.metadata.get("theme","pine") == "winter" and not state.track_elevated:
		left.y += track.snow_banks.height_at(Vector2(left.x,-left.z))
		right.y += track.snow_banks.height_at(Vector2(right.x,-right.z))
		front_left.y += track.snow_banks.height_at(Vector2(front_left.x,-front_left.z))
		front_right.y += track.snow_banks.height_at(Vector2(front_right.x,-front_right.z))
	var left_kind: int = surface_at(track, left, state.track_elevated)
	var right_kind: int = surface_at(track, right, state.track_elevated)
	var front_left_kind: int = surface_at(track, front_left, state.track_elevated)
	var front_right_kind: int = surface_at(track, front_right, state.track_elevated)
	var left_strength: float = physics_intensity(state, frame, left_kind, -1.0, -1.0)
	var right_strength: float = physics_intensity(state, frame, right_kind, 1.0, -1.0)
	var front_left_strength: float = physics_intensity(state, frame, front_left_kind, -1.0, 1.0)
	var front_right_strength: float = physics_intensity(state, frame, front_right_kind, 1.0, 1.0)
	var strongest: float = maxf(maxf(left_strength,right_strength),maxf(front_left_strength,front_right_strength))
	if not active and strongest < 0.035: return
	if not active:
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
			_mark(previous_left, left, state.tire_dirt, surface_at(track, previous_left, state.track_elevated), (previous_left_strength+left_strength)*0.5)
			_mark(previous_right, right, state.tire_dirt, surface_at(track, previous_right, state.track_elevated), (previous_right_strength+right_strength)*0.5)
			_mark(previous_front_left, front_left, state.tire_dirt, surface_at(track, previous_front_left, state.track_elevated), (previous_front_left_strength+front_left_strength)*0.5)
			_mark(previous_front_right, front_right, state.tire_dirt, surface_at(track, previous_front_right, state.track_elevated), (previous_front_right_strength+front_right_strength)*0.5)
	previous_left = left
	previous_right = right
	previous_front_left = front_left
	previous_front_right = front_right
	previous_left_strength = left_strength
	previous_right_strength = right_strength
	previous_front_left_strength = front_left_strength
	previous_front_right_strength = front_right_strength
	active = maxf(strongest,maxf(maxf(left_strength,right_strength),maxf(front_left_strength,front_right_strength))) >= 0.012


func _bind_bridges(track: NativeTrack) -> void:
	if _bridge_material == null or _bridge_track == track: return
	_bridge_track = track
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


func _mark(a: Vector3, b: Vector3, dirt: float, surface_kind: int = -1, strength: float = 1.0) -> void:
	var style: Vector4 = _surface_style(surface_kind, dirt, strength, desert_sand)
	var tint := Color(style.x, style.y, style.z, style.w)
	var width: float = _surface_width(surface_kind, strength)
	var relief: float = _surface_relief(surface_kind, strength)
	var rotation := Vector3(-atan2(b.y-a.y,Vector2(b.x-a.x,b.z-a.z).length()),atan2(b.x-a.x,b.z-a.z),0)
	var basis: Basis = Basis.from_euler(rotation).scaled_local(Vector3(width,relief,a.distance_to(b)+0.06))
	mark_transforms[cursor] = Transform3D(basis,(a+b)*0.5)
	mark_colors[cursor] = tint
	var loose: float = 1.0 if surface_kind in [1,2,7,10] else 0.0
	var phase: float = fposmod(a.x*0.173+a.z*0.271,1.0)
	mark_custom[cursor] = Color(clampf(float(surface_kind)/10.0,0.0,1.0),strength,loose,phase)
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
		1: result = Vector4(0.23, 0.285, 0.125, 0.60) # Dark brown-green crushed grass.
		2: result = Vector4(0.68, 0.53, 0.32, 0.52) # Compressed dirt or sand groove.
		3, 6: result = Vector4(0.12, 0.18, 0.19, 0.42) # Thin wet wake.
		5: result = Vector4(0.16, 0.17, 0.16, 0.50) # Rubber on painted kerb.
		7: result = Vector4(0.43, 0.56, 0.67, 0.66) # Disturbed snowbank.
		8: result = Vector4(0.82, 0.88, 0.94, 0.42) # Pale crystalline abrasion through frosty ice.
		10: result = Vector4(0.57,0.65,0.69,0.42) # Compressed snow on packed terrain.
		11: result = Vector4(0.38,0.51,0.59,0.32) # Wet slush wake.
		9: result = Vector4(0.07, 0.10, 0.105, 0.48) # Damp rubber on storm asphalt.
		0:
			result = Vector4(0.43, 0.29, 0.15, 0.62) if dirt > 0.025 else Vector4(0.12, 0.115, 0.105, 0.46)
		_:
			result = Vector4(0.49, 0.34, 0.18, 0.78) if dirt > 0.025 else Vector4(0.10, 0.11, 0.105, 0.70)
	if kind == 2 and desert:
		result = Vector4(0.66,0.55,0.39,0.28) # Restrained pressed-sand grooves.
	if kind in [0,5,8,9]: result.w *= 0.02+0.98*pow(clampf(strength,0.0,1.0),1.7)
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
