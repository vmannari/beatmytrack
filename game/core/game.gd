extends Node
## Composition and lifecycle; canonical dynamics live in VehicleSimulation.

const PROFILE_PATHS: Array[String] = ["res://resources/stable.tres", "res://resources/balanced.tres", "res://resources/loose.tres"]
var profile_index: int = 1
var handling: HandlingConfig
var sim: VehicleSimulation
var yard := PlaygroundData.new()
var driver := DriverInput.new()
var frame := DriveFrame.new()
var recorder := HandlingRecorder.new()
var car: CarVisual
var camera: FollowCamera
var trails: SkidTrails
var hud: PlaygroundHUD
var paused: bool = false
var previous_position: Vector2
var previous_heading: float = 0.0
var demo_capture: bool = false
var capture_path: String = ""


func _ready() -> void:
	if Engine.physics_ticks_per_second != VehicleSimulation.TICK_RATE:
		push_error("Project physics rate must match the canonical 120 Hz step.")
		get_tree().quit(1)
		return
	handling = (load(PROFILE_PATHS[profile_index]) as HandlingConfig).duplicate() as HandlingConfig
	sim = VehicleSimulation.new(handling)
	var world: Node3D = $World
	var ground := PlaygroundVisual.new()
	world.add_child(ground)
	ground.build(yard)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-58, -35, 0)
	light.light_color = Color("fff1d8")
	light.light_energy = 1.0
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 100.0
	world.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("647158")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("bac8ce")
	environment.environment.ambient_light_energy = 0.35
	world.add_child(environment)
	car = CarVisual.new()
	world.add_child(car)
	trails = SkidTrails.new()
	world.add_child(trails)
	camera = FollowCamera.new()
	world.add_child(camera)
	camera.current = true
	hud = PlaygroundHUD.new()
	hud.config = handling
	hud.driver = driver
	add_child(hud)
	hud.restart_requested.connect(restart)
	hud.pause_requested.connect(toggle_pause)
	hud.profile_requested.connect(select_profile)
	hud.handling_edited.connect(restart)
	hud.record_requested.connect(toggle_recording)
	restart()
	print("PLAYGROUND_READY")
	if OS.is_debug_build():
		for argument: String in OS.get_cmdline_user_args():
			if argument == "--demo":
				demo_capture = true
			if argument.begins_with("--capture="):
				capture_path = argument.trim_prefix("--capture=")
		if not capture_path.is_empty() and not demo_capture:
			_capture_frame()


func _physics_process(_delta: float) -> void:
	if sim == null or paused:
		return
	previous_position = sim.state.position
	previous_heading = sim.state.heading
	frame = driver.sample()
	if demo_capture:
		frame = DriveFrame.sample(0.7 if sim.state.tick > 190 else 0.0, 1.0, 0.0)
	sim.step(frame, yard)
	trails.sample(sim.state, frame)
	recorder.append(frame, sim.state)
	if recorder.active and recorder.frames.size() >= HandlingRecorder.LIMIT:
		_save_recording()
	if demo_capture and sim.state.tick == 400:
		demo_capture = false
		paused = true
		_capture_frame()


func _process(delta: float) -> void:
	if sim == null:
		return
	var weight: float = Engine.get_physics_interpolation_fraction() if not paused else 1.0
	var point: Vector2 = previous_position.lerp(sim.state.position, weight)
	var heading: float = lerp_angle(previous_heading, sim.state.heading, weight)
	car.present(point, heading, sim.state, frame)
	camera.follow(point, sim.state.velocity, heading, delta)
	hud.update_values(sim.state, frame, delta, paused, recorder.active)


func restart() -> void:
	recorder.active = false
	driver.clear()
	frame = DriveFrame.new()
	paused = false
	sim.reset(yard.spawn, yard.spawn_heading)
	previous_position = sim.state.position
	previous_heading = sim.state.heading
	trails.clear()
	camera.follow(sim.state.position, Vector2.ZERO, sim.state.heading, 0.0, true)
	hud.touch.enabled = true
	hud.message_label.text = "Brake before the circle. Lift and countersteer to catch a slide."


func select_profile(index: int) -> void:
	profile_index = clampi(index, 0, PROFILE_PATHS.size() - 1)
	handling = (ResourceLoader.load(PROFILE_PATHS[profile_index], "", ResourceLoader.CACHE_MODE_IGNORE) as HandlingConfig).duplicate() as HandlingConfig
	sim.config = handling
	hud.show_config(handling)
	restart()


func toggle_pause() -> void:
	paused = not paused
	driver.clear()
	frame = DriveFrame.new()
	hud.touch.enabled = not paused
	if recorder.active:
		_save_recording()
	hud.message_label.text = "PAUSED · press Esc or Pause to resume" if paused else "Resumed. Inputs released."


func toggle_recording() -> void:
	if not OS.is_debug_build():
		return
	if recorder.active:
		_save_recording()
	else:
		restart()
		recorder.start(sim, yard)


func _save_recording() -> void:
	var error: Error = recorder.save(sim.state)
	hud.message_label.text = "Saved user://handling_capture.json" if error == OK else "Capture failed: " + error_string(error)
	if error == OK:
		print("HANDLING_CAPTURE: " + ProjectSettings.globalize_path("user://handling_capture.json"))


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("restart"):
		restart()
	elif event.is_action_pressed("pause"):
		toggle_pause()
	elif event.is_action_pressed("debug_hud"):
		hud.debug_enabled = not hud.debug_enabled
	elif OS.is_debug_build() and event is InputEventKey:
		match event.physical_keycode:
			KEY_1: select_profile(0)
			KEY_2: select_profile(1)
			KEY_3: select_profile(2)
			KEY_F2: hud.toggle_tuning()
			KEY_F3: toggle_recording()
			KEY_F6: select_profile(profile_index)


func _notification(what: int) -> void:
	if sim != null and what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		if not paused:
			toggle_pause()


func _capture_frame() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Screenshot capture needs a graphical display.")
		get_tree().quit(1)
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var screenshot: Image = get_viewport().get_texture().get_image()
	var error: Error = screenshot.save_png(capture_path)
	if error != OK:
		push_error("Screenshot save failed: %s" % error_string(error))
		get_tree().quit(1)
		return
	print("CAPTURE_SAVED: " + capture_path)
	get_tree().quit()
