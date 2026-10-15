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
	OS.set_environment("BMT_API_URL","")
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
	app.cloud_root_override = test_directory.path_join("cloud")
	var local_records: RefCounted = app.get("records")
	# Records path is injected before _ready can read or write owner data.
	check(_set_records_path(local_records, test_directory.path_join("records.json")), "local records have an isolated injectable path")
	if failures > 0:
		app.free()
		_finish()
		return
	root.add_child(app)
	var deadline: int = Time.get_ticks_msec()+10000
	while not app.get("startup_complete") and Time.get_ticks_msec() < deadline: await process_frame
	check(app.get("startup_complete"),"startup completes within its deadline")
	check(app.get("screen") == "account","isolated guest starts at Account")
	app.cloud.root_override = test_directory.path_join("cloud")
	app.cloud.load_cached()
	# Race now lists backend publications. Seed a cached immutable fixture so
	# this offline test still exercises real search, selection and racing.
	var cached_doc: Dictionary = TrackDocument.from_builtin(NativeTrack.read("res://resources/tracks/starter_circuit.json"))
	var cached_body: String = JSON.stringify(cached_doc)
	var cached_hash: String = cached_body.sha256_text()
	var cached_version: String = "00000000-0000-4000-8000-000000000001"
	app.cloud.entries.append({"track_id":"fixture-track", "version_id":cached_version,"content_hash":cached_hash,"name":"Starter fixture","creator":"Fixture author","creator_id":"fixture-owner","points":cached_doc.points,"theme":"pine","rating_average":null,"rating_count":0})
	app.cloud._write(app.cloud.cache_root().path_join(cached_hash+".json"),cached_doc)
	app.cloud._write(app.cloud.cache_root().path_join("index.json"),{"entries":app.cloud.entries})
	app.call("_show_screen","tracks") # Explicit guest choice, independent of saved owner identity.
	await process_frame
	check(app.get("screen") == "tracks" and app.get("game") == null, "startup opens Race with no running simulation")
	check((app.get("root_ui") as Node).find_child("TrackBrowser", true, false) != null, "Race exposes track discovery")
	check((app.get("root_ui") as Node).find_child("Tab_play", true, false) == null, "navigation has no Home tab")
	check((app.get("root_ui") as Node).find_child("Tab_create", true, false) != null, "Race exposes creator navigation")
	await _check_library()
	await process_frame
	await process_frame
	await _capture("app-race")
	var create_button: Button = (app.get("root_ui") as Node).find_child("Tab_create", true, false)
	await _viewport_tap(create_button.get_global_rect().get_center())
	await process_frame
	await process_frame
	check(app.get("screen") == "biome", "viewport-dispatched finger tap opens the creator biome choice")
	if app.get("screen") == "biome":
		(app.get("root_ui").find_child("Biome_pine",true,false) as Button).pressed.emit()
		await process_frame
		(app.get("root_ui").find_child("CreateTrack",true,false) as Button).pressed.emit()
		await process_frame
		await process_frame
	check(app.get("screen") == "create","biome selection creates a new editable track")
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
	await _check_editor_save_prompt()
	app.queue_free()
	await process_frame
	_finish()


func _check_editor_save_prompt() -> void:
	app.call("_start_new_document")
	await process_frame
	app.call("_select_creation_biome", "pine")
	await process_frame
	var draft: Dictionary = app.get("document")
	check(app.call("_save_draft") == OK and not (app.get("library") as TrackLibrary).load_wip(draft.id).is_empty(), "editor recovery autosave exists before departure choice")
	app.call("_request_editor_exit")
	await process_frame
	var dialog: ConfirmationDialog = (app.get("root_ui") as Node).find_child("SaveChangesDialog", true, false)
	check(dialog != null and dialog.visible, "leaving an unsaved editor opens the Save, Discard or Cancel prompt")
	var field: LineEdit = dialog.find_child("SaveDraftName", true, false) if dialog != null else null
	check(field != null and field.text.is_empty() and dialog.get_ok_button().disabled, "new draft requires a name before Save is available")
	if dialog != null: dialog.custom_action.emit(&"discard")
	await process_frame
	await process_frame
	check(app.get("screen") == "tracks", "Discard completes the requested editor exit on Race")
	check((app.get("library") as TrackLibrary).load_wip(draft.id).is_empty(), "Discard removes the autosaved recovery draft")


