class_name VehicleSimulation
extends RefCounted
## Canonical core: no nodes, input polling, wall clock, file I/O or random numbers.
## Float replay equivalence is measured on one engine/platform only at this gate.

const RALLY_HANDBRAKE = preload("res://vehicle/rally_handbrake.gd")
const PHYSICS_VERSION: String = "arcade-planar-0.59"
const SOIL_TORQUE_GAIN: float = 1.35 # Loose verge bite beyond pure longitudinal drag.
const SOIL_ROUGH_YAW_ACCELERATION: float = 1.45 # rad/s^2 peak spatial tyre deflection.
const TICK_RATE: int = 120
const STEP: float = 1.0 / TICK_RATE
const ROLL_DURATION_TICKS: int = 72 # 0.6 s per revolution; shared with presentation.
const ROLL_CONTINUE_SPEED: float = 18.0 # Remaining lateral m/s needed for another flip.

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
	state.collision_impulse = Vector2.ZERO
	state.scrape_strength = 0.0
	state.scrape_normal = Vector2.ZERO
	state.scrape_speed = 0.0
	LaunchStart.advance(state, frame)
	# Brake pressure is only input driven; no automatic drift latch.
	var requested_handbrake: float = frame.handbrake / 255.0
	state.handbrake_pressure = move_toward(state.handbrake_pressure, requested_handbrake,
		(30.0 if requested_handbrake > state.handbrake_pressure else 3.0) * STEP)
	var old_position: Vector2 = state.position
	var old_heading: float = state.heading
	var old_velocity: Vector2 = state.velocity
	state.roll_cooldown = maxi(0, state.roll_cooldown - 1)
	if state.roll_ticks > 0:
		state.roll_ticks -= 1
		state.velocity = state.velocity.move_toward(Vector2.ZERO, 28.0 * STEP)
		state.position += state.velocity * STEP
		if ground != null:
			ground.resolve(state, old_position, config)
			ground.step_props(state, old_position, config, STEP)
		# Decide at tire contact using velocity AFTER collision resolution. Momentum
		# can carry another revolution, even onto asphalt, but a stop/rebound cannot.
		var continuing_speed: float = -state.roll_direction * state.velocity.dot(state.right())
		if state.roll_ticks == 0 and continuing_speed >= ROLL_CONTINUE_SPEED:
			state.roll_ticks = ROLL_DURATION_TICKS
			state.roll_cooldown = ROLL_DURATION_TICKS + 2 * TICK_RATE
		state.yaw_rate = 0.0
		state.tick += 1
		return
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
	if pickup > 0.0:
		surface.x = minf(1.0, surface.x * config.loose_surface_grip)
	var fluids: Vector2 = ground.tire_fluids(state) if ground != null else Vector2.ZERO
	# Loose ground can trip a fast broadside slide; remaining lateral momentum determines the number of rolls.
	if pickup > 0.0 and state.roll_cooldown == 0 and state.velocity.length() >= 24.0 and absf(state.slip_angle()) >= deg_to_rad(65.0):
		state.roll_ticks = ROLL_DURATION_TICKS
		state.roll_direction = -signf(state.velocity.dot(state.right()))
		state.roll_cooldown = ROLL_DURATION_TICKS + 2 * TICK_RATE
		state.tick += 1
		return
	var dirt_loss: float = dirt_grip_loss(state.tire_dirt, config.dirty_tire_grip_loss, pickup > 0.0)
	var tire_grip: float = 1.0 - maxf(dirt_loss, maxf(state.tire_oil * 0.65, state.tire_water * 0.18))
	var throttle: float = frame.throttle / 255.0
	var brake: float = frame.brake / 255.0
	var handbrake: float = state.handbrake_pressure
	if config.progressive_handling and brake > 0.0:
		throttle = 0.0
	# Automatic clutch disconnects drive while pulling the rear brake.
	throttle *= 1.0 - requested_handbrake
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
	var wheel_soil: Vector4 = _wheel_soil_contacts(ground) if config.wheel_soil_drag else Vector4(pickup,pickup,pickup,pickup)
	# Unequal resistance across the car pulls it toward the wheels that left the
	# road. This is a bounded continuous yaw demand rather than an impulse, so a
	# one-wheel excursion is noticeable and settles immediately after rejoining.
	var left_soil: float = (wheel_soil.x + wheel_soil.z) * 0.5
	var right_soil: float = (wheel_soil.y + wheel_soil.w) * 0.5
	var soil_drag_rate: float = (7.5 + speed * 0.38) * smoothstep(3.0,14.0,speed) * config.soil_drag_multiplier
	var brake_turn: float = brake * absf(state.steering) * smoothstep(4.0, 12.0, longitudinal)
	var lift: float = (1.0 - throttle) * (1.0 - brake) * smoothstep(8.0, 24.0, longitudinal)
	# Explicit rear braking replaces lift-off unloading rather than stacking with it.
	lift *= 1.0 - handbrake
	target_yaw += state.steering * lift * config.lift_off_rotation
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
	# Rear lock changes tire forces, not the front steering angle or a target radius.
	var axle: Vector3 = _handbrake_axles(longitudinal, lateral, steer_angle, surface.x * tire_grip, requested_handbrake) if handbrake > 0.0 else Vector3.ZERO
	var axle_acceleration: Vector2 = right * axle.x + forward * axle.y
	# Retain low-speed hairpin rotation while limiting fast rear-lock spins.
	var rear_lock_yaw_limit: float = lerpf(4.0, 3.2, smoothstep(12.0, 24.0, speed))
	var yaw_limit: float = lerpf(config.maximum_yaw_rate, rear_lock_yaw_limit, handbrake)
	target_yaw = clampf(target_yaw, -config.maximum_yaw_rate, config.maximum_yaw_rate)
	var yaw_response: float = config.mass / config.rotational_inertia * 7.0
	if config.progressive_handling and requested_steering * state.yaw_rate < 0.0:
		# Follow the player's correction sooner; no road/heading target or speed gift.
		yaw_response *= 1.0 + config.countersteer_assistance * smoothstep(0.04, 0.3, absf(slip))
	var normal_yaw: float = lerpf(state.yaw_rate, target_yaw, 1.0 - exp(-yaw_response * STEP))
	var axle_yaw: float = state.yaw_rate + axle.z * STEP
	if handbrake > 0.0 and longitudinal > 1.0 and target_yaw * axle_yaw < 0.0:
		# Rear lock must retain the existing steering correction while the wheels
		# unwind rotation from the previous turn. Add only that bounded response;
		# axle forces and angular momentum still determine the resulting yaw.
		axle_yaw += normal_yaw - state.yaw_rate
	state.yaw_rate = lerpf(normal_yaw, axle_yaw, handbrake)
	# Differential wheel drag creates a moment about the centre of mass. This is
	# applied as angular acceleration after steering response, so it adds to or
	# opposes a corner instead of being hidden inside the requested steering yaw.
	var differential_deceleration: float = (right_soil-left_soil) * soil_drag_rate * 0.5
	var soil_angular_acceleration: float = differential_deceleration * config.mass * config.track_width * 0.5 / config.rotational_inertia * SOIL_TORQUE_GAIN
	state.yaw_rate += soil_angular_acceleration * STEP * signf(longitudinal)
	state.yaw_rate += _soil_rough_yaw_acceleration(wheel_soil,speed) * STEP
	state.yaw_rate = clampf(state.yaw_rate,-yaw_limit,yaw_limit)
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
	grip_limit *= 1.0 - lift * absf(state.steering) * config.lift_off_grip_loss
	grip_limit *= 1.0 - throttle * absf(state.steering) * config.throttle_grip_loss
	if config.progressive_handling:
		grip_limit *= 1.0 - brake_turn * config.brake_grip_loss
	var lateral_acceleration: float = clampf(-lateral * config.lateral_response * tire_grip, -grip_limit, grip_limit)
	var next_lateral: float = move_toward(lateral, 0.0, absf(lateral_acceleration) * STEP)
	if handbrake > 0.0:
		next_lateral = lerpf(next_lateral, lateral + axle_acceleration.dot(right) * STEP, handbrake)
	# Grip redirects most scrubbed lateral energy into travel instead of deleting it.
	# Fade for broadside slides; retain direction in reverse. Apply before pedals so
	# braking and drag still remove energy, and collisions never get compensated.
	var removed_energy: float = maxf(0.0, lateral * lateral - next_lateral * next_lateral)
	# During rear-grip recovery, sideways scrub must not feed backward travel
	# after the nose has turned through the hairpin.
	if handbrake > 0.0 and longitudinal < 0.0: removed_energy = 0.0
	var alignment: float = clampf(absf(longitudinal) / maxf(absf(lateral), 0.01), 0.0, 1.0)
	longitudinal = signf(longitudinal) * sqrt(longitudinal * longitudinal + removed_energy * config.corner_energy_retention * alignment * (1.0 - requested_handbrake))
	var drive_acceleration: float = _pedal_acceleration(longitudinal, frame.throttle / 255.0, brake)
	if handbrake > 0.0:
		state.reverse_wait = 0.0
		if brake > 0.0:
			drive_acceleration = -signf(longitudinal) * config.braking_force / config.mass * brake
		else:
			drive_acceleration = _pedal_acceleration(longitudinal, throttle, 0.0)
	if config.progressive_handling and throttle > 0.0 and longitudinal > 0.0:
		drive_acceleration *= 1.0 - config.slide_drive_loss * smoothstep(0.10, 0.55, absf(slip))
	# Combined traction budgets make braking and acceleration compete with cornering.
	var lateral_usage: float = absf(lateral_acceleration) / maxf(grip_limit, 0.01)
	var longitudinal_limit: float = config.longitudinal_grip * sqrt(maxf(0.25, 1.0 - lateral_usage * lateral_usage * 0.65))
	# Fade coating-related longitudinal loss at crawling speed so soil cannot
	# strand the car against movable props; full penalty applies above 12 m/s.
	var drive_tire_grip: float = 1.0 - maxf(dirt_loss * smoothstep(3.0, 12.0, speed), maxf(state.tire_oil * 0.65, state.tire_water * 0.18))
	longitudinal_limit *= surface.x * drive_tire_grip
	drive_acceleration = clampf(drive_acceleration, -longitudinal_limit, longitudinal_limit)
	# Temporary forward drive only; braking/reverse and maximum speed stay unchanged.
	if drive_acceleration > 0.0 and throttle > 0.0 and longitudinal >= 0.0:
		if state.tick < state.launch_delay_until: drive_acceleration = 0.0
		elif state.tick < state.launch_end_tick: drive_acceleration *= 1.0 + state.launch_gain
	# Impact recoil may exceed powered reverse speed. Preserve that momentum,
	# but the reverse pedal cannot sustain or increase an overspeed recoil.
	if longitudinal < -config.reverse_speed:
		drive_acceleration = maxf(0.0, drive_acceleration)
	var next_longitudinal: float = longitudinal + (drive_acceleration + axle_acceleration.dot(forward) * handbrake) * STEP
	if requested_handbrake > 0.0 and longitudinal * next_longitudinal < 0.0: next_longitudinal = 0.0
	if requested_handbrake == 0.0 and brake == 0.0 and handbrake > 0.0 and next_longitudinal < 0.0:
		# Brief, dissipative exit assistance catches reverse chassis slip while
		# rear traction recovers. It does not reverse momentum or supply power.
		next_longitudinal = RALLY_HANDBRAKE.catch_backward(next_longitudinal,handbrake,surface.x*tire_grip,STEP)
	# Braking never crosses zero into reverse until the stopped hold delay elapses.
	if brake > 0.0 and longitudinal > 0.0 and next_longitudinal < 0.0:
		next_longitudinal = 0.0
	# Tiny negative projections while the chassis finishes rotating are inside
	# the stopped band; repeatedly clamping them strands a powered exit at zero.
	var forward_crossing_threshold: float = -0.15 if handbrake > 0.0 and requested_handbrake == 0.0 else 0.0
	if throttle > 0.0 and longitudinal < forward_crossing_threshold and next_longitudinal > 0.0:
		next_longitudinal = 0.0
	var resistance: float = (config.rolling_resistance + config.drag * speed * speed) / config.mass
	resistance += surface.y
	# Soil drag dissipates sideways momentum too, including under throttle.
	var average_soil: float = (wheel_soil.x+wheel_soil.y+wheel_soil.z+wheel_soil.w)*0.25
	var soil_contact: float = maxf(pickup,average_soil)
	# Stronger high-speed scrub makes a full off-track excursion costly while
	# averaging the probes keeps one or two escaped wheels proportional.
	var soil_drag: float = soil_contact * soil_drag_rate
	# Grass has a separate rolling penalty. Reuse the four material contacts
	# (grass pickup is 0.5, sand is 1.0) so resistance begins at the first wheel,
	# without changing contamination or adding another set of ground probes.
	var grass_contact: float = _grass_contact(wheel_soil, pickup)
	# Retain the tuned low-speed powered escape, especially for the kart.
	# Above 24 m/s grass takes the full penalty even with throttle held.
	var grass_drive: float = 1.0 - throttle * (1.0-smoothstep(14.0,24.0,speed))
	soil_drag += grass_contact * (1.5 + speed * 0.75) * smoothstep(0.0, 2.0, speed) * config.soil_drag_multiplier * grass_drive
	next_lateral = move_toward(next_lateral, 0.0, soil_drag * STEP)
	resistance += soil_drag
	next_longitudinal = move_toward(next_longitudinal, 0.0, resistance * STEP)
	next_longitudinal = clampf(next_longitudinal, -maxf(config.reverse_speed, -longitudinal), config.maximum_speed)
	state.velocity = forward * next_longitudinal + right * next_lateral
	state.velocity = state.velocity.limit_length(config.maximum_speed)
	if handbrake > 0.0 and throttle == 0.0: state.velocity = state.velocity.limit_length(speed)
	var previous_position: Vector2 = state.position
	state.position += state.velocity * STEP
	if ground != null:
		ground.resolve(state, previous_position, config)
		ground.step_props(state,previous_position,config,STEP)
		ground.slow_in_snow(state,previous_position,config,STEP)
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
	if ground != null: ground.step_speed_bumps(state,old_position,old_heading,old_velocity,config,STEP)
	state.tick += 1


