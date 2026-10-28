class_name RouteDriver
extends RefCounted
## Conservative diagnostic driver. Generated route guides ordinary quantized input.
var speed_scale: float = 1.0 # Opt-in device stress; ordinary diagnostics retain 1.0.


func sample(state: VehicleState, track: NativeTrack, config: HandlingConfig) -> DriveFrame:
	var index: int = track.nearest_route(state.position, state.route_index)
	var speed: float = state.velocity.length()
	var lookahead: int = 3
	if config.continuous_turn_radius:
		# A finite steering ramp needs an earlier target, not the old instant-lock
		# aim point. This affects diagnostic input planning, never car physics.
		lookahead = clampi(ceili(6.0+speed/maxf(config.steering_rate,0.1)*1.5),6,16)
	var target: Vector2 = track.route[(index + lookahead) % track.route.size()]
	var offset: Vector2 = target - state.position
	var avoidance: Vector2 = track.collision_normal(state.position + state.velocity * 0.35, config.collision_radius + 0.3, state.track_elevated)
	if avoidance != Vector2.ZERO:
		offset += avoidance * 3.0
	var desired: float = atan2(offset.x, offset.y)
	var error: float = wrapf(desired - state.heading, -PI, PI)
	var steer: float = clampf(error * 2.3 - state.yaw_rate * 0.15, -1.0, 1.0)
	if config.continuous_turn_radius:
		var wheel_angle: float = config.steering_angle*(1.0-config.high_speed_steering_reduction*clampf(speed/24.0,0.0,1.0))
		var radius: float = maxf(config.low_speed_turn_radius+speed*speed/config.low_speed_turn_acceleration,config.wheelbase/tan(wheel_angle)*config.rear_grip/config.front_grip)
		steer = clampf(2.0*radius*sin(error)/maxf(offset.length(),1.0)-state.yaw_rate*0.15,-1.0,1.0)
	var future: Vector2 = track.route[(index + lookahead + 9) % track.route.size()] - target
	var corner: float = absf(wrapf(atan2(future.x, future.y) - desired, -PI, PI))
	var target_speed: float = clampf(12.0 - corner * 10.0 - absf(error) * 8.0, 3.0, 12.0)
	target_speed *= clampf(speed_scale,1.0,3.0)
	if avoidance != Vector2.ZERO:
		target_speed = minf(target_speed, 4.0)
	var result := DriveFrame.new()
	result.steer = clampi(roundi(steer * 127), -127, 127)
	result.throttle = 166 if speed < target_speed else 0
	result.brake = 128 if speed > target_speed + 1.0 else 0
	if config.single_pedal: result.brake = 0 # Lift supplies all deceleration; keep Drive selected.
	return result
