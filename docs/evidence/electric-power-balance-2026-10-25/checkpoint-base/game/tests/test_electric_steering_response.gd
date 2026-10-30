extends "res://tests/test_electric_turning.gd"
const RESPONSE_OUTPUT: String = "res://../docs/evidence/electric-steering-response-2026-10-25"

func early(config: HandlingConfig, speed: float, gas: float, direction: float) -> Dictionary:
	var sim := VehicleSimulation.new(config)
	sim.state.velocity = Vector2(0,speed)
	var input := DriverInput.new()
	input.single_pedal = true
	input.set_touch(0,&"steer_right" if direction>0 else &"steer_left")
	input.set_touch(1,&"accelerate",gas)
	var reached: float = 99
	var course: float = 0
	for tick: int in range(60):
		sim.step(input.sample())
		if reached == 99 and absf(sim.state.steering) >= 0.95: reached = (tick+1)/120.0
		if tick == 11: course = rad_to_deg(atan2(sim.state.velocity.x,sim.state.velocity.y))*direction
	input.clear()
	return {"steering_95_seconds":reached,"course_100ms":course}

func correction(config: HandlingConfig) -> Dictionary:
	var sim := VehicleSimulation.new(config)
	sim.state.velocity = Vector2(0,24)
	for tick: int in range(60): sim.step(DriveFrame.sample(0.65,0.45,0))
	var yaw_seconds: float = 99
	var course_seconds: float = 99
	var previous: float = atan2(sim.state.velocity.x,sim.state.velocity.y)
	for tick: int in range(120):
		sim.step(DriveFrame.sample(-0.65,0.45,0))
		var angle: float = atan2(sim.state.velocity.x,sim.state.velocity.y)
		if sim.state.yaw_rate < 0 and yaw_seconds == 99: yaw_seconds = (tick+1)/120.0
		if wrapf(angle-previous,-PI,PI) < -0.00001 and course_seconds == 99: course_seconds = (tick+1)/120.0
		previous = angle
	return {"yaw_seconds":yaw_seconds,"course_seconds":course_seconds}

func run() -> void:
	output = RESPONSE_OUTPUT
	var old: HandlingConfig = load(RESPONSE_OUTPUT+"/before/electric-3.tres") as HandlingConfig
	var current: HandlingConfig = VehicleCatalog.config("electric")
	check(old.version == "electric-3" and current.version == "electric-4","actual preceding accepted tune versus the faster version")
	for speed: float in [12.0,24.0,36.0,48.0]:
		for gas: float in [0.45,0.65,1.0]:
			var label: String = str(speed)+"/"+str(gas)
			var before: Dictionary = turn(old,speed,gas)
			var after: Dictionary = turn(current,speed,gas)
			var early_before: Dictionary = early(old,speed,gas,1)
			var early_after: Dictionary = early(current,speed,gas,1)
			var mirrored: Dictionary = early(current,speed,gas,-1)
			var matched_speed: float = speed_after(old,speed,gas,float(after.get("seconds",5)))
			metrics[label] = {"before":before,"after":after,"early_before":early_before,"early_after":early_after,"old_speed_at_new_finish":matched_speed}
			check(before.complete and after.complete,"both actual velocity paths complete a quarter turn: "+label)
			check(after.seconds <= before.seconds*0.88 and after.radius <= before.radius*0.88,"at least twelve percent faster and tighter than the preceding accepted tune: "+label)
			check(early_after.course_100ms > early_before.course_100ms*2,"actual travel direction responds more than twice as far in the first 100ms: "+label)
			check(early_after.steering_95_seconds <= early_before.steering_95_seconds*0.60,"saved touch actions reach steering lock at least forty percent sooner: "+label)
			check(is_equal_approx(mirrored.course_100ms,early_after.course_100ms),"touch steering onset is symmetric: "+label)
			check(after.speed >= matched_speed*0.95 and after.speed <= current.maximum_speed,"faster path retains speed at the same elapsed tick: "+label)
			check(after.peak_slip < (20 if gas<0.5 else 45),"calm rear breakaway remains bounded: "+label)
	var before_correction: Dictionary = correction(old)
	var after_correction: Dictionary = correction(current)
	metrics.correction = {"before":before_correction,"after":after_correction}
	check(after_correction.yaw_seconds < before_correction.yaw_seconds*0.8 and after_correction.course_seconds < before_correction.course_seconds*0.8,"opposite steering catches chassis and travel direction at least twenty percent sooner")
	print("ELECTRIC_RESPONSE_METRICS ",JSON.stringify(metrics))
	var report := FileAccess.open(RESPONSE_OUTPUT+"/response.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	report.close()
	print("ELECTRIC_RESPONSE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
