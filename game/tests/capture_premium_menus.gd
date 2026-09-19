extends SceneTree
## Real menu evidence with disposable local records and no owner-data access.
## Result images use a controlled 108.816 s fixture against a 109.000 s PB;
## these are presentation examples, never claimed completed driving runs.

var checks: int = 0
var failures: int = 0
var app: Node
var test_directory: String
var capture_directory: String
var evidence: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: " + description)


func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-menus="):
			capture_directory = argument.trim_prefix("--capture-menus=")
	check(DisplayServer.get_name() != "headless" and capture_directory.is_absolute_path(), "menu evidence uses a graphical display and explicit absolute output directory")
	if failures > 0:
		_finish()
		return
	check(DirAccess.make_dir_recursive_absolute(capture_directory) == OK, "menu evidence directory is writable")
	for physical_size: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1600, 720)]:
		root.size = physical_size
		await process_frame
		await process_frame
		test_directory = "user://premium_menu_capture_" + TrackLibrary.unique_id()
		check(DirAccess.make_dir_recursive_absolute(test_directory) == OK, "isolated records directory is writable")
		app = (load("res://core/app.tscn") as PackedScene).instantiate()
		app.set("library", TrackLibrary.new(test_directory))
		app.set("records", LocalRecords.new(test_directory.path_join("records.json")))
		root.add_child(app)
		await _settle()
		await _capture("home-first", physical_size)
		await _navigate("garage")
		await _capture("garage", physical_size)
		await _navigate("tracks")
		await _capture("tracks", physical_size)
		await _populated_gallery(physical_size)
		# The normal app integration independently verifies the creator and
		# track-selection/race flows; this also checks the settings icon entry.
		await _navigate("settings")
		await _capture("settings", physical_size)
		await _navigate("play")
		await _result_fixture()
		await _capture("results-fixture", physical_size, true)
		if physical_size == Vector2i(1280, 720):
			await _check_result_retry()
		app.call("_leave_race")
		await _settle()
		app.call("_show_screen", "play")
		await _settle()
		await _capture("home-returning-fixture", physical_size, true)
		app.queue_free()
		await process_frame
		_cleanup()
	var manifest := FileAccess.open(capture_directory.path_join("manifest.json"), FileAccess.WRITE)
	check(manifest != null, "menu evidence manifest is writable")
	if manifest != null:
		manifest.store_string(JSON.stringify({
			"kind": "actual Godot menu captures",
			"results": "Controlled completed-session fixture: 108.816 s against a 109.000 s PB. No driven race is claimed.",
			"layout": "Uses the project's canvas_items stretch and expand aspect. Compact physical output preserves the 1280x720 logical design; this is not a physical-phone test.",
			"captures": evidence,
		}, "\t") + "\n")
		manifest.close()
	_finish()


func _navigate(destination: String) -> void:
	var node_name: String = "MenuSettings" if destination == "settings" else "Tab_" + destination
	var button: Button = (app.get("root_ui") as Node).find_child(node_name, true, false)
	check(button != null and button.is_visible_in_tree(), "visible navigation to " + destination)
	if button == null:
		app.call("_show_screen", destination)
	else:
		# Dispatch through the viewport to catch covered or unreachable actions.
		await _tap(button.get_global_rect().get_center())
		check(app.get("screen") == destination, "viewport touch reaches " + destination)
		if app.get("screen") != destination:
			app.call("_show_screen", destination)
	await _settle()


