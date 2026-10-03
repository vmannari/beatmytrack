extends SceneTree
## Camera behavior, framing and preference failures, independent of the verifier.
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + message)

func run() -> void:
	var camera := FollowCamera.new()
	camera.speed_zoom_enabled = false # Explicit fixed-framing calibration remains available.
	root.add_child(camera)
	camera.current = true
	var baseline: CameraProfile = load("res://resources/camera.tres")
	camera.set_mode("follow_car")
	check(camera.profile.pitch_degrees < baseline.pitch_degrees and camera.profile.pitch_degrees >= 40.0, "lower view remains overhead")
	check(camera.profile != baseline and not baseline.follow_heading and baseline.pitch_degrees == 56.0, "mode owns its profile and preserves baseline")
	var results: Array[float] = []
	for fps: int in [30, 60, 120]:
		camera.follow(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0, true)
		for frame: int in range(fps / 2): camera.follow(Vector2.ZERO, Vector2.ZERO, PI / 2.0, 1.0 / fps)
		results.append(camera.smoothed_yaw)
		check(camera.smoothed_yaw < -0.2 and camera.smoothed_yaw > -PI / 2.0 + 0.1, "turn follows with visible lag at %d fps" % fps)
	check(absf(results[0] - results[1]) < 0.00001 and absf(results[1] - results[2]) < 0.00001, "yaw response is independent of display rate")
	_check_rotation_limit(camera)
	camera.follow(Vector2.ZERO, Vector2.ZERO, deg_to_rad(179.0), 0.0, true)
	var previous: float = camera.smoothed_yaw
	camera.follow(Vector2.ZERO, Vector2.ZERO, deg_to_rad(-179.0), 1.0 / 60.0)
	check(absf(angle_difference(previous, camera.smoothed_yaw)) < deg_to_rad(1.0), "heading wrap takes short arc")
	camera.add_collision_impact(Vector2(16, 0))
	camera.follow(Vector2(30, -20), Vector2.ZERO, -1.0, 0.0, true)
	check(absf(angle_difference(camera.smoothed_yaw, 1.0)) < 0.00001 and camera.focus == VisualGeometry.world(Vector2(30, -20)), "restart/rewind snap resets yaw and translation together")
	check(camera.trauma == 0.0 and camera.impact_velocity == Vector2.ZERO, "snap clears impact")
	camera.set_mode("look_ahead")
	camera.follow(Vector2.ZERO, Vector2(0, 18), 0.0, 0.0, true)
	var extra: float = camera.focus.length()
	camera.set_mode("overhead")
	camera.follow(Vector2.ZERO, Vector2(0, 18), 0.0, 0.0, true)
	check(extra > camera.focus.length() + 2.0, "look-ahead shows materially more road at normal speed")
	_check_look_ahead_delay(camera)
	for dimensions: Vector2i in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1600, 720)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await process_frame
		for mode: String in CameraProfile.MODES:
			camera.set_mode(mode)
			for heading: float in [0.0, PI * 0.5, PI, PI * 1.5]:
				var forward := Vector2(sin(heading), cos(heading))
				for speed: float in [-12.0, 0.0, 18.0, 55.0]:
					camera.follow(Vector2.ZERO, forward * speed, heading, 0.0, true)
					check(camera.focus.length() <= camera.profile.maximum_look_ahead + 0.0001, "look-ahead bound " + mode)
					check(is_equal_approx(camera.size, baseline.baseline_extent / baseline.magnification), "fixed vertical magnification preserved with speed zoom off " + mode)
					if mode != "follow_car": check(is_equal_approx(camera.smoothed_yaw, deg_to_rad(baseline.world_yaw_degrees)), "world rotation fixed " + mode)
					for height: float in [0.0, 4.0]:
						var car_pixel: Vector2 = camera.unproject_position(Vector3(0, height, 0))
						check(Rect2(40, 70, dimensions.x - 80, dimensions.y - 140).has_point(car_pixel), "car stays clear of screen edges on ground/bridge " + mode)
						check(not camera.is_position_behind(Vector3(0, height, 0)), "car stays in front of camera " + mode)
					check(camera.global_basis.z.y > 0.7, "no horizon/low chase angle " + mode)
	_check_speed_zoom(camera)
	# Persist through the same atomic store; fail without losing older settings.
	var directory: String = "user://camera_test_" + TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var store := LocalRecords.new(directory.path_join("records.json"))
	store.settings.favorites = ["starter_circuit"]
	store.settings.camera_speed_zoom = false
	for mode: String in CameraProfile.MODES:
		store.settings.camera_mode = mode
		check(store.save_records() == OK, "camera preference commits " + mode)
		var reload := LocalRecords.new(store.path)
		reload.load_records()
		check(reload.settings.camera_mode == mode and reload.settings.favorites == ["starter_circuit"], "reload preserves camera and unrelated preferences " + mode)
		check(reload.settings.camera_speed_zoom == false, "reload preserves disabled speed zoom " + mode)
	store.settings.camera_mode = "unknown"
	check(store.save_records() == ERR_INVALID_DATA and store.settings.camera_mode == "look_ahead", "invalid camera preference rejected without losing committed settings")
	store.settings.camera_speed_zoom = "yes"
	check(store.save_records() == ERR_INVALID_DATA and store.settings.camera_speed_zoom == false, "speed zoom rejects non-boolean preferences without losing saved settings")
	var valid_path: String = store.path
	store.path = directory.path_join("missing/records.json")
	store.settings.camera_mode = "follow_car"
	check(store.save_records() != OK and store.settings.camera_mode == "look_ahead", "failed write keeps prior saved camera")
	store.path = valid_path
	# Online races omit local ratings; camera preferences still load and save.
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = TrackCompiler.compile(TrackDocument.create_default())
	game.production_mode = true
	game.preference_records = store
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	check(game.rating_records == null and game.camera.mode == "look_ahead", "race loads preferences independently of local rating records")
	check(not game.camera.speed_zoom_enabled, "race loads saved speed zoom independently of ratings")
	var state: Array = game.sim.state.snapshot()
	var rules: Dictionary = RewindHistory.properties(game.track_session, true)
	var key: String = store.key_for(game.native_track, game.handling)
	game.toggle_pause()
	game.hud.pause_menu._settings()
	var zoom_choice: CheckButton = game.hud.pause_menu.find_child("RaceSpeedZoom", true, false)
	zoom_choice.set_pressed_no_signal(true)
	zoom_choice.toggled.emit(true)
	check(game.paused and game.camera.speed_zoom_enabled, "pause toggle enables speed zoom without unpausing")
	var zoom_reload := LocalRecords.new(store.path)
	zoom_reload.load_records()
	check(zoom_reload.settings.camera_speed_zoom == true, "pause zoom preference persists for next race")
	var picker: OptionButton = game.hud.pause_menu.find_child("RaceCameraMode", true, false)
	picker.select(1)
	picker.item_selected.emit(1)
	check(game.paused and not game.hud.touch.enabled and game.camera.mode == "follow_car", "pause selector changes camera without unpausing")
	var reload := LocalRecords.new(store.path)
	reload.load_records()
	check(reload.settings.camera_mode == "follow_car", "pause selection persists for next race")
	store.path = directory.path_join("missing/records.json")
	picker.select(0)
	picker.item_selected.emit(0)
	check(game.camera.mode == "overhead" and store.settings.camera_mode == "follow_car", "failed save still permits testing camera in current race")
	check(game.hud.pause_menu.status.text.contains("Could not save"), "pause menu reports camera save failure")
	zoom_choice.set_pressed_no_signal(false)
	zoom_choice.toggled.emit(false)
	check(not game.camera.speed_zoom_enabled and store.settings.camera_speed_zoom == true and game.hud.pause_menu.status.text.contains("Could not save"), "failed zoom save retains previous preference and permits session testing")
	store.path = valid_path
	game.set_camera_mode("follow_car")
	game.toggle_pause()
	var shortcut := InputEventKey.new()
	shortcut.pressed = true
	shortcut.physical_keycode = KEY_C
	game._unhandled_key_input(shortcut)
	check(game.camera.mode == "look_ahead", "C cycles the race camera")
	game.restart()
	check(game.camera.mode == "look_ahead", "retry keeps chosen camera")
	check(game.sim.state.snapshot() == state and RewindHistory.properties(game.track_session, true) == rules, "camera switching leaves canonical state and race gates unchanged")
	check(store.key_for(game.native_track, game.handling) == key, "camera choice leaves record partition unchanged")
	game.queue_free()
	camera.queue_free()
	await process_frame
	for filename: String in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)
	print("CAMERA_MODE_TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _check_rotation_limit(camera: FollowCamera) -> void:
	# A large heading gap used to cause arbitrarily fast initial rotation.
	const MAX_DEGREES_PER_SECOND: float = 60.0
	for fps: int in [30, 60, 120]:
		for direction: float in [-1.0, 1.0]:
			camera.follow(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0, true)
			var peak: float = 0.0
			var travel: float = 0.0
			for frame: int in range(fps * 2):
				var previous: float = camera.smoothed_yaw
				camera.follow(Vector2.ZERO, Vector2.ZERO, direction * deg_to_rad(175.0), 1.0 / fps)
				var movement: float = absf(rad_to_deg(angle_difference(previous, camera.smoothed_yaw)))
				peak = maxf(peak, movement * fps)
				travel += movement
			check(peak <= MAX_DEGREES_PER_SECOND + 0.0001, "large turn never exceeds 60 degrees/s at %d fps, direction %.0f (peak %.2f)" % [fps, direction, peak])
			check(travel > 100.0 and travel <= 120.0001, "camera follows a large turn without racing ahead or freezing")
	# Uneven render times, short-arc wrap and changing turn direction all obey
	# the same limit; stopped/invalid elapsed time contributes no rotation.
	camera.follow(Vector2.ZERO, Vector2.ZERO, deg_to_rad(179.0), 0.0, true)
	for delta: float in [1.0 / 120.0, 1.0 / 30.0, 0.125, 0.4, 0.0, -0.1]:
		var previous: float = camera.smoothed_yaw
		camera.follow(Vector2.ZERO, Vector2.ZERO, deg_to_rad(-45.0), delta)
		var movement: float = absf(rad_to_deg(angle_difference(previous, camera.smoothed_yaw)))
		check(movement <= MAX_DEGREES_PER_SECOND * maxf(delta, 0.0) + 0.0001, "rotation cap holds with uneven/zero elapsed time")
	var monotonic: bool = true
	# Allow the bounded turn plus settling; a 180-degree gap needs at least 3 s.
	for frame: int in range(240):
		var previous_error: float = angle_difference(camera.smoothed_yaw, deg_to_rad(45.0))
		camera.follow(Vector2.ZERO, Vector2.ZERO, deg_to_rad(-45.0), 1.0 / 60.0)
		var current_error: float = angle_difference(camera.smoothed_yaw, deg_to_rad(45.0))
		monotonic = monotonic and absf(current_error) <= absf(previous_error) + 0.000001 and previous_error * current_error >= -0.000000001
	check(monotonic, "camera approaches its target monotonically without overshoot")
	check(absf(angle_difference(camera.smoothed_yaw, deg_to_rad(45.0))) < 0.01, "camera eventually aligns without overshoot")

func _check_look_ahead_delay(camera: FollowCamera) -> void:
	var delayed: Array[Vector3] = []
	for fps: int in [30, 60, 120]:
		camera.set_mode("look_ahead")
		camera.follow(Vector2.ZERO, Vector2(0, 22), 0.0, 0.0, true)
		var original: Vector3 = camera.focus
		var target: Vector3 = VisualGeometry.world(Vector2(9, 0))
		var monotonic: bool = true
		for frame: int in range(fps / 2):
			var previous_distance: float = camera.focus.distance_to(target)
			camera.follow(Vector2.ZERO, Vector2(22, 0), PI / 2.0, 1.0 / fps)
			monotonic = monotonic and camera.focus.distance_to(target) <= previous_distance + 0.000001
			check(camera.look_ahead_offset.length() <= 9.00001, "delayed offset stays bounded through turn")
		var movement: float = camera.focus.distance_to(original)
		var total: float = original.distance_to(target)
		check(movement > total * 0.35 and movement < total * 0.7, "look-ahead shift remains gradual after half a second at %d fps" % fps)
		check(monotonic, "look-ahead approaches the new direction without overshooting")
		delayed.append(camera.focus)
		# Slower offset motion retains the existing 9/s position response.
		var previous: Vector3 = camera.focus
		camera.follow(Vector2(1, 0), Vector2(22, 0), PI / 2.0, 1.0 / fps)
		var response: float = 1.0 - exp(-9.0 / fps)
		check(camera.focus.x - previous.x >= response - 0.000001, "moving-car tracking remains responsive at %d fps" % fps)
		camera.follow(Vector2(40, -20), Vector2.ZERO, 0.0, 0.0, true)
		check(camera.focus == VisualGeometry.world(Vector2(40, -20)) and camera.look_ahead_offset == Vector2.ZERO, "restart/rewind clears stale look-ahead immediately")
	check(delayed[0].distance_to(delayed[1]) < 0.12 and delayed[1].distance_to(delayed[2]) < 0.12, "look-ahead response stays consistent across display rates")

func _check_speed_zoom(camera: FollowCamera) -> void:
	var base_size: float = camera.profile.baseline_extent / camera.profile.magnification
	for mode: String in CameraProfile.MODES:
		camera.set_mode(mode)
		camera.speed_zoom_enabled = true
		var previous_size: float = base_size
		camera.follow(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0, true)
		var slow_width: float = camera.unproject_position(Vector3(2, 0, 0)).distance_to(camera.unproject_position(Vector3(-2, 0, 0)))
		for speed: float in [0.0, 5.0, 30.0 / 3.6, 20.0, 30.0, 160.0 / 3.6, 90.0]:
			camera.follow(Vector2.ZERO, Vector2(0, speed), 0.0, 0.0, true)
			check(camera.size >= previous_size - 0.00001 and camera.size <= base_size * 1.12 + 0.00001, "speed zoom grows monotonically with a slight bounded pullback " + mode)
			if speed <= 30.0 / 3.6: check(is_equal_approx(camera.size, base_size), "standing/slow driving preserves calibrated extent " + mode)
			previous_size = camera.size
		var fast_width: float = camera.unproject_position(Vector3(2, 0, 0)).distance_to(camera.unproject_position(Vector3(-2, 0, 0)))
		check(is_equal_approx(camera.size, base_size * 1.12) and fast_width / slow_width > 0.89, "maximum speed still preserves car readability " + mode)
		var forward_size: float = camera.size
		camera.follow(Vector2.ZERO, Vector2(0, -90), 0.0, 0.0, true)
		check(is_equal_approx(camera.size, forward_size), "speed zoom also handles reverse travel " + mode)
		camera.speed_zoom_enabled = false
		camera.follow(Vector2.ZERO, Vector2(0, 90), 0.0, 0.0, true)
		check(is_equal_approx(camera.size, base_size), "speed zoom off retains fixed framing at full speed " + mode)
	var results: Array[float] = []
	for fps: int in [30, 60, 120]:
		camera.speed_zoom_enabled = true
		camera.follow(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0, true)
		camera.follow(Vector2.ZERO, Vector2(0, 60), 0.0, 1.0 / fps)
		check(camera.zoom_multiplier > 1.0 and camera.zoom_multiplier < 1.01, "acceleration starts a gentle zoom at %d fps" % fps)
		for frame: int in range(fps - 1): camera.follow(Vector2.ZERO, Vector2(0, 60), 0.0, 1.0 / fps)
		results.append(camera.zoom_multiplier)
		check(camera.zoom_multiplier > 1.08 and camera.zoom_multiplier < 1.11, "zoom eases gradually toward full extent at %d fps" % fps)
		var high: float = camera.zoom_multiplier
		camera.follow(Vector2.ZERO, Vector2.ZERO, 0.0, 1.0 / fps)
		check(camera.zoom_multiplier < high and camera.zoom_multiplier > 1.08, "braking returns toward the car gently at %d fps" % fps)
		for frame: int in range(fps * 4): camera.follow(Vector2.ZERO, Vector2.ZERO, 0.0, 1.0 / fps)
		check(absf(camera.zoom_multiplier - 1.0) < 0.0005, "zoom settles back to baseline after stopping")
	check(absf(results[0] - results[1]) < 0.000001 and absf(results[1] - results[2]) < 0.000001, "zoom easing is independent of display rate")
	camera.follow(Vector2.ZERO, Vector2(0, 60), 0.0, 0.0, true)
	var previous_zoom: float = camera.zoom_multiplier
	camera.follow(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0)
	camera.follow(Vector2.ZERO, Vector2.ZERO, 0.0, -0.1)
	check(camera.zoom_multiplier == previous_zoom, "zero/negative elapsed time cannot change zoom")
	camera.speed_zoom_enabled = false
	camera.follow(Vector2.ZERO, Vector2(0, 60), 0.0, 1.0 / 60.0)
	check(camera.zoom_multiplier > 1.1 and camera.zoom_multiplier < previous_zoom, "disabling zoom while driving eases back smoothly")
	camera.follow(Vector2(40, -20), Vector2.ZERO, 0.0, 0.0, true)
	check(camera.zoom_multiplier == 1.0 and is_equal_approx(camera.size, base_size), "restart/rewind snap restores appropriate zoom without stale state")
