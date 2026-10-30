extends "res://tests/test_kart_high_speed_turning.gd"
## Compare the current tune with the exact previous resource at matched speeds.

func run() -> void:
	var old: HandlingConfig = load("res://tests/fixtures/kart_realistic_turning_before.tres")
	var current: HandlingConfig = load("res://tests/fixtures/kart_final_reference/kart7.tres")
	check(old.version == "kart-6" and current.version == "kart-7", "new handling has a distinct record identity")
	var before_fields := old.snapshot()
	var after_fields := current.snapshot()
	for field: String in ["version", "steering_rate", "front_grip", "rear_grip", "corner_energy_retention"]:
		before_fields.erase(field)
		after_fields.erase(field)
	check(before_fields == after_fields, "unrelated handling remains unchanged")
	var results: Array[Dictionary] = []
	for kph: float in [20.0, 40.0, 80.0, 100.0, 120.0, 140.0]:
		for steering: float in [0.45, 1.0]:
			var before := circle(old, kph, steering)
			var after := circle(current, kph, steering)
			var mirror := circle(current, kph, -steering)
			var ratio: float = after.radius / before.radius
			var label := "%s km/h, steering %s" % [kph, steering]
			check(before.angle >= TAU and after.angle >= TAU, "complete circles: " + label)
			check(before.minimum_kph > kph * 0.98 and after.minimum_kph > kph * 0.98 and after.maximum_kph < kph * 1.02, "matched speed: " + label)
			check(ratio > 0.90 and ratio < 1.01, "bounded turning radius: " + label)
			if kph >= 80.0 and steering == 1.0: check(ratio < 0.98, "tighter fast turn: " + label)
			if kph <= 40.0: check(absf(ratio - 1.0) < 0.01, "low speed radius retained: " + label)
			check(is_equal_approx(after.radius, mirror.radius), "left and right symmetry: " + label)
			check(after.replay_exact and mirror.replay_exact, "deterministic replay: " + label)
			check(after.peak_slip_deg < 12.0 and after.recovery_ms > 0.0 and after.recovery_ms <= 350.0, "controlled slip and recovery: " + label)
			results.append({"kph": kph, "steering": steering, "before": before, "after": after, "ratio": ratio})
	for mode: int in range(4):
		var before := VehicleSimulation.new(old)
		var after := VehicleSimulation.new(current)
		if mode == 1 or mode == 2:
			before.state.velocity = Vector2(0, old.maximum_speed)
			after.state.velocity = before.state.velocity
		var exact := true
		for tick: int in range(3600):
			var frame := DriveFrame.sample(0, 1 if mode == 0 else 0, 1 if mode == 1 or mode == 3 else 0)
			before.step(frame)
			after.step(frame)
			exact = exact and before.state.snapshot() == after.state.snapshot()
		check(exact, "straight acceleration, braking, coast and reverse unchanged: " + str(mode))
	var initial := VehicleSimulation.new(current)
	initial.state.velocity = Vector2(0, 100.0 / 3.6)
	initial.step(DriveFrame.sample(1, 0, 0))
	check(initial.state.steering < 0.2, "steering builds progressively rather than reaching lock immediately")
	for tick: int in range(30): initial.step(DriveFrame.sample(1, 0, 0))
	for tick: int in range(6): initial.step(DriveFrame.sample(-1, 0, 0))
	check(initial.state.steering < 0.0, "countersteering crosses centre within 50 ms")
	var track: NativeTrack = NativeTrack.read("res://tests/fixtures/legacy_tracks/slicks_arto4_test.json")
	var records := LocalRecords.new("user://kart_realistic_identity.json")
	check(records.key_for(track, old) != records.key_for(track, current), "previous personal bests retain separate rules")
	# Isolate energy retention from the steering and grip changes at identical inputs.
	var retention_control: HandlingConfig = current.duplicate() as HandlingConfig
	retention_control.corner_energy_retention = old.corner_energy_retention
	var less_scrub := VehicleSimulation.new(retention_control)
	var more_scrub := VehicleSimulation.new(current)
	less_scrub.state.velocity = Vector2(0, 80.0 / 3.6)
	more_scrub.state.velocity = less_scrub.state.velocity
	for tick: int in range(240):
		var frame := DriveFrame.sample(0.7, 0.0, 0.0)
		less_scrub.step(frame)
		more_scrub.step(frame)
	check(more_scrub.state.velocity.length() < less_scrub.state.velocity.length(), "cornering scrub costs speed when coasting")
	var report := {"checks": checks, "failures": failures, "turns": results, "scrub_control_kph": less_scrub.state.velocity.length() * 3.6, "scrub_current_kph": more_scrub.state.velocity.length() * 3.6, "config_hash": JSON.stringify(current.snapshot(), "", true).sha256_text()}
	print("KART_REALISTIC_TURNING ", JSON.stringify(report))
	quit(1 if failures else 0)
