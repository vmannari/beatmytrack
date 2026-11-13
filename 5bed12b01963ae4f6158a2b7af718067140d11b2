extends "res://tests/test_electric_power.gd"

const RADIUS_OUTPUT: String = "res://../docs/evidence/electric-turn-radius-2026-10-25"
var prior_simulation: GDScript

func held_circle(config: HandlingConfig, speed: float, steer: float, previous: bool = false) -> Dictionary:
	var sim: RefCounted = prior_simulation.new(config) if previous else VehicleSimulation.new(config)
	sim.state.velocity = Vector2(0,speed)
	sim.state.steering = steer
	var speed_integral: float = 0.0
	var distance: float = 0.0
	var angle: float = 0.0
	var minimum_speed: float = INF
	var maximum_speed: float = 0.0
	var peak_slip: float = 0.0
	var frames: Array = []
	var direction: float = signf(speed)
	var target_angle: float = TAU if absf(steer) == 1.0 else PI*0.5
	var last_course: float = atan2(sim.state.velocity.x,sim.state.velocity.y)
	for tick: int in range(120*150):
		var travel_speed: float = sim.state.velocity.length()
		var drag_acceleration: float = (config.rolling_resistance+config.drag*travel_speed*travel_speed)/config.mass
		var speed_error: float = absf(speed)-travel_speed
		speed_integral = clampf(speed_integral+speed_error*VehicleSimulation.STEP*4.0,-5.0,8.0)
		var acceleration: float = speed_error*5.0+speed_integral+drag_acceleration
		var power: float = config.engine_force/config.mass*(1.0-0.45*travel_speed/(config.reverse_speed if speed<0 else config.maximum_speed))
		var pedal: float = config.accelerator_for_acceleration(acceleration,power)
		var frame := DriveFrame.sample(steer,pedal,1.0 if speed<0 else 0.0)
		frames.append(frame.packed())
		var before: Vector2 = sim.state.position
		sim.step(frame)
		var course: float = atan2(sim.state.velocity.x,sim.state.velocity.y)
		if tick >= 360:
			distance += before.distance_to(sim.state.position)
			angle += wrapf(course-last_course,-PI,PI)*signf(steer)*direction
			minimum_speed = minf(minimum_speed,sim.state.velocity.length())
			maximum_speed = maxf(maximum_speed,sim.state.velocity.length())
			peak_slip = maxf(peak_slip,rad_to_deg(absf(sim.state.slip_angle())))
		last_course = course
		if angle >= target_angle: break
	var replay: RefCounted = prior_simulation.new(config) if previous else VehicleSimulation.new(config)
	replay.state.velocity = Vector2(0,speed)
	replay.state.steering = steer
	for packed: Array in frames:
		replay.step(DriveFrame.sample(float(packed[0])/127.0,float(packed[1])/255.0,float(packed[2])/255.0))
	return {"radius":distance/maxf(angle,0.001),"angle":angle,"target_angle":target_angle,"minimum_speed":minimum_speed,"maximum_speed":maximum_speed,"peak_slip":peak_slip,"replay_exact":sim.state.snapshot()==replay.state.snapshot(),"ticks":frames.size()}

func run() -> void:
	prior_simulation = GDScript.new()
	prior_simulation.source_code = FileAccess.get_file_as_string(RADIUS_OUTPUT+"/before/game__vehicle__vehicle_simulation.gd").replace("class_name VehicleSimulation","").trim_prefix("\ufeff")
	check(prior_simulation.reload() == OK,"actual rejected electric-9 simulation compiles")
	var old: HandlingConfig = load(RADIUS_OUTPUT+"/before/game__resources__cars__electric.tres") as HandlingConfig
	var current: HandlingConfig = VehicleCatalog.config("electric")
	metrics.circles = {}
	for kph: float in [5.0,10.0,15.0,20.0,25.0,30.0,35.0,39.9,40.0]:
		var speed: float = kph/3.6
		var before: Dictionary = held_circle(old,speed,1.0,true)
		var after: Dictionary = held_circle(current,speed,1.0)
		var mirror: Dictionary = held_circle(current,speed,-1.0)
		var radius_floor: float = maxf(6.0,speed*speed/9.0)
		metrics.circles[str(kph)] = {"before":before,"after":after,"radius_floor":radius_floor}
		check(after.angle >= TAU,"held steering completes a full circle: "+str(kph))
		check(after.minimum_speed > speed*0.98 and after.maximum_speed < speed*1.02,"ordinary pedal feedback maintains measured speed: "+str(kph))
		check(after.radius >= radius_floor*0.98,"sustained path meets radius and cornering-acceleration bounds: "+str(kph))
		if kph>=20: check(after.radius >= before.radius*1.25,"held turn is materially wider than rejected tune: "+str(kph))
		check(is_equal_approx(after.radius,mirror.radius),"left/right held circles are symmetric: "+str(kph))
		check(after.replay_exact,"actual held-circle input replays exactly: "+str(kph))
	for kph: float in [20.0,30.0,40.0]:
		var full: Dictionary = metrics.circles[str(kph)].after
		for steer: float in [0.35,0.65]:
			var partial: Dictionary = held_circle(current,kph/3.6,steer)
			check(partial.angle >= partial.target_angle and partial.radius > full.radius*1.2,"partial steering retains a wider path: "+str(kph)+"/"+str(steer))
	for kph: float in [5.0,10.0,20.0]:
		var reverse: Dictionary = held_circle(current,-kph/3.6,1.0)
		check(reverse.angle >= TAU and reverse.radius >= 6.0*0.98 and reverse.replay_exact,"reverse radius is bounded and replayable: "+str(kph))
	# Exact accepted high-speed arithmetic, including sideways states and throttle/lift.
	var high_exact: bool = true
	for speed: float in [60.0/3.6,20.0,24.0,36.0,44.0]:
		for slip: float in [-0.8,0.0,0.8]:
			for steer: float in [-1.0,0.0,1.0]:
				for gas: float in [0.0,0.25,1.0]:
					var before: RefCounted = prior_simulation.new(old)
					var after := VehicleSimulation.new(current)
					before.state.velocity = Vector2(sin(slip),cos(slip))*speed
					after.state.velocity = before.state.velocity
					before.step(DriveFrame.sample(steer,gas,0))
					after.step(DriveFrame.sample(steer,gas,0))
					high_exact = high_exact and before.state.snapshot()==after.state.snapshot()
	check(high_exact,"135 states at or above 60 km/h retain accepted arithmetic exactly")
	for boundary: float in [40.0/3.6,16.66]:
		var below := VehicleSimulation.new(current)
		var above := VehicleSimulation.new(current)
		below.state.velocity = Vector2(0,boundary-0.001)
		above.state.velocity = Vector2(0,boundary+0.001)
		below.state.steering = 1.0
		above.state.steering = 1.0
		below.step(DriveFrame.sample(1,0.25,0))
		above.step(DriveFrame.sample(1,0.25,0))
		check(absf(below.state.yaw_rate-above.state.yaw_rate) < absf(below.state.yaw_rate)*0.01,"no steering jump across curvature fade boundary: "+str(boundary))
	var file := FileAccess.open(RADIUS_OUTPUT+"/circles.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	file.close()
	print("ELECTRIC_TURN_RADIUS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
