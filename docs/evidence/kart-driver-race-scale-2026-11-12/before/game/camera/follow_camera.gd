class_name FollowCamera
extends Camera3D

var profile: CameraProfile = preload("res://resources/camera.tres")
var focus: Vector3 = Vector3.ZERO
var initialized: bool = false
var mode: String = CameraProfile.MODES[0]
var smoothed_yaw: float = 0.0
var look_ahead_offset: Vector2 = Vector2.ZERO
var speed_zoom_enabled: bool = true
var speed_zoom_strength: float = CameraProfile.DEFAULT_SPEED_ZOOM_STRENGTH:
	set(value):
		speed_zoom_strength = clampf(value, 0.0, CameraProfile.MAX_SPEED_ZOOM_STRENGTH) if is_finite(value) else CameraProfile.DEFAULT_SPEED_ZOOM_STRENGTH
var zoom_multiplier: float = 1.0
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


func set_mode(value: String) -> void:
	mode = CameraProfile.valid_mode(value)
	profile = CameraProfile.for_mode(mode)
	initialized = false
	clear_shake()


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
	var step: float = maxf(delta, 0.0)
	var desired_zoom: float = 1.0
	if speed_zoom_enabled:
		var amount: float = smoothstep(profile.speed_zoom_start_kmh, profile.speed_zoom_full_kmh, velocity.length() * 3.6)
		desired_zoom += speed_zoom_strength * amount
	zoom_multiplier = desired_zoom if snap or not initialized else lerpf(zoom_multiplier, desired_zoom, 1.0 - exp(-profile.speed_zoom_smoothing * step))
	projection = PROJECTION_ORTHOGONAL if profile.orthographic else PROJECTION_PERSPECTIVE
	keep_aspect = KEEP_HEIGHT
	# Orthographic distance alone does not pull back: widen the whole-world extent.
	size = profile.baseline_extent / profile.magnification * zoom_multiplier
	fov = profile.field_of_view
	near = 0.1
	far = 180.0
	var ahead: Vector2 = velocity * profile.velocity_look_ahead
	if velocity.length() > 0.5:
		ahead += Vector2(sin(heading), cos(heading)) * profile.forward_look_ahead
	ahead = ahead.limit_length(profile.maximum_look_ahead)
	if snap or not initialized or profile.look_ahead_smoothing <= 0.0:
		look_ahead_offset = ahead
	else:
		# Delay changes around the car separately from ordinary position tracking.
		look_ahead_offset = look_ahead_offset.lerp(ahead, 1.0 - exp(-profile.look_ahead_smoothing * step))
	var desired: Vector3 = VisualGeometry.world(point + look_ahead_offset)
	var desired_yaw: float = deg_to_rad(profile.world_yaw_degrees) - (heading if profile.follow_heading else 0.0)
	if snap or not initialized:
		focus = desired
		smoothed_yaw = desired_yaw
		initialized = true
	else:
		focus = focus.lerp(desired, 1.0 - exp(-profile.smoothing * step))
		if profile.follow_heading:
			# Ease over the shortest arc, with a hard speed cap even after a spin.
			var eased_turn: float = angle_difference(smoothed_yaw, desired_yaw) * (1.0 - exp(-profile.heading_smoothing * step))
			var maximum_turn: float = deg_to_rad(profile.maximum_yaw_speed_degrees) * step
			smoothed_yaw += clampf(eased_turn, -maximum_turn, maximum_turn)
		else:
			smoothed_yaw = desired_yaw
	if snap:
		clear_shake()
	var shake: Vector2 = shake_offset(delta)
	var height: float = profile.height * zoom_multiplier
	var offset := Vector3(0, height, height / tan(deg_to_rad(profile.pitch_degrees)))
	var shaken_focus: Vector3 = focus + VisualGeometry.world(shake)
	position = shaken_focus + offset.rotated(Vector3.UP, smoothed_yaw)
	look_at(shaken_focus, Vector3.UP)
