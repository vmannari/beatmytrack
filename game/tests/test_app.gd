extends SceneTree
## Real app composition, editor input handlers and production test-drive round trip.
## All persistence is redirected to one isolated disposable test directory.

var checks: int = 0
var failures: int = 0
var app: Node
var test_directory: String
var capture_directory: String = ""


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
		if argument.begins_with("--capture-app-flow="):
			capture_directory = argument.trim_prefix("--capture-app-flow=")
	if not capture_directory.is_empty():
		check(DisplayServer.get_name() != "headless" and capture_directory.is_absolute_path(), "flow capture uses a graphical display and explicit absolute output directory")
		if failures > 0:
			_finish()
			return
		check(DirAccess.make_dir_recursive_absolute(capture_directory) == OK, "flow capture directory is writable")
	test_directory = "user://app_test_" + TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(test_directory)
	var scene: PackedScene = load("res://core/app.tscn")
	check(scene != null, "app scene loads")
	if scene == null:
		_finish()
		return
	app = scene.instantiate()
	app.set("library", TrackLibrary.new(test_directory))
	var local_records: RefCounted = app.get("records")
	# Records path is injected before _ready can read or write owner data.
	check(_set_records_path(local_records, test_directory.path_join("records.json")), "local records have an isolated injectable path")
	if failures > 0:
		app.free()
		_finish()
		return
	root.add_child(app)
	await process_frame
	await process_frame
	check(app.get("screen") == "play" and app.get("game") == null, "startup opens Play with no running simulation")
	check((app.get("root_ui") as Node).find_child("StartRace", true, false) != null, "Play exposes the primary Race action")
	check(_button(app.get("root_ui"), "Create") != null, "Play exposes creator navigation")
	await _check_library()
	await _capture("app-home")
	var create_button: Button = _button(app.get("root_ui"), "Create")
	await _viewport_tap(create_button.get_global_rect().get_center())
	await process_frame
	await process_frame
	check(app.get("screen") == "create", "viewport-dispatched finger tap opens the creator through its menu button")
	if app.get("screen") != "create":
		# Preserve the failure, then continue independent integration checks.
		app.call("_show_screen", "create")
		await process_frame
		await process_frame
	var document: Dictionary = app.get("document")
	check(TrackDocument.validate(document).is_empty(), "first editor opens a valid starter circuit")
	check((app.get("test_button") as Button).disabled and not (app.get("share_button") as Button).disabled, "blank draft can be shared but needs road before practice")
	# The general route/history regression uses the existing valid loop fixture.
	var fixture: Dictionary = TrackDocument.create_default()
	fixture.id = document.id
	app.set("document",fixture)
	app.call("_show_screen","create")
	await process_frame
	await process_frame
	var initial_canvas: EditorCanvas = app.get("canvas")
	check(initial_canvas.size.x > 0.0 and initial_canvas.size.y > 0.0 and is_finite(initial_canvas.zoom) and initial_canvas.pan.is_finite() and initial_canvas.to_screen(Vector2.ZERO).is_finite(), "first layout has a finite, usable editor transform")
	(app.get("root_ui").find_child("RenameTrack",true,false) as Button).pressed.emit()
	await process_frame
	var name_field: LineEdit = (app.get("root_ui") as Node).find_child("CircuitName",true,false)
	check(name_field != null, "editor exposes a native editable circuit name")
	if name_field != null:
		await _viewport_tap(name_field.get_global_rect().get_center())
		check(name_field.has_focus(), "viewport-dispatched touch focuses the native circuit-name field")
		name_field.release_focus()
	var rename: Window=app.get("root_ui").find_child("RenameDialog",true,false)
	rename.hide(); rename.queue_free()
	await process_frame
	await _check_input_and_history()
	await _check_view_retention()
	await _capture_editor_themes()
	await _check_import_copy()
	await _check_test_drive()
	await _check_clean_result()
	_check_records()
	app.queue_free()
	await process_frame
	_finish()


func _set_records_path(records: RefCounted, path: String) -> bool:
	for property: Dictionary in records.get_property_list():
		if property.name in ["path", "file_path", "records_path"]:
			records.set(property.name, path)
			return true
	return false


