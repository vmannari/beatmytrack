class_name RouteDriver
extends RefCounted
## Conservative diagnostic driver. Generated route guides ordinary quantized input.
var speed_scale: float = 1.0 # Opt-in device stress; ordinary diagnostics retain 1.0.


func sample(state: VehicleState, track: NativeTrack, config: HandlingConfig) -> DriveFrame:
	var index: int = track.nearest_route(state.position, state.route_index)
	var target: Vector2 = track.route[(index + 3) % track.route.size()]
	var offset: Vector2 = target - state.position
	var avoidance: Vector2 = track.collision_normal(state.position + state.velocity * 0.35, config.collision_radius + 0.3, state.track_elevated)
	if avoidance != Vector2.ZERO:
		offset += avoidance * 3.0
	var desired: float = atan2(offset.x, offset.y)
	var error: float = wrapf(desired - state.heading, -PI, PI)
	var speed: float = state.velocity.length()
	var steer: float = clampf(error * 2.3 - state.yaw_rate * 0.15, -1.0, 1.0)
	var future: Vector2 = track.route[(index + 12) % track.route.size()] - target
	var corner: float = absf(wrapf(atan2(future.x, future.y) - desired, -PI, PI))
	var target_speed: float = clampf(12.0 - corner * 10.0 - absf(error) * 8.0, 3.0, 12.0)
	target_speed *= clampf(speed_scale,1.0,3.0)
	if avoidance != Vector2.ZERO:
		target_speed = minf(target_speed, 4.0)
	var result := DriveFrame.new()
	result.steer = clampi(roundi(steer * 127), -127, 127)
	result.throttle = 166 if speed < target_speed else 0
	result.brake = 128 if speed > target_speed + 1.0 else 0
	return result
