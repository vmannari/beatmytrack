extends "res://tests/test_electric_turn_radius.gd"

const CONSISTENT_OUTPUT: String = "res://../docs/evidence/electric-tighter-held-steering-2026-10-26"

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output=argument.trim_prefix("--evidence-root=")
	prior_simulation = GDScript.new()
	prior_simulation.source_code = FileAccess.get_file_as_string(CONSISTENT_OUTPUT+"/before/game__vehicle__vehicle_simulation.gd").replace("class_name VehicleSimulation","").trim_prefix("\ufeff")
	check(prior_simulation.reload()==OK,"actual task-start simulation compiles")
	var old: HandlingConfig = load(CONSISTENT_OUTPUT+"/before/game__resources__cars__electric.tres") as HandlingConfig
	var current: HandlingConfig = VehicleCatalog.config("electric")
	check(old.version=="electric-14" and current.version=="electric-19" and VehicleSimulation.PHYSICS_VERSION=="arcade-planar-0.75","new steering contract has a versioned competitive identity")
	for field: String in ["maximum_speed","reverse_speed","mass","engine_force","braking_force","coast_pedal","longitudinal_grip","rear_wheel_drive","single_pedal"]:
		check(old.get(field)==current.get(field),"accepted propulsion/braking field is retained: "+field)
	for reverse: bool in [false,true]:
		var before_straight: RefCounted=prior_simulation.new(old)
		var after_straight := VehicleSimulation.new(current)
		var exact_straight: bool=true
		for tick: int in range(2400):
			var frame := DriveFrame.sample(0,1.0 if tick<1200 else 0.0,1.0 if reverse else 0.0)
			before_straight.step(frame)
			after_straight.step(frame)
			if tick<1200: exact_straight=exact_straight and before_straight.state.snapshot()==after_straight.state.snapshot()
		check(exact_straight,"actual task-start straight powered propulsion remains tick-exact, reverse="+str(reverse))
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
		if kph>=15 and kph<=30: check(after.radius<before.radius*0.85,"ordinary corners regain materially tighter steering: "+str(kph))
		check(is_equal_approx(after.radius,mirror.radius),"held left/right circles are symmetric: "+str(kph))
		check(after.replay_exact,"recorded held-circle inputs replay exactly: "+str(kph))
		last_radius=after.radius
	for kph: float in [10.0,30.0,60.0,110.0]:
		var full: Dictionary = metrics.circles[str(kph)].after
		for strength: float in [0.25,0.5,0.75]:
			var partial: Dictionary = held_circle(current,kph/3.6,strength)
			check(partial.angle>=partial.target_angle and partial.radius>full.radius*1.1,"controller partial input retains a wider turn: "+str(kph)+"/"+str(strength))
	# At parking speed, judge keyboard agility by the actual key-press transient;
	# an arbitrarily huge held circle would prevent navigating tight roads.
	metrics.keyboard_onset={}
	for kph: float in [5.0,10.0,20.0,30.0]:
		var old_onset: RefCounted = prior_simulation.new(old)
		var new_onset := VehicleSimulation.new(current)
		old_onset.state.velocity=Vector2(0,kph/3.6)
		new_onset.state.velocity=old_onset.state.velocity
		var keys := DriverInput.new()
		keys.single_pedal=true
		Input.action_press(&"steer_right",1.0)
		Input.action_press(&"accelerate",0.25)
		var same_buildup: bool=true
		for tick: int in range(24):
			var frame: DriveFrame=keys.sample()
			old_onset.step(frame)
			new_onset.step(frame)
			same_buildup=same_buildup and new_onset.state.steering>=old_onset.state.steering
		check(same_buildup and absf(atan2(new_onset.state.velocity.x,new_onset.state.velocity.y))>=absf(atan2(old_onset.state.velocity.x,old_onset.state.velocity.y)),"input buildup becomes more connected while retaining the useful path: "+str(kph))
		metrics.keyboard_onset[str(kph)]={"before_degrees":rad_to_deg(absf(atan2(old_onset.state.velocity.x,old_onset.state.velocity.y))),"after_degrees":rad_to_deg(absf(atan2(new_onset.state.velocity.x,new_onset.state.velocity.y)))}
		keys.clear()
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
			if tick==11: check(sim.state.steering<=0.95,"keyboard input still builds rather than snapping instantly: "+str(kph))
			if tick==23: first_course=rad_to_deg(atan2(sim.state.velocity.x,sim.state.velocity.y))
		metrics.input[str(kph)]={"steering_200ms":sim.state.steering,"course_200ms":first_course}
		check(sim.state.steering>0.95,"keyboard press reaches usable lock within 200ms at every speed: "+str(kph))
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
	# Parse the configured keyboard/controller events, including analog deadzone.
	var physical_driver := DriverInput.new()
	physical_driver.single_pedal=true
	var key := InputEventKey.new()
	key.device=16
	key.physical_keycode=KEY_D
	key.keycode=KEY_D
	key.pressed=true
	Input.parse_input_event(key)
	await process_frame
	await process_frame
	print("KEYBOARD_PROBE ",InputMap.event_is_action(key,&"steer_right")," ",physical_driver.sample().packed())
	check(physical_driver.sample().steer==127,"configured keyboard D produces full right steering")
	var release_key: InputEventKey=key.duplicate() as InputEventKey
	release_key.pressed=false
	Input.parse_input_event(release_key)
	await process_frame
	physical_driver.clear()
	var last_strength: int = 0
	for strength: float in [0.25,0.5,0.75,1.0]:
		var axis := InputEventJoypadMotion.new()
		axis.device=0
		axis.axis=JOY_AXIS_LEFT_X
		axis.axis_value=strength
		Input.parse_input_event(axis)
		await process_frame
		var sampled: int=physical_driver.sample().steer
		check(sampled>last_strength and sampled<=127,"controller axis retains ordered partial steering after its deadzone: "+str(strength))
		last_strength=sampled
	var reset_axis := InputEventJoypadMotion.new()
	reset_axis.device=0
	reset_axis.axis=JOY_AXIS_LEFT_X
	reset_axis.axis_value=0.0
	Input.parse_input_event(reset_axis)
	await process_frame
	physical_driver.clear()
	# The diagnostic planning correction is opt-in; all six other drivers retain exact input.
	var prior_driver := GDScript.new()
	prior_driver.source_code=FileAccess.get_file_as_string(CONSISTENT_OUTPUT+"/before/game__input__route_driver.gd").replace("class_name RouteDriver","")
	check(prior_driver.reload()==OK,"task-start diagnostic driver compiles")
	var track := NativeTrack.read("res://tests/fixtures/legacy_tracks/slicks_ovaali3_test.json")
	for id: String in VehicleCatalog.IDS:
		if id=="electric": continue
		var config: HandlingConfig=VehicleCatalog.config(id)
		var before_driver: RefCounted=prior_driver.new()
		var after_driver := RouteDriver.new()
		var sim := VehicleSimulation.new(config)
		sim.reset(track.spawn,track.spawn_heading)
		var exact_inputs: bool=true
		for tick: int in range(600):
			var before_frame: DriveFrame=before_driver.sample(sim.state,track,config)
			var after_frame: DriveFrame=after_driver.sample(sim.state,track,config)
			exact_inputs=exact_inputs and before_frame.packed()==after_frame.packed()
			sim.step(before_frame,track)
		check(exact_inputs,"other car retains exact diagnostic inputs: "+id)
	var file := FileAccess.open(output+"/continuous-handling.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	file.close()
	print("ELECTRIC_CONSISTENT_HANDLING: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
