extends SceneTree
## The editor's untimed practice does not participate in race completion/storage.
## An independent six-lap witness checks actual driving past the normal finish.

var checks: int = 0
var failures: int = 0
var capture_path: String = ""


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: " + description)


func run() -> void:
	root.size = Vector2i(1280, 720)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-practice="):
			capture_path = argument.trim_prefix("--capture-practice=")
	var track := NativeTrack.read("res://resources/tracks/starter_circuit.json")
	check(track != null, "real native practice fixture loads")
	if track == null:
		_finish()
		return
	await _check_practice(track)
	await _check_normal_race(track)
	_finish()


func _new_game(track: NativeTrack, practice: bool) -> Node:
	var game: Node = (load("res://core/game.tscn") as PackedScene).instantiate()
	game.set("initial_track", track)
	game.set("production_mode", true)
	game.set("editor_test", practice)
	root.add_child(game)
	game.set_physics_process(false)
	return game


func _check_practice(track: NativeTrack) -> void:
	var game: Node = _new_game(track, true)
	var observed: Dictionary = {"completed": 0, "edited": 0, "position": Vector2.ZERO}
	game.connect("race_completed", func() -> void: observed.completed += 1)
	game.connect("edit_here_requested", func(position: Vector2) -> void:
		observed.edited += 1
		observed.position = position)
	var sim: VehicleSimulation = game.get("sim")
	var session: TrackSession = game.get("track_session")
	var hud: PlaygroundHUD = game.get("hud")
	check(int(game.get("countdown_ticks")) == 0 and sim.state.tick == 0, "practice starts at rest without a race countdown")
	check(bool(game.get("attempt_practice")), "editor drive is always marked practice at the result boundary")
	check(not hud.race_timer.visible and not hud.title.visible, "practice hides the timed race and lap presentation")
	check(hud.pause_button.text == "Practice (untimed)", "practice has a compact untimed status")
	check(hud.find_child("EditHere", true, false) != null and hud.find_child("PracticeRestart", true, false) != null, "practice exposes Restart and Edit here")
	check(game.get("camera") is FollowCamera and hud.touch is TouchControls, "practice uses the existing gameplay camera and real driving controls")
	game.set("ai_enabled", true)
	var witness := TrackSession.new(120, 6)
	for tick: int in range(120 * 240):
		var before: Vector2 = sim.state.position
		game.call("_physics_process", 1.0 / 120.0)
		witness.advance(track, before, sim.state.position, sim.state.route_index)
		if sim.state.tick == 1200 and not capture_path.is_empty():
			await _capture(game)
		if witness.finished:
			break
	print("PRACTICE_DRIVE laps=", witness.completed_laps, " ticks=", sim.state.tick, " collisions=", sim.state.collision_count)
	check(witness.finished and witness.completed_laps == 6, "actual editor driving continues through six full ordered laps")
	check(not bool(game.get("paused")) and int(observed.completed) == 0, "practice cannot emit results or stop after the normal five-lap limit")
	check(session.elapsed_ticks == 0 and session.completed_laps == 0 and session.lap_times.is_empty() and not session.finished, "practice creates no scored race times or lap records")
	var finished_tick: int = sim.state.tick
	game.call("_physics_process", 1.0 / 120.0)
	check(sim.state.tick == finished_tick + 1, "simulation continues after the sixth lap")
	game.call("toggle_recording")
	check(not (game.get("recorder") as HandlingRecorder).active, "editor practice cannot enable developer recording persistence")
	var pause: Button = hud.pause_button
	pause.pressed.emit()
	check(bool(game.get("paused")) and not hud.touch.enabled, "practice status pauses and releases touch controls")
	var paused_tick: int = sim.state.tick
	game.call("_physics_process", 1.0 / 120.0)
	check(sim.state.tick == paused_tick, "paused practice does not advance simulation")
	game.call("_process", 0.1)
	check(pause.text == "Paused · Resume", "paused practice exposes a visible Resume action")
	pause.pressed.emit()
	check(not bool(game.get("paused")) and hud.touch.enabled, "the same practice status resumes driving")
	(hud.find_child("PracticeRestart", true, false) as Button).pressed.emit()
	check(sim.state.tick == 0 and sim.state.position == track.spawn and sim.state.velocity == Vector2.ZERO, "Restart restores the original track spawn and stopped car")
	check(int(game.get("countdown_ticks")) == 0 and not bool(game.get("paused")) and bool(game.get("attempt_practice")), "practice restart remains immediate and untimed")
	game.call("_physics_process", 1.0 / 120.0)
	check((game.get("countdown_label") as Label).text.is_empty(), "practice never displays a race start announcement")
	for tick: int in range(300):
		game.call("_physics_process", 1.0 / 120.0)
	var returned_position: Vector2 = sim.state.position
	check(returned_position.distance_to(track.spawn) > 1.0, "return fixture has actually driven away from spawn")
	(game.get("driver") as DriverInput).set_touch(9, &"accelerate")
	(hud.find_child("EditHere", true, false) as Button).pressed.emit()
	check(int(observed.edited) == 1 and observed.position == returned_position, "Edit here emits the actual current simulation position")
	check(bool(game.get("paused")) and not hud.touch.enabled and (game.get("driver") as DriverInput).touches.is_empty(), "Edit here releases driving inputs before navigation")
	check(int(observed.completed) == 0, "returning to edit never emits a scored completion")
	game.queue_free()
	await process_frame


