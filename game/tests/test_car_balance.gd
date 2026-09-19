extends SceneTree
## Controlled skidpad: fastest clean lap found by a common geometric controller.
## This measures circuit suitability; it is not an optimal driver or player PB.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var best: Dictionary = {}
	for id: String in VehicleCatalog.IDS:
		var config: HandlingConfig = VehicleCatalog.config(id)
		var fastest: float = INF
		var chosen_speed: int = 0
		for requested: int in range(6,39):
			var time: float = _circle(config,requested)
			if time < fastest:
				fastest = time
				chosen_speed = requested
		best[id] = fastest
		print("CAR_SKIDPAD ",id," clean_18m_radius_lap=",fastest," target_mps=",chosen_speed)
	var ok: bool = best.formula < best.classic and best.formula < best.pickup and best.formula < best.compact
	print("CAR_BALANCE_TESTS: 1 checks, ",0 if ok else 1," failures")
	quit(0 if ok else 1)

func _circle(config: HandlingConfig, speed: float) -> float:
	var radius: float = 18.0
	var sim := VehicleSimulation.new(config)
	sim.reset(Vector2(0,radius),PI*0.5)
	sim.state.velocity = Vector2(speed,0)
	var progress: float = 0.0
	var previous: float = 0.0
	var lap_start: int = -1
	for tick: int in range(2400):
		var normal: Vector2 = sim.state.position.normalized()
		var tangent := Vector2(normal.y,-normal.x)
		var offset: float = sim.state.position.length()-radius
		var desired: Vector2 = tangent - normal*offset*0.35
		var error: float = angle_difference(sim.state.heading,atan2(desired.x,desired.y))
		var feed: float = atan(config.wheelbase/radius)/(config.steering_angle*(1.0-config.high_speed_steering_reduction*clampf(sim.state.velocity.length()/24.0,0,1))) * config.rear_grip/config.front_grip
		var steer: float = feed + error*1.5
		var actual: float = sim.state.velocity.length()
		var throttle: float = clampf(0.40+(speed-actual)*0.40,0,1)
		var brake: float = clampf((actual-speed-0.5)*0.3,0,1)
		sim.step(DriveFrame.sample(steer,throttle,brake))
		if lap_start >= 0 and (absf(offset) > 2.0 or absf(sim.state.slip_angle()) > 0.35): return INF
		if absf(offset) > 8.0: return INF
		var angle: float = atan2(sim.state.position.x,sim.state.position.y)
		progress += angle_difference(previous,angle)
		previous = angle
		if progress >= TAU and lap_start < 0: lap_start = tick
		if progress >= TAU*2.0: return (tick-lap_start)/120.0
	return INF
