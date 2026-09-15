class_name VehicleSimulation
extends RefCounted
## Canonical core: no nodes, input polling, wall clock, file I/O or random numbers.
## Float replay equivalence is measured on one engine/platform only at this gate.

const PHYSICS_VERSION: String = "arcade-planar-0.21"
const TICK_RATE: int = 120
const STEP: float = 1.0 / TICK_RATE

var state := VehicleState.new()
var config: HandlingConfig
var kerb_probe := VehicleState.new()


func _init(handling: HandlingConfig) -> void:
	config = handling


func reset(point: Vector2, direction: float = 0.0) -> void:
	state = VehicleState.new()
	state.position = point
	state.heading = direction


func step(frame: DriveFrame, ground: PlaygroundData = null) -> void:
	var old_position: Vector2 = state.position
	var old_heading: float = state.heading
	state.jump_cooldown = maxi(0,state.jump_cooldown-1)
	if state.jump_height > 0.0:
		var previous: Vector2 = state.position
		state.position += state.velocity*STEP
		state.jump_velocity -= 9.81*STEP
		state.jump_height = maxf(0.0,state.jump_height+state.jump_velocity*STEP)
		if ground != null:
			ground.resolve(state,previous,config)
			ground.step_props(state,previous,config,STEP)
		if state.jump_height == 0.0:
			state.jump_velocity = 0.0
			state.velocity *= 0.88
		_step_kerbs(old_position,old_heading,null)
		state.tick += 1
		return
	var surface: Vector2 = ground.surface_factors(state) if ground != null else Vector2(1.0, 0.0)
	var pickup: float = ground.tire_pickup(state) if ground != null else 0.0
	var fluids: Vector2 = ground.tire_fluids(state) if ground != null else Vector2.ZERO
	var tire_grip: float = 1.0 - maxf(state.tire_dirt * config.dirty_tire_grip_loss, maxf(state.tire_oil * 0.65, state.tire_water * 0.18))
	var throttle: float = frame.throttle / 255.0
	var brake: float = frame.brake / 255.0
	if config.progressive_handling and brake > 0.0:
		throttle = 0.0
	var requested_steering: float = frame.steer / 127.0
	var steering_response: float = config.steering_rate
	if config.progressive_handling and state.steering != 0.0 and (signf(requested_steering) != signf(state.steering) or absf(requested_steering) < absf(state.steering)):
		steering_response = maxf(steering_response, config.countersteering_rate)
	state.steering = move_toward(state.steering, requested_steering, steering_response * STEP)
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
	var brake_turn: float = brake * absf(state.steering) * smoothstep(4.0, 12.0, longitudinal)
	if config.progressive_handling:
		# Front traction saturates smoothly: excess entry speed widens the path
		# instead of continuing to rotate the chassis into an involuntary drift.
		var grip_yaw: float = config.lateral_grip * config.front_grip * surface.x * tire_grip / maxf(speed, 1.0)
		var demand: float = absf(target_yaw) / maxf(grip_yaw, 0.01)
		target_yaw /= pow(1.0 + pow(demand, 6.0), 1.0 / 6.0)
		# Sustained, bounded weight transfer; repeated taps cannot stack impulses.
		target_yaw += signf(state.steering) * brake_turn * config.brake_rotation
	# Power rotates the rear; lifting restores rear grip and reduces rotation.
	target_yaw += state.steering * throttle * config.throttle_rotation * speed_fraction * signf(longitudinal)
	if longitudinal > 1.0 and not config.progressive_handling:
		target_yaw += slip * config.countersteer_assistance
	target_yaw = clampf(target_yaw, -config.maximum_yaw_rate, config.maximum_yaw_rate)
	var yaw_response: float = config.mass / config.rotational_inertia * 7.0
	if config.progressive_handling and requested_steering * state.yaw_rate < 0.0:
		# Follow the player's correction sooner; no road/heading target or speed gift.
		yaw_response *= 1.0 + config.countersteer_assistance * smoothstep(0.04, 0.3, absf(slip))
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
	grip_limit *= surface.x * tire_grip
	grip_limit *= 1.0 - throttle * absf(state.steering) * config.throttle_grip_loss
	if config.progressive_handling:
		grip_limit *= 1.0 - brake_turn * config.brake_grip_loss
	var lateral_acceleration: float = clampf(-lateral * config.lateral_response * tire_grip, -grip_limit, grip_limit)
	var next_lateral: float = move_toward(lateral, 0.0, absf(lateral_acceleration) * STEP)
	# Grip redirects most scrubbed lateral energy into travel instead of deleting it.
	# Fade for broadside slides; retain direction in reverse. Apply before pedals so
	# braking and drag still remove energy, and collisions never get compensated.
	var removed_energy: float = maxf(0.0, lateral * lateral - next_lateral * next_lateral)
	var alignment: float = clampf(absf(longitudinal) / maxf(absf(lateral), 0.01), 0.0, 1.0)
	longitudinal = signf(longitudinal) * sqrt(longitudinal * longitudinal + removed_energy * config.corner_energy_retention * alignment)
	var drive_acceleration: float = _pedal_acceleration(longitudinal, frame.throttle / 255.0, brake)
	if config.progressive_handling and throttle > 0.0 and longitudinal > 0.0:
		drive_acceleration *= 1.0 - config.slide_drive_loss * smoothstep(0.10, 0.55, absf(slip))
	# Combined traction budgets make braking and acceleration compete with cornering.
	var lateral_usage: float = absf(lateral_acceleration) / maxf(grip_limit, 0.01)
	var longitudinal_limit: float = config.longitudinal_grip * sqrt(maxf(0.25, 1.0 - lateral_usage * lateral_usage * 0.65))
	longitudinal_limit *= surface.x * tire_grip
	drive_acceleration = clampf(drive_acceleration, -longitudinal_limit, longitudinal_limit)
	# Impact recoil may exceed powered reverse speed. Preserve that momentum,
	# but the reverse pedal cannot sustain or increase an overspeed recoil.
	if longitudinal < -config.reverse_speed:
		drive_acceleration = maxf(0.0, drive_acceleration)
	var next_longitudinal: float = longitudinal + drive_acceleration * STEP
	# Braking never crosses zero into reverse until the stopped hold delay elapses.
	if brake > 0.0 and longitudinal > 0.0 and next_longitudinal < 0.0:
		next_longitudinal = 0.0
	if throttle > 0.0 and longitudinal < 0.0 and next_longitudinal > 0.0:
		next_longitudinal = 0.0
	var resistance: float = (config.rolling_resistance + config.drag * speed * speed) / config.mass
	resistance += surface.y
	next_longitudinal = move_toward(next_longitudinal, 0.0, resistance * STEP)
	next_longitudinal = clampf(next_longitudinal, -maxf(config.reverse_speed, -longitudinal), config.maximum_speed)
	state.velocity = forward * next_longitudinal + right * next_lateral
	state.velocity = state.velocity.limit_length(config.maximum_speed)
	var previous_position: Vector2 = state.position
	state.position += state.velocity * STEP
	if ground != null:
		ground.resolve(state, previous_position, config)
		ground.step_props(state,previous_position,config,STEP)
		ground.launch_jump(state,previous_position)
	# Only actual resolved travel coats/cleans tires. Waiting or pushing a wall
	# cannot clean them, and reverse travel counts just like forward travel.
	var distance: float = state.position.distance_to(previous_position)
	if pickup > 0.0:
		state.tire_dirt = minf(1.0, state.tire_dirt + distance * pickup / config.tire_pickup_distance)
	else:
		state.tire_dirt = maxf(0.0, state.tire_dirt - distance / config.tire_clean_distance)
	state.tire_oil = clampf(state.tire_oil + (distance / 3.0 if fluids.x > 0.0 else -distance / 180.0), 0.0, 1.0)
	state.tire_water = clampf(state.tire_water + (distance / 3.0 if fluids.y > 0.0 else -distance / 20.0), 0.0, 1.0)
	_step_kerbs(old_position,old_heading,ground)
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
	if config.slide_power_recovery > 0.0 and speed > 0.0:
		# Optional original-based tune: retain more of the engine's normal force
		# while sideways. It still acts only along the chassis, requires throttle,
		# and remains below full engine force and the surface traction budget.
		var slide: float = smoothstep(0.06, 0.30, absf(state.slip_angle()))
		power_falloff += (1.0 - power_falloff) * config.slide_power_recovery * slide
	return config.engine_force / config.mass * throttle * power_falloff