func _check_normal_race(track: NativeTrack) -> void:
	var game: Node = _new_game(track, false)
	var observed: Dictionary = {"completed": 0, "edited": 0}
	game.connect("race_completed", func() -> void: observed.completed += 1)
	game.connect("edit_here_requested", func(_position: Vector2) -> void: observed.edited += 1)
	var sim: VehicleSimulation = game.get("sim")
	var session: TrackSession = game.get("track_session")
	check(session.target_laps == 5 and int(game.get("countdown_ticks")) == 360, "ordinary production racing keeps five laps and the three-second countdown")
	check((sim.state.position - track.finish_center).dot(track.finish_forward) <= -2.99, "race car starts fully behind the finish stripe")
	check(not bool(game.get("attempt_practice")), "ordinary fresh race remains eligible for normal records")
	game.call("_physics_process", 1.0 / 120.0)
	check(sim.state.tick == 0 and (game.get("countdown_label") as Label).text == "3", "normal countdown excludes canonical racing time")
	var announcement: Label = game.get("countdown_label")
	check(announcement.offset_top == -170 and announcement.offset_bottom == -70, "countdown and GO share the raised announcement area")
	if not capture_path.is_empty():
		var practice_path: String = capture_path
		capture_path = practice_path.get_basename() + "-race-start.png"
		await _capture(game)
		game.set("countdown_ticks", 0)
		game.call("_physics_process", 1.0 / 120.0)
		capture_path = practice_path.get_basename() + "-go.png"
		await _capture(game)
		capture_path = practice_path
	game.call("_edit_here")
	check(int(observed.edited) == 0 and not bool(game.get("paused")), "editor return action is inactive during ordinary races")
	game.set("ai_enabled", true)
	var fourth_lap_checked: bool = false
	for tick: int in range(120 * 240):
		game.call("_physics_process", 1.0 / 120.0)
		if session.completed_laps == 4 and not fourth_lap_checked:
			fourth_lap_checked = true
			check(not session.finished and int(observed.completed) == 0, "four laps cannot finish an ordinary five-lap race")
		if session.finished:
			break
	check(fourth_lap_checked and session.finished and session.completed_laps == 5, "actual normal driving still finishes precisely five ordered laps")
	check(bool(game.get("paused")) and int(observed.completed) == 1 and session.lap_times.size() == 5, "normal finish still stops driving and emits one result with five times")
	var finished_tick: int = sim.state.tick
	game.call("_physics_process", 1.0 / 120.0)
	check(sim.state.tick == finished_tick and int(observed.completed) == 1, "ordinary finish cannot advance or emit duplicate results")
	game.queue_free()
	await process_frame


func _capture(game: Node) -> void:
	if DisplayServer.get_name() == "headless" or not capture_path.is_absolute_path():
		check(false, "practice capture requires a graphical display and absolute output path")
		return
	for frame: int in range(4):
		game.call("_process", 0.1)
		await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(capture_path) == OK, "practice gameplay screenshot saved")
	print("PRACTICE_CAPTURE_SAVED: ", capture_path)


func _finish() -> void:
	print("EDITOR_PRACTICE_TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
