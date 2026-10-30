extends "res://tests/probe_electric_character.gd"

func run() -> void:
	var old: HandlingConfig=load(CHARACTER_OUTPUT+"/before/game__resources__cars__electric.tres") as HandlingConfig
	var current: HandlingConfig=VehicleCatalog.config("electric")
	var compact: HandlingConfig=VehicleCatalog.config("compact")
	check(old.version=="electric-16" and current.version=="electric-20","distinct electric balance has a new identity")
	var changed: Array[String]=["version","regeneration","steering_rate","rotational_inertia","lateral_response","launch_lateral_response_scale","power_lateral_response_scale","slide_drive_loss"]
	for field: String in old.snapshot():
		if field in changed: continue
		check(current.get(field)==old.get(field),"retained electric field: "+field)
	check(current.mass>compact.mass*1.4 and current.maximum_speed>compact.maximum_speed*1.1,"electric retains its heavier, faster identity")
	check(current.rear_wheel_drive and current.single_pedal and not compact.single_pedal,"rear-motor one-pedal control remains distinct from compact")
	check(current.lateral_response>compact.lateral_response*1.4 and current.lateral_grip>compact.lateral_grip*1.2,"electric remains more planted off power than compact")
	metrics.launch={"electric":launch(current),"compact":launch(compact)}
	check(metrics.launch.electric[str(100.0/3.6)]<metrics.launch.compact[str(100.0/3.6)]*0.85,"electric keeps a materially punchier launch than compact")
	metrics.phase={"before":input_phase(old),"after":input_phase(current),"compact":input_phase(compact)}
	check(metrics.phase.after.lock_ms<metrics.phase.before.lock_ms*0.8 and metrics.phase.after.lock_ms<=120.0,"input filtering is more connected than electric-16")
	check(metrics.phase.after.lock_ms>metrics.phase.compact.lock_ms*2.0,"input keeps more weight than compact's quick lock")
	check(metrics.phase.after.course_100ms>=metrics.phase.compact.course_100ms*0.7 and metrics.phase.after.course_100ms<=metrics.phase.compact.course_100ms*1.1,"initial course response is useful without exceeding compact agility")
	check(metrics.phase.after.course_200ms>=metrics.phase.compact.course_200ms*0.85 and metrics.phase.after.course_200ms<=metrics.phase.compact.course_200ms*1.25,"held input develops useful cornering authority")
	metrics.pulse={"before":keyboard_pulse(old),"after":keyboard_pulse(current),"compact":keyboard_pulse(compact)}
	var before_loss: float=metrics.pulse.before.samples[1].speed_kph-metrics.pulse.before.samples[4].speed_kph
	var after_loss: float=metrics.pulse.after.samples[1].speed_kph-metrics.pulse.after.samples[4].speed_kph
	var compact_loss: float=metrics.pulse.compact.samples[1].speed_kph-metrics.pulse.compact.samples[4].speed_kph
	metrics.release_loss_kph={"before":before_loss,"after":after_loss,"compact":compact_loss}
	check(after_loss<before_loss*0.9 and after_loss>before_loss*0.72,"stronger braking still removes less corner speed than electric-16")
	check(after_loss>compact_loss*2.0,"lift retains clear electric regeneration rather than compact coasting")
	check(metrics.pulse.after.peak_slip<24.0 and metrics.pulse.after.peak_slip>15.0,"keyboard power develops a deliberate controllable slide")
	for reverse: bool in [false,true]:
		var before := VehicleSimulation.new(old)
		var after := VehicleSimulation.new(current)
		var exact: bool=true
		for tick: int in range(2400):
			var frame := DriveFrame.sample(0,1,1 if reverse else 0)
			before.step(frame)
			after.step(frame)
			exact=exact and before.state.snapshot()==after.state.snapshot()
		check(exact,"straight electric punch and cap remain tick-exact, reverse="+str(reverse))
	task_start=GDScript.new()
	task_start.source_code=FileAccess.get_file_as_string(CHARACTER_OUTPUT+"/before/game__vehicle__vehicle_simulation.gd").replace("class_name VehicleSimulation","").trim_prefix("\ufeff")
	check(task_start.reload()==OK,"task-start physics compiles for drift comparison")
	metrics.power={}
	for speed: float in [0.0,10.0,20.0,30.0]:
		var result: Dictionary=powered_turn(current,speed,0.65,1.0)
		metrics.power[str(speed)]=result
		var prior: Dictionary=powered_turn(old,speed,0.65,1.0,true)
		result.previous_slip=prior.peak_slip
		check(result.peak_slip>prior.peak_slip*1.5 and result.peak_slip<24.0,"power slide is easier while the high-speed fade stays controllable: "+str(speed))
		check(result.recovered_slip<0.1 and result.replay_exact,"slide recovers and replays exactly: "+str(speed))
	var file := FileAccess.open(output+"/character.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	file.close()
	print("ELECTRIC_CHARACTER: %d checks, %d failures " % [checks,failures],JSON.stringify(metrics))
	quit(1 if failures else 0)
