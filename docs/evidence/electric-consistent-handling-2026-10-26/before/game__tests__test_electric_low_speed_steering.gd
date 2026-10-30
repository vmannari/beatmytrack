extends "res://tests/test_electric_power.gd"
const LOW_OUTPUT: String = "res://../docs/evidence/electric-190-2026-10-25"
const LOW_BASELINE: String = "res://../docs/evidence/electric-launch-drift-2026-10-25"
const BASELINE: String = "res://../docs/evidence/electric-low-speed-steering-2026-10-25"
var previous_simulation: GDScript

func onset(config: HandlingConfig, speed: float, steering: float, previous: bool = false) -> Dictionary:
	var sim: RefCounted = previous_simulation.new(config) if previous else VehicleSimulation.new(config)
	sim.state.velocity = Vector2(0,speed)
	var driver := DriverInput.new()
	driver.single_pedal = true
	driver.reverse_selected = speed < 0
	driver.set_touch(0,&"steer_right" if steering>0 else &"steer_left",absf(steering))
	driver.set_touch(1,&"accelerate",0.25)
	for tick: int in range(24): sim.step(driver.sample())
	driver.clear()
	var course: float = atan2(sim.state.velocity.x,sim.state.velocity.y*(1 if speed>0 else -1))
	return {"heading":absf(sim.state.heading),"course":absf(course),"speed":sim.state.velocity.length(),"yaw":sim.state.yaw_rate}

func run() -> void:
	previous_simulation = GDScript.new()
	previous_simulation.source_code = FileAccess.get_file_as_string(BASELINE+"/before/game__vehicle__vehicle_simulation.gd.txt").replace("class_name VehicleSimulation","").trim_prefix("\ufeff")
	check(previous_simulation.reload() == OK,"actual accepted physics0.69 compiles for before/after")
	var old: HandlingConfig = load(BASELINE+"/before/electric-6.tres") as HandlingConfig
	var current: HandlingConfig = VehicleCatalog.config("electric")
	old.maximum_speed = current.maximum_speed
	check(old.version == "electric-6" and current.version == "electric-11" and VehicleSimulation.PHYSICS_VERSION == "arcade-planar-0.72","low-speed correction has new competitive identity")
	var preceding: HandlingConfig = load(LOW_BASELINE+"/before/game__resources__cars__electric.tres") as HandlingConfig
	preceding.maximum_speed = current.maximum_speed
	metrics.onset = {}
	for speed: float in [1.0,3.0,5.0,7.0,-1.0,-3.0,-5.0,-7.0]:
		for steering: float in [0.35,0.65,1.0]:
			var before: Dictionary = onset(old,speed,steering,true)
			var after: Dictionary = onset(current,speed,steering)
			var mirrored: Dictionary = onset(current,speed,-steering)
			var prior: Dictionary = onset(preceding,speed,steering)
			check(after.course/prior.course < (0.70 if absf(speed)<=3 else 0.90 if absf(speed)<=5 else 0.99),"further reduction versus rejected electric-8: "+str(speed)+"/"+str(steering))
			var ratio: float = after.course/before.course
			metrics.onset[str(speed)+"/"+str(steering)] = {"before":before,"after":after,"course_ratio":ratio,"preceding":prior,"preceding_ratio":after.course/prior.course}
			check(ratio < (0.48 if absf(speed)<=3 else 0.80 if absf(speed)<=5 else 0.99) and ratio > 0.05,"actual touch steering is calmer but remains responsive: "+str(speed)+"/"+str(steering))
			check(is_equal_approx(mirrored.course,after.course) and is_equal_approx(mirrored.speed,after.speed),"low-speed left/right response is symmetric: "+str(speed)+"/"+str(steering))
	# Exact high-speed comparisons include sideways states, not just straight travel.
	var high_exact: bool = true
	var high_cases: int = 0
	for speed: float in [60.0/3.6,20.0,24.0,36.0,44.0]:
		for slip: float in [-0.8,0.0,0.8]:
			for steer: float in [-1.0,0.0,1.0]:
				for gas: float in [0.0,0.25,1.0]:
					var before: RefCounted = previous_simulation.new(old)
					var after := VehicleSimulation.new(current)
					before.state.velocity = Vector2(sin(slip),cos(slip))*speed
					after.state.velocity = before.state.velocity
					var frame := DriveFrame.sample(steer,gas,0)
					before.step(frame)
					after.step(frame)
					high_exact = high_exact and before.state.snapshot() == after.state.snapshot()
					high_cases += 1
	check(high_exact,"all high-speed single ticks remain exact, including broadside and lift/brake")
	metrics.high_speed_exact_cases = high_cases
	for speed: float in [20.0,24.0,36.0,44.0]:
		var before: RefCounted = previous_simulation.new(old)
		var after := VehicleSimulation.new(current)
		before.state.velocity = Vector2(0,speed)
		after.state.velocity = before.state.velocity
		var exact: bool = true
		for tick: int in range(120):
			var frame := DriveFrame.sample(sin(tick*0.05)*0.65,0.65,0)
			before.step(frame)
			after.step(frame)
			exact = exact and before.state.snapshot() == after.state.snapshot()
		check(exact,"accepted high-speed cornering remains tick-exact for a full second: "+str(speed))
	# Straight launch and released-pedal stopping are unchanged through the fade.
	for pedal: float in [0.0,1.0]:
		var before: RefCounted = previous_simulation.new(old)
		var after := VehicleSimulation.new(current)
		if pedal == 0:
			before.state.velocity = Vector2(0,20)
			after.state.velocity = before.state.velocity
		var exact: bool = true
		for tick: int in range(1200):
			before.step(DriveFrame.sample(0,pedal,0))
			after.step(DriveFrame.sample(0,pedal,0))
			exact = exact and before.state.snapshot() == after.state.snapshot()
		check(exact,"straight launch or strong braking remains exact, pedal="+str(pedal))
	for id: String in VehicleCatalog.IDS:
		if id == "electric": continue
		var config: HandlingConfig = VehicleCatalog.config(id)
		var before: RefCounted = previous_simulation.new(config)
		var after := VehicleSimulation.new(config)
		var exact: bool = true
		for tick: int in range(2400):
			var frame := DriveFrame.sample(sin(tick*0.02),1 if tick%240<150 else 0,0.7 if tick%240>200 else 0,1 if tick%120<10 else 0)
			before.step(frame)
			after.step(frame)
			exact = exact and before.state.snapshot() == after.state.snapshot()
		check(exact,"other car retains exact accepted physics: "+id)
	var report := FileAccess.open(LOW_OUTPUT+"/low-speed.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	report.close()
	print("ELECTRIC_LOW_SPEED_METRICS ",JSON.stringify(metrics))
	print("ELECTRIC_LOW_SPEED: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
