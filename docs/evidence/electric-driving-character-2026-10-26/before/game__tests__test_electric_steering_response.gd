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
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	var old: HandlingConfig = load(RESPONSE_OUTPUT+"/before/electric-3.tres") as HandlingConfig
	var current: HandlingConfig = VehicleCatalog.config("electric")
	var task_start: HandlingConfig = load("res://../docs/evidence/electric-tighter-held-steering-2026-10-26/before/game__resources__cars__electric.tres") as HandlingConfig
	check(old.version == "electric-3" and current.version == "electric-16","original slow steering versus current balanced electric tune")
	old = steering_reference(old,current)
	for speed: float in [20.0,24.0,36.0,current.maximum_speed]:
		for gas: float in [0.45,0.65,1.0]:
			var label: String = str(speed)+"/"+str(gas)
			var before: Dictionary = turn(old,speed,gas)
			var after: Dictionary = turn(current,speed,gas)
			var prior: Dictionary = turn(task_start,speed,gas)
			var early_before: Dictionary = early(old,speed,gas,1)
			var early_after: Dictionary = early(current,speed,gas,1)
			var mirrored: Dictionary = early(current,speed,gas,-1)
			var matched_speed: float = speed_after(old,speed,gas,float(after.get("seconds",5)))
			metrics[label] = {"before":before,"after":after,"task_start":prior,"early_before":early_before,"early_after":early_after,"old_speed_at_new_finish":matched_speed}
			check(before.complete and after.complete,"both actual velocity paths complete a quarter turn: "+label)
			# The owner rejects the preceding wide-circle target. Measure the
			# requested gain against that actual tune; keep the onset/slip bounds.
			check(prior.complete and float(after.get("seconds",99)) <= float(prior.get("seconds",0)) and after.radius <= prior.radius*0.9,"turn retains prompt completion on a tighter path than rejected electric-14: "+label)
			check(early_after.course_100ms < early_before.course_100ms*0.75,"actual travel direction stays at least 25 percent less abrupt than the original in the first 100ms: "+label)
			check(early_after.steering_95_seconds >= early_before.steering_95_seconds*1.5 and early_after.steering_95_seconds<=0.20,"steering builds more gradually while reaching held lock within 200 ms: "+label)
			check(is_equal_approx(mirrored.course_100ms,early_after.course_100ms),"touch steering onset is symmetric: "+label)
			check(after.speed >= matched_speed*0.95 and after.speed <= current.maximum_speed+0.00001,"faster path retains speed at the same elapsed tick: "+label)
			check(after.peak_slip < (20 if gas<0.5 else 45),"calm rear breakaway remains bounded: "+label)
	var before_correction: Dictionary = correction(old)
	var after_correction: Dictionary = correction(current)
	metrics.correction = {"before":before_correction,"after":after_correction}
	check(after_correction.yaw_seconds<0.35 and after_correction.course_seconds<0.35,"opposite steering catches chassis and travel direction within 350 ms")
	print("ELECTRIC_RESPONSE_METRICS ",JSON.stringify(metrics))
	var report := FileAccess.open(output+"/response.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	report.close()
	print("ELECTRIC_RESPONSE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