static func dirt_grip_loss(dirt: float, sensitivity: float, loose_contact: bool = false) -> float:
	# Road contamination bites early after a short excursion, then continuously
	# recovers with the existing distance-cleaned coating. Preserve loose-ground
	# balance and at least 30% road traction even at a full coating.
	if loose_contact: return dirt * sensitivity
	return clampf(sensitivity * 2.0, 0.45, 0.70) * sqrt(clampf(dirt, 0.0, 1.0)) if sensitivity > 0.0 else 0.0


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
		atan2((heights.y+heights.w-heights.x-heights.z)*0.5,config.track_width))
	state.kerb_velocity.x += minf(0.30,rise*speed*0.12)
	state.kerb_velocity += ((target-state.kerb_offset)*324.0-state.kerb_velocity*24.0)*STEP
	state.kerb_offset += state.kerb_velocity*STEP
	state.kerb_offset.x = clampf(state.kerb_offset.x,-0.015,0.14)
	state.kerb_offset.y = clampf(state.kerb_offset.y,-0.08,0.08)
	state.kerb_offset.z = clampf(state.kerb_offset.z,-0.10,0.10)


func _wheel_soil_contact(ground: PlaygroundData, center_contact: float) -> float:
	var contacts: Vector4 = _wheel_soil_contacts(ground)
	return maxf(center_contact,maxf(maxf(contacts.x,contacts.y),maxf(contacts.z,contacts.w)))