func _step_kerbs(previous: Vector2, previous_heading: float, ground: PlaygroundData) -> void:
	var heights := Vector4.ZERO
	var rise: float = 0.0
	if ground != null and not state.track_elevated and state.jump_height == 0.0:
		kerb_probe.position = previous
		kerb_probe.heading = previous_heading
		var last: Vector4 = ground.kerb_heights(kerb_probe,config)
		# Sample actual resolved tyre travel at <=10 cm to detect short crossings
		# at ordinary top speed and during reverse travel.
		var travel: float = previous.distance_to(state.position)+absf(angle_difference(previous_heading,state.heading))*config.wheelbase*0.5
		var samples: int = maxi(1,ceili(travel/0.10))
		for sample: int in range(1,samples+1):
			var t: float = float(sample)/samples
			kerb_probe.position = previous.lerp(state.position,t)
			kerb_probe.heading = lerp_angle(previous_heading,state.heading,t)
			heights = ground.kerb_heights(kerb_probe,config)
			for wheel: int in range(4): rise += maxf(0.0,heights[wheel]-last[wheel])*0.25
			last = heights
	var speed: float = state.velocity.length()
	# A low kerb dissipates a little speed. It never supplies a collision impulse,
	# airborne mode, steering kick or forward energy. Capped for long rumble runs.
	var loss: float = minf(0.65*STEP,speed*rise*0.10)*smoothstep(1.0,8.0,speed)
	if speed > 0.0: state.velocity *= maxf(0.0,speed-loss)/speed
	var target := Vector3((heights.x+heights.y+heights.z+heights.w)*0.25,
		atan2((heights.x+heights.y-heights.z-heights.w)*0.5,config.wheelbase),
		atan2((heights.y+heights.w-heights.x-heights.z)*0.5,1.66*HandlingConfig.BODY_SCALE))
	state.kerb_velocity.x += minf(0.30,rise*speed*0.12)
	state.kerb_velocity += ((target-state.kerb_offset)*324.0-state.kerb_velocity*24.0)*STEP
	state.kerb_offset += state.kerb_velocity*STEP
	state.kerb_offset.x = clampf(state.kerb_offset.x,-0.015,0.14)
	state.kerb_offset.y = clampf(state.kerb_offset.y,-0.08,0.08)
	state.kerb_offset.z = clampf(state.kerb_offset.z,-0.10,0.10)
