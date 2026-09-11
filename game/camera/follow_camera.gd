class_name FollowCamera
extends Camera3D

var profile: CameraProfile = preload("res://resources/camera.tres")
var focus: Vector3 = Vector3.ZERO
var initialized: bool = false


func follow(point: Vector2, velocity: Vector2, heading: float, delta: float, snap: bool = false) -> void:
	projection = PROJECTION_ORTHOGONAL if profile.orthographic else PROJECTION_PERSPECTIVE
	keep_aspect = KEEP_HEIGHT
	size = profile.baseline_extent / profile.magnification
	fov = profile.field_of_view
	near = 0.1
	far = 180.0
	var ahead: Vector2 = velocity * profile.velocity_look_ahead
	if velocity.length() > 0.5:
		ahead += Vector2(sin(heading), cos(heading)) * profile.forward_look_ahead
	ahead = ahead.limit_length(profile.maximum_look_ahead)
	var desired: Vector3 = VisualGeometry.world(point + ahead)
	if snap or not initialized:
		focus = desired
		initialized = true
	else:
		focus = focus.lerp(desired, 1.0 - exp(-profile.smoothing * delta))
	var yaw: float = deg_to_rad(profile.world_yaw_degrees) - (heading if profile.follow_heading else 0.0)
	var offset := Vector3(0, profile.height, profile.height / tan(deg_to_rad(profile.pitch_degrees)))
	position = focus + offset.rotated(Vector3.UP, yaw)
	look_at(focus, Vector3.UP)