func _check_library() -> void:
	_button(app.get("root_ui"),"Tracks").pressed.emit()
	await process_frame
	await process_frame
	var browser: TrackBrowser = (app.get("root_ui") as Node).find_child("TrackBrowser",true,false)
	while browser.loading: await process_frame
	check(browser.matches.size() == browser.builtin_ids.size() and browser.grid.get_child_count() == 6,"track library pages the complete built-in collection into six visual cards")
	await _capture("track-library")
	var search: LineEdit = browser.find_child("Search_name",true,false)
	search.text = "1wAy"
	search.text_changed.emit(search.text)
	check(browser.matches.size() == 1,"name search is case insensitive and filters the full catalog")
	var creator_search: LineEdit = browser.find_child("Search_creator",true,false)
	creator_search.text = str(browser.matches[0].creator).to_lower()
	creator_search.text_changed.emit(creator_search.text)
	check(browser.matches.size() == 1,"creator and name search combine in the live browser")
	await process_frame
	await process_frame
	await _viewport_tap((browser.grid.get_child(0) as Button).get_global_rect().get_center())
	var chosen: NativeTrack = app.get("selected_track")
	check(chosen.identity == "slicks_1way_test","a route card selects its exact circuit")
	(browser.find_child("ToggleFavorite",true,false) as Button).pressed.emit()
	var store: LocalRecords = app.get("records")
	var reloaded := LocalRecords.new(store.path)
	reloaded.load_records()
	check(chosen.identity in reloaded.settings.get("favorites",[]),"favorites persist across store instances")
	(browser.find_child("Filter_favorites",true,false) as Button).pressed.emit()
	check(browser.matches.size() == 1,"Favorites intersects the current name filter")
	search.text = "no such track"
	search.text_changed.emit(search.text)
	check(browser.matches.is_empty() and browser.random_button.disabled,"empty results disable random choice and expose a recovery message")
	search.text = ""
	search.text_changed.emit("")
	browser.random_button.pressed.emit()
	check((app.get("selected_track") as NativeTrack).identity == chosen.identity,"random favorite respects both collection and search filters")
	await process_frame
	await _capture("track-favorites")
	(browser.find_child("LibraryRace",true,false) as Button).pressed.emit()
	await process_frame
	check((app.get("game").get("native_track") as NativeTrack).identity == chosen.identity,"library Race starts the selected favorite")
	check((app.get("game").get("track_session") as TrackSession).target_laps == 5,"production menu starts a five-lap race")
	app.call("_leave_race")
	await process_frame
	await process_frame
	browser = (app.get("root_ui") as Node).find_child("TrackBrowser",true,false)
	while browser.loading: await process_frame
	check(browser.state.get("section") == "favorites" and browser.matches.size() == 1,"return from racing preserves library filters")
	app.call("_show_screen","play")
	await process_frame
	await process_frame


