extends "res://tests/probe_electric_power_increment.gd"

const EASE_OUTPUT = "res://../docs/evidence/electric-drift-easier-2026-10-28"

func run() -> void:
	output = EASE_OUTPUT
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var old: HandlingConfig = load(EASE_OUTPUT+"/before/game/resources/cars/electric.tres") as HandlingConfig
	var current: HandlingConfig = (load("res://tests/fixtures/volt_turn_reference/electric_26.tres") as HandlingConfig).duplicate()
	current.power_lateral_response_scale = 0.25 # Isolate this historical increment from the later powered-drift tune.
	for field: String in ["soil_drag_multiplier", "loose_surface_grip", "dirty_tire_grip_loss", "tire_pickup_distance", "tire_clean_distance"]: current.set(field, old.get(field)) # Isolate the later off-road tune.
	old.low_speed_turn_radius = current.low_speed_turn_radius
	old.low_speed_turn_acceleration = current.low_speed_turn_acceleration # Later radius tune is checked independently.
	check(old.version=="electric-21" and current.version=="electric-26","incremental drift has its own Electric identity")
	old.engine_force = current.engine_force # Isolate the drift change from the later acceleration tune.
	check(current.power_lateral_response_scale==0.25,"small power-on rear-response reduction")
	for field: String in old.snapshot():
		if field in ["version","power_lateral_response_scale"]: continue
		check(current.get(field)==old.get(field),"all other settings stay exact: "+field)
	metrics.turns = {}
	for kph: float in [0.0,10.0,30.0,50.0,80.0,120.0,170.0]:
		for steering: float in [0.35,0.65,1.0]:
			for pedal: float in [0.55,0.65,0.8,1.0]:
				var before: Dictionary = slide_sample(old,kph,steering,pedal)
				var after: Dictionary = slide_sample(current,kph,steering,pedal)
				var mirror: Dictionary = slide_sample(current,kph,-steering,pedal)
				var label: String = str(kph)+"/"+str(steering)+"/"+str(pedal)
				metrics.turns[label] = {"before":before,"after":after}
				check(after.peak>=before.peak-0.01 and after.peak<24.0,"slightly more slide stays bounded: "+label)
				check(after.end_kph>kph and after.end_kph>=before.end_kph*0.98,"power retains acceleration and at least 98% of prior speed: "+label)
				check(after.recovery_ms>0 and after.recovery_ms<=300 and after.final_slip<0.1,"straightening recovers within 300ms: "+label)
				check(after.replay_exact and is_equal_approx(after.peak,mirror.peak),"exact replay and mirrored slide: "+label)
	var reference: Dictionary = metrics.turns["50.0/1.0/0.65"]
	check(reference.after.peak>=reference.before.peak*1.04 and reference.after.peak<=reference.before.peak*1.10,"50km/h moderate pedal gives 4-10% more drift")
	check(reference.after.onset_ms>0 and reference.after.onset_ms<reference.before.onset_ms,"moderate-pedal slide begins a little earlier")
	for direction: int in [0,1]:
		var before := VehicleSimulation.new(old)
		var after := VehicleSimulation.new(current)
		var exact: bool = true
		for tick: int in range(2400):
			var frame := DriveFrame.sample(0,1 if tick%480<300 else 0,direction)
			before.step(frame)
			after.step(frame)
			exact = exact and before.state.snapshot()==after.state.snapshot()
		check(exact,"straight acceleration/regen/hold stay tick-exact, D/R="+str(direction))
	for kph: float in [5.0,30.0,80.0,170.0,-25.2]:
		for pedal: float in [0.0,0.24,0.4]:
			var before := VehicleSimulation.new(old)
			var after := VehicleSimulation.new(current)
			before.state.velocity = Vector2(0,kph/3.6)
			after.state.velocity = before.state.velocity
			var exact: bool = true
			for tick: int in range(360):
				var frame := DriveFrame.sample(0.65,pedal,1 if kph<0 else 0)
				before.step(frame)
				after.step(frame)
				exact = exact and before.state.snapshot()==after.state.snapshot()
			check(exact,"light pedal and released turns stay exact: "+str(kph)+"/"+str(pedal))
	metrics.electric = {"handling_version":current.version,"config_hash":JSON.stringify(current.snapshot(),"",true).sha256_text()}
	var file := FileAccess.open(output+"/power-increment.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	file.close()
	print("ELECTRIC_DRIFT_EASIER: %d checks, %d failures" % [checks,failures])
	quit.call_deferred(1 if failures else 0)
