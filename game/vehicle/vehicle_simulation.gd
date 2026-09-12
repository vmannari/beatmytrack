class_name VehicleSimulation
extends RefCounted
## Canonical core: no nodes, input polling, wall clock, file I/O or random numbers.
## Float replay equivalence is measured on one engine/platform only at this gate.

const PHYSICS_VERSION: String = "arcade-planar-0.7"
const TICK_RATE: int = 120
const STEP: float = 1.0 / TICK_RATE

var state := VehicleState.new()
var config: HandlingConfig


func _init(handling: HandlingConfig) -> void:
	config = handling


func reset(point: Vector2, direction: float = 0.0) -> void:
	state = VehicleState.new()
	state.position = point
	state.heading = direction


func step(frame: DriveFrame, ground: PlaygroundData = null) -> void:
	var surface: Vector2 = ground.surface_factors(state) if ground != null else Vector2(1.0, 0.0)
	var throttle: float = frame.throttle / 255.0
	var brake: float = frame.brake / 255.0
	state.steering = move_toward(state.steering, frame.steer / 127.0, config.steering_rate * STEP)
	var forward: Vector2 = state.forward()
	var right: Vector2 = state.right()
	var longitudinal: float = state.velocity.dot(forward)
	var lateral: float = state.velocity.dot(right)
	var speed: float = state.velocity.length()
	var slip: float = state.slip_angle()
	var speed_fraction: float = clampf(absf(longitudinal) / 24.0, 0.0, 1.0)
	var steer_angle: float = state.steering * config.steering_angle * (1.0 - config.high_speed_steering_reduction * speed_fraction)
	var target_yaw: float = longitudinal / config.wheelbase * tan(steer_angle)
	target_yaw *= config.front_grip / config.rear_grip
	# Power rotates the rear; lifting restores rear grip and reduces rotation.
	target_yaw += state.steering * throttle * config.throttle_rotation * speed_fraction * signf(longitudinal)
	if longitudinal > 1.0:
		target_yaw += slip * config.countersteer_assistance
	target_yaw = clampf(target_yaw, -config.maximum_yaw_rate, config.maximum_yaw_rate)
	var yaw_response: float = config.mass / config.rotational_inertia * 7.0
	state.yaw_rate = lerpf(state.yaw_rate, target_yaw, 1.0 - exp(-yaw_response * STEP))
	state.heading = wrapf(state.heading + state.yaw_rate * STEP, -PI, PI)
	# Use the newly turned chassis frame while retaining world-space momentum.
	forward = state.forward()
	right = state.right()
	longitudinal = state.velocity.dot(forward)
	lateral = state.velocity.dot(right)
	var slide_amount: float = smoothstep(config.slip_threshold, config.slip_threshold * 2.0, absf(slip)) if speed > 3.0 else 0.0
	var target_grip: float = lerpf(1.0, config.sliding_grip, slide_amount)
	state.grip = move_toward(state.grip, target_grip, config.grip_recovery * STEP)
	var grip_limit: float = config.lateral_grip * state.grip * (config.front_grip + config.rear_grip) * 0.5
	grip_limit *= surface.x
	grip_limit *= 1.0 - throttle * absf(state.steering) * config.throttle_grip_loss
	var lateral_acceleration: float = clampf(-lateral * config.lateral_response, -grip_limit, grip_limit)
	var next_lateral: float = move_toward(lateral, 0.0, absf(lateral_acceleration) * STEP)
	# Grip redirects most scrubbed lateral energy into travel instead of deleting it.
	# Fade for broadside slides; retain direction in reverse. Apply before pedals so
	# braking and drag still remove energy, and collisions never get compensated.
	var removed_energy: float = maxf(0.0, lateral * lateral - next_lateral * next_lateral)
	var alignment: float = clampf(absf(longitudinal) / maxf(absf(lateral), 0.01), 0.0, 1.0)
	longitudinal = signf(longitudinal) * sqrt(longitudinal * longitudinal + removed_energy * config.corner_energy_retention * alignment)
	var drive_acceleration: float = _pedal_acceleration(longitudinal, throttle, brake)
	# Combined traction budgets make braking and acceleration compete with cornering.
	var lateral_usage: float = absf(lateral_acceleration) / maxf(grip_limit, 0.01)
	var longitudinal_limit: float = config.longitudinal_grip * sqrt(maxf(0.25, 1.0 - lateral_usage * lateral_usage * 0.65))
	longitudinal_limit *= surface.x
	drive_acceleration = clampf(drive_acceleration, -longitudinal_limit, longitudinal_limit)
	var next_longitudinal: float = longitudinal + drive_acceleration * STEP
	# Braking never crosses zero into reverse until the stopped hold delay elapses.
	if brake > 0.0 and longitudinal > 0.0 and next_longitudinal < 0.0:
		next_longitudinal = 0.0
	if throttle > 0.0 and longitudinal < 0.0 and next_longitudinal > 0.0:
		next_longitudinal = 0.0
	var resistance: float = (config.rolling_resistance + config.drag * speed * speed) / config.mass
	resistance += surface.y
	next_longitudinal = move_toward(next_longitudinal, 0.0, resistance * STEP)
	next_longitudinal = clampf(next_longitudinal, -config.reverse_speed, config.maximum_speed)
	state.velocity = forward * next_longitudinal + right * next_lateral
	state.velocity = state.velocity.limit_length(config.maximum_speed)
	var previous_position: Vector2 = state.position
	state.position += state.velocity * STEP
	if ground != null:
		ground.resolve(state, previous_position, config)
	state.tick += 1


func _pedal_acceleration(speed: float, throttle: float, brake: float) -> float:
	if brake > 0.0:
		if absf(speed) < 0.15 and throttle == 0.0:
			state.reverse_wait += STEP
		elif speed > 0.15 or throttle > 0.0:
			state.reverse_wait = 0.0
		if speed > 0.15 or throttle > 0.0:
			# Brake wins simultaneous pedals; no accidental burnout/boost.
			return -signf(speed) * config.braking_force / config.mass * brake
		if state.reverse_wait >= config.reverse_delay or speed < -0.15:
			return -config.engine_force / config.mass * 0.55 * brake
		return -speed / STEP
	state.reverse_wait = 0.0
	if speed < -0.15 and throttle > 0.0:
		return config.braking_force / config.mass * throttle
	var power_falloff: float = 1.0 - 0.45 * clampf(speed / config.maximum_speed, 0.0, 1.0)
	return config.engine_force / config.mass * throttle * power_falloff
