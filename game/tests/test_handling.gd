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
	_original_slide()
	_original_laps()
	print("HANDLING_TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _original_slide() -> void:
	var original: HandlingConfig = load("res://resources/baseline.tres")
	var tune: HandlingConfig = load("res://resources/original_slide.tres")
	var refined: HandlingConfig = load("res://resources/compact_fun.tres")
	check(tune.version == "handling-0.15-original-slide" and refined.version == "handling-0.19-compact-rwd", "Original+ remains frozen while Drift+ has a distinct record identity")
	check(refined.steering_rate == 24.0 and refined.grip_recovery == 8.0 and refined.throttle_rotation == 0.25 and refined.throttle_grip_loss == 0.08, "Drift+ pins moderate rear-drive power rotation, rear traction loss and quick recovery")
	var previous_corner := car(tune)
	var refined_corner := car(refined)
	advance(previous_corner, 100, 0.8, 1, 0)
	advance(refined_corner, 100, 0.8, 1, 0)
	print("DRIFT_PLUS_METRIC powered corner slip Original+/Drift+ degrees=", [absf(rad_to_deg(previous_corner.state.slip_angle())), absf(rad_to_deg(refined_corner.state.slip_angle()))])
	check(absf(refined_corner.state.slip_angle()) > deg_to_rad(25.0) and absf(refined_corner.state.slip_angle()) < deg_to_rad(32.0), "Drift+ powered drift sits in the intended midpoint band")
	var power_oversteer := car(refined)
	var coast_turn := car(refined)
	advance(power_oversteer, 72, 0.7, 1.0, 0)
	advance(coast_turn, 72, 0.7, 0.0, 0)
	print("DRIFT_PLUS_METRIC power/coast slip and heading=", [absf(rad_to_deg(power_oversteer.state.slip_angle())), absf(rad_to_deg(coast_turn.state.slip_angle())), absf(rad_to_deg(power_oversteer.state.heading)), absf(rad_to_deg(coast_turn.state.heading))])
	check(absf(power_oversteer.state.slip_angle()) > absf(coast_turn.state.slip_angle()) + deg_to_rad(5.0), "Drift+ throttle creates clear power oversteer relative to coasting")
	check(absf(power_oversteer.state.heading) > absf(coast_turn.state.heading), "Drift+ throttle rotates the chassis more than coasting")
	advance(refined_corner, 180, 0, 0.6, 0)
	check(absf(refined_corner.state.slip_angle()) < 0.03, "Drift+ recovers after unwinding and driving out")
	var drift_locked := car(refined)
	advance(drift_locked, 1200, 1, 1, 0)
	print("DRIFT_PLUS_METRIC full-lock speed/slip=", [drift_locked.state.velocity.length(), absf(rad_to_deg(drift_locked.state.slip_angle()))])
	check(drift_locked.state.position.is_finite() and drift_locked.state.velocity.length() < refined.maximum_speed and absf(drift_locked.state.slip_angle()) < deg_to_rad(55), "Drift+ sustained full lock remains bounded below a broadside spin")
	var slides: Array[float] = []
	var push: Array[float] = []
	for config: HandlingConfig in [original, tune]:
		var corner := car(config)
		advance(corner, 100, 0.8, 1, 0)
		slides.append(absf(rad_to_deg(corner.state.slip_angle())))
		var gas := car(config)
		var coast := car(config)
		gas.state.velocity = Vector2(8, 18)
		coast.state.velocity = gas.state.velocity
		advance(gas, 1, 0, 1, 0)
		advance(coast, 1, 0, 0, 0)
		var engine_delta: Vector2 = (gas.state.velocity - coast.state.velocity) / VehicleSimulation.STEP
		push.append(engine_delta.y)
		check(absf(engine_delta.x) < 0.0001 and gas.state.heading == 0.0, config.profile_name + " throttle adds acceleration along the nose without snapping momentum")
	print("ORIGINAL_SLIDE_METRIC powered corner slip old/new degrees=", slides, " nose-directed engine acceleration old/new=", push)
	check(slides[1] > slides[0] * 1.10 and slides[1] < slides[0] * 1.65, "Original+ adds a modest 10-65% slip increase in the same powered bend")
	check(push[1] > push[0] * 1.20, "Original+ has at least 20% stronger nose-directed engine traction during a slide")
	var old_sprint := car(original, 0)
	var new_sprint := car(tune, 0)
	advance(old_sprint, 1200, 0, 1, 0)
	advance(new_sprint, 1200, 0, 1, 0)
	check(old_sprint.state.snapshot() == new_sprint.state.snapshot(), "straight-line acceleration and top speed remain exactly Original")
	var gas := car(tune)
	var coast := car(tune)
	var brake := car(tune)
	for sim: VehicleSimulation in [gas, coast, brake]:
		sim.state.velocity = Vector2(8, 18)
	advance(gas, 30, 0, 1, 0)
	advance(coast, 30, 0, 0, 0)
	advance(brake, 30, 0, 0, 1)
	check(gas.state.velocity.y > coast.state.velocity.y and coast.state.velocity.y > brake.state.velocity.y, "nose pull requires throttle; lifting and braking reduce drive")
	check(absf(gas.state.slip_angle()) < absf(coast.state.slip_angle()), "throttle progressively pulls a slide toward the nose")
	var abuse := car(tune, 36)
	var no_boost: bool = true
	for tick: int in range(1800):
		var before: float = abuse.state.velocity.length_squared()
		abuse.step(DriveFrame.sample(sin(tick * 0.03), 0, 1.0 if tick % 60 < 6 else 0.0))
		no_boost = no_boost and abuse.state.velocity.length_squared() <= before + 0.001
	check(no_boost, "Original+ steering and brake tapping cannot create coasting energy")
	var both := car(tune, 0)
	advance(both, 300, 1, 1, 1)
	check(both.state.position == Vector2.ZERO, "Original+ simultaneous pedals at rest still brake without a boost")
	var locked := car(tune)
	advance(locked, 1200, 1, 1, 0)
	print("ORIGINAL_SLIDE_METRIC full-lock speed=", locked.state.velocity.length(), " slip=", rad_to_deg(locked.state.slip_angle()))
	check(locked.state.position.is_finite() and locked.state.velocity.length() < tune.maximum_speed * 0.8 and absf(locked.state.slip_angle()) < deg_to_rad(30), "Original+ held power/full lock remains bounded and costs speed")
	advance(locked, 180, 0, 0.6, 0)
	check(absf(locked.state.slip_angle()) < 0.02, "Original+ settles after unwinding and driving out")
	for angle: float in [-PI * 0.5, PI * 0.5, PI]:
		var directed := car(tune)
		var unpowered := car(tune)
		for sim: VehicleSimulation in [directed, unpowered]:
			sim.state.heading = angle
			sim.state.velocity = sim.state.forward() * 18.0 + sim.state.right() * 8.0
		advance(directed, 1, 0, 1, 0)
		advance(unpowered, 1, 0, 0, 0)
		var force: Vector2 = (directed.state.velocity - unpowered.state.velocity) / VehicleSimulation.STEP
		check(force.dot(directed.state.forward()) > 13.0 and absf(force.dot(directed.state.right())) < 0.001 and force.length() <= tune.engine_force / tune.mass, "slide thrust follows the rotated chassis and stays inside engine force at heading %.0f" % rad_to_deg(angle))

func _original_laps() -> void:
	var config: HandlingConfig = load("res://resources/original_slide.tres")
	for name: String in ["freeway", "1way", "66", "offroad"]:
		var track: NativeTrack = NativeTrack.read("res://tests/fixtures/legacy_tracks/slicks_" + name + "_test.json")
		var sim := VehicleSimulation.new(config)
		sim.reset(track.spawn, track.spawn_heading)
		sim.state.route_index = track.nearest_route(track.spawn)
		var session := TrackSession.new(120, 3)
		var driver := RouteDriver.new()
		var frames: Array = []
		for tick: int in range(24000):
			var frame: DriveFrame = driver.sample(sim.state, track, config)
			var previous: Vector2 = sim.state.position
			sim.step(frame, track)
			session.advance(track, previous, sim.state.position, sim.state.route_index)
			frames.append(frame.packed())
			if session.finished:
				break
		check(session.completed_laps == 3, "Original+ " + name + " completes three ordered diagnostic laps")
		check(sim.state.collision_count == 0, "Original+ " + name + " conservative driver avoids barriers")
		var replay := VehicleSimulation.new(config)
		replay.reset(track.spawn, track.spawn_heading)
		replay.state.route_index = track.nearest_route(track.spawn)
		var replay_session := TrackSession.new(120, 3)
		var decoded: Array = JSON.parse_string(JSON.stringify(frames))
		for packed: Array in decoded:
			var frame := DriveFrame.new()
			frame.steer = int(packed[0])
			frame.throttle = int(packed[1])
			frame.brake = int(packed[2])
			var previous: Vector2 = replay.state.position
			replay.step(frame, track)
			replay_session.advance(track, previous, replay.state.position, replay.state.route_index)
		check(replay.state.snapshot() == sim.state.snapshot() and replay_session.lap_times == session.lap_times, "Original+ " + name + " full race JSON replay is exact")
		print("ORIGINAL_SLIDE_LAPS ", name, " times=", session.lap_times, " contacts=", sim.state.collision_count)

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
	for name: String in ["stable", "balanced", "loose", "baseline", "original_slide", "compact_fun"]:
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