func _set_records_path(records: RefCounted, path: String) -> bool:
	for property: Dictionary in records.get_property_list():
		if property.name in ["path", "file_path", "records_path"]:
			records.set(property.name, path)
			return true
	return false


func _check_library() -> void:
	var browser: TrackBrowser = (app.get("root_ui") as Node).find_child("TrackBrowser",true,false)
	check(browser != null,"guest Race creates the browser")
	if browser == null: return
	while browser.loading: await process_frame
	await process_frame
	await process_frame
	check(browser.matches.size() == 1 and browser.grid.get_child_count() > 0 and browser.grid.get_child_count() <= 12,"track carousel displays the cached backend publication")
	await _capture("track-library")
	browser.search_dialog.open_for(browser.state,browser.random_button)
	browser.search_dialog._scope(1)
	var search: LineEdit = browser.search_dialog.edit
	search.text = "sTaRtEr"
	search.text_changed.emit(search.text)
	browser.search_dialog._apply()
	check(browser.matches.size() == 1,"name search is case insensitive and filters the full catalog")
	browser.search_dialog.open_for(browser.state,browser.random_button)
	browser.search_dialog._scope(2)
	search.text = str(browser.matches[0].creator).to_lower()
	search.text_changed.emit(search.text)
	check(not browser.search_dialog.matches.is_empty(),"creator search finds the selected creator")
	browser.search_dialog.close()
	await process_frame
	await process_frame
	await _viewport_tap((browser.grid.get_child(0) as Button).get_global_rect().get_center())
	while browser.selecting: await process_frame
	var chosen: NativeTrack = app.get("selected_track")
	check(chosen.identity == "cloud_fixture-track" and chosen.metadata.cloud_version == "00000000-0000-4000-8000-000000000001","a route card selects the stable track and exact immutable publication: "+chosen.identity+" / "+app.cloud.last_error)
	(browser.find_child("ToggleFavorite",true,false) as Button).pressed.emit()
	var store: LocalRecords = app.get("records")
	var reloaded := LocalRecords.new(store.path)
	reloaded.load_records()
	check(chosen.identity in reloaded.settings.get("favorites",[]),"favorites persist across store instances")
	browser.filter_dialog.open_for(browser.state,browser.filter_button)
	browser.filter_dialog._choose("section","favorites")
	browser.filter_dialog._apply()
	check(browser.matches.size() == 1,"Favorites intersects the current name filter")
	browser.search_dialog.open_for(browser.state,browser.random_button)
	browser.search_dialog._scope(1)
	search.text = "no such track"
	search.text_changed.emit(search.text)
	browser.search_dialog._apply()
	check(browser.matches.is_empty() and browser.random_button.disabled,"empty results disable random choice and expose a recovery message")
	browser.search_dialog.open_for(browser.state,browser.random_button)
	browser.search_dialog.clear_search()
	browser.search_dialog._apply()
	browser.random_button.pressed.emit()
	while browser.selecting: await process_frame
	check((app.get("selected_track") as NativeTrack).identity == chosen.identity,"random favorite respects both collection and search filters")
	await process_frame
	await _capture("track-favorites")
	(browser.find_child("LibraryRace",true,false) as Button).pressed.emit()
	while app.cloud_starting: await process_frame
	check((app.get("game").get("native_track") as NativeTrack).identity == chosen.identity,"library Race starts the selected favorite")
	check((app.get("game").get("track_session") as TrackSession).target_laps == 5,"production menu starts a five-lap race")
	app.call("_leave_race")
	await process_frame
	await process_frame
	browser = (app.get("root_ui") as Node).find_child("TrackBrowser",true,false)
	while browser.loading: await process_frame
	check(browser.state.get("section") == "favorites" and browser.matches.size() == 1,"return from racing preserves library filters")
	app.browser_state = {}
	app.call("_show_screen","tracks")
	await process_frame
	await process_frame