func _check_input_and_history() -> void:
	_button(app.get("root_ui"), "Waypoints").pressed.emit()
	var canvas: EditorCanvas = app.get("canvas")
	var original: Dictionary = (app.get("document") as Dictionary).duplicate(true)
	var start: Vector2 = canvas.to_screen(Vector2(original.points[0][0], original.points[0][1]))
	var destination: Vector2 = start + Vector2(canvas.scale_factor() * 2.0, 0.0)
	_mouse(canvas, start, true)
	check(canvas.dragging and canvas.active_pointer == -1, "mouse press selects and starts a handle drag")
	var motion := InputEventMouseMotion.new()
	motion.position = destination
	motion.relative = destination - start
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	canvas._gui_input(motion)
	_mouse(canvas, destination, false)
	check(not canvas.dragging and canvas.active_pointer == -99, "mouse release ends its gesture")
	var changed: Dictionary = (app.get("document") as Dictionary).duplicate(true)
	check(changed.points[0] != original.points[0] and changed.points.size() == original.points.size(), "mouse drag moves exactly the selected route handle")
	check((app.get("history") as Array).size() == 1, "one completed drag creates one undo step")
	var library: TrackLibrary = app.get("library")
	check(library.load_wip(changed.id) == changed, "completed valid mouse edit autosaves to the isolated library")
	var expected_preview: NativeTrack = TrackCompiler.compile(changed)
	check(canvas.preview.track != null and canvas.preview.track.content_hash == expected_preview.content_hash and canvas.preview.track.cells == expected_preview.cells, "released editor drag refreshes the exact compiled native preview")
	_button(app.get("root_ui"), "Undo").pressed.emit()
	await process_frame
	await process_frame
	check(app.get("document") == original, "Undo restores the whole pre-drag document")
	_button(app.get("root_ui"), "Redo").pressed.emit()
	await process_frame
	await process_frame
	check(app.get("document") == changed, "Redo restores the edited document")
	canvas = app.get("canvas")
	start = canvas.to_screen(Vector2(changed.points[1][0], changed.points[1][1]))
	_touch(canvas, 3, start, true)
	check(canvas.dragging and canvas.active_pointer == 3, "touch press starts a handle drag through the same canvas")
	_drag(canvas, 3, start + Vector2(canvas.scale_factor(), 0.0))
	_touch(canvas, 3, start, false, true)
	check(not canvas.dragging and not canvas.panning and canvas.touches.is_empty() and canvas.active_pointer == -99, "canceled touch releases capture and all gesture state")
	var after_cancel: Dictionary = (app.get("document") as Dictionary).duplicate(true)
	_drag(canvas, 3, start + Vector2(100, 100))
	check(app.get("document") == after_cancel, "stale drag after cancellation cannot edit the route")
	_touch(canvas, 8, start, true)
	canvas.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not canvas.dragging and canvas.touches.is_empty() and canvas.active_pointer == -99, "focus loss cancels active touch capture")
	(app.get("canvas") as EditorCanvas).fit()
	var background := Vector2(20, 20)
	var second := Vector2(180, 20)
	var route_before: Array = (app.get("document") as Dictionary).points.duplicate(true)
	_touch(canvas, 10, background, true)
	check(canvas.panning, "empty-background touch starts panning")
	_touch(canvas, 11, second, true)
	var pan_before: Vector2 = canvas.pan
	var zoom_before: float = canvas.zoom
	_drag(canvas, 10, background + Vector2(12, 14))
	_drag(canvas, 11, second + Vector2(52, 14))
	check(canvas.pan != pan_before and not is_equal_approx(canvas.zoom, zoom_before), "two fingers pan and zoom together")
	check((app.get("document") as Dictionary).points == route_before, "two-finger navigation leaves route geometry unchanged")
	_touch(canvas, 11, second + Vector2(52, 14), false)
	pan_before = canvas.pan
	_drag(canvas, 10, background + Vector2(17, 14))
	check(canvas.pan.distance_to(pan_before + Vector2(5, 0)) < 0.1, "remaining finger continues panning without a jump after pinch")
	_touch(canvas, 10, background + Vector2(17, 14), false)
	check(canvas.touches.is_empty() and not canvas.dragging and not canvas.panning and canvas.active_pointer == -99, "pinch release leaves no captured or stuck gesture")
	# Starting a fresh handle drag after pinch also proves gesture recovery.
	var current: Dictionary = app.get("document")
	start = canvas.to_screen(Vector2(current.points[2][0], current.points[2][1]))
	_touch(canvas, 12, start, true)
	check(canvas.dragging and canvas.selected == 2, "a fresh handle remains draggable after multitouch navigation")
	var history_before: int = (app.get("history") as Array).size()
	var emulated := InputEventMouseButton.new()
	emulated.device = -1
	emulated.position = start
	emulated.button_index = MOUSE_BUTTON_LEFT
	emulated.pressed = true
	canvas._gui_input(emulated)
	emulated.pressed = false
	canvas._gui_input(emulated)
	check(canvas.dragging and canvas.active_pointer == 12 and (app.get("history") as Array).size() == history_before, "touch-emulated mouse events cannot duplicate or end a handle edit")
	_touch(canvas, 12, start, false)
	_touch(canvas, 20, background, true)
	_touch(canvas, 21, second, true)
	_drag(canvas, 20, background + Vector2(10, 10))
	_drag(canvas, 21, second + Vector2(30, 10))
	_touch(canvas, 20, background + Vector2(10, 10), false)
	pan_before = canvas.pan
	_drag(canvas, 21, second + Vector2(35, 10))
	check(canvas.panning and canvas.active_pointer == 21 and canvas.pan.distance_to(pan_before + Vector2(5, 0)) < 0.1, "lifting the first pinch finger hands smooth panning to the second")
	_touch(canvas, 21, second + Vector2(35, 10), false)
	check(canvas.touches.is_empty() and not canvas.dragging and not canvas.panning and canvas.active_pointer == -99, "both pinch release orders leave no captured gesture")
	(app.get("canvas") as EditorCanvas).fit()
	var handles_visible: bool = true
	for point: Array in (app.get("document") as Dictionary).points:
		handles_visible = handles_visible and Rect2(Vector2(26, 26), canvas.size - Vector2(52, 52)).has_point(canvas.to_screen(Vector2(point[0], point[1])))
	check(handles_visible, "Fit returns every complete route handle inside the editing canvas")
	check(TrackDocument.validate(app.get("document")).is_empty(), "input gestures preserve a valid editable circuit")


