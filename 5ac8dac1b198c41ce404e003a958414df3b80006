extends "res://tests/probe_electric_slide_access.gd"

const ACCEL_OUTPUT = "res://../docs/evidence/electric-acceleration-2026-10-28"

func rolling(config: HandlingConfig, from_kph: float, to_kph: float, pedal: float) -> float:
	var sim := VehicleSimulation.new(config)
	sim.state.velocity = Vector2(0,from_kph/3.6)
	for tick: int in range(3600):
		sim.step(DriveFrame.sample(0,pedal,0))
		if sim.state.velocity.y >= to_kph/3.6: return (tick+1)/120.0
	return 30.0

func run() -> void:
	output = ACCEL_OUTPUT
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var old: HandlingConfig = load(ACCEL_OUTPUT+"/before/game/resources/cars/electric.tres")
	var current: HandlingConfig = VehicleCatalog.config("electric")
	check(old.version == "electric-22" and current.version == "electric-23","versioned small acceleration increase")
	check(current.engine_force == 41000.0,"motor force increases by 7.9 percent")
	check(current.snapshot().size() == old.snapshot().size(),"no new handling capabilities")
	for key: String in old.snapshot():
		if key in ["version","engine_force"]: continue
		check(old.get(key) == current.get(key),"unchanged tune: "+key)
	metrics.launch = {"before":launch(old),"after":launch(current)}
	var target := str(100.0/3.6)
	check(metrics.launch.after[target] < metrics.launch.before[target] and metrics.launch.after[target] >= metrics.launch.before[target]*0.92,"slightly quicker 0-100, within eight percent")
	metrics.rolling = {}
	for pedal: float in [0.65,1.0]:
		var before := rolling(old,50,100,pedal)
		var after := rolling(current,50,100,pedal)
		metrics.rolling[str(pedal)] = {"before":before,"after":after}
		check(after < before and after >= before*0.90,"slightly quicker 50-100 at pedal "+str(pedal))
	# Zero drive demand leaves service braking, regeneration and hold tick-exact.
	for speed: float in [-7.0,0.0,20.0,current.maximum_speed]:
		for brake: float in [0.0,0.5,1.0]:
			var a := VehicleSimulation.new(old)
			var b := VehicleSimulation.new(current)
			a.state.velocity = Vector2(0,speed)
			b.state.velocity = a.state.velocity
			var exact := true
			for tick: int in range(12):
				a.step(DriveFrame.sample(0,0,brake))
				b.step(DriveFrame.sample(0,0,brake))
				exact = exact and a.state.snapshot() == b.state.snapshot()
			check(exact,"retained lift/brake response "+str(speed)+"/"+str(brake))
	metrics.turns = {}
	for kph: float in [0.0,10.0,30.0,50.0,80.0,120.0,170.0]:
		for steering: float in [0.35,0.65,1.0]:
			for pedal: float in [0.55,0.65,0.8,1.0]:
				var before := slide_sample(old,kph,steering,pedal)
				var after := slide_sample(current,kph,steering,pedal)
				metrics.turns[str(kph)+"/"+str(steering)+"/"+str(pedal)] = {"before":before,"after":after}
				check(after.peak < 24.0,"powered slide stays bounded")
				check(after.end_kph > kph and after.end_kph >= before.end_kph*0.99,"power retains acceleration and turn exit speed")
				check(after.recovery_ms > 0 and after.recovery_ms <= 300 and after.final_slip < 0.1,"slide remains easy to recover")
				check(after.replay_exact,"powered turn replays exactly")
	var cap := VehicleSimulation.new(current)
	for tick: int in range(3600): cap.step(DriveFrame.sample(0,1,0))
	check(cap.state.velocity.y <= current.maximum_speed and cap.state.velocity.y > current.maximum_speed-0.1,"unchanged 190 km/h forward cap")
	for tick: int in range(1200): cap.step(DriveFrame.new())
	check(cap.state.velocity == Vector2.ZERO,"lift still stops and holds")
	for tick: int in range(600): cap.step(DriveFrame.sample(0,0,1))
	check(cap.state.velocity.y >= -current.reverse_speed and cap.state.velocity.y < -6,"reverse remains bounded with stronger motor")
	metrics.electric = {"handling_version":current.version,"config_hash":JSON.stringify(current.snapshot(),"",true).sha256_text()}
	var file := FileAccess.open(output+"/acceleration.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	file.close()
	print("ELECTRIC_ACCELERATION: %d checks, %d failures launch=%s rolling=%s" % [checks,failures,JSON.stringify(metrics.launch),JSON.stringify(metrics.rolling)])
	quit.call_deferred(1 if failures else 0)
