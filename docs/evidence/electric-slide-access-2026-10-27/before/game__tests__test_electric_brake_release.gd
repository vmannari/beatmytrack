extends "res://tests/test_electric_power.gd"
const RELEASE_OUTPUT: String = "res://../docs/evidence/electric-brake-release-2026-10-25"
var previous_simulation: GDScript

func released_stop(config: HandlingConfig, speed: float, previous: bool = false) -> Dictionary:
	var sim: RefCounted = previous_simulation.new(config) if previous else VehicleSimulation.new(config)
	sim.state.velocity = Vector2(0,speed)
	var driver := DriverInput.new()
	driver.single_pedal = true
	driver.reverse_selected = speed < 0
	driver.set_touch(0,&"accelerate")
	driver.release_touch(0)
	var frame: DriveFrame = driver.sample()
	var ticks: int = 0
	var first: float = 0
	var monotonic: bool = true
	var before: float = absf(speed)
	while sim.state.velocity != Vector2.ZERO and ticks < 1200:
		sim.step(frame)
		var after: float = sim.state.velocity.length()
		if ticks == 0: first = (absf(speed)-after)*120
		monotonic = monotonic and after <= before and sim.state.velocity.y*speed >= 0
		before = after
		ticks += 1
	var stopped: bool = sim.state.velocity == Vector2.ZERO
	for tick: int in range(600): sim.step(frame)
	return {"seconds":ticks/120.0,"metres":absf(sim.state.position.y),"first_deceleration":first,
		"monotonic":monotonic,"stopped":stopped,"holds":sim.state.velocity==Vector2.ZERO,
		"released_frame":frame.packed()}

func run() -> void:
	output = RELEASE_OUTPUT
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	previous_simulation = GDScript.new()
	previous_simulation.source_code = FileAccess.get_file_as_string(RELEASE_OUTPUT+"/before/game__vehicle__vehicle_simulation.gd.txt").replace("class_name VehicleSimulation","").trim_prefix("\ufeff")
	check(previous_simulation.reload() == OK,"actual preceding physics compiles for comparison")
	var old: HandlingConfig = load(RELEASE_OUTPUT+"/before/electric-5.tres") as HandlingConfig
	var current: HandlingConfig = VehicleCatalog.config("electric")
	# Isolate braking/steering from the owner-requested cap and its power falloff.
	old.maximum_speed = current.maximum_speed
	check(old.version == "electric-5" and current.version == "electric-17" and VehicleSimulation.PHYSICS_VERSION == "arcade-planar-0.74","competitive braking behavior and current low-speed tune are versioned")
	metrics.stops = {}
	for speed: float in [7.0,20.0,100.0/3.6,44.0,-7.0,-20.0]:
		var before: Dictionary = released_stop(old,speed,true)
		var after: Dictionary = released_stop(current,speed)
		metrics.stops[str(speed)] = {"before":before,"after":after}
		check(after.first_deceleration >= 12 and after.first_deceleration < 13,"released touch immediately applies controlled regeneration: "+str(speed))
		check(after.seconds > before.seconds and after.seconds < before.seconds*1.3,"gentler release retains a predictable stopping interval: "+str(speed))
		check(after.monotonic and after.stopped and after.holds,"release stops exactly without reversing or creep: "+str(speed))
		check(after.released_frame[1] == 0 and (after.released_frame.size() == 3 or after.released_frame[3] == 0),"actual touch release needs neither brake nor handbrake: "+str(speed))
	check(float(metrics.stops["20.0"].after.seconds)>1.5 and float(metrics.stops["20.0"].after.seconds)<1.75 and float(metrics.stops["20.0"].after.metres)>15.0 and float(metrics.stops["20.0"].after.metres)<18.0,"72 km/h release stop follows the less abrupt character bounds")
	var full := VehicleSimulation.new(current)
	var partial := VehicleSimulation.new(current)
	full.state.velocity = Vector2(0,20)
	partial.state.velocity = Vector2(0,20)
	for tick: int in range(30):
		full.step(DriveFrame.sample(0,0,0))
		partial.step(DriveFrame.sample(0,0.12,0))
	check(full.state.velocity.y < partial.state.velocity.y and partial.state.velocity.y < 20,"partial release retains progressive braking control")
	# Same tyres with a regeneration-only request reproduce the old rear ceiling.
	var rear_only: HandlingConfig = current.duplicate() as HandlingConfig
	rear_only.regeneration = 26.0
	rear_only.single_pedal = false
	var motor := VehicleSimulation.new(rear_only)
	motor.state.velocity = Vector2(0,20)
	motor.step(DriveFrame.sample(0,0,0))
	metrics.rear_only_deceleration = (20-motor.state.velocity.y)*120
	var stress: HandlingConfig=current.duplicate() as HandlingConfig
	stress.regeneration=26.0
	var blended := VehicleSimulation.new(stress)
	blended.state.velocity=Vector2(0,20)
	blended.step(DriveFrame.sample(0,0,0))
	check(float(metrics.rear_only_deceleration)<16 and (20-blended.state.velocity.y)*120>26,"automatic brake blend still removes the rear-only ceiling in the retained 26 m/s2 mechanism fixture")
	for direction: int in [0,255]:
		var before: RefCounted = previous_simulation.new(old)
		var after := VehicleSimulation.new(current)
		var exact: bool = true
		for tick: int in range(1200):
			# The later owner correction intentionally changes parking-speed turns.
			# Preserve the straight power contract; high-speed turning is compared
			# exactly in test_electric_low_speed_steering.gd against electric-6.
			var frame := DriveFrame.sample(0,0.3+0.7*absf(sin(tick*0.007)),direction/255.0)
			before.step(frame)
			after.step(frame)
			exact = exact and before.state.snapshot() == after.state.snapshot()
		check(exact,"straight powered acceleration remains tick-exact, direction="+str(direction))
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
		check(exact,"other car remains tick-exact across power/coast/brake/handbrake: "+id)
	metrics.launch = launch(current)
	check(metrics.launch == launch(old),"softened launch times remain exact")
	var report := FileAccess.open(output+"/release.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	report.close()
	print("ELECTRIC_RELEASE_METRICS ",JSON.stringify(metrics))
	print("ELECTRIC_RELEASE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