func _check_input_and_history() -> void:
	_button(app.get("root_ui"), "Track").pressed.emit()
	var canvas: EditorCanvas = app.get("canvas")
	canvas.document.pieces.insert(0,RoadPieces.create("straight",Vector2(-25,-12)))
	canvas.selected_piece = 0
	canvas.snap_enabled = false
	var original: Dictionary = (app.get("document") as Dictionary).duplicate(true)
	var start: Vector2 = canvas.to_screen(canvas._geometry_handle(original.pieces[0],"width"))
	var destination: Vector2 = start + Vector2(0.0,canvas.scale_factor() * 2.0)
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
	check(changed.pieces[0].width != original.pieces[0].width and changed.points == original.points, "mouse drag changes only the selected road width")
	check((app.get("history") as Array).size() == 1, "one completed drag creates one undo step")
	var library: TrackLibrary = app.get("library")
	# Gesture autosaves use the existing ordered background writer. Observe its
	# completed disk result without forcing the shipping write to be synchronous.
	var save_deadline: int = Time.get_ticks_msec()+5000
	while (app.editor_writes.thread != null or not app.editor_writes.pending.is_empty()) and Time.get_ticks_msec() < save_deadline:
		await process_frame
	check(library.load_wip(changed.id) == changed, "completed valid mouse edit autosaves to the isolated library")
	var expected_preview: NativeTrack = TrackCompiler.compile(changed)
	while app.get("editor_preview_thread") != null: await process_frame
	check(canvas.native_preview != null and canvas.native_preview.content_hash == expected_preview.content_hash and canvas.native_preview.cells == expected_preview.cells, "released editor drag refreshes the exact compiled native preview")
	_button(app.get("root_ui"), "Undo").pressed.emit()
	await process_frame
	await process_frame
	check(app.get("document") == original, "Undo restores the whole pre-drag document")
	_button(app.get("root_ui"), "Redo").pressed.emit()
	await process_frame
	await process_frame
	check(app.get("document") == changed, "Redo restores the edited document")
	canvas = app.get("canvas")
	start = canvas.to_screen(canvas._geometry_handle(changed.pieces[0],"width"))
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
	canvas.selected_piece = 0
	start = canvas.to_screen(canvas._geometry_handle(current.pieces[0],"width"))
	_touch(canvas, 12, start, true)
	check(canvas.dragging and canvas.geometry_drag == "width", "a fresh handle remains draggable after multitouch navigation")
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
	check(copy.creator == library.owner_name, "editable import stamps the current owner")
	check(library.load_wip(saved.id) == saved, "importing an existing identifier cannot overwrite the original draft")
	check(library.load_wip(copy.id) == copy, "the imported copy is persisted independently")
	check(imported.id == saved.id, "import does not mutate the supplied document")
	check((app.get("history") as Array).is_empty() and (app.get("redo_history") as Array).is_empty(), "import clears unrelated undo and redo history")


func _check_view_retention() -> void:
	var canvas: EditorCanvas = app.get("canvas")
	canvas.zoom_by(1.2)
	canvas.pan += Vector2(35, -12)
	_button(app.get("root_ui"), "Surfaces").pressed.emit()
	var saved_zoom: float = canvas.zoom
	var saved_pan: Vector2 = canvas.pan
	app.call("_set_document_value", "theme", "coast")
	await process_frame
	await process_frame
	canvas = app.get("canvas")
	check(canvas.mode == "paint" and canvas.pan == saved_pan and is_equal_approx(canvas.zoom, saved_zoom), "changing theme preserves the editor tool, zoom and pan")
	app.call("_undo")
	await process_frame
	await process_frame
	canvas = app.get("canvas")
	check(canvas.mode == "paint" and canvas.pan == saved_pan and is_equal_approx(canvas.zoom, saved_zoom), "Undo preserves the current editor view and tool")
	_button(app.get("root_ui"), "Track").pressed.emit()
	(app.get("canvas") as EditorCanvas).fit()


