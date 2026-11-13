extends "res://tests/test_electric_turn_radius.gd"

const CONSISTENT_OUTPUT: String = "res://../docs/evidence/electric-consistent-handling-2026-10-26"

func run() -> void:
	prior_simulation = GDScript.new()
	prior_simulation.source_code = FileAccess.get_file_as_string(CONSISTENT_OUTPUT+"/before/game__vehicle__vehicle_simulation.gd").replace("class_name VehicleSimulation","").trim_prefix("\ufeff")
	check(prior_simulation.reload()==OK,"actual task-start simulation compiles")
	var old: HandlingConfig = load(CONSISTENT_OUTPUT+"/before/game__resources__cars__electric.tres") as HandlingConfig
	var current: HandlingConfig = VehicleCatalog.config("electric")
	metrics.circles={}
	var last_radius: float = 0.0
	for kph: float in [5.0,10.0,15.0,20.0,25.0,30.0,35.0,40.0,45.0,50.0,55.0,60.0,72.0,90.0,110.0,140.0,170.0,190.0]:
		var before: Dictionary = held_circle(old,kph/3.6,1.0,true)
		var after: Dictionary = held_circle(current,kph/3.6,1.0)
		var mirror: Dictionary = held_circle(current,kph/3.6,-1.0)
		metrics.circles[str(kph)]={"before":before,"after":after}
		check(after.angle>=TAU,"actual held input completes a circle: "+str(kph))
		check(after.minimum_speed>kph/3.6*0.98,"speed feedback holds requested travel speed: "+str(kph))
		check(after.radius>=last_radius*0.995,"holding the same steering never tightens the turn as speed rises: "+str(kph))
		if kph<=30: check(after.radius>before.radius*1.15,"slow sustained turn is materially calmer: "+str(kph))
		check(is_equal_approx(after.radius,mirror.radius),"held left/right circles are symmetric: "+str(kph))
		check(after.replay_exact,"recorded held-circle inputs replay exactly: "+str(kph))
		last_radius=after.radius
	for kph: float in [10.0,30.0,60.0,110.0]:
		var full: Dictionary = metrics.circles[str(kph)].after
		for strength: float in [0.25,0.5,0.75]:
			var partial: Dictionary = held_circle(current,kph/3.6,strength)
			check(partial.angle>=partial.target_angle and partial.radius>full.radius*1.1,"controller partial input retains a wider turn: "+str(kph)+"/"+str(strength))
	# Real action sampling covers keyboard full-lock, controller strengths and release.
	metrics.input={}
	for kph: float in [5.0,20.0,40.0,60.0,110.0]:
		var sim := VehicleSimulation.new(current)
		sim.state.velocity=Vector2(0,kph/3.6)
		var driver := DriverInput.new()
		driver.single_pedal=true
		Input.action_press(&"steer_right",1.0)
		Input.action_press(&"accelerate",0.25)
		var first_course: float = 0.0
		for tick: int in range(24):
			sim.step(driver.sample())
			if tick==23: first_course=rad_to_deg(atan2(sim.state.velocity.x,sim.state.velocity.y))
		metrics.input[str(kph)]={"steering_200ms":sim.state.steering,"course_200ms":first_course}
		check(sim.state.steering<0.75,"keyboard press builds steering gradually at every speed: "+str(kph))
		driver.clear()
		for tick: int in range(24): sim.step(DriveFrame.sample(0,0.25,0))
		check(sim.state.steering==0.0,"keyboard release recentres without sticking: "+str(kph))
	# Quantized changes of one km/h must not expose the old 29/40/60 speed cliffs.
	var previous_curvature: float = INF
	var previous_steering: float = -1.0
	for kph: int in range(1,191):
		var sim := VehicleSimulation.new(current)
		sim.state.velocity=Vector2(0,float(kph)/3.6)
		sim.state.steering=1.0
		sim.step(DriveFrame.sample(1,0.25,0))
		var curvature: float = absf(sim.state.yaw_rate)/(float(kph)/3.6)
		check(curvature<=previous_curvature*1.001,"one-km/h sweep never restores tighter curvature: "+str(kph))
		previous_curvature=curvature
		var onset := VehicleSimulation.new(current)
		onset.state.velocity=Vector2(0,float(kph)/3.6)
		onset.step(DriveFrame.sample(1,0.25,0))
		if previous_steering>=0: check(is_equal_approx(onset.state.steering,previous_steering),"steering input response is consistent across speeds: "+str(kph))
		previous_steering=onset.state.steering
	var file := FileAccess.open(CONSISTENT_OUTPUT+"/handling.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	file.close()
	print("ELECTRIC_CONSISTENT_HANDLING: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
