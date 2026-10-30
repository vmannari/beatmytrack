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
	await _check_creator_proof()
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
	var observed: Dictionary = {"completed": 0, "edited": 0, "position": Vector2.ZERO, "tested":0}
	game.connect("practice_lap_completed",func() -> void: observed.tested += 1)
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
	check(hud.practice_status.text == "Practice (untimed)", "practice has a compact untimed status")
	check(hud.find_child("EditHere", true, false) != null and hud.find_child("PracticeRestart", true, false) != null, "practice exposes Restart and Edit here")
	check(game.get("camera") is FollowCamera and hud.touch is TouchControls, "practice uses the existing gameplay camera and real driving controls")
	game.set("ai_enabled", true)
	var witness := TrackSession.new(120, 6)
	for tick: int in range(120 * 240):
		var before: Vector2 = sim.state.position
		game.call("_physics_process", 1.0 / 120.0)
		witness.advance(track, before, sim.state.position,sim.state.route_index,sim.state.track_elevated)
		if sim.state.tick == 1200 and not capture_path.is_empty():
			await _capture(game)
		if witness.finished:
			break
	print("PRACTICE_DRIVE laps=", witness.completed_laps, " ticks=", sim.state.tick, " collisions=", sim.state.collision_count)
	check(witness.finished and witness.completed_laps == 6, "actual editor driving continues through six full ordered laps")
	check(observed.tested == 0 and not game.get("practice_validation_eligible"),"AI practice cannot unlock publication")
	check(not bool(game.get("paused")) and int(observed.completed) == 0, "practice cannot emit results or stop after the normal five-lap limit")
	check(session.elapsed_ticks == 0 and session.completed_laps == 0 and session.lap_times.is_empty() and not session.finished, "practice creates no scored race times or lap records")
	var finished_tick: int = sim.state.tick
	game.call("_physics_process", 1.0 / 120.0)
	check(sim.state.tick == finished_tick + 1, "simulation continues after the sixth lap")
	game.call("toggle_recording")
	check(not (game.get("recorder") as HandlingRecorder).active, "editor practice cannot enable developer recording persistence")
	var pause: Button = hud.menu_button
	pause.pressed.emit()
	check(bool(game.get("paused")) and not hud.touch.enabled, "practice status pauses and releases touch controls")
	var paused_tick: int = sim.state.tick
	game.call("_physics_process", 1.0 / 120.0)
	check(sim.state.tick == paused_tick, "paused practice does not advance simulation")
	game.call("_process", 0.1)
	check(hud.pause_menu.visible, "paused practice exposes a visible Resume action")
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
	check(sim.state.tick == 0 and game.get("race_cues").stage == 1, "normal countdown excludes canonical racing time")
	var cue_constants: Dictionary = game.get("race_cues").get_script().get_script_constant_map()
	var start_atlas: Texture2D = cue_constants.get("START_LIGHTS_ATLAS")
	check(start_atlas != null and start_atlas.get_size() == Vector2(3264, 120), "start lights use one padded preloaded six-frame atlas")
	var finish_panel: Texture2D = cue_constants.get("RACE_COMPLETE_PANEL")
	check(finish_panel != null and finish_panel.get_size() == Vector2(1024, 341), "finish uses one mobile-sized preloaded completion panel")
	var announcement: Label = game.get("countdown_label")
	check(announcement.offset_top == -170 and announcement.offset_bottom == -70, "countdown and GO share the raised announcement area")
	if not capture_path.is_empty():
		var practice_path: String = capture_path
		capture_path = practice_path.get_basename() + "-race-start.png"
		await _capture(game)
		game.get("race_cues").show_start(60, 0)
		capture_path = practice_path.get_basename() + "-all-red.png"
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
	check(not bool(game.get("paused")) and int(observed.completed) == 0 and session.lap_times.size() == 5, "finish defers results while preserving five scored laps")
	var scored_snapshot: Array = sim.state.snapshot()
	var scored_ticks: int = session.elapsed_ticks
	var coast: VehicleSimulation = game.get("finish_sim")
	check(coast != null and coast.state != sim.state, "finish coast has independent state")
	var finish_position: Vector2 = coast.state.position
	for tick: int in range(108): game.call("_physics_process", 1.0 / 120.0)
	check(coast.state.position.distance_to(finish_position) > 1.0, "car continues moving after crossing finish")
	check(sim.state.snapshot() == scored_snapshot and session.elapsed_ticks == scored_ticks, "coasting cannot change official state or time")
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	game.call("_unhandled_input", tap)
	check(bool(game.get("paused")) and int(observed.completed) == 1, "race-complete panel tap can continue after the guarded reveal")
	if not capture_path.is_empty():
		var saved_path: String = capture_path
		capture_path = saved_path.get_basename() + "-finish.png"
		await _capture(game)
		var cues: Control = game.get("race_cues")
		for sample: int in range(18):
			cues.show_finish(0.12 + sample * 0.025)
			capture_path = saved_path.get_basename() + "-flag-%02d.png" % sample
			await _capture(game)
		cues.show_finish(0.5)
		capture_path = saved_path
	for tick: int in range(108): game.call("_physics_process", 1.0 / 120.0)
	check(bool(game.get("paused")) and int(observed.completed) == 1, "coast ends with exactly one result")
	var finished_tick: int = sim.state.tick
	game.call("_physics_process", 1.0 / 120.0)
	check(sim.state.tick == finished_tick and int(observed.completed) == 1, "ordinary finish cannot advance or emit duplicate results")
	game.call("restart")
	check(game.get("finish_sim") == null and game.get("race_cues").stage == 1 and not bool(game.get("paused")), "retry resets coast and red lights")
	for light: int in range(1, 6):
		game.call("_physics_process", 1.0 / 120.0)
		check(game.get("race_cues").stage == light and sim.state.tick == 0, "red lights accumulate while race clock stays stopped: %d" % light)
		for tick: int in range(59): game.call("_physics_process", 1.0 / 120.0)
	for tick: int in range(59): game.call("_physics_process", 1.0 / 120.0)
	check(game.get("race_cues").stage == 5 and sim.state.tick == 0, "all five reds hold before release")
	game.call("_physics_process", 1.0 / 120.0)
	check(game.get("race_cues").stage == 0 and sim.state.tick == 0, "all lights extinguish on countdown boundary before canonical race tick")
	game.call("_physics_process", 1.0 / 120.0)
	check(sim.state.tick == 1,"canonical race advances immediately after lights-out")
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

