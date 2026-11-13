extends SceneTree
## KFS01-KFS03: bounded fast-corner slip, low-speed control and exact replay.

var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)

func turn(config: HandlingConfig, speed: float, steer: float) -> Dictionary:
	var sim := VehicleSimulation.new(config)
	var replay := VehicleSimulation.new(config)
	sim.state.velocity = Vector2(0, speed)
	replay.state.velocity = sim.state.velocity
	var frames: Array[DriveFrame] = []
	var peak: float = 0.0
	var slip_sum: float = 0.0
	for tick: int in range(1200):
		var frame := DriveFrame.sample(steer, 1, 0)
		frames.append(frame)
		sim.step(frame)
		peak = maxf(peak, absf(rad_to_deg(sim.state.slip_angle())))
		if tick >= 960: slip_sum += absf(rad_to_deg(sim.state.slip_angle()))
	var final: Array = sim.state.snapshot()
	for start: int in range(0, frames.size(), 4):
		for index: int in range(start, mini(start + 4, frames.size())):
			replay.step(frames[index])
	var recovery: int = 0
	for tick: int in range(120):
		sim.step(DriveFrame.sample(0, 1, 0))
		if recovery == 0 and absf(sim.state.slip_angle()) < deg_to_rad(0.5) and absf(sim.state.yaw_rate) < 0.01:
			recovery = tick + 1
	return {"peak": peak, "mean": slip_sum / 240.0, "state": final, "replay": final == replay.state.snapshot(), "recovery": recovery, "speed": replay.state.velocity.length() * 3.6}

func _initialize() -> void:
	var old: HandlingConfig = load("res://tests/fixtures/kart_fast_slide_before.tres")
	# Preserve the former response-only tune as a historical regression. Active
	# momentum/force behavior is covered by test_kart_momentum_slide.gd.
	var kart: HandlingConfig = load("res://tests/fixtures/kart_momentum_slide_before.tres")
	var expected: HandlingConfig = old.duplicate() as HandlingConfig
	expected.version = "kart-17"
	expected.high_speed_lateral_response_scale = 0.5
	check(kart.snapshot() == expected.snapshot(), "only fast lateral response and version change")
	var previous_slip: float = 0.0
	var previous_extra: float = -1.0
	var previous: HandlingConfig = load("res://tests/fixtures/kart_noticeable_slide_before.tres")
	for kph: float in [90.0, 98.0, 100.0, 105.0, 110.0, 115.0, 120.0, 125.0, 130.0, 135.0, 140.0]:
		var baseline: float = matched_speed_slip(old, kph)
		var slip: float = matched_speed_slip(kart, kph)
		var extra: float = slip - baseline
		var prior_extra: float = matched_speed_slip(previous, kph) - baseline
		check(slip > previous_slip, "corner slip grows with speed: %s" % kph)
		check(extra >= previous_extra - 0.0001, "added slide develops gradually: %s" % kph)
		check(slip < 8.0, "stronger top-speed slide stays bounded: %s" % kph)
		if kph <= 100.0: check(extra < 0.05, "hardly any added slide through 100 km/h")
		if kph >= 110.0: check(extra > prior_extra * 1.2, "stronger effect throughout the fast-speed range")
		print("KART_SPEED_SLIDE kph=%.0f slip_deg=%.3f extra_deg=%.3f" % [kph, slip, extra])
		previous_slip = slip
		previous_extra = extra
	for steer: float in [0.35, 0.65, 1.0]:
		var before := turn(old, old.maximum_speed, steer)
		var after := turn(kart, kart.maximum_speed, steer)
		var mirror := turn(kart, kart.maximum_speed, -steer)
		var prior_turn := turn(previous, previous.maximum_speed, steer)
		check(after.mean > before.mean * 1.05, "mild additional sustained slip, steer=%s" % steer)
		check(after.peak < 10.0 and after.mean < 9.0, "visible slide stays bounded, steer=%s" % steer)
		check(after.peak > prior_turn.peak * 1.2, "stronger actual corner-entry slide")
		check(after.mean > prior_turn.mean * 1.08, "stronger slide survives normal corner-speed loss")
		check(after.speed > 118.0 and after.speed < 141.0, "retains fast-corner speed")
		check(is_equal_approx(after.mean, mirror.mean) and is_equal_approx(after.speed, mirror.speed), "left/right symmetry")
		check(after.replay and mirror.replay, "exact replay with four steps per presentation frame")
		check(after.recovery > 0 and after.recovery <= 60, "straightening settles within half a second")
		print("KART_FAST_SLIDE steer=%s before_deg=%.3f after_deg=%.3f peak_deg=%.3f speed_kph=%.3f recovery_ms=%.1f" % [steer, before.mean, after.mean, after.peak, after.speed, after.recovery * 1000.0 / 120.0])
	# Low-speed turns include braking/reverse. Keep below the onset window.
	for speed: float in [-6.0, 1.0, 6.0, 15.0, 24.0]:
		for steer: float in [-1.0, -0.35, 0.0, 0.35, 1.0]:
			var a := VehicleSimulation.new(old)
			var b := VehicleSimulation.new(kart)
			a.state.velocity = Vector2(0, speed)
			b.state.velocity = a.state.velocity
			for tick: int in range(60):
				var frame := DriveFrame.sample(steer, 0, 0.2)
				a.step(frame)
				b.step(frame)
				check(a.state.snapshot() == b.state.snapshot(), "low-speed turn/brake/reverse remains exact")
	for mode: int in range(4):
		var a := VehicleSimulation.new(old)
		var b := VehicleSimulation.new(kart)
		if mode in [1, 2]: a.state.velocity = Vector2(0, old.maximum_speed)
		b.state.velocity = a.state.velocity
		for tick: int in range(1200):
			var frame := DriveFrame.sample(0, 1 if mode == 0 else 0, 1 if mode in [1, 3] else 0)
			a.step(frame)
			b.step(frame)
			check(a.state.snapshot() == b.state.snapshot(), "straight acceleration/braking/coast/reverse remains exact")
		if mode == 0: check(absf(b.state.velocity.length() * 3.6 - 140.0) < 0.01, "140 km/h straight cap retained")
	for id: String in VehicleCatalog.ALL_IDS:
		if id == "kart": continue
		var other: HandlingConfig = VehicleCatalog.config(id)
		check(other.high_speed_lateral_response_scale == 1.0 and not other.snapshot().has("high_speed_lateral_response_scale"), "other car retains config identity: " + id)
	var track := NativeTrack.read("res://resources/tracks/ellipse.json")
	var records := LocalRecords.new("user://kart_fast_slide_unused.json")
	check(records.key_for(track, kart) != records.key_for(track, old), "PB/replay contracts distinguish changed kart")
	print("KART_FAST_SLIDE_HASH ", JSON.stringify(kart.snapshot(), "", true).sha256_text())
	print("KART_FAST_SLIDE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func matched_speed_slip(config: HandlingConfig, kph: float) -> float:
	# Diagnostic speed fixture: keep direction/momentum from the real step and
	# regulate only speed, so every configuration follows the same speed sample.
	var sim := VehicleSimulation.new(config)
	var speed: float = kph / 3.6
	sim.state.velocity = Vector2(0, speed)
	for tick: int in range(600):
		sim.step(DriveFrame.sample(0.12, 0.5, 0))
		sim.state.velocity = sim.state.velocity.normalized() * speed
	return absf(rad_to_deg(sim.state.slip_angle()))
