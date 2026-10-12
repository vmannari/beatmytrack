class_name TrajectoryHandbrake
extends RefCounted
## Small action refinement, using the exact existing car/road mechanics.
## All predicted states are private copies; only ordinary inputs are returned.
const STEPS: int = 36
const HOLD_TICKS: int = 12

static func refine(state: VehicleState, track: NativeTrack, trajectory: RacingTrajectory, progress: float, config: HandlingConfig, frame: DriveFrame, pace: float) -> DriveFrame:
	if config.vehicle_id != "compact" or state.velocity.length() < 9.0: return frame
	var future: Dictionary = trajectory.at(progress+state.velocity.length()*0.35)
	if absf(future.curvature) < 0.075 and state.handbrake_pressure < 0.01: return frame
	var best: DriveFrame = frame
	var score: float = -INF
	for pressure: int in [0,112,255]:
		var candidate := DriveFrame.new()
		candidate.steer = frame.steer; candidate.throttle = frame.throttle; candidate.brake = frame.brake
		candidate.handbrake = pressure
		if pressure > 0: candidate.throttle = 0
		var simulation := VehicleSimulation.new(config)
		for property: Dictionary in state.get_property_list():
			if int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE:
				var value: Variant = state.get(property.name)
				if value is Array: value = value.duplicate(true)
				simulation.state.set(property.name,value)
		var predicted: DriveFrame = candidate
		for tick: int in range(STEPS):
			if tick >= HOLD_TICKS and tick%HOLD_TICKS == 0:
				var s: float = trajectory.project(simulation.state.position,track.route_progress(simulation.state.position,simulation.state.route_index))
				var ref: Dictionary = trajectory.at(s)
				var speed: float = simulation.state.velocity.length()
				var aim: Vector2 = trajectory.at(s+4.0+speed*0.25).point-simulation.state.position
				var direction: Vector2 = simulation.state.velocity.normalized() if speed > 2.0 else simulation.state.forward()
				var right := Vector2(direction.y,-direction.x)
				var k: float = 2.0*aim.dot(right)/maxf(aim.length_squared(),1.0)
				var forward_speed: float = simulation.state.velocity.dot(simulation.state.forward())
				var angle: float = config.steering_angle*(1.0-config.high_speed_steering_reduction*clampf(absf(forward_speed)/24.0,0.0,1.0))
				predicted = DriveFrame.new()
				predicted.steer = clampi(roundi(atan(config.wheelbase*k*speed/maxf(absf(forward_speed),maxf(1.0,speed*0.5)))/angle*127.0),-127,127)
				predicted.throttle = 255 if speed < minf(config.maximum_speed,float(ref.speed)*pace) else 0
				predicted.brake = 128 if speed > float(ref.speed)*pace+0.8 else 0
			simulation.step(predicted,track)
		var s: float = trajectory.project(simulation.state.position,track.route_progress(simulation.state.position,simulation.state.route_index))
		var ref: Dictionary = trajectory.at(s)
		var normal := Vector2(cos(ref.heading),-sin(ref.heading))
		var error: float = (simulation.state.position-ref.point).dot(normal)
		var outside: float = error-clampf(error,ref.lower,ref.upper)
		var direction: float = atan2(simulation.state.velocity.x,simulation.state.velocity.y)
		var heading_error: float = wrapf(direction-ref.heading,-PI,PI)
		var gain: float = wrapf(s-progress,-trajectory.length*0.5,trajectory.length*0.5)
		var value: float = gain+simulation.state.velocity.length()*0.08-0.8*error*error-4.0*heading_error*heading_error-50.0*outside*outside-0.4*pressure/255.0
		if simulation.state.collision_count > state.collision_count or simulation.state.roll_ticks > 0: value = -INF
		if value > score: score = value; best = candidate
	return best