func _check_import_copy() -> void:
	app.call("_save_draft")
	var saved: Dictionary = (app.get("document") as Dictionary).duplicate(true)
	var imported: Dictionary = saved.duplicate(true)
	imported.name = "Willow Circuit"
	imported["creator"] = "Mira"
	var library: TrackLibrary = app.get("library")
	app.call("_accept_import", imported)
	await process_frame
	await process_frame
	var copy: Dictionary = app.get("document")
	check(copy.id != saved.id and copy.name == imported.name, "import opens a separately identified local draft")
	check(copy.creator == "Mira", "import preserves the shared creator attribution for search")
	check(library.load_wip(saved.id) == saved, "importing an existing identifier cannot overwrite the original draft")
	check(library.load_wip(copy.id) == copy, "the imported copy is persisted independently")
	check(imported.id == saved.id, "import does not mutate the supplied document")
	check((app.get("history") as Array).is_empty() and (app.get("redo_history") as Array).is_empty(), "import clears unrelated undo and redo history")


func _check_view_retention() -> void:
	var canvas: EditorCanvas = app.get("canvas")
	canvas.zoom_by(1.2)
	canvas.pan += Vector2(35, -12)
	_button(app.get("root_ui"), "Add bend").pressed.emit()
	var saved_zoom: float = canvas.zoom
	var saved_pan: Vector2 = canvas.pan
	app.call("_set_document_value", "theme", "coast")
	await process_frame
	await process_frame
	canvas = app.get("canvas")
	check(canvas.mode == "add" and canvas.pan == saved_pan and is_equal_approx(canvas.zoom, saved_zoom), "changing theme preserves the editor tool, zoom and pan")
	app.call("_undo")
	await process_frame
	await process_frame
	canvas = app.get("canvas")
	check(canvas.mode == "add" and canvas.pan == saved_pan and is_equal_approx(canvas.zoom, saved_zoom), "Undo preserves the current editor view and tool")
	_button(app.get("root_ui"), "Move").pressed.emit()
	(app.get("canvas") as EditorCanvas).fit()


