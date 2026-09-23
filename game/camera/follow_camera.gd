class_name FollowCamera
extends Camera3D

var profile: CameraProfile = preload("res://resources/camera.tres")
var focus: Vector3 = Vector3.ZERO
var initialized: bool = false
var trauma: float = 0.0
var impact_offset: Vector2 = Vector2.ZERO
var impact_velocity: Vector2 = Vector2.ZERO
var surface_target: float = 0.0
var surface_strength: float = 0.0
var shake_time: float = 0.0

const MAX_IMPACT_METRES: float = 0.32 # Approximately 10 px at the calibrated vertical extent.
const MAX_SURFACE_METRES: float = 0.05
const IMPACT_SPRING: float = 190.0
const IMPACT_DAMPING: float = 20.0
const TRAUMA_DECAY: float = 5.0
const SURFACE_RESPONSE: float = 9.0
const SURFACE_PRIMARY_FREQUENCY: float = 61.0
const SURFACE_SECONDARY_FREQUENCY: float = 43.0


func add_collision_impact(resolved_velocity_change: Vector2) -> void:
	var impulse: float = resolved_velocity_change.length()
	var strength: float = smoothstep(2.0, 20.0, impulse)
	if strength <= 0.0:
		return
	# The post-minus-pre velocity change points away from the struck surface.
	# Add to a bounded spring velocity so repeated contacts combine without restarting.
	var direction: Vector2 = resolved_velocity_change / impulse
	impact_velocity += direction * lerpf(0.8, 5.2, strength)
	impact_velocity = impact_velocity.limit_length(5.2)
	trauma = clampf(trauma + strength * 0.72, 0.0, 1.0)


func set_off_track_rumble(strength: float) -> void:
	surface_target = clampf(strength, 0.0, 1.0)


func clear_shake() -> void:
	trauma = 0.0
	impact_offset = Vector2.ZERO
	impact_velocity = Vector2.ZERO
	surface_target = 0.0
	surface_strength = 0.0
	shake_time = 0.0


func shake_offset(delta: float) -> Vector2:
	var step: float = maxf(delta, 0.0)
	shake_time += step
	trauma = maxf(0.0, trauma - TRAUMA_DECAY * step)
	impact_velocity += -impact_offset * IMPACT_SPRING * step
	impact_velocity *= exp(-IMPACT_DAMPING * step)
	impact_offset += impact_velocity * step
	impact_offset = impact_offset.limit_length(MAX_IMPACT_METRES)
	surface_strength = lerpf(surface_strength, surface_target, 1.0 - exp(-SURFACE_RESPONSE * step))
	# A small loose-ground heave with slower beats than the collision response.
	# Keeping this presentation-only preserves canonical handling and replays.
	var vibration := Vector2(
		sin(shake_time * SURFACE_PRIMARY_FREQUENCY) + sin(shake_time * 37.0) * 0.35,
		cos(shake_time * 53.0) + sin(shake_time * SURFACE_SECONDARY_FREQUENCY) * 0.35
	) * MAX_SURFACE_METRES * surface_strength * 0.62
	var impact_noise := Vector2(sin(shake_time * 71.0), cos(shake_time * 83.0)) * 0.018 * trauma * trauma
	return (impact_offset + impact_noise + vibration).limit_length(MAX_IMPACT_METRES)


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
	if snap:
		clear_shake()
	var shake: Vector2 = shake_offset(delta)
	var yaw: float = deg_to_rad(profile.world_yaw_degrees) - (heading if profile.follow_heading else 0.0)
	var offset := Vector3(0, profile.height, profile.height / tan(deg_to_rad(profile.pitch_degrees)))
	var shaken_focus: Vector3 = focus + VisualGeometry.world(shake)
	position = shaken_focus + offset.rotated(Vector3.UP, yaw)
	look_at(shaken_focus, Vector3.UP)
