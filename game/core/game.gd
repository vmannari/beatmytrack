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
var track_index: int = -1
const TRACK_NAMES: Array[String] = ["slicks_freeway_test", "slicks_1way_test", "slicks_66_test", "slicks_offroad_test"]
var native_track: NativeTrack
var track_session: TrackSession
var track_ground: Node3D
var track_debug: TrackDebug
var ai_enabled: bool = false
var route_driver := RouteDriver.new()
var overview: bool = false
var capture_tick: int = 0
var bridge_presentation: BridgePresentation


func _ready() -> void:
	if Engine.physics_ticks_per_second != VehicleSimulation.TICK_RATE:
		push_error("Project physics rate must match the canonical 120 Hz step.")
		get_tree().quit(1)
		return
	handling = (load(PROFILE_PATHS[profile_index]) as HandlingConfig).duplicate() as HandlingConfig
	sim = VehicleSimulation.new(handling)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--track="):
			track_index = TRACK_NAMES.find(argument.trim_prefix("--track="))
		if argument == "--overview": overview = true
		if argument == "--ai": ai_enabled = true
		if argument.begins_with("--capture-tick="): capture_tick = int(argument.trim_prefix("--capture-tick="))
	if track_index >= 0:
		native_track = NativeTrack.read("res://resources/tracks/" + TRACK_NAMES[track_index] + ".json")
		yard = native_track
	var world: Node3D = $World
	_build_ground(world)
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
	hud.track_requested.connect(cycle_track)
	track_debug = TrackDebug.new()
	var debug_layer := CanvasLayer.new()
	debug_layer.layer = 5
	add_child(debug_layer)
	debug_layer.add_child(track_debug)
	restart()
	print("PLAYGROUND_READY")
	if OS.is_debug_build():
		for argument: String in OS.get_cmdline_user_args():
			if argument == "--demo":
				demo_capture = true
			if argument.begins_with("--capture="):
				capture_path = argument.trim_prefix("--capture=")
		if not capture_path.is_empty() and not demo_capture and capture_tick == 0:
			_capture_frame()


func _physics_process(_delta: float) -> void:
	if sim == null or paused:
		return
	previous_position = sim.state.position
	previous_heading = sim.state.heading
	frame = driver.sample()
	if ai_enabled and native_track != null:
		frame = route_driver.sample(sim.state, native_track, handling)
	if demo_capture:
		frame = DriveFrame.sample(0.7 if sim.state.tick > 190 else 0.0, 1.0, 0.0)
	sim.step(frame, yard)
	if native_track != null:
		track_session.advance(native_track, previous_position, sim.state.position, sim.state.route_index)
	trails.sample(sim.state, frame, bridge_presentation)
	recorder.append(frame, sim.state)
	if recorder.active and recorder.frames.size() >= HandlingRecorder.LIMIT:
		_save_recording()
	if demo_capture and sim.state.tick == 400:
		demo_capture = false
		paused = true
		_capture_frame()
	if capture_tick > 0 and sim.state.tick == capture_tick and not capture_path.is_empty():
		paused = true
		_capture_frame()


func _process(delta: float) -> void:
	if sim == null:
		return
	var weight: float = Engine.get_physics_interpolation_fraction() if not paused else 1.0
	var point: Vector2 = previous_position.lerp(sim.state.position, weight)
	var heading: float = lerp_angle(previous_heading, sim.state.heading, weight)
	car.present(point, heading, sim.state, frame)
	car.rotation.x = 0.0
	if native_track != null:
		var axle: Vector2 = Vector2(sin(heading), cos(heading)) * handling.wheelbase * 0.5
		var front: float = bridge_presentation.height_at(point + axle, sim.state.route_index)
		var rear: float = bridge_presentation.height_at(point - axle, sim.state.route_index)
		car.position.y = (front + rear) * 0.5
		car.rotation.x = atan2(front - rear, handling.wheelbase)
	camera.follow(point, sim.state.velocity, heading, delta)
	hud.update_values(sim.state, frame, delta, paused, recorder.active)
	track_debug.visible = overview and native_track != null
	if native_track != null:
		track_debug.track = native_track
		track_debug.state = sim.state
		track_debug.queue_redraw()
		var progress_text: String = "FINISH" if track_session.next_checkpoint == native_track.checkpoints.size() else "CP %d/%d" % [track_session.next_checkpoint + 1, native_track.checkpoints.size()]
		var status_text: String = "PAUSED" if paused else ("FINISHED - R retry" if track_session.finished else ("AI practice" if ai_enabled else "practice"))
		hud.message_label.text = "%s | Lap %d/3 | %s | %.2fs | %s | F4 overview F5 track F9 AI" % [native_track.identity, mini(3, track_session.completed_laps + 1), progress_text, track_session.elapsed_ticks / 120.0, status_text]


func restart() -> void:
	recorder.active = false
	driver.clear()
	frame = DriveFrame.new()
	paused = false
	sim.reset(yard.spawn, yard.spawn_heading)
	track_session = TrackSession.new()
	hud.title.text = "CIRCUIT / 01  ·  " + (TRACK_NAMES[track_index].trim_prefix("slicks_").trim_suffix("_test").to_upper() if native_track != null else "HANDLING YARD")
	if native_track != null:
		sim.state.route_index = native_track.nearest_route(sim.state.position)
		sim.state.track_elevated = native_track.elevated_at(sim.state.position, sim.state.route_index)
	previous_position = sim.state.position
	previous_heading = sim.state.heading
	trails.clear()
	camera.follow(sim.state.position, Vector2.ZERO, sim.state.heading, 0.0, true)
	hud.touch.enabled = true
	hud.message_label.text = "Brake before the circle. Lift and countersteer. F5: handling test tracks."


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
			KEY_F4: overview = not overview
			KEY_F7: track_debug.detail = (track_debug.detail + 1) % 3
			KEY_F5: cycle_track()
			KEY_F9:
				ai_enabled = not ai_enabled
				restart()


func _build_ground(world: Node3D) -> void:
	if native_track != null:
		var visual := NativeTrackVisual.new()
		bridge_presentation = BridgePresentation.new(native_track)
		world.add_child(visual)
		visual.build(native_track, bridge_presentation)
		track_ground = visual
	else:
		bridge_presentation = null
		var visual := PlaygroundVisual.new()
		world.add_child(visual)
		visual.build(yard)
		track_ground = visual


func cycle_track() -> void:
	track_index = (track_index + 1) % (TRACK_NAMES.size() + 1)
	track_ground.queue_free()
	native_track = NativeTrack.read("res://resources/tracks/" + TRACK_NAMES[track_index] + ".json") if track_index < TRACK_NAMES.size() else null
	yard = native_track if native_track != null else PlaygroundData.new()
	_build_ground($World)
	restart()


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
