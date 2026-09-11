class_name SkidTrails
extends Node3D
## Fixed-size ring of 240 pooled meshes; no per-tick node allocation or unbounded trails.

const CAPACITY: int = 240
var marks: Array[MeshInstance3D] = []
var cursor: int = 0
var previous_left: Vector3
var previous_right: Vector3
var active: bool = false


func _ready() -> void:
	var surface := VisualGeometry.material(Color("303938"))
	for i: int in range(CAPACITY):
		var mark: MeshInstance3D = VisualGeometry.box(self, Vector3(0.16, 0.006, 1), Vector3.ZERO, surface)
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mark.visible = false
		marks.append(mark)


func clear() -> void:
	active = false
	for mark: MeshInstance3D in marks:
		mark.visible = false


func sample(state: VehicleState, frame: DriveFrame) -> void:
	var slipping: bool = absf(state.slip_angle()) > 0.16 or frame.brake > 200
	if not slipping or state.velocity.length() < 4.0:
		active = false
		return
	var axle: Vector2 = state.position - state.forward() * 1.28
	var left: Vector3 = VisualGeometry.world(axle - state.right() * 0.76) + Vector3(0, 0.028, 0)
	var right: Vector3 = VisualGeometry.world(axle + state.right() * 0.76) + Vector3(0, 0.028, 0)
	if active:
		if left.distance_to(previous_left) < 0.22:
			return
		_mark(previous_left, left)
		_mark(previous_right, right)
	previous_left = left
	previous_right = right
	active = true


func _mark(a: Vector3, b: Vector3) -> void:
	var mark: MeshInstance3D = marks[cursor]
	cursor = (cursor + 1) % CAPACITY
	mark.visible = true
	mark.position = (a + b) * 0.5
	mark.scale.z = a.distance_to(b) + 0.04
	mark.rotation.y = atan2(b.x - a.x, b.z - a.z)