func _wheel_soil_contacts(ground: PlaygroundData) -> Vector4:
	if ground == null: return Vector4.ZERO
	# Fixed order: front-left, front-right, rear-left, rear-right. Probes use
	# canonical axle dimensions and the current deck for deterministic replays.
	var contacts := Vector4.ZERO
	var probe := VehicleState.new()
	probe.track_elevated = state.track_elevated
	var index: int = 0
	for axle: float in [0.5, -0.5]:
		for side: float in [-0.5, 0.5]:
			probe.position = state.position + state.forward()*config.wheelbase*axle + state.right()*config.track_width*side
			contacts[index] = ground.tire_pickup(probe)
			index += 1
	return contacts


func _grass_contact(contacts: Vector4, center: float) -> float:
	var wheels: float = (float(contacts.x == 0.5) + float(contacts.y == 0.5) + float(contacts.z == 0.5) + float(contacts.w == 0.5)) * 0.25
	return maxf(float(center == 0.5), wheels)


func _soil_rough_yaw_acceleration(contacts: Vector4, speed: float) -> float:
	var contact_count: float = float(contacts.x>0.0)+float(contacts.y>0.0)+float(contacts.z>0.0)+float(contacts.w>0.0)
	if contact_count == 0.0: return 0.0
	# Two incommensurate spatial waves approximate small terrain-driven tyre
	# deflections. World-space sampling feels irregular but remains replay-safe
	# and independent of simulation/display rate.
	var roughness: float = sin(state.position.x*2.71+state.position.y*1.83)
	roughness += sin(state.position.x*5.17-state.position.y*3.29+0.73)*0.45
	return roughness/1.45 * SOIL_ROUGH_YAW_ACCELERATION * contact_count*0.25 * smoothstep(3.0,18.0,speed)


# Rear braking acts through axle contact velocities, not a desired slip angle.
func _handbrake_axles(longitudinal: float, lateral: float, steering: float, surface_grip: float, pressure: float) -> Vector3:
	return RALLY_HANDBRAKE.forces(config, longitudinal, lateral, state.yaw_rate, steering, surface_grip, pressure, state.handbrake_pressure, STEP)
