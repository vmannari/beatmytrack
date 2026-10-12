extends RefCounted
## Export-excluded exact .50 contact methods for the retained historical replay.
## Copied from the task-start canonical sources archived in backend/tests/fixtures/physics_050.
const VERSION: String = "arcade-planar-0.50"

class Track extends NativeTrack:
	func resolve(state: VehicleState, from: Vector2, config: HandlingConfig) -> void:
		state.route_index = nearest_route(from, state.route_index)
		state.track_elevated = collision_elevated_at(from, state.route_index, config.collision_radius,1 if state.track_elevated else 0)
		# Circle against native occupied cells, substeps shorter than half a cell.
		# Stable row order and bounded path sampling prevent thin-wall tunnelling.
		var movement: Vector2 = state.position - from
		var steps: int = maxi(1, ceili(movement.length() / (cell_size * 0.45)))
		var accepted: Vector2 = from
		var contact: Vector3 = _contact(from, config.collision_radius, state.track_elevated)
		for step_index: int in range(1, steps + 1):
			var point: Vector2 = from + movement * (float(step_index) / steps)
			var next_route: int = nearest_route(point, state.route_index)
			var next_elevated: bool = collision_elevated_at(point, next_route, config.collision_radius,1 if state.track_elevated else 0)
			var next_contact: Vector3 = _contact(point, config.collision_radius, next_elevated)
			if next_contact.z > 0.0:
				# A pre-existing overlap must not freeze outward movement. Require
				# non-increasing penetration against the same wall at each step.
				# New or deeper contacts still stop at the last accepted position.
				# Compare penetration on the candidate layer. An existing rail
				# overlap can straddle a layer boundary during outward recovery.
				var previous_contact: Vector3 = contact if next_elevated == state.track_elevated else _contact(accepted, config.collision_radius, next_elevated)
				var escaping: bool = previous_contact.z > 0.0
				var blocking_normal := Vector2(next_contact.x, next_contact.y)
				if escaping:
					var blocker: Vector2 = _escape_blocker(accepted, point, config.collision_radius, next_elevated)
					if blocker != Vector2.ZERO:
						escaping = false
						blocking_normal = blocker
				if not escaping:
					state.position = accepted
					_bounce(state, blocking_normal, config)
					# Consume the remaining tangential displacement instead of discarding
					# the whole step. Sweep it too, so sliding cannot tunnel past corners.
					var remaining: Vector2 = from + movement - accepted
					var slide: Vector2 = remaining - blocking_normal * remaining.dot(blocking_normal)
					var slide_steps: int = maxi(1, ceili(slide.length() / (cell_size * 0.45)))
					var slide_from: Vector2 = accepted
					for i: int in range(1, slide_steps + 1):
						var candidate: Vector2 = slide_from + slide * (float(i) / slide_steps)
						var candidate_route: int = nearest_route(candidate, state.route_index)
						var candidate_layer: bool = collision_elevated_at(candidate, candidate_route, config.collision_radius,1 if state.track_elevated else 0)
						if _contact(candidate, config.collision_radius, candidate_layer).z > 0.0:
							# Shallow flat-wall overlap can rub along its face. Do not
							# project an embedded corner contact around a rail tip.
							var flat_face: bool = absf(blocking_normal.x) > 0.99999 or absf(blocking_normal.y) > 0.99999
							if not flat_face or _contact(state.position, config.collision_radius, candidate_layer).z <= 0.0 or _escape_blocker(state.position, candidate, config.collision_radius, candidate_layer) != Vector2.ZERO:
								# A second obstacle can block the tangent. Do not bank
								# the rejected speed and release it after alignment.
								var tangent: Vector2 = slide.normalized()
								var completed: float = clampf(state.position.distance_to(slide_from) / maxf(slide.length(), 0.000001), 0.0, 1.0)
								state.velocity -= tangent * state.velocity.dot(tangent) * (1.0 - completed)
								var probe: Vector2 = state.position + state.velocity * VehicleSimulation.STEP
								var probe_layer: bool = collision_elevated_at(probe, nearest_route(probe, state.route_index), config.collision_radius,1 if state.track_elevated else 0)
								if _contact(probe, config.collision_radius, probe_layer).z > 0.0 and (_contact(state.position, config.collision_radius, probe_layer).z <= 0.0 or _escape_blocker(state.position, probe, config.collision_radius, probe_layer) != Vector2.ZERO):
									state.velocity = Vector2.ZERO
								break
						state.position = candidate
						state.route_index = candidate_route
						state.track_elevated = candidate_layer
					return
			accepted = point
			contact = next_contact
			state.route_index = next_route
			state.track_elevated = next_elevated
		state.position = accepted

	func _bounce(state: VehicleState, normal: Vector2, config: HandlingConfig) -> void:
		var inward_speed: float = state.velocity.dot(normal)
		if inward_speed >= 0.0:
			return
		var energy: float = config.mass * state.velocity.length_squared() + config.rotational_inertia * state.yaw_rate * state.yaw_rate
		# The circle collider has no contact lever arm. Approximate front/rear
		# leverage from the body axes: oblique hits turn it, centred hits do not.
		var turn: float = -normal.dot(state.forward()) * normal.dot(state.right()) * -inward_speed * config.collision_turn_strength
		var tangent: Vector2 = state.velocity - normal * inward_speed
		# Small inward speeds are sustained rubbing, not a fresh crash. Preserve
		# tangential travel and gently steer the chassis parallel to the barrier.
		var impact: float = smoothstep(0.0, config.wall_slide_speed, -inward_speed)
		state.velocity = tangent * sqrt(1.0 - config.collision_energy_loss * impact) - normal * inward_speed * config.restitution * impact
		var alignment_yaw: float = -normal.dot(state.forward()) * normal.dot(state.right()) * config.wall_alignment_rate
		var contact_yaw: float = lerpf(state.yaw_rate, alignment_yaw, 0.25)
		var rotation_budget: float = maxf(0.0, energy - config.mass * state.velocity.length_squared())
		var yaw_limit: float = minf(config.maximum_yaw_rate, sqrt(rotation_budget / config.rotational_inertia))
		state.yaw_rate = clampf(lerpf(contact_yaw, state.yaw_rate * (1.0 - config.collision_energy_loss) + turn, impact), -yaw_limit, yaw_limit)
		state.collision_count += 1

class Simulation extends VehicleSimulation:
	func step(frame: DriveFrame, ground: PlaygroundData = null) -> void:
		LaunchStart.advance(state, frame)
		# Brake pressure is only input driven; no automatic drift latch.
		var requested_handbrake: float = frame.handbrake / 255.0
		state.handbrake_pressure = move_toward(state.handbrake_pressure, requested_handbrake,
			(30.0 if requested_handbrake > state.handbrake_pressure else 3.0) * STEP)
		var old_position: Vector2 = state.position
		var old_heading: float = state.heading
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
		var tire_grip: float = 1.0 - maxf(state.tire_dirt * config.dirty_tire_grip_loss, maxf(state.tire_oil * 0.65, state.tire_water * 0.18))
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
		state.yaw_rate = lerpf(normal_yaw, state.yaw_rate + axle.z * STEP, handbrake)
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
		var drive_tire_grip: float = 1.0 - maxf(state.tire_dirt * config.dirty_tire_grip_loss * smoothstep(3.0, 12.0, speed), maxf(state.tire_oil * 0.65, state.tire_water * 0.18))
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
		state.tick += 1

static func copy_track(source: NativeTrack) -> NativeTrack:
	var result := Track.new()
	RewindHistory.restore(result,RewindHistory.properties(source))
	return result
