extends "res://tests/probe_electric_slide_access.gd"

const TIGHT_OUTPUT = "res://../docs/evidence/electric-turning-tighter-2026-10-28"

func held_circle(config: HandlingConfig, speed: float, steer: float) -> Dictionary:
	var sim: RefCounted = VehicleSimulation.new(config)
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
	var replay: RefCounted = VehicleSimulation.new(config)
	replay.state.velocity = Vector2(0,speed)
	replay.state.steering = steer
	for packed: Array in frames:
		replay.step(DriveFrame.sample(float(packed[0])/127.0,float(packed[1])/255.0,float(packed[2])/255.0))
	return {"radius":distance/maxf(angle,0.001),"angle":angle,"target_angle":target_angle,"minimum_speed":minimum_speed,"maximum_speed":maximum_speed,"peak_slip":peak_slip,"replay_exact":sim.state.snapshot()==replay.state.snapshot(),"ticks":frames.size()}

func run() -> void:
	output = TIGHT_OUTPUT
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var old: HandlingConfig = load(TIGHT_OUTPUT+"/before/game/resources/cars/electric.tres")
	var current: HandlingConfig = (load("res://tests/fixtures/volt_turn_reference/electric_26.tres") as HandlingConfig).duplicate()
	current.power_lateral_response_scale = 0.25 # Isolate this historical increment from the later powered-drift tune.
	for field: String in ["soil_drag_multiplier", "loose_surface_grip", "dirty_tire_grip_loss", "tire_pickup_distance", "tire_clean_distance"]: current.set(field, old.get(field)) # Isolate the later off-road tune.
	check(old.version == "electric-23" and current.version == "electric-26","versioned tighter steering envelope")
	check(current.low_speed_turn_radius == 2.3 and current.low_speed_turn_acceleration == 75.0,"modest radius and speed progression reduction")
	check(old.snapshot().size() == current.snapshot().size(),"no new handling capabilities")
	for field: String in old.snapshot():
		if field in ["version","low_speed_turn_radius","low_speed_turn_acceleration"]: continue
		check(old.get(field) == current.get(field),"unchanged tune: "+field)
	metrics.circles = {}
	for kph: float in [5.0,10.0,20.0,30.0,40.0,60.0,80.0,120.0]:
		var before := held_circle(old,kph/3.6,1.0)
		var after := held_circle(current,kph/3.6,1.0)
		var mirror := held_circle(current,kph/3.6,-1.0)
		metrics.circles[str(kph)] = {"before":before,"after":after}
		check(after.angle >= after.target_angle and after.minimum_speed > kph/3.6*0.95,"held circle completes at its requested speed: "+str(kph))
		check(after.radius <= before.radius*1.001 and after.radius >= before.radius*0.86,"radius tightens modestly without widening: "+str(kph))
		if kph >= 30:
			check(after.radius < before.radius*0.97,"ordinary driving circle is at least three percent tighter: "+str(kph))
		check(is_equal_approx(after.radius,mirror.radius) and after.replay_exact,"left/right symmetry and exact held-circle replay: "+str(kph))
	metrics.turns = {}
	for kph: float in [0.0,10.0,30.0,50.0,80.0,120.0,170.0]:
		for steering: float in [0.35,0.65,1.0]:
			for pedal: float in [0.55,0.65,0.8,1.0]:
				var after := slide_sample(current,kph,steering,pedal)
				metrics.turns[str(kph)+"/"+str(steering)+"/"+str(pedal)] = after
				check(after.peak < 24.0,"powered slide stays bounded")
				check(after.end_kph > kph,"powered tighter turn still accelerates")
				check(after.recovery_ms > 0 and after.recovery_ms <= 300 and after.final_slip < 0.1,"straightening still catches the slide")
				check(after.replay_exact,"powered turn replays exactly")
	# Steering changes cannot alter straight power, brake, lift or reverse behavior.
	for mode: int in range(3):
		var before := VehicleSimulation.new(old)
		var after := VehicleSimulation.new(current)
		var exact := true
		for tick: int in range(1200):
			var frame := DriveFrame.sample(0,1 if mode == 0 and tick < 600 else 0,1 if mode == 1 or mode == 2 and tick > 600 else 0)
			before.step(frame)
			after.step(frame)
			exact = exact and before.state.snapshot() == after.state.snapshot()
		check(exact,"straight acceleration/brake/reverse/lift remains tick exact, mode="+str(mode))
	metrics.electric = {"handling_version":current.version,"config_hash":JSON.stringify(current.snapshot(),"",true).sha256_text()}
	var file := FileAccess.open(output+"/turning.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	file.close()
	print("ELECTRIC_TURNING_TIGHTER: %d checks, %d failures circles=%s" % [checks,failures,JSON.stringify(metrics.circles)])
	quit.call_deferred(1 if failures else 0)

