extends SceneTree
## Headless regression and integration checks; no framework/runtime dependency.

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: " + description)


func advance(sim: VehicleSimulation, count: int, steering: float, gas: float, brake: float) -> void:
	var frame: DriveFrame = DriveFrame.sample(steering, gas, brake)
	for i: int in range(count):
		sim.step(frame)


## Distance travelled / velocity-direction change measures the path, not body yaw.
func corner_radius(config: HandlingConfig, speed: float) -> float:
	var car := VehicleSimulation.new(config)
	car.state.velocity = Vector2(0, speed)
	var distance: float = 0.0
	for i: int in range(600):
		var previous: Vector2 = car.state.position
		car.step(DriveFrame.sample(1, 0.5, 0))
		distance += car.state.position.distance_to(previous)
		var direction: float = atan2(car.state.velocity.x, car.state.velocity.y)
		if direction >= PI * 0.5:
			return distance / direction
	return INF


func _run() -> void:
	var config := HandlingConfig.new()
	var legacy := config.duplicate() as HandlingConfig
	legacy.engine_force = 10500.0
	legacy.maximum_speed = 34.0
	legacy.corner_energy_retention = 0.0
	legacy.rear_grip = 0.95
	legacy.throttle_rotation = 0.35
	legacy.throttle_grip_loss = 0.12
	legacy.steering_rate = 8.0
	legacy.steering_angle = 0.52
	legacy.high_speed_steering_reduction = 0.8
	legacy.lateral_grip = 16.0
	legacy.sliding_grip = 0.72
	legacy.lateral_response = 9.0
	legacy.rotational_inertia = 1300.0
	legacy.maximum_yaw_rate = 2.6
	for speed: float in [12.0, 18.0, 24.0]:
		var old_radius: float = corner_radius(legacy, speed)
		var new_radius: float = corner_radius(config, speed)
		print("METRIC: quarter-turn at %.0f km/h, effective radius %.2fm -> %.2fm" % [speed * 3.6, old_radius, new_radius])
		check(is_finite(new_radius) and new_radius < old_radius * 0.75, "actual turning path at %.0f km/h is at least 25%% tighter" % (speed * 3.6))
	var sim := VehicleSimulation.new(config)
	var old_corner := config.duplicate() as HandlingConfig
	old_corner.corner_energy_retention = 0.0
	var old_coast := VehicleSimulation.new(old_corner)
	var new_coast := VehicleSimulation.new(config)
	old_coast.state.velocity = Vector2(0, 30)
	new_coast.state.velocity = old_coast.state.velocity
	advance(old_coast, 120, 0.6, 0, 0)
	advance(new_coast, 120, 0.6, 0, 0)
	print("METRIC: 108 km/h coasting turn after 1s: %.1f -> %.1f km/h" % [old_coast.state.velocity.length() * 3.6, new_coast.state.velocity.length() * 3.6])
	# Owner requested a middle ground after the 85% retention iteration.
	check(new_coast.state.velocity.length() > old_coast.state.velocity.length() + 1.0 and new_coast.state.velocity.length() < 28.3, "cornering retains some speed while still scrubbing at least 6 km/h")
	check(new_coast.state.velocity.dot(new_coast.state.forward()) > old_coast.state.velocity.dot(old_coast.state.forward()), "corner retention improves forward speed as well as total speed")
	var energy_run := VehicleSimulation.new(config)
	energy_run.state.velocity = Vector2(8, 30)
	var no_boost: bool = true
	for i: int in range(1200):
		var before: float = energy_run.state.velocity.length_squared()
		energy_run.step(DriveFrame.sample(sin(i * 0.03), 0, 0))
		no_boost = no_boost and energy_run.state.velocity.length_squared() <= before + 0.001
	check(no_boost, "steering and slide recovery never create energy without throttle")
	advance(sim, 600, 0, 0, 0)
	check(sim.state.position == Vector2.ZERO and sim.state.heading == 0, "idle has no creep or stationary steering")
	advance(sim, 360, 0, 1, 0)
	print("METRIC: speed after 3 seconds = %.2f m/s" % sim.state.velocity.length())
	check(sim.state.velocity.y > 20.0 and absf(sim.state.velocity.x) < 0.001, "throttle accelerates along car heading")
	advance(sim, 3000, 0, 1, 0)
	check(sim.state.velocity.length() <= config.maximum_speed + 0.001, "forward speed cap")
	print("METRIC: achieved top speed = %.1f km/h" % (sim.state.velocity.length() * 3.6))
	check(sim.state.velocity.length() >= 45.9, "full throttle reaches the increased top speed")
	var acceleration_times: Array[float] = []
	for setup: HandlingConfig in [legacy, config]:
		var sprint := VehicleSimulation.new(setup)
		while sprint.state.velocity.length() < 100.0 / 3.6 and sprint.state.tick < 1200:
			sprint.step(DriveFrame.sample(0, 1, 0))
		acceleration_times.append(sprint.state.tick * VehicleSimulation.STEP)
	print("METRIC: 0-100 km/h %.2fs -> %.2fs" % [acceleration_times[0], acceleration_times[1]])
	check(acceleration_times[1] < acceleration_times[0] * 0.75, "0-100 acceleration is at least 25% quicker")
	var fast_turn := VehicleSimulation.new(config)
	fast_turn.state.velocity = Vector2(0, config.maximum_speed)
	advance(fast_turn, 120, 0.35, 0, 0)
	check(fast_turn.state.velocity.x > 10.0 and fast_turn.state.position.is_finite(), "steering changes travel direction from the new top speed")
	advance(fast_turn, 240, 0, 0, 0)
	check(absf(fast_turn.state.slip_angle()) < 0.04, "high-speed turn recovers after lifting and centering")
	var lighter := VehicleSimulation.new(config.duplicate() as HandlingConfig)
	var heavier := VehicleSimulation.new(config.duplicate() as HandlingConfig)
	heavier.config.mass *= 1.5
	advance(lighter, 120, 0, 1, 0)
	advance(heavier, 120, 0, 1, 0)
	check(lighter.state.velocity.length() > heavier.state.velocity.length(), "mass changes acceleration under identical engine force")
	var braking := VehicleSimulation.new(config)
	var coasting := VehicleSimulation.new(config)
	braking.state.velocity = Vector2(0, 24)
	coasting.state.velocity = Vector2(0, 24)
	advance(braking, 160, 0, 0, 1)
	advance(coasting, 160, 0, 0, 0)
	print("METRIC: 1.33s braking %.2fm, coasting %.2fm" % [braking.state.position.y, coasting.state.position.y])
	check(braking.state.velocity.length() < 2.0 and braking.state.position.y < coasting.state.position.y * 0.65, "braking materially reduces stopping distance")
	var reverse := VehicleSimulation.new(config)
	advance(reverse, 20, 0, 0, 1)
	check(reverse.state.velocity == Vector2.ZERO, "reverse requires a stopped hold delay")
	advance(reverse, 250, 0, 0, 1)
	check(reverse.state.velocity.y < -2.0 and reverse.state.velocity.length() <= config.reverse_speed, "held brake engages bounded reverse")
	advance(reverse, 120, 0, 1, 0)
	check(reverse.state.velocity.y >= 0.0, "throttle brakes reverse before accelerating forward")
	var both := VehicleSimulation.new(config)
	advance(both, 300, 1, 1, 1)
	check(both.state.position == Vector2.ZERO, "brake wins simultaneous pedals at rest; no stationary rotation")
	var turning := VehicleSimulation.new(config)
	turning.state.velocity = Vector2(0, 18)
	advance(turning, 30, 1, 0.5, 0)
	check(turning.state.yaw_rate > 0.2 and turning.state.heading > 0, "right steering rotates clockwise promptly")
	advance(turning, 60, -1, 0.5, 0)
	check(turning.state.yaw_rate < -0.2, "countersteering reverses yaw")
	var rearward := VehicleSimulation.new(config)
	rearward.state.velocity = Vector2(0, -5)
	advance(rearward, 30, 1, 0, 0)
	check(rearward.state.heading < 0, "reverse reverses steering direction")
	var sliding := VehicleSimulation.new(config)
	sliding.state.velocity = Vector2(8, 18)
	sliding.state.grip = config.sliding_grip
	var initial_slip: float = absf(sliding.state.slip_angle())
	advance(sliding, 180, 0, 0, 0)
	print("METRIC: released slide %.1f -> %.1f degrees" % [rad_to_deg(initial_slip), rad_to_deg(sliding.state.slip_angle())])
	check(absf(sliding.state.slip_angle()) < 0.04 and sliding.state.grip > 0.99, "lifting and centering steering recovers a seeded slide")
	var powered := VehicleSimulation.new(config)
	var lifted := VehicleSimulation.new(config)
	powered.state.velocity = Vector2(0, 24)
	lifted.state.velocity = powered.state.velocity
	advance(powered, 100, 0.8, 1, 0)
	advance(lifted, 100, 0.8, 0, 0)
	print("METRIC: corner slip power %.1f°, lift %.1f°" % [rad_to_deg(powered.state.slip_angle()), rad_to_deg(lifted.state.slip_angle())])
	# Speculative reference tune: throttle pulls toward the nose rather than
	# artificially rotating the rear. Compare the same seeded slide, no steering.
	var pull := VehicleSimulation.new(config)
	var coast_slide := VehicleSimulation.new(config)
	pull.state.velocity = Vector2(8, 18)
	coast_slide.state.velocity = pull.state.velocity
	advance(pull, 12, 0, 1, 0)
	advance(coast_slide, 12, 0, 0, 0)
	check(absf(pull.state.slip_angle()) < absf(coast_slide.state.slip_angle()) and pull.state.heading == 0, "throttle pulls a slide toward the nose without automatic rotation")
	var tap := VehicleSimulation.new(config)
	tap.state.velocity = Vector2(0, 18)
	advance(tap, 6, 1, 0, 0)
	check(tap.state.steering == 1.0 and tap.state.heading > 0.015, "50ms steering tap promptly rotates the chassis")
	check(tap.state.heading > atan2(tap.state.velocity.x, tap.state.velocity.y) + 0.005, "trajectory lags behind chassis rotation")
	check(absf(powered.state.slip_angle()) < deg_to_rad(18.0), "powered corner stays below 18 degrees slip instead of the previous 27")
	var yard := PlaygroundData.new()
	var hit := VehicleState.new()
	hit.position = Vector2(90, 0)
	hit.velocity = Vector2(30, 6)
	var energy: float = hit.velocity.length_squared()
	yard.resolve(hit, Vector2(45, 0), config)
	check(hit.position.x <= yard.half_extent.x - config.collision_radius and hit.velocity.x < 0, "wall confines and reflects car")
	check(hit.velocity.length_squared() < energy and hit.collision_count == 1, "collision loses energy and increments contact count")
	var sweep := VehicleState.new()
	sweep.position = Vector2(-3, 10)
	sweep.velocity = Vector2(40, 0)
	yard.resolve(sweep, Vector2(-43, 10), config)
	check(sweep.position.x < -29 and sweep.velocity.x < 0, "swept island collision prevents tunnelling across an entire obstacle")
	var embedded := VehicleState.new()
	embedded.position = Vector2(-23, 10)
	yard.resolve(embedded, embedded.position, config)
	check(embedded.position.distance_to(Vector2(-23, 10)) >= 6.55, "overlap recovery remains finite at island centre")
	var logs: Array[DriveFrame] = []
	for i: int in range(2400):
		logs.append(DriveFrame.sample(sin(i * 0.013), 0.8, 1.0 if i % 500 > 430 else 0.0))
	var reference := VehicleSimulation.new(config)
	reference.reset(yard.spawn)
	var recorder := HandlingRecorder.new()
	recorder.start(reference, yard)
	for input: DriveFrame in logs:
		reference.step(input, yard)
		recorder.append(input, reference.state)
	# Roundtrip quantized control data through JSON; vary ticks consumed per render.
	var decoded: Array = JSON.parse_string(JSON.stringify(recorder.frames))
	for batch: int in [1, 2, 4, 8]:
		var replay := VehicleSimulation.new(config)
		replay.reset(yard.spawn)
		for start: int in range(0, decoded.size(), batch):
			for i: int in range(start, mini(start + batch, decoded.size())):
				var input := DriveFrame.new()
				input.steer = int(decoded[i][0])
				input.throttle = int(decoded[i][1])
				input.brake = int(decoded[i][2])
				replay.step(input, yard)
		check(replay.state.snapshot() == reference.state.snapshot(), "exact same-engine replay after JSON roundtrip, ticks/render=%d" % batch)
	check(recorder.checkpoints.size() == 20 and recorder.header.handling.mass == config.mass, "capture includes quantized ticks, state checkpoints and full handling config")
	var test_path: String = "user://test_handling_capture.json"
	check(recorder.save(reference.state, test_path) == OK, "diagnostic recording saves successfully")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(test_path))
	check(saved.inputs.size() == 2400 and saved.manifest.physics_version == VehicleSimulation.PHYSICS_VERSION and saved.final_state[9] == 2400, "saved capture contains run identity, all inputs and final tick")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	print("REPLAY: 2400 ticks, zero same-engine state divergence; Android NOT TESTED")
	for path: String in ["res://resources/stable.tres", "res://resources/balanced.tres", "res://resources/loose.tres"]:
		var preset := VehicleSimulation.new(load(path) as HandlingConfig)
		preset.reset(yard.spawn)
		for input: DriveFrame in logs:
			preset.step(input, yard)
		check(preset.state.position.is_finite() and preset.state.velocity.length() <= preset.config.maximum_speed + 0.01, "bounded mixed-input run: " + preset.config.profile_name)
	await _integration()
	print("DRIVING_TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _integration() -> void:
	var scene: Node = load("res://core/game.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var input: DriverInput = scene.get("driver")
	var sim: VehicleSimulation = scene.get("sim")
	Input.action_press("accelerate")
	for i: int in range(30):
		await physics_frame
	check(sim.state.velocity.length() > 1, "main scene samples keyboard actions into canonical simulation")
	scene.call("toggle_pause")
	var paused_tick: int = sim.state.tick
	for i: int in range(4):
		await physics_frame
	check(sim.state.tick == paused_tick and input.sample().throttle == 0, "pause stops physics and releases keyboard input")
	scene.call("toggle_pause")
	input.set_touch(1, &"steer_left")
	input.set_touch(2, &"accelerate")
	input.set_touch(3, &"brake")
	var sample: DriveFrame = input.sample()
	check(sample.steer == -127 and sample.throttle == 255 and sample.brake == 255, "three simultaneous touch inputs survive sampling")
	input.release_touch(1)
	check(input.sample().steer == 0 and input.sample().throttle == 255, "releasing one finger preserves the other pedal")
	var hud: PlaygroundHUD = scene.get("hud")
	var canceled := InputEventScreenTouch.new()
	canceled.index = 2
	canceled.pressed = true
	canceled.canceled = true
	hud.touch._input(canceled)
	check(input.sample().throttle == 0, "canceled touch safely releases its pedal")
	input.set_touch(4, &"accelerate")
	var drag := InputEventScreenDrag.new()
	drag.index = 4
	drag.position = Vector2(600, 300)
	hud.touch._input(drag)
	check(input.sample().throttle == 0, "dragging outside touch zone releases action")
	scene.call("_notification", Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(bool(scene.get("paused")) and input.touches.is_empty(), "focus loss pauses and releases all fingers")
	scene.call("restart")
	check(sim.state.tick == 0 and sim.state.velocity == Vector2.ZERO and sim.state.position == Vector2(0, -35), "restart restores identical initial state immediately")
	scene.call("select_profile", 2)
	check(sim.config.profile_name == "Loose" and sim.state.tick == 0, "profile switch updates simulation and resets")
	var profile_buttons: Node = hud.tune_fields.get_child(1)
	profile_buttons.get_child(0).emit_signal("pressed")
	check(sim.config.profile_name == "Stable", "on-screen preset button selects its own bound index")
	hud._change_setting(18.5, "lateral_grip")
	check(sim.config.lateral_grip == 18.5 and sim.state.tick == 0, "live tuning writes active handling and resets the run")
	var camera: FollowCamera = scene.get("camera")
	for heading: float in [0.0, PI * 0.5, PI, -PI * 0.5]:
		camera.follow(Vector2.ZERO, Vector2(sin(heading), cos(heading)) * sim.config.maximum_speed, heading, 0.0, true)
		var screen: Vector2 = camera.unproject_position(Vector3.ZERO)
		var viewport: Vector2 = root.get_visible_rect().size
		check(screen.x > viewport.x * 0.15 and screen.x < viewport.x * 0.85 and screen.y > viewport.y * 0.15 and screen.y < viewport.y * 0.85, "camera retains player at heading %.0f degrees" % rad_to_deg(heading))
	scene.queue_free()
	await process_frame