func _tap(point: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = point
	down.pressed = true
	root.push_input(down, true)
	await process_frame
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = point
	up.pressed = false
	root.push_input(up, true)
	await process_frame


func _check_result_retry() -> void:
	var game: Node = app.get("game")
	var hud: PlaygroundHUD = game.get("hud")
	check(not hud.visible, "results hide the gameplay HUD and pedal overlay")
	var retry: Button = (app.get("root_ui") as Node).find_child("RetryRace", true, false)
	check(retry != null and retry.is_visible_in_tree(), "results expose a reachable retry action")
	if retry == null:
		return
	await _tap(retry.get_global_rect().get_center())
	check(hud.visible and hud.touch.enabled and not (app.get("root_ui") as Control).visible, "retry restores gameplay controls and dismisses the result overlay")
	var session: TrackSession = game.get("track_session")
	check(not session.finished and not bool(game.get("paused")) and session.completed_laps == 0, "result retry starts a fresh unpaused race")


func _result_fixture() -> void:
	var track: NativeTrack = app.get("selected_track")
	var records: LocalRecords = app.get("records")
	var baseline_laps: Array[float] = [22.0, 21.0, 23.0, 22.0, 21.0]
	check(records.record(track, load("res://resources/balanced.tres") as HandlingConfig, 109.0, baseline_laps) == OK, "isolated result fixture baseline saved")
	app.call("_start_race", track, false)
	var game: Node = app.get("game")
	game.set_physics_process(false)
	var completed := TrackSession.new()
	completed.completed_laps = 5
	completed.elapsed_ticks = 13058
	completed.lap_start_time = 108.816
	completed.lap_times.assign([22.0, 21.0, 23.0, 22.0, 20.816])
	completed.finished = true
	game.set("track_session", completed)
	game.set("paused", true)
	game.set("attempt_practice", false)
	game.emit_signal("race_completed")
	await _settle()


func _settle() -> void:
	await process_frame
	await process_frame
	var browser: TrackBrowser = (app.get("root_ui") as Node).find_child("TrackBrowser", true, false)
	if browser != null:
		while browser.loading:
			await process_frame
	# Keep screenshots independent of the desktop cursor's position. This is
	# a viewport event only; it does not warp the owner's operating-system mouse.
	var pointer := InputEventMouseMotion.new()
	pointer.position = Vector2(-100, -100)
	root.push_input(pointer, true)
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw


func _capture(label: String, physical_size: Vector2i, fixture: bool = false) -> void:
	var viewport_rect: Rect2 = root.get_visible_rect()
	_check_actions(app.get("root_ui"), viewport_rect, false, label)
	var filename: String = "%s-%dx%d.png" % [label, physical_size.x, physical_size.y]
	var screenshot: Image = root.get_texture().get_image()
	check(screenshot.get_size() == physical_size, "physical screenshot size " + filename)
	var error: Error = screenshot.save_png(capture_directory.path_join(filename))
	check(error == OK, "menu evidence saved " + filename)
	if error == OK:
		print("MENU_CAPTURE_SAVED: " + capture_directory.path_join(filename))
	evidence.append({"file": filename, "physical_size": [screenshot.get_width(), screenshot.get_height()], "logical_size": [viewport_rect.size.x, viewport_rect.size.y], "fixture": fixture})


func _check_actions(node: Node, bounds: Rect2, inside_scroll: bool, label: String) -> void:
	if node is SubViewport or node is Window:
		return
	if node is Control and not (node as Control).is_visible_in_tree():
		return
	if node is ScrollContainer:
		inside_scroll = true
	if (node is BaseButton or node is LineEdit or node is Slider) and not inside_scroll:
		var control: Control = node as Control
		var rect: Rect2 = control.get_global_rect()
		check(rect.size.x > 0.0 and rect.size.y > 0.0 and bounds.grow(1.0).encloses(rect), "%s action remains inside logical viewport: %s %s" % [label, node.name, rect])
	for child: Node in node.get_children():
		_check_actions(child, bounds, inside_scroll, label)


func _cleanup() -> void:
	# No subdirectories are created; cleanup is restricted to this harness root.
	if not test_directory.begins_with("user://premium_menu_capture_track_"):
		return
	var directory := DirAccess.open(test_directory)
	if directory != null:
		for filename: String in directory.get_files():
			DirAccess.remove_absolute(test_directory.path_join(filename))
		DirAccess.remove_absolute(test_directory)


func _finish() -> void:
	_cleanup()
	print("PREMIUM_MENU_CAPTURES: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _populated_gallery(physical_size: Vector2i) -> void:
	var browser: TrackBrowser = (app.get("root_ui") as Node).find_child("TrackBrowser",true,false)
	var original: Array[Dictionary] = browser.catalog.entries.duplicate(true)
	var sample: Dictionary = original[0].duplicate(true)
	# Metadata-only gallery fixtures, never saved into the owner catalog.
	for index: int in range(7):
		var entry: Dictionary = sample.duplicate(true)
		entry.id = "gallery_fixture_%d" % index
		entry.name = ["Pine Ridge", "Redrock Run", "Harbor Run", "Frostbite Run", "Stormy Slalom", "Forest Loop", "Desert Sprint"][index]
		entry.creator = "Gallery fixture"
		entry.theme = TrackTheme.IDS[index%TrackTheme.IDS.size()]
		browser.catalog.entries.append(entry)
	browser.call("_refresh")
	await _settle()
	check(browser.grid.get_child_count() == 6,"populated discovery gallery stays bounded at six cards")
	await _capture("tracks-populated-fixture",physical_size,true)
	browser.call("_page",1)
	await _settle()
	check(browser.grid.get_child_count() == 2,"discovery next page shows remaining entries")
	await _capture("tracks-storm-fixture",physical_size,true)
	browser.catalog.entries = original
	browser.state.page = 0
	browser.call("_refresh")