func _check_test_drive() -> void:
	var before: Dictionary = (app.get("document") as Dictionary).duplicate(true)
	var compiled: NativeTrack = TrackCompiler.compile(before)
	var zoom_before: float = (app.get("canvas") as EditorCanvas).zoom
	(app.get("test_button") as Button).pressed.emit()
	await process_frame
	var game: Node = app.get("game")
	check(game != null and bool(game.get("production_mode")) and bool(game.get("editor_test")), "Test launches the real gameplay scene in untimed editor practice")
	if game == null:
		return
	game.set_physics_process(false)
	var driven: NativeTrack = game.get("native_track")
	check(driven != null and driven.content_hash == compiled.content_hash and driven.cells == compiled.cells and driven.route == compiled.route, "practice uses exactly the compiled draft content, surfaces and route")
	check(not (app.get("root_ui") as Control).visible, "the editor is hidden during practice")
	var sim: VehicleSimulation = game.get("sim")
	check(int(game.get("countdown_ticks")) == 0 and bool(game.get("attempt_practice")), "creator practice begins immediately and is always unscored")
	game.call("_physics_process", 1.0 / 120.0)
	var countdown: Label = game.get("countdown_label")
	check(countdown.text.is_empty(), "untimed editor driving has no racing countdown or GO announcement")
	var pause_key := InputEventKey.new()
	pause_key.physical_keycode = KEY_ESCAPE
	pause_key.keycode = KEY_ESCAPE
	pause_key.pressed = true
	game.call("_unhandled_key_input", pause_key)
	check(bool(game.get("paused")), "Escape pauses editor practice")
	var paused_tick: int = sim.state.tick
	game.call("_physics_process", 1.0 / 120.0)
	check(sim.state.tick == paused_tick, "paused editor practice cannot advance canonical simulation")
	game.call("_unhandled_key_input", pause_key)
	check(not bool(game.get("paused")), "Escape resumes editor practice")
	game.set("ai_enabled", true)
	var session: TrackSession = game.get("track_session")
	for tick: int in range(1800):
		game.call("_physics_process", 1.0 / 120.0)
	check(sim.state.position.distance_to(driven.spawn) > 1.0, "practice actually drives the authored map")
	check(not session.finished and session.elapsed_ticks == 0 and session.lap_times.is_empty(), "practice creates no scored lap times or race result")
	check(not (app.get("root_ui") as Control).visible, "ongoing practice never opens a result overlay")
	await _capture("creator-test-drive", 30)
	var hud: PlaygroundHUD = game.get("hud")
	(hud.find_child("PracticeRestart", true, false) as Button).pressed.emit()
	check(sim.state.tick == 0 and sim.state.position == driven.spawn and int(game.get("countdown_ticks")) == 0, "Restart immediately resets the same draft without a countdown")
	for tick: int in range(300):
		game.call("_physics_process", 1.0 / 120.0)
	var edit_position: Vector2 = sim.state.position
	(hud.find_child("EditHere", true, false) as Button).pressed.emit()
	await process_frame
	await process_frame
	check(app.get("game") == null and app.get("screen") == "create", "Edit here returns directly to the editor and releases the running game")
	check(app.get("document") == before, "practice and returning preserve the editable draft exactly")
	check(TrackCompiler.compile(app.get("document")).content_hash == compiled.content_hash, "returning from practice preserves the circuit content hash")
	var returned_canvas: EditorCanvas = app.get("canvas")
	check(is_equal_approx(returned_canvas.zoom, zoom_before) and returned_canvas.to_screen(edit_position).distance_to(returned_canvas.size * 0.5) < 2.0, "Edit here retains editor zoom and centers the actual driven location")
	await _capture("creator-returned")
	var records: RefCounted = app.get("records")
	check((records.get("records") as Dictionary).is_empty(), "editor practice never writes a local personal best")


func _check_clean_result() -> void:
	# This fixture targets the result-to-storage boundary. Actual ordered
	# driving is covered above; it does not claim a second driven race.
	var track: NativeTrack = app.get("selected_track")
	app.call("_start_race", track, false)
	var game: Node = app.get("game")
	game.set_physics_process(false)
	var completed := TrackSession.new()
	completed.completed_laps = 5
	completed.elapsed_ticks = 120 * 109
	completed.lap_start_time = 109.0
	completed.lap_times.assign([22.0, 21.0, 23.0, 22.0, 21.0])
	completed.finished = true
	game.set("track_session", completed)
	game.set("paused", true)
	game.set("attempt_practice", false)
	game.emit_signal("race_completed")
	var records: LocalRecords = app.get("records")
	check(records.best_for(track, game.get("handling")) == 109.0 and _button(app.get("root_ui"), "Choose track") != null, "a clean normal race result persists its local PB and exposes track selection")
	check(((app.get("root_ui") as Node).find_child("ResultStatus",true,false) as Label).text == "FIRST TIME SET","a first normal finish is presented as the player's benchmark")
	await _capture("normal-race-debrief")
	# Controlled result fixtures exercise improvement feedback; they are not
	# additional claims of AI-driven lap times.
	completed.lap_times[4] = 20.816
	completed.lap_start_time = 108.816
	app.call("_results")
	check(((app.get("root_ui") as Node).find_child("ResultDelta",true,false) as Label).text.begins_with("0.184 s faster"),"the integrated PB screen uses the previous saved target")
	await _capture("improved-race-debrief")
	completed.lap_times[4] = 21.0
	completed.lap_start_time = 109.0
	app.call("_results")
	check(((app.get("root_ui") as Node).find_child("ResultDelta",true,false) as Label).text.begins_with("+0.184 s off"),"a slower integrated finish presents its exact gap without replacing the PB")
	game.emit_signal("exit_requested")
	await process_frame
	await process_frame
	var resumed: Node = (load("res://core/app.tscn") as PackedScene).instantiate()
	resumed.set("library",app.get("library"))
	resumed.set("records",LocalRecords.new(records.path))
	root.add_child(resumed)
	await process_frame
	await process_frame
	check((resumed.get("selected_track") as NativeTrack).identity == track.identity,"relaunch resumes the last ordinary race circuit")
	check(((resumed.get("root_ui") as Node).find_child("RaceTarget",true,false) as Label).text == "01:48.816","returning home presents the actual stored five-lap time to beat")
	await _capture("returning-race-home")
	resumed.queue_free()
	await process_frame


