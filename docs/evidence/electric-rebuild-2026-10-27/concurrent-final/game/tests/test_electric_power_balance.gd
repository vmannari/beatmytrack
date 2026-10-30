extends "res://tests/test_electric_power.gd"
const BALANCE_OUTPUT: String = "res://../docs/evidence/electric-power-balance-2026-10-25"

func stop(config: HandlingConfig, speed: float) -> Dictionary:
	var sim := VehicleSimulation.new(config)
	sim.state.velocity = Vector2(0,speed)
	var first: float = 0
	var ticks: int = 0
	while sim.state.velocity != Vector2.ZERO and ticks < 1200:
		sim.step(DriveFrame.sample(0,0,0))
		if ticks == 0: first = (speed-sim.state.velocity.y)*120.0
		ticks += 1
	var stopped: bool = sim.state.velocity == Vector2.ZERO
	for tick: int in range(600): sim.step(DriveFrame.sample(1,0,0))
	return {"seconds":ticks/120.0,"metres":sim.state.position.y,"initial_deceleration":first,"stopped":stopped,"holds":sim.state.velocity==Vector2.ZERO}

func run() -> void:
	output = BALANCE_OUTPUT
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	var old: HandlingConfig = load(BALANCE_OUTPUT+"/before/electric-4.tres") as HandlingConfig
	var current: HandlingConfig = VehicleCatalog.config("electric")
	check(old.version == "electric-4" and current.version == "electric-19","versioned preceding power tune and current brake balance")
	metrics.before_launch = launch(old)
	metrics.after_launch = launch(current)
	for target: float in [20.0,100.0/3.6,40.0]:
		var before: float = metrics.before_launch[str(target)]
		var after: float = metrics.after_launch[str(target)]
		check(after >= before*1.25 and after <= before*1.6,"launch is substantially softer through "+str(target)+" m/s")
	check(float(metrics.after_launch[str(100.0/3.6)]) < 1.8,"electric launch remains responsive after softening")
	metrics.before_stop = stop(old,20)
	metrics.after_stop = stop(current,20)
	check(metrics.after_stop.initial_deceleration >= 20 and metrics.after_stop.initial_deceleration < 21,"release immediately produces controlled regeneration")
	check(metrics.after_stop.seconds > 0.95 and metrics.after_stop.seconds < 1.05 and metrics.after_stop.metres > 9.5 and metrics.after_stop.metres < 10.2,"firm one-pedal stop remains within the new balance bounds")
	check(metrics.after_stop.stopped and metrics.after_stop.holds,"release reaches exact zero and holds without creep")
	check(absf(current.maximum_speed*3.6-190.0)<0.001,"top speed follows the owner-requested 190 km/h cap")
	var sim := VehicleSimulation.new(current)
	for tick: int in range(3600): sim.step(DriveFrame.sample(0,1,0))
	metrics.top_speed = sim.state.velocity.length()
	check(is_equal_approx(sim.state.velocity.length(),current.maximum_speed),"actual full-pedal speed reaches and obeys the 190 km/h cap")
	for field: String in ["maximum_yaw_rate","lateral_grip","corner_energy_retention","throttle_rotation"]:
		check(current.get(field) == old.get(field),"quicker steering and calm corner balance retained: "+field)
	check(current.single_pedal and current.rear_wheel_drive and current.reverse_speed == old.reverse_speed,"one pedal, rear drive and reverse limit retained")
	metrics.before_corner = corner(old,1)
	metrics.after_corner = corner(current,1)
	metrics.gentle_corner = corner(current,0.45)
	check(metrics.after_corner.peak_slip_degrees <= metrics.before_corner.peak_slip_degrees and metrics.gentle_corner.peak_slip_degrees < 8,"softer power does not exaggerate sliding")
	print("ELECTRIC_BALANCE_METRICS ",JSON.stringify(metrics))
	var report := FileAccess.open(output+"/balance.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	report.close()
	print("ELECTRIC_BALANCE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
