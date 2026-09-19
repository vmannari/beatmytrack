class_name SkidTrails
extends Node3D
## Fixed-size ring rendered in one instanced draw, with per-mark tint/opacity.

const CAPACITY: int = 240
var instances: MultiMesh
var mark_colors := PackedColorArray()
var mark_transforms: Array[Transform3D] = []
var wheelbase: float = 2.56 * HandlingConfig.BODY_SCALE
var track_width: float = 1.52 * HandlingConfig.BODY_SCALE
var cursor: int = 0
var previous_left: Vector3
var previous_right: Vector3
var active: bool = false


func _ready() -> void:
	mark_colors.resize(CAPACITY)
	mark_transforms.resize(CAPACITY)
	var surface := VisualGeometry.material(Color.WHITE)
	surface.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	surface.vertex_color_use_as_albedo = true
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.16 * HandlingConfig.BODY_SCALE, 0.006, 1)
	mesh.material = surface
	instances = MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.mesh = mesh
	instances.instance_count = CAPACITY
	instances.visible_instance_count = 0
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = instances
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(batch)


func clear() -> void:
	active = false
	cursor = 0
	instances.visible_instance_count = 0


func sample(state: VehicleState, frame: DriveFrame, bridge: BridgePresentation = null) -> void:
	var slipping: bool = absf(state.slip_angle()) > 0.16 or frame.brake > 200
	if state.jump_height > 0.0 or state.roll_ticks > 0 or (not slipping and state.tire_dirt < 0.025) or state.velocity.length() < 1.0:
		active = false
		return
	var axle: Vector2 = state.position - state.forward() * (wheelbase * 0.5)
	var left: Vector3 = VisualGeometry.world(axle - state.right() * (track_width * 0.5)) + Vector3(0, 0.028, 0)
	var right: Vector3 = VisualGeometry.world(axle + state.right() * (track_width * 0.5)) + Vector3(0, 0.028, 0)
	if bridge != null:
		left.y += bridge.height_at(Vector2(left.x, -left.z), state.route_index,1 if state.track_elevated else 0)
		right.y += bridge.height_at(Vector2(right.x, -right.z), state.route_index,1 if state.track_elevated else 0)
	if active:
		if left.distance_to(previous_left) < 0.22:
			return
		_mark(previous_left, left, state.tire_dirt)
		_mark(previous_right, right, state.tire_dirt)
	previous_left = left
	previous_right = right
	active = true


func _mark(a: Vector3, b: Vector3, dirt: float) -> void:
	var tint := Color("a47a43") if dirt > 0.025 else Color("303938")
	tint.a = clampf(dirt * 0.85, 0.03, 0.85) if dirt > 0.025 else 1.0
	var rotation := Vector3(-atan2(b.y-a.y,Vector2(b.x-a.x,b.z-a.z).length()),atan2(b.x-a.x,b.z-a.z),0)
	var basis: Basis = Basis.from_euler(rotation).scaled_local(Vector3(1,1,a.distance_to(b)+0.04))
	mark_transforms[cursor] = Transform3D(basis,(a+b)*0.5)
	mark_colors[cursor] = tint
	instances.set_instance_transform(cursor,mark_transforms[cursor])
	instances.set_instance_color(cursor,mark_colors[cursor])
	instances.visible_instance_count = mini(CAPACITY,instances.visible_instance_count+1)
	cursor = (cursor + 1) % CAPACITY
