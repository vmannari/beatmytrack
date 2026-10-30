extends SceneTree
const _NATIVE_TRACK = preload("res://track/native_track.gd")
const OUTPUT: String = "res://../docs/evidence/electric-power-2026-10-25"
var output: String = OUTPUT
var checks: int = 0
var failures: int = 0
var metrics: Dictionary = {}

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func turn(config: HandlingConfig, speed: float, gas: float, direction: float = 1) -> Dictionary:
	var sim := VehicleSimulation.new(config)
	sim.state.velocity = Vector2(0,speed)
	var distance: float = 0
	var heading: float = 0
	var previous_angle: float = 0
	var peak: float = 0
	for tick: int in range(960):
		var previous: Vector2 = sim.state.position
		sim.step(DriveFrame.sample(direction,gas,0))
		distance += sim.state.position.distance_to(previous)
		var angle: float = atan2(sim.state.velocity.x,sim.state.velocity.y)
		heading += wrapf(angle-previous_angle,-PI,PI)
		previous_angle = angle
		peak = maxf(peak,absf(rad_to_deg(sim.state.slip_angle())))
		if heading*direction >= PI*0.5:
			return {"complete":true,"radius":distance/(heading*direction),"seconds":(tick+1)/120.0,"speed":sim.state.velocity.length(),"peak_slip":peak}
	return {"complete":false,"radius":distance/maxf(heading*direction,0.001),"speed":sim.state.velocity.length(),"peak_slip":peak}

func speed_after(config: HandlingConfig, speed: float, gas: float, seconds: float) -> float:
	var sim := VehicleSimulation.new(config)
	sim.state.velocity = Vector2(0,speed)
	for tick: int in range(roundi(seconds*120)):
		sim.step(DriveFrame.sample(1,gas,0))
	return sim.state.velocity.length()

func steering_reference(reference: HandlingConfig, current: HandlingConfig) -> HandlingConfig:
	# Isolate steering from the owner's later motor/braking/speed correction.
	# Preserve the actual old steering and grip fields for the propulsion comparison.
	var matched: HandlingConfig = reference.duplicate() as HandlingConfig
	for field: String in ["engine_force","longitudinal_grip","maximum_speed","regeneration"]:
		matched.set(field,current.get(field))
	return matched

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	var old: HandlingConfig = load(OUTPUT+"/before/turning-before.tres") as HandlingConfig
	var current: HandlingConfig = VehicleCatalog.config("electric")
	var task_start: HandlingConfig = load("res://../docs/evidence/electric-normal-track-steering-2026-10-26/before/game__resources__cars__electric.tres") as HandlingConfig
	check(old != null and old.high_speed_steering_reduction > current.high_speed_steering_reduction,"actual pre-correction steering baseline is retained")
	old = steering_reference(old,current)
	for speed: float in [20.0,24.0,36.0,current.maximum_speed]:
		for gas: float in [0.45,0.65,1.0]:
			var key: String = str(speed)+"/"+str(gas)
			metrics[key] = {"old":turn(old,speed,gas),"new":turn(current,speed,gas),"task_start":turn(task_start,speed,gas)}
			var before: Dictionary = metrics[key].old
			var after: Dictionary = metrics[key].new
			check(before.complete and after.complete,"actual velocity path completes a quarter turn: "+key)
			check(metrics[key].task_start.complete and after.radius < metrics[key].task_start.radius*0.8,"normal/high-speed path is materially tighter than the rejected electric-13 tune: "+key)
			# Earlier turn completion means less time accelerating. Compare speed
			# at the same elapsed tick, retaining the established five-percent bound.
			var matched_speed: float = speed_after(old,speed,gas,float(after.get("seconds",5.0)))
			metrics[key].old_speed_at_new_finish = matched_speed
			check(after.speed >= matched_speed*0.95 and after.speed <= current.maximum_speed+0.00001,"tighter turn retains speed at equal elapsed time: "+key)
			check(after.peak_slip < (20 if gas<0.5 else 45),"calmer rear grip avoids the initial near-broadside turn: "+key)
			var mirrored: Dictionary = turn(current,speed,gas,-1)
			check(mirrored.complete and is_equal_approx(mirrored.radius,after.radius) and is_equal_approx(mirrored.speed,after.speed),"left and right paths are symmetric: "+key)
	print("ELECTRIC_TURNING_METRICS ",JSON.stringify(metrics))
	var report := FileAccess.open(output+"/turning.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	report.close()
	print("ELECTRIC_TURNING: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
