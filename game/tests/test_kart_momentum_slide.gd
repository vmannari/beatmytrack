extends SceneTree

var checks: int = 0
var failures: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", message)

func trace(config: HandlingConfig, kph: float, steer: float, pedal: float, ticks: int) -> Dictionary:
	var sim := VehicleSimulation.new(config)
	sim.state.velocity = Vector2(0, kph / 3.6)
	var samples: Array = []
	var frames: Array[DriveFrame] = []
	var peak: float = 0.0
	for tick: int in range(ticks):
		var frame := DriveFrame.sample(steer, pedal, 0)
		frames.append(frame)
		sim.step(frame)
		peak = maxf(peak, absf(rad_to_deg(sim.state.slip_angle())))
		if tick % 6 == 5:
			samples.append([sim.state.position.x, sim.state.position.y, sim.state.heading, sim.state.velocity.x, sim.state.velocity.y])
	var replay := VehicleSimulation.new(config)
	replay.state.velocity = Vector2(0, kph / 3.6)
	for start: int in range(0, frames.size(), 4):
		for index: int in range(start, mini(start+4, frames.size())): replay.step(frames[index])
	check(replay.state.snapshot() == sim.state.snapshot(), "world-space path replays exactly")
	return {"samples": samples, "state": sim.state.snapshot(), "position": sim.state.position, "velocity": sim.state.velocity, "heading": sim.state.heading, "peak": peak, "sim": sim}

func _initialize() -> void:
	var before: HandlingConfig = load("res://tests/fixtures/kart_momentum_slide_before.tres")
	var current: HandlingConfig = VehicleCatalog.config("kart")
	var expected: HandlingConfig = before.duplicate() as HandlingConfig
	expected.version = "kart-18"
	expected.high_speed_lateral_response_scale = 1.0
	expected.high_speed_lateral_grip_scale = 0.85
	check(current.snapshot() == expected.snapshot(), "replace response-only tuning with speed-dependent tire force")
	var output: Dictionary = {}
	for pedal: float in [0.0, 1.0]:
		for steer: float in [-1.0, -0.65, 0.65, 1.0]:
			var old := trace(before, 140, steer, pedal, 120)
			var now := trace(current, 140, steer, pedal, 120)
			var old_angle: float = absf(atan2(old.velocity.x, old.velocity.y))
			var new_angle: float = absf(atan2(now.velocity.x, now.velocity.y))
			check(new_angle < old_angle, "travel turns less from the incoming movement vector")
			check(now.position.y > old.position.y, "carries farther along the incoming movement vector")
			if pedal == 1: check(now.position.y > old.position.y + 1.0, "measurable outward path instead of only a different body angle")
			check(now.peak < 22.0, "no excessive broadside slide during entry")
			print("VECTOR_ENTRY pedal=",pedal," steer=",steer," travel_deg=",[rad_to_deg(old_angle),rad_to_deg(new_angle)]," incoming_distance=",[old.position.y,now.position.y]," peak_deg=",now.peak)
			if pedal == 1 and steer == 0.65: output = {"before": old.samples, "after": now.samples}
	var previous_difference: float = -1.0
	for kph: float in [40.0, 80.0, 100.0, 120.0, 140.0]:
		var planted: HandlingConfig = current.duplicate() as HandlingConfig
		planted.high_speed_lateral_grip_scale = 1.0
		var reference := trace(planted, kph, 0.65, 0, 60)
		var now := trace(current, kph, 0.65, 0, 60)
		var difference: float = reference.position.distance_to(now.position)
		check(difference >= previous_difference - 0.00001, "outward movement increases gradually with speed")
		previous_difference = difference
		if kph <= 80: check(reference.state == now.state, "normal-speed handling remains exact")
		if kph == 100: check(difference < 0.01, "hardly any added outward movement at 100 km/h")
		print("VECTOR_SPEED kph=",kph," outward_difference_m=",difference)
	var sustained := trace(current, 140, 0.65, 1, 1200)
	check(sustained.peak < 25.0, "sustained turn stays away from a broadside spin")
	check(sustained.velocity.length() * 3.6 > 90.0, "strong turn keeps useful forward travel")
	var recovery: int = 0
	for tick: int in range(120):
		sustained.sim.step(DriveFrame.sample(0, 1, 0))
		if recovery == 0 and absf(sustained.sim.state.slip_angle()) < deg_to_rad(0.5) and absf(sustained.sim.state.yaw_rate) < 0.01: recovery = tick+1
	check(recovery > 0 and recovery <= 90, "straightening recovers within 750ms")
	print("VECTOR_SUSTAINED peak_deg=",sustained.peak," speed_kph=",sustained.velocity.length()*3.6," recovery_ms=",recovery*1000.0/120.0)
	for mode: int in range(4):
		var a := VehicleSimulation.new(before)
		var b := VehicleSimulation.new(current)
		if mode in [1, 2]: a.state.velocity = Vector2(0, before.maximum_speed)
		b.state.velocity = a.state.velocity
		for tick: int in range(1200):
			var frame := DriveFrame.sample(0, 1 if mode == 0 else 0, 1 if mode in [1, 3] else 0)
			a.step(frame)
			b.step(frame)
			check(a.state.snapshot() == b.state.snapshot(), "straight power/coast/braking/reverse remains exact")
		if mode == 0: check(absf(b.state.velocity.length()*3.6-140.0) < 0.01, "straight cap remains 140km/h")
	var coast := VehicleSimulation.new(current)
	coast.state.velocity = Vector2(0, current.maximum_speed)
	for tick: int in range(120):
		var speed: float = coast.state.velocity.length()
		coast.step(DriveFrame.sample(0.65, 0, 0))
		check(coast.state.velocity.length() <= speed + 0.00001, "grip/steering cannot add coasting energy")
	for id: String in VehicleCatalog.ALL_IDS:
		if id == "kart": continue
		var other: HandlingConfig = VehicleCatalog.config(id)
		check(other.high_speed_lateral_grip_scale == 1.0 and not other.snapshot().has("high_speed_lateral_grip_scale"), "other cars retain identity and force limits")
	var file := FileAccess.open("res://../build/kart-momentum-slide/trajectory.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(output))
	file.close()
	print("KART_MOMENTUM_HASH ", JSON.stringify(current.snapshot(), "", true).sha256_text())
	print("KART_MOMENTUM: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
