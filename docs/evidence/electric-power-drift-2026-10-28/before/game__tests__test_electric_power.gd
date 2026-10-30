extends SceneTree
const _NATIVE_TRACK = preload("res://track/native_track.gd")
const OUTPUT: String = "res://../docs/evidence/electric-power-2026-10-25"
var output: String = OUTPUT
var checks: int = 0
var failures: int = 0
var metrics: Dictionary = {}

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output=argument.trim_prefix("--evidence-root=")
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func launch(config: HandlingConfig) -> Dictionary:
	var sim := VehicleSimulation.new(config)
	var result: Dictionary = {}
	for tick: int in range(1200):
		sim.step(DriveFrame.sample(0,1,0))
		for target: float in [20.0,100.0/3.6,40.0]:
			if sim.state.velocity.y >= target and not result.has(str(target)):
				result[str(target)] = (tick+1)/120.0
	return result

func corner(config: HandlingConfig, pedal: float, speed: float = 20.0, steer: float = 0.65) -> Dictionary:
	var sim := VehicleSimulation.new(config)
	sim.state.velocity = Vector2(0,speed)
	var peak: float = 0.0
	for tick: int in range(120):
		sim.step(DriveFrame.sample(steer,pedal,0))
		peak = maxf(peak,absf(rad_to_deg(sim.state.slip_angle())))
	var result: Dictionary = {"peak_slip_degrees":peak,"speed":sim.state.velocity.length(),"slip_degrees":absf(rad_to_deg(sim.state.slip_angle()))}
	for tick: int in range(240): sim.step(DriveFrame.sample(0,0,0))
	result.released_speed = sim.state.velocity.length()
	result.released_slip_degrees = absf(rad_to_deg(sim.state.slip_angle()))
	for tick: int in range(120): sim.step(DriveFrame.sample(0,0.60,0))
	result.recovery_speed = sim.state.velocity.length()
	result.recovery_slip_degrees = absf(rad_to_deg(sim.state.slip_angle()))
	return result

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	var old: HandlingConfig = load(OUTPUT+"/before/electric.tres") as HandlingConfig
	var current: HandlingConfig = VehicleCatalog.config("electric")
	check(old != null and old.version == "electric-2" and current.version == "electric-19","actual original and current balanced competitive tunes")
	metrics.old_launch = launch(old)
	metrics.new_launch = launch(current)
	metrics.old_corner = corner(old,1)
	metrics.new_corner = corner(current,1)
	metrics.gentle_corner = corner(current,0.45)
	var old_100: float = metrics.old_launch[str(100.0/3.6)]
	var new_100: float = metrics.new_launch[str(100.0/3.6)]
	# The owner now requests less aggressive power than electric-4. The dedicated
	# balance regression compares that actual preceding tune; retain a responsive
	# electric launch against the original electric-2 without its rejected target.
	check(new_100 <= old_100*0.85 and new_100 > old_100*0.75,"softer 0-100 launch retains a moderate improvement over the original electric tune")
	check(float(metrics.new_launch[str(20.0)]) < 1.2,"balanced electric launch reaches 72 kph within 1.2 seconds")
	# The owner now requests easier deliberate power slides; retain the planted
	# light-pedal response and bounded recovery while allowing a larger power angle.
	check(float(metrics.new_corner.peak_slip_degrees)>8.0 and float(metrics.new_corner.peak_slip_degrees)<24.0,"hard-power normal-speed turn develops the requested bounded slide")
	check(float(metrics.gentle_corner.peak_slip_degrees)<8 and float(metrics.new_corner.speed)>float(metrics.gentle_corner.speed),"progressive throttle retains power authority with both turns controlled")
	check(float(metrics.new_corner.released_slip_degrees) < 2 and float(metrics.new_corner.recovery_slip_degrees) < 2 and float(metrics.new_corner.recovery_speed) > 10,"lifting and unwinding catch the slide before powering away")
	var lift := VehicleSimulation.new(current)
	lift.state.velocity = Vector2(0,20)
	for tick: int in range(240): lift.step(DriveFrame.sample(0,0,0))
	check(lift.state.velocity == Vector2.ZERO,"controlled release reaches a complete stop from 72 kph within two seconds")
	for tick: int in range(600): lift.step(DriveFrame.sample(1,0,0))
	check(lift.state.velocity == Vector2.ZERO,"release holds the complete stop without creep")
	var rear := VehicleSimulation.new(current)
	var awd: HandlingConfig = current.duplicate() as HandlingConfig
	awd.rear_wheel_drive = false
	var all := VehicleSimulation.new(awd)
	for tick: int in range(60):
		rear.step(DriveFrame.sample(0,1,0))
		all.step(DriveFrame.sample(0,1,0))
	check(rear.state.velocity.y < all.state.velocity.y,"stronger launch retains a real rear-axle traction ceiling")
	for tick: int in range(1800): rear.step(DriveFrame.sample(0,1,0))
	check(rear.state.velocity.length() <= current.maximum_speed and absf(current.maximum_speed*3.6-190.0)<0.001,"electric obeys the owner-requested 190 km/h cap")
	for direction: int in [0,255]:
		var ordinary := VehicleSimulation.new(current)
		var requested := VehicleSimulation.new(current)
		for tick: int in range(720):
			ordinary.step(DriveFrame.sample(sin(tick*0.015),1 if tick<360 else 0,direction/255.0))
			requested.step(DriveFrame.sample(sin(tick*0.015),1 if tick<360 else 0,direction/255.0,1))
		check(ordinary.state.snapshot() == requested.state.snapshot(),"powerful tune still has no handbrake, direction="+str(direction))
	# One-pedal brake blending leaves all six other cars' actual sampled states
	# byte-for-byte equivalent to the retained earlier integrator.
	var source := GDScript.new()
	source.source_code = FileAccess.get_file_as_string(OUTPUT+"/before/game__vehicle__vehicle_simulation.gd.txt").replace("class_name VehicleSimulation","").trim_prefix("\ufeff")
	check(source.reload() == OK,"task-start integrator compiles for exact comparison")
	for id: String in VehicleCatalog.IDS:
		if id == "electric": continue
		var config: HandlingConfig = VehicleCatalog.config(id)
		var before: RefCounted = source.new(config)
		var after := VehicleSimulation.new(config)
		var exact: bool = true
		for tick: int in range(1200):
			var frame := DriveFrame.sample(sin(tick*0.02),1 if tick%240<150 else 0,0.7 if tick%240>200 else 0,1 if tick%120<10 else 0)
			before.step(frame)
			after.step(frame)
			exact = exact and before.state.snapshot() == after.state.snapshot()
		check(exact,id+" retains every task-start tick")
	print("ELECTRIC_POWER_METRICS ",JSON.stringify(metrics))
	var report := FileAccess.open(output+"/power.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	report.close()
	print("ELECTRIC_POWER: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
