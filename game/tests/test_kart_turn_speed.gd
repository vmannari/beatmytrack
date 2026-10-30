extends SceneTree
## Exercise the actual simulation at full power, including entry and exit.

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: ", label)


func run_turn(config: HandlingConfig, steer: float, start_kph: float, turn_ticks: int, release_ticks: int = 0) -> Dictionary:
	var sim := VehicleSimulation.new(config)
	sim.state.velocity = Vector2(0.0, start_kph / 3.6)
	var samples: Array[float] = []
	var frames: Array = []
	for tick: int in range(turn_ticks + release_ticks):
		var frame := DriveFrame.sample(steer if tick < turn_ticks else 0.0, 1.0, 0.0)
		frames.append(frame)
		sim.step(frame)
		samples.append(sim.state.velocity.length() * 3.6)
	var snapshot: Array = sim.state.snapshot()
	var replay := VehicleSimulation.new(config)
	replay.state.velocity = Vector2(0.0, start_kph / 3.6)
	for start: int in range(0, frames.size(), 4):
		for index: int in range(start, mini(start + 4, frames.size())):
			replay.step(frames[index])
	return {"samples": samples, "replay_exact": snapshot == replay.state.snapshot()}


func run() -> void:
	var kart: HandlingConfig = load("res://resources/cars/kart.tres")
	var control: HandlingConfig = kart.duplicate() as HandlingConfig
	control.turn_speed_reduction = 0.0
	check(is_equal_approx(kart.turn_speed_reduction, 1.0 / 7.0), "kart uses the requested high-speed turn reduction")
	var pickup: HandlingConfig = load("res://resources/cars/pickup.tres")
	check(pickup.turn_speed_reduction == 0.0 and not pickup.snapshot().has("turn_speed_reduction"), "other cars retain the zero setting and their established configuration identity")
	for mode: int in range(4):
		var before := VehicleSimulation.new(control)
		var after := VehicleSimulation.new(kart)
		if mode == 1 or mode == 2:
			before.state.velocity = Vector2(0.0, kart.maximum_speed)
			after.state.velocity = before.state.velocity
		var equal := true
		for tick: int in range(1800):
			var frame := DriveFrame.sample(0.0, 1.0 if mode == 0 else 0.0, 1.0 if mode == 1 or mode == 3 else 0.0)
			before.step(frame)
			after.step(frame)
			equal = equal and before.state.snapshot() == after.state.snapshot()
		check(equal, "straight acceleration, braking, coast and reverse remain exact, mode %d" % mode)
		if mode == 0:
			check(absf(after.state.velocity.length() * 3.6 - 140.0) < 0.01, "straight-line maximum speed remains 140 km/h")
	var full := run_turn(kart, 1.0, 140.0, 1200, 1200)
	var mirror := run_turn(kart, -1.0, 140.0, 1200)
	var partial := run_turn(kart, 0.5, 140.0, 1200)
	var unchanged := run_turn(control, 1.0, 140.0, 1200)
	var low := run_turn(kart, 1.0, 40.0, 120)
	var low_control := run_turn(control, 1.0, 40.0, 120)
	var speeds: Array = full.samples
	var first := float(speeds[0])
	var second := float(speeds[119])
	var later := float(speeds[1199])
	var partial_final := float(partial.samples[1199])
	var old_final := float(unchanged.samples[1199])
	check(first > 139.5, "turn entry does not abruptly clamp speed")
	check(second < first and second > later, "speed decreases gradually after turning begins")
	check(later >= 118.0 and later <= 122.0, "sustained full turn settles near 120 km/h")
	check(old_final > later + 2.0, "sustained full turn is slower than the previous tune")
	check(partial_final > later and partial_final < old_final, "partial steering has an intermediate speed")
	check(absf(float(mirror.samples[1199]) - later) < 0.001, "left and right turn speed matches")
	check(absf(float(low.samples[119]) - float(low_control.samples[119])) < 0.001, "low-speed turn is unaffected")
	check(float(speeds[2399]) > later + 2.0 and float(speeds[2399]) > 139.0, "straightening restores straight-line speed")
	check(full.replay_exact and mirror.replay_exact and partial.replay_exact, "recorded inputs replay exactly at 120 Hz and 30 Hz presentation")
	for braking: bool in [false, true]:
		var sim := VehicleSimulation.new(kart)
		sim.state.velocity = Vector2(0.0, 140.0 / 3.6)
		var monotonic := true
		for tick: int in range(60):
			var previous_speed: float = sim.state.velocity.length()
			sim.step(DriveFrame.sample(1.0, 0.0, 1.0 if braking else 0.0))
			monotonic = monotonic and sim.state.velocity.length() <= previous_speed + 0.00001
		check(monotonic, "no speed is added above the turn target while %s" % ("braking" if braking else "coasting"))
	print("KART_TURN_SPEED first=%.3f one_second=%.3f full=%.3f half=%.3f control=%.3f exit=%.3f" % [first, second, later, partial_final, old_final, speeds[2399]])
	print("KART_TURN_SPEED: %d checks, %d failures" % [checks, failures])
	quit.call_deferred(1 if failures else 0)