func _check_records() -> void:
	var records := LocalRecords.new()
	records.path = test_directory.path_join("record_fixture.json")
	var track: NativeTrack = TrackCompiler.compile(TrackDocument.create_default())
	var handling: HandlingConfig = load("res://resources/balanced.tres")
	var laps: Array[float] = [10.0, 21.0, 23.0,30.0,30.0]
	var first_save: Error = records.record(track, handling, 114.0, laps)
	print("APP_RECORD_SAVE error=", error_string(first_save), " entries=", records.records.size())
	check(first_save == OK, "local result persists atomically in isolated storage")
	var key: String = records.key_for(track, handling)
	check(records.best_for(track, handling) == 114.0 and int(records.records[key].flying_ms) == 21000, "local result distinguishes whole race from flying laps and excludes standing lap")
	laps = [20.5, 19.5, 20.0,30.0,30.0]
	check(records.record(track, handling, 120.0, laps) == OK, "a later slower race can still persist a better flying lap")
	check(records.best_for(track, handling) == 114.0 and int(records.records[key].flying_ms) == 19500, "slower attempt preserves race PB while improving flying PB")
	var changed_track: NativeTrack = track.duplicate() as NativeTrack
	changed_track.content_hash += "_revision"
	check(records.key_for(changed_track, handling) != key and records.best_for(changed_track, handling) == 0.0, "track content revision partitions local comparisons")
	var changed_handling: HandlingConfig = handling.duplicate() as HandlingConfig
	changed_handling.version = "integration-other-handling"
	check(records.key_for(track, changed_handling) != key, "handling revision partitions local comparisons")
	var reloaded := LocalRecords.new()
	reloaded.path = records.path
	reloaded.load_records()
	check(reloaded.records == records.records, "saved records survive a new store instance")
	# Syntactically valid but corrupt document contract exercises recovery quietly.
	var file := FileAccess.open(records.path, FileAccess.WRITE)
	file.store_string("[]")
	file.close()
	reloaded.records.clear()
	reloaded.load_records()
	check(reloaded.best_for(track, handling) == 114.0 and int(reloaded.records.get(key, {}).get("flying_ms", 0)) == 21000, "corrupt primary recovers the previous committed backup")


func _capture_editor_themes() -> void:
	if capture_directory.is_empty():
		return
	var original: Dictionary = (app.get("document") as Dictionary).duplicate(true)
	for theme: String in ["pine", "coast", "desert"]:
		app.call("_set_document_value", "theme", theme)
		await process_frame
		await process_frame
		(app.get("canvas") as EditorCanvas).fit()
		await _capture("creator-theme-" + theme)
	# Restore the same authoring document after visual-only evidence variants.
	app.set("document", original)
	app.call("_show_screen", "create")
	await process_frame
	await process_frame
	app.call("_save_draft")


func _capture(name: String, settle_frames: int = 2) -> void:
	if capture_directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	await process_frame
	for frame: int in range(settle_frames):
		await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = capture_directory.path_join(name + ".png")
	var error: Error = image.save_png(path)
	check(error == OK, "graphical flow capture saved: " + name)
	if error == OK:
		print("APP_CAPTURE_SAVED: " + path)


func _mouse(canvas: EditorCanvas, point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	canvas._gui_input(event)


func _touch(canvas: EditorCanvas, index: int, point: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	canvas._gui_input(event)


func _drag(canvas: EditorCanvas, index: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	canvas._gui_input(event)


func _button(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node
	for child: Node in node.get_children():
		var found: Button = _button(child, text)
		if found != null:
			return found
	return null


func _line_edit(node: Node) -> LineEdit:
	if node is LineEdit:
		return node
	for child: Node in node.get_children():
		var found: LineEdit = _line_edit(child)
		if found != null:
			return found
	return null


func _viewport_tap(point: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = point
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = point
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame


func _finish() -> void:
	# The test creates no child directories and only removes its own verified root.
	if test_directory.begins_with("user://app_test_track_"):
		var directory := DirAccess.open(test_directory)
		if directory != null:
			for filename: String in directory.get_files():
				DirAccess.remove_absolute(test_directory.path_join(filename))
			DirAccess.remove_absolute(test_directory)
	print("APP_TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
