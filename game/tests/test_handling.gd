extends SceneTree
## Behavioral acceptance for the 2026-09-14 handling slice, same-engine only.
const _NATIVE_TRACK = preload("res://track/native_track.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: " + description)

func car(config: HandlingConfig, speed: float = 24.0) -> VehicleSimulation:
	var result := VehicleSimulation.new(config)
	result.state.velocity = Vector2(0, speed)
	return result

func advance(sim: VehicleSimulation, ticks: int, steer: float, throttle: float, brake: float) -> void:
	for tick: int in range(ticks):
		sim.step(DriveFrame.sample(steer, throttle, brake))

func _run() -> void:
	var config := HandlingConfig.new()
	var input_car := car(config)
	advance(input_car, 1, 1, 0, 0)
	check(input_car.state.heading > 0 and input_car.state.steering > 0, "steering responds on the first 120 Hz tick")
	advance(input_car, 17, 1, 0, 0)
	check(input_car.state.steering == 1.0, "full digital lock within 150 ms")
	advance(input_car, 6, -1, 0, 0)
	check(absf(input_car.state.steering) < 0.01, "reversal crosses centre within 50 ms")
	advance(input_car, 18, -1, 0, 0)
	check(input_car.state.yaw_rate < 0, "countersteering catches and reverses yaw")
	var gentle := car(config, 18)
	advance(gentle, 90, 0.3, 0.5, 0)
	check(absf(gentle.state.slip_angle()) < deg_to_rad(6), "gentle powered bend remains planted below six degrees slip")
	var radii: Array[float] = []
	for speed: float in [18.0, 36.0]:
		var corner := car(config, speed)
		advance(corner, 30, 1, 0, 0)
		var velocity_angle: float = atan2(corner.state.velocity.x, corner.state.velocity.y)
		radii.append(corner.state.position.length() / velocity_angle)
	print("HANDLING_METRIC entry radii 18/36 m/s: ", radii)
	check(radii[1] > radii[0] * 1.5, "excess entry speed runs wider rather than granting the same turning radius")
	var preset_slips: Array[float] = []
	for path: String in ["stable", "balanced", "loose"]:
		var tune: HandlingConfig = load("res://resources/" + path + ".tres")
		check(tune.engine_force == config.engine_force and tune.maximum_speed == config.maximum_speed, tune.profile_name + " keeps identical power and top speed")
		var trail := car(tune)
		var no_rotation: HandlingConfig = tune.duplicate() as HandlingConfig
		no_rotation.brake_rotation = 0.0
		no_rotation.brake_grip_loss = 0.0
		var control := car(no_rotation)
		advance(trail, 36, 0.85, 0, 0.65)
		advance(control, 36, 0.85, 0, 0.65)
		var degrees: float = absf(rad_to_deg(trail.state.slip_angle()))
		preset_slips.append(degrees)
		print("HANDLING_METRIC ", tune.profile_name, " trail slip=", degrees, " heading gain=", rad_to_deg(trail.state.heading - control.state.heading))
		check(trail.state.heading > control.state.heading + 0.015 and degrees < 25, tune.profile_name + " trail brake adds bounded intentional rotation")
		advance(trail, 180, 0, 0.6, 0)
		check(absf(trail.state.slip_angle()) < 0.02, tune.profile_name + " unwinding catches the slide and accelerates away")
	check(preset_slips[0] < preset_slips[1] and preset_slips[1] < preset_slips[2], "Planted / Balanced / Playful give progressively stronger short slides")
	var clean := car(config)
	var sideways := car(config)
	sideways.state.velocity = Vector2(12, sqrt(24.0 * 24.0 - 144.0))
	var clean_before: float = clean.state.velocity.length()
	var slide_before: float = sideways.state.velocity.length()
	advance(clean, 24, 0, 1, 0)
	advance(sideways, 24, 0.8, 1, 0)
	check(clean.state.velocity.length() - clean_before > sideways.state.velocity.length() - slide_before, "straight clean exit gains more speed than powering through a slide")
	for mode: int in range(3):
		var abuse := car(config, 36)
		var safe: bool = true
		for tick: int in range(1800):
			var before: float = abuse.state.velocity.length_squared()
			abuse.step(DriveFrame.sample(sin(tick * 0.09), 1.0 if mode == 2 else 0.0, 1.0 if mode > 0 and tick % 12 < 6 else 0.0))
			safe = safe and abuse.state.position.is_finite() and absf(abuse.state.yaw_rate) <= config.maximum_yaw_rate
			if mode != 2:
				safe = safe and abuse.state.velocity.length_squared() <= before + 0.001
		check(safe, "brake-tap / steering abuse stays bounded, no coasting energy gain, mode %d" % mode)
	var full_lock := car(config)
	advance(full_lock, 1200, 1, 1, 0)
	print("HANDLING_METRIC full-lock power speed=", full_lock.state.velocity.length(), " slip=", rad_to_deg(full_lock.state.slip_angle()))
	check(full_lock.state.velocity.length() < config.maximum_speed * 0.8 and absf(full_lock.state.slip_angle()) < deg_to_rad(30), "held throttle/full lock scrubs speed without an unavoidable spin")
	_baseline()
	_replays()
	_recovery_and_feedback()
	print("HANDLING_TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _recovery_and_feedback() -> void:
	var config := HandlingConfig.new()
	var unassisted: HandlingConfig = config.duplicate() as HandlingConfig
	unassisted.countersteer_assistance = 0.0
	var catches: Array[float] = []
	for tune: HandlingConfig in [config, unassisted]:
		var slide := car(tune)
		slide.state.velocity = Vector2(-8, 24)
		slide.state.yaw_rate = 2.0
		slide.state.steering = 0.8
		advance(slide, 12, -0.6, 0, 0)
		catches.append(slide.state.heading)
	print("HANDLING_METRIC countersteer heading overshoot assisted/unassisted=", catches)
	check(catches[0] < catches[1], "countersteer assistance reduces unwanted yaw during a seeded slide")
	var mirror_left := car(config)
	var mirror_right := car(config)
	for tick: int in range(120):
		mirror_left.step(DriveFrame.sample(-0.8, 0, 0.6))
		mirror_right.step(DriveFrame.sample(0.8, 0, 0.6))
	check(absf(mirror_left.state.position.x + mirror_right.state.position.x) < 0.0001 and absf(mirror_left.state.heading + mirror_right.state.heading) < 0.0001, "trail-brake response is left/right symmetric")
	var straight := car(config)
	straight.state.steering = 1.0
	check(TireAudio.scrub_amount(straight.state) == 0, "steering input alone does not produce tyre scrub")
	straight.state.velocity = Vector2(5, 20)
	var before: Array = straight.state.snapshot()
	var scrub: float = TireAudio.scrub_amount(straight.state)
	check(scrub > 0.5 and straight.state.snapshot() == before, "actual slip produces feedback without mutating canonical state")
	straight.state.jump_height = 1.0
	check(TireAudio.scrub_amount(straight.state) == 0, "airborne tyres are silent")
	var player := TireAudio.new()
	player.loudness = 1.0
	player.present(straight.state, 0.016, false)
	check(player.loudness == 0.0, "takeoff immediately silences the audio envelope")
	straight.state.jump_height = 0.0
	player.present(straight.state, 0.1, false)
	check(player.loudness > 0.0, "grounded slip raises audio volume")
	player.present(straight.state, 0.016, true)
	check(player.loudness == 0.0, "pause/countdown immediately silence the audio envelope")
	player.free()
	var sample: AudioStreamWAV = TireAudio.make_scrub()
	var peak: int = 0
	for index: int in range(sample.loop_end):
		peak = maxi(peak, absi(sample.data.decode_s16(index * 2)))
	check(peak > 1000 and peak < 32767 and sample.data.decode_s16(0) == 0 and sample.data.decode_s16(sample.data.size() - 2) == 0, "original scrub sample is nonempty, unclipped and has silent loop endpoints")

func _baseline() -> void:
	var golden: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/handling_baseline.json"))
	var sim := VehicleSimulation.new(load("res://resources/baseline.tres") as HandlingConfig)
	var largest_error: float = 0.0
	for tick: int in range(1200):
		sim.step(DriveFrame.sample(sin(tick * 0.019), 0.8, 0.7 if tick % 240 > 180 else 0.0))
		if (tick + 1) % 120 == 0:
			var actual: Array = sim.state.snapshot()
			var expected: Array = golden.checkpoints[(tick + 1) / 120 - 1]
			for index: int in range(14):
				largest_error = maxf(largest_error, absf(float(actual[index]) - float(expected[index])))
	print("HANDLING_METRIC baseline max scalar error=", largest_error)
	check(largest_error < 0.00001, "Baseline reproduces pre-change recorded checkpoints within JSON precision")

func _replays() -> void:
	for name: String in ["stable", "balanced", "loose", "baseline"]:
		var config: HandlingConfig = load("res://resources/" + name + ".tres")
		var frames: Array = []
		var reference := car(config)
		for tick: int in range(2400):
			var frame := DriveFrame.sample(sin(tick * 0.031), 0.8, 0.7 if tick % 240 > 180 else 0.0)
			frames.append([frame.steer, frame.throttle, frame.brake])
			reference.step(frame)
		var decoded: Array = JSON.parse_string(JSON.stringify(frames))
		for batch: int in [1, 2, 4, 8]:
			var replay := car(config)
			for start: int in range(0, decoded.size(), batch):
				for index: int in range(start, mini(start + batch, decoded.size())):
					var frame := DriveFrame.new()
					frame.steer = int(decoded[index][0])
					frame.throttle = int(decoded[index][1])
					frame.brake = int(decoded[index][2])
					replay.step(frame)
			check(replay.state.snapshot() == reference.state.snapshot(), "%s exact JSON replay, %d ticks/render" % [name, batch])