func _check_test_drive() -> void:
	var before: Dictionary = (app.get("document") as Dictionary).duplicate(true)
	var compiled: NativeTrack = TrackCompiler.compile(before)
	var zoom_before: float = (app.get("canvas") as EditorCanvas).zoom
	(app.get("test_button") as Button).pressed.emit()
	var deadline: int = Time.get_ticks_msec() + 15000
	while app.cloud_starting and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.cloud_starting, "practice finishes track loading within its deadline")
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
	app._restore_cloud_selection("cloud_fixture-track")
	var track: NativeTrack = app.get("selected_track")
	await app.call("_start_race", track, false)
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
	check(records.best_for(track, game.get("handling")) == 109.0 and (app.get("root_ui") as Node).find_child("ContinueResults",true,false) != null, "a clean normal race result persists its local PB and exposes Continue")
	check(((app.get("root_ui") as Node).find_child("RaceAchievement",true,false) as Label).text in ["FIRST FINISH","CLEAN RACE"],"a first normal finish is presented as the player's benchmark")
	await _capture("normal-race-debrief")
	var first_record: Dictionary = records.records.duplicate(true)
	var first_panel: Node = app.root_ui.find_child("ContinueResults",true,false)
	app.call("_results")
	check(records.records == first_record and app.root_ui.find_child("ContinueResults",true,false) == first_panel,"duplicate finish keeps one result and one saved attempt")
	# Controlled result fixtures exercise improvement feedback; they are not
	# additional claims of AI-driven lap times.
	await app.call("_retry_race")
	check(app.game == game and app._result_game_id == 0,"Retry starts a new result lifecycle on the same Game node")
	game.set("track_session",completed)
	game.set("paused",true)
	completed.lap_times[4] = 20.816
	completed.lap_start_time = 108.816
	app.call("_results")
	check(((app.get("root_ui") as Node).find_child("ResultDelta",true,false) as Label).text == "-0.184 s vs personal best","the integrated PB screen uses the previous saved target")
	await _capture("improved-race-debrief")
	await app.call("_retry_race")
	game.set("track_session",completed)
	game.set("paused",true)
	completed.lap_times[4] = 21.0
	completed.lap_start_time = 109.0
	app.call("_results")
	check(((app.get("root_ui") as Node).find_child("ResultDelta",true,false) as Label).text == "+0.184 s vs personal best","a slower integrated finish presents its exact gap without replacing the PB")
	var race_handling: HandlingConfig = game.get("handling")
	game.emit_signal("exit_requested")
	await process_frame
	await process_frame
	check(app.records.best_for(track,race_handling) == 108.816,"Race return preserves the best time for the active handling")
	await _capture("tracks-saved-best")
	var resumed: Node = (load("res://core/app.tscn") as PackedScene).instantiate()
	resumed.set("library",app.get("library"))
	resumed.set("records",LocalRecords.new(records.path))
	resumed.cloud_root_override = test_directory.path_join("cloud")
	resumed.cloud_root_override = test_directory.path_join("cloud")
	root.add_child(resumed)
	while not resumed.startup_complete: await process_frame
	resumed.online.client.configure("")
	resumed.cloud.root_override = test_directory.path_join("cloud")
	resumed.cloud.load_cached()
	resumed._restore_cloud_selection(str(resumed.records.settings.get("last_track","")))
	resumed.call("_show_screen", "tracks")
	await process_frame
	await process_frame
	var resumed_browser: TrackBrowser = resumed.get("root_ui").find_child("TrackBrowser",true,false)
	while resumed_browser.loading or resumed_browser.selecting: await process_frame
	check(((resumed.get("root_ui") as Node).find_child("LibraryBestTime",true,false) as Label).text == MenuStyle.time_text(108.816),"Tracks shows the active handling PB after loading a new app instance")
	resumed.call("_show_screen", "tracks")
	await process_frame
	check((resumed.get("selected_track") as NativeTrack).identity == track.identity,"relaunch resumes the last ordinary race circuit")
	check(((resumed.get("root_ui") as Node).find_child("LibraryBestTime",true,false) as Label).text == "01:48.816","returning Race presents the actual stored five-lap time to beat")
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