func _check_creator_proof() -> void:
	var source := FileAccess.open("res://../backend/tests/fixtures/verified_oval.json",FileAccess.READ)
	var fixture: Dictionary = JSON.parse_string(source.get_as_text())
	var document: Dictionary = fixture.document
	var track: NativeTrack = TrackCompiler.compile(document)
	track.spawn = Vector2(document.start_line.position[0],document.start_line.position[1])
	track.spawn_heading = PI*0.5-deg_to_rad(float(document.start_line.heading))
	var game: Node = _new_game(track,true)
	var sim: VehicleSimulation = game.get("sim")
	var route_driver := RouteDriver.new()
	var controls: DriverInput = game.get("driver")
	for tick: int in range(24000):
		var input: DriveFrame = route_driver.sample(sim.state,track,game.get("handling"))
		controls.clear()
		controls.set_touch(0,&"steer_right" if input.steer >= 0 else &"steer_left",absf(float(input.steer))/127.0)
		controls.set_touch(1,&"accelerate",float(input.throttle)/255.0)
		controls.set_touch(2,&"brake",float(input.brake)/255.0)
		game.call("_physics_process",1.0/120.0)
		if game.get("practice_validation").finished: break
	check(game.get("practice_validation").finished,"creator proof completes one ordered lap with input controls")
	var frames: Array = game.get("online_frames").duplicate(true)
	check(not frames.is_empty() and frames.size() == sim.state.tick,"practice records every canonical input through completion")
	game.call("_physics_process",1.0/120.0)
	check(game.get("online_frames").size() == frames.size(),"proof freezes at completion while practice continues")
	var output := FileAccess.open("res://../build/creator-practice-proof.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"document":document,"replay":{"schema":"bmt-replay-v1","frames":frames,"race_proof":game.race_proof.recording(game.practice_validation)}}))
	output.close()
	game.call("restart")
	check(game.get("online_frames").is_empty(),"restart discards previous proof inputs")
	game.queue_free()
	await process_frame
