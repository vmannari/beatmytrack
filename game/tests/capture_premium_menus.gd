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
		while not app.get("startup_complete"): await process_frame
		app.call("_show_screen","play")
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
	if destination == "play" and (app.get("root_ui") as Node).find_child("Tab_play",true,false) == null: destination = "tracks"
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
	if browser.cloud != null:
		browser.cloud.changed.disconnect(browser._cloud_changed)
		browser.cloud = null
	var original: Array[Dictionary] = browser.catalog.entries.duplicate(true)
	var sample: Dictionary = {}
	for entry: Dictionary in original:
		if entry.source == "builtin": sample = entry.duplicate(true); break
	browser.catalog.entries.assign([sample])
	# Metadata-only gallery fixtures, never saved into the owner catalog.
	for index: int in range(7):
		var entry: Dictionary = sample.duplicate(true)
		entry.id = "gallery_fixture_%d" % index
		entry.name = ["Pine Ridge", "Redrock Run", "Harbor Run", "Frostbite Run", "Stormy Slalom", "Forest Loop", "Desert Sprint"][index]
		entry.creator = "Gallery fixture"
		entry.theme = TrackTheme.IDS[index%TrackTheme.IDS.size()]
		browser.catalog.entries.append(entry)
	browser.records.settings["track_ratings"] = {"gallery_fixture_0":4,"gallery_fixture_2":5}
	browser.call("_refresh")
	await _settle()
	check(browser.grid.get_child_count() == mini(12,browser.matches.size()),"all eight fixture tracks are reachable in one continuous row")
	for card: TrackTile in browser.grid.get_children():
		var rating: int = int(browser.records.settings.track_ratings.get(str(card.entry.id),0))
		check(card.personal_rating == rating,"gallery shows saved rating for its track identity")
		check(card.rating_text() == ("%.1f (1)" % rating if rating > 0 else "— (0)"),"gallery shows rating and bracketed local vote count")
	var tile: TrackTile = browser.grid.get_child(0)
	var selected_before: String = browser.selected_track.identity
	var star: Button = tile.get_node("ToggleFavorite")
	var favorite_id: String = str(tile.entry.id)
	await _tap(star.get_global_rect().get_center())
	check(favorite_id in browser.records.settings.get("favorites",[]),"card star saves favorite through viewport touch")
	check(browser.selected_track.identity == selected_before and not browser.selecting,"star does not trigger track selection")
	check(browser.detail.find_children("*","TrackShowroom",true,false).is_empty(),"bottom card has no overview")
	await _settle()
	var race_chart: TrackDistribution = browser.find_child("RaceDistribution",true,false)
	var lap_chart: TrackDistribution = browser.find_child("LapDistribution",true,false)
	check(race_chart != null and lap_chart == null,"reference layout shows a race comparison below the hero")
	check(browser.find_child("DeleteUserTrack",true,false) == null and browser.find_child("RemixTrack",true,false) == null,"Play does not expose track modification actions")
	await _capture("tracks-populated-fixture",physical_size,true)
	# Presentation-only transition fixture; retain canonical selected track.
	var transition_bounds: Rect2 = browser.hero.get_global_rect()
	browser.preview_entry = {"id":"transition_start","name":"Pine Ridge","creator":"Gallery fixture","theme":"pine","points":[[0,0],[80,0],[110,60],[40,90]]}
	browser._show_hero("PINE RIDGE","pine")
	await create_timer(0.2).timeout
	browser._selection_serial += 1
	browser.preview_entry = {"id":"transition_fixture","name":"Redrock Run","creator":"Gallery fixture","theme":"desert","points":[[0,0],[80,0],[110,60],[40,90]]}
	browser._hero_direction = 1.0
	browser._show_hero("REDROCK RUN","desert")
	await create_timer(0.05).timeout
	await RenderingServer.frame_post_draw
	check(is_equal_approx(browser.hero.position.x,browser.records_panel.position.x),"hero and records share the same slide offset")
	var outgoing_alpha: float = browser.hero.modulate.a
	check(outgoing_alpha > 0.0 and outgoing_alpha < 1.0,"scenery visibly blends during transition")
	check(browser.hero.size == transition_bounds.size and (browser.find_child("HeroSlot",true,false) as Control).get_global_rect() == transition_bounds,"slide keeps the allocated section bounds fixed")
	check(browser._section_offset > 0.0 and browser._section_offset < 48.0,"forward slide is between its start and centered position")
	await _capture("section-slide-mid",physical_size,true)
	# Interrupt before the first fade completes: newest title must win now.
	browser._selection_serial += 1
	browser.preview_entry.name = "Frostbite Run"
	browser.preview_entry.theme = "winter"
	browser._hero_direction = -1.0
	browser._show_hero("FROSTBITE RUN","winter")
	check((browser.hero.find_child("HeroTrackTitle",true,false) as Label).text == "FROSTBITE RUN","interrupt updates title immediately")
	await create_timer(0.05).timeout
	await RenderingServer.frame_post_draw
	check(browser._section_offset < 0.0 and browser._section_offset > -48.0,"reverse slide interrupts immediately from the left")
	await _capture("section-slide-interrupted",physical_size,true)
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	check(browser._hero_scenery.get_child_count() == 1,"interrupted scenery settles without queued transitions")
	check(is_zero_approx(browser._section_offset),"slide settles at the centered crop")
	await _capture("section-slide-settled",physical_size,true)
	browser.preview_entry = {}
	browser._show_detail()
	await _settle()

	var wheel := InputEventMouseButton.new()
	wheel.position = browser.gallery.get_global_rect().get_center()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	root.push_input(wheel,true)
	await create_timer(0.4).timeout
	await _settle()
	check(browser.gallery.scroll_horizontal > 0,"mouse wheel scrolls the continuous row")
	await _capture("tracks-storm-fixture",physical_size,true)
	browser.gallery.scroll_horizontal = 0
	await _settle()
	var before_favorites: Array = browser.records.settings.get("favorites",[]).duplicate()
	var touch_origin: Vector2 = browser.gallery.get_global_rect().get_center()
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = touch_origin
	touch.pressed = true
	root.push_input(touch,true)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = touch_origin-Vector2(280,0)
	drag.relative = Vector2(-280,0)
	root.push_input(drag,true)
	check(browser.gallery.scroll_horizontal == mini(280,int(browser.gallery_content.custom_minimum_size.x-browser.gallery.size.x)),"drag follows the pointer smoothly before snapping")
	touch = InputEventScreenTouch.new()
	touch.index = 0
	touch.position = drag.position
	touch.pressed = false
	root.push_input(touch,true)
	await _settle()
	await create_timer(0.25).timeout
	check(browser.gallery.scroll_horizontal > 0,"mobile swipe scrolls the track row")
	check(browser.gallery.scroll_horizontal % browser.tile_stride == 0,"released swipe locks to a full card boundary")
	check((int(browser.gallery.size.x)+12) % browser.tile_stride == 0,"carousel width fits only complete cards")
	check(browser.selected_track.identity == selected_before and not browser.selecting,"swipe never selects a track")
	check(browser.records.settings.get("favorites",[]) == before_favorites,"swipe never toggles a favorite")
	await _tap((browser.find_child("RaceSearch",true,false) as Button).get_global_rect().get_center())
	check(browser.search_dialog.visible,"Search beside Filters opens through viewport input")
	var search: LineEdit = browser.search_dialog.find_child("Search_search",true,false)
	var search_before: Dictionary = browser.state.duplicate(true)
	await create_timer(0.2).timeout
	await _settle()
	check(not browser.gallery.is_processing_input(),"search blocks underlying carousel gestures")
	check(browser.search_dialog.matches.size() == 8 and browser.search_dialog.results.get_child_count() == 4,"empty initial search renders four real previews and full count")
	for result: Control in browser.search_dialog.results.get_children():
		check(result.get_global_rect().grow(1).encloses((result.get_child(0) as Control).get_global_rect()),"search row content stays inside its touch target")
	await _capture("search-default",physical_size,true)
	search.text = "Redrock"
	search.text_changed.emit(search.text)
	await _settle()
	check(browser.search_dialog.matches.size() == 1 and browser.search_dialog.matches[0].name == "Redrock Run","Search previews names across the full catalog")
	check(browser.state == search_before,"typing leaves applied gallery filters unchanged")
	await _capture("search-name",physical_size,true)
	search.text = "Gallery fixture"
	search.text_changed.emit(search.text)
	check(browser.search_dialog.matches.size() == 7,"Search finds creators across the full catalog")
	await _tap(browser.search_dialog.scopes[1].get_global_rect().get_center())
	check(browser.search_dialog.matches.is_empty(),"name-only scope excludes creator matches")
	await _settle()
	await _capture("search-empty",physical_size,true)
	await _tap(browser.search_dialog.scopes[2].get_global_rect().get_center())
	check(browser.search_dialog.matches.size() == 7,"creator-only scope returns creator matches")
	await _tap(browser.search_dialog.more_button.get_global_rect().get_center())
	check(browser.search_dialog.results.get_child_count() == 7,"more expands real search results")
	await _tap(browser.search_dialog.apply_button.get_global_rect().get_center())
	check(not browser.search_dialog.visible and browser.matches.size() == 7 and browser.state.search_kind == 2,"Show tracks applies search and scope")
	check(browser.gallery.is_processing_input(),"applying search restores carousel input")
	check(not (browser.find_child("RaceSearch",true,false) as Button).has_focus(),"closed Search leaves no focus border on its launcher")
	await _tap((browser.find_child("RaceSearch",true,false) as Button).get_global_rect().get_center())
	await create_timer(0.2).timeout
	await _tap((browser.search_dialog.find_child("ClearSearch",true,false) as Button).get_global_rect().get_center())
	check(search.text.is_empty() and browser.state.search == "Gallery fixture","Clear previews empty search until applied")
	var cancel_search := InputEventKey.new()
	cancel_search.keycode = KEY_ESCAPE
	cancel_search.pressed = true
	root.push_input(cancel_search,true)
	check(not browser.search_dialog.visible and browser.state.search == "Gallery fixture","Escape discards pending search")
	await _tap((browser.find_child("RaceSearch",true,false) as Button).get_global_rect().get_center())
	await create_timer(0.2).timeout
	search.text = ""
	search.text_changed.emit("")
	await _tap(browser.search_dialog.apply_button.get_global_rect().get_center())
	check(browser.matches.size() == 8,"clearing and applying restores all fixture results")
	await _tap((browser.find_child("RaceSearch",true,false) as Button).get_global_rect().get_center())
	await create_timer(0.2).timeout
	await _tap(((app.get("root_ui") as Node).find_child("Tab_create",true,false) as Control).get_global_rect().get_center())
	check(not browser.search_dialog.visible and app.get("screen") == "tracks","search backdrop dismisses without underlying navigation")
	await _tap((browser.find_child("RaceSearch",true,false) as Button).get_global_rect().get_center())
	await create_timer(0.2).timeout
	await _tap(browser.search_dialog.scopes[0].get_global_rect().get_center())
	search.text = "Redrock"
	search.text_changed.emit(search.text)
	await _settle()
	await _tap((browser.search_dialog.results.get_child(0) as Control).get_global_rect().get_center())
	check(not browser.search_dialog.visible and browser.state.search == "Redrock","touching a preview applies search and selects its track")
	while browser.selecting: await process_frame
	browser.state.search = ""
	browser.state.search_kind = 0
	browser._refresh()
	await _settle()

	await _tap((browser.find_child("RaceFilters",true,false) as Button).get_global_rect().get_center())
	check(browser.filter_dialog.visible,"Filters opens through viewport input")
	await create_timer(0.2).timeout
	await _settle()
	var filter_scroll: ScrollContainer = browser.filter_dialog.panel.find_children("*","ScrollContainer",true,false)[0]
	check(filter_scroll.scroll_vertical == 0,"drawer opens with the Show heading visible")
	check(filter_scroll.get_v_scroll_bar().max_value <= filter_scroll.get_v_scroll_bar().page+1,"all filter groups fit the landscape drawer without scrolling")
	await _capture("filters-default",physical_size,true)
	var pending_before: Dictionary = browser.state.duplicate(true)
	var drawer: CanvasLayer = browser.filter_dialog
	var grass: Button = drawer.find_child("Choice_theme_pine",true,false)
	await _tap(grass.get_global_rect().get_center())
	check(browser.filter_dialog.draft.theme == "pine" and browser.state == pending_before,"filter choices preview without changing the gallery")
	await _tap(browser.filter_dialog.rating_slider.get_global_rect().get_center())
	check(is_equal_approx(float(browser.filter_dialog.draft.minimum_rating),2.5),"touch selects the midpoint of the rating slider")
	var rating_touch := InputEventScreenTouch.new()
	rating_touch.index = 1
	rating_touch.pressed = true
	rating_touch.position = browser.filter_dialog.rating_slider.get_global_rect().get_center()
	root.push_input(rating_touch,true)
	var rating_drag := InputEventScreenDrag.new()
	rating_drag.index = 1
	rating_drag.position = rating_touch.position+Vector2(600,0)
	rating_drag.relative = Vector2(600,0)
	root.push_input(rating_drag,true)
	rating_touch.pressed = false
	rating_touch.position = rating_drag.position
	root.push_input(rating_touch,true)
	check(is_equal_approx(float(browser.filter_dialog.draft.minimum_rating),5.0),"touch drag follows the rating slider and clamps at five outside its bounds")
	browser.filter_dialog.rating_slider.value = 4.1
	check(is_equal_approx(float(browser.filter_dialog.draft.minimum_rating),4.1),"rating slider supports 0.1 steps")
	browser.filter_dialog.rating_slider.grab_focus()
	var increase := InputEventKey.new()
	increase.keycode = KEY_RIGHT
	increase.pressed = true
	root.push_input(increase,true)
	check(is_equal_approx(float(browser.filter_dialog.draft.minimum_rating),4.2),"keyboard rating adjustment advances one tenth")
	increase.pressed = false
	root.push_input(increase,true)
	browser.filter_dialog.rating_slider.value = 4.1
	check(browser.filter_dialog.apply_button.text == "SHOW 0 TRACKS","preview count combines biome and minimum rating")
	await _settle()
	await _capture("filters-rating",physical_size,true)
	await _tap(browser.filter_dialog.apply_button.get_global_rect().get_center())
	check(not browser.filter_dialog.visible and browser.matches.is_empty(),"Show tracks commits combined filters and handles zero results")
	await _tap((browser.find_child("RaceFilters",true,false) as Button).get_global_rect().get_center())
	await create_timer(0.2).timeout
	check(is_equal_approx(browser.filter_dialog.rating_slider.value,4.1),"reopening keeps the applied rating")
	var reset: Button = drawer.find_child("ResetFilters",true,false)
	await _tap(reset.get_global_rect().get_center())
	check(browser.matches.is_empty(),"Reset previews defaults without silently committing")
	await _tap(browser.filter_dialog.apply_button.get_global_rect().get_center())
	check(browser.matches.size() == 8,"Reset then Show restores all fixture tracks")
	await _tap((browser.find_child("RaceFilters",true,false) as Button).get_global_rect().get_center())
	await create_timer(0.2).timeout
	await _tap(grass.get_global_rect().get_center())
	var cancel := InputEventKey.new()
	cancel.keycode = KEY_ESCAPE
	cancel.pressed = true
	root.push_input(cancel,true)
	check(not browser.filter_dialog.visible and browser.state.theme == "all" and browser.gallery.is_processing_input(),"Escape discards pending choices and restores carousel input")
	await _tap((browser.find_child("RaceFilters",true,false) as Button).get_global_rect().get_center())
	await create_timer(0.2).timeout
	await _tap(((app.get("root_ui") as Node).find_child("Tab_create",true,false) as Control).get_global_rect().get_center())
	check(not browser.filter_dialog.visible and app.get("screen") == "tracks","backdrop tap closes filters without navigating the menu underneath")
	check(not browser.filter_button.has_focus(),"closed Filters leaves no focus border on its launcher")
	browser.filter_dialog.close()
	await _settle()

	# A large catalog remains bounded while every entry can be scrolled into view.
	var small_catalog: Array[Dictionary] = browser.catalog.entries.duplicate(true)
	for index: int in range(1000):
		var entry: Dictionary = sample.duplicate(true)
		entry.id = "large_fixture_%d" % index
		entry.name = "ZZ %04d" % index
		browser.catalog.entries.append(entry)
	browser._refresh()
	await _settle()
	browser.gallery.scroll_horizontal = 999999
	await _settle()
	check(browser.grid.get_child_count() <= 12,"large catalog renders at most twelve nearby cards")
	check((browser.grid.get_child(browser.grid.get_child_count()-1) as TrackTile).entry.name == "ZZ 0999","continuous scrolling reaches the last track in a thousand-entry catalog")
	browser.catalog.entries = small_catalog
	browser.gallery.scroll_horizontal = 0
	browser._refresh()
	await _settle()
	var stable: Dictionary = _race_rectangles(browser)
	for control: Node in browser.find_children("*","Button",true,false):
		check((control as Button).text not in ["<",">"],"carousel has no visible arrow buttons")
	var original_metadata: Dictionary = browser.selected_track.metadata.duplicate(true)
	browser.selected_track.metadata.title = "A very long track title with many words to exercise stable section widths"
	browser.selected_track.metadata.creator = "A long creator name that must not move the route or records"
	browser._show_detail()
	await _settle()
	check(_race_rectangles(browser) == stable,"long track titles and creator names preserve every section rectangle")
	browser.selected_track.metadata = original_metadata
	browser._show_detail()
	await _settle()
	var rail: Control = browser.find_child("RaceModes",true,false)
	check(rail.get_global_rect().end.x < browser.hero.global_position.x,"mode rail sits to the left of the preview")
	check(browser.find_child("HeroRace",true,false) == null and browser.find_child("Mode_dice",true,false) == null,"duplicate Race and Random actions are removed")
	var random_rect: Rect2 = browser.random_button.get_global_rect()
	check(random_rect.size.x >= 190 and random_rect.size.x == (browser.find_child("RaceFilters",true,false) as Control).size.x and random_rect.size.x == (browser.find_child("RaceSearch",true,false) as Control).size.x,"Random, Filters and Search are equal spacious widths")
	var key: String = browser.records.key_for(browser.selected_track,HandlingSelection.config())
	browser.discovery.records_by_rules_key[key] = {
		"race_top_percent":18,"lap_top_percent":7,
		"race_distribution":{"bins":[1,3,6,10,17,23,28,22,16,9,5,2],"min_ms":55000,"max_ms":80000,"player_bin":7},
		"lap_distribution":{"bins":[2,7,12,19,15,8,3],"min_ms":11000,"max_ms":17000,"player_bin":2},
		"friends":[{"player":"Fixture Alex","race_ms":68421,"lap_ms":13410},{"player":"Fixture Jen","race_ms":70053,"lap_ms":13702},{"player":"Fixture third player with a long display name","race_ms":71000,"lap_ms":13900}]}
	browser.call("_show_detail")
	await _settle()
	check(_race_rectangles(browser) == stable,"comparison data preserves section rectangles")
	await _capture("tracks-data-fixture",physical_size,true)
	# Verified-track controls must fit the same layout without invented scores.
	browser.selected_track.metadata.cloud_version = "layout-fixture"
	browser._show_detail()
	await _settle()
	check(_race_rectangles(browser) == stable,"cloud controls preserve section rectangles")
	await _capture("tracks-cloud-controls-fixture",physical_size,true)
	browser.selected_track.metadata.erase("cloud_version")
	browser.discovery.records_by_rules_key.clear()
	browser.catalog.entries = original
	browser.state.page = 0
	browser.call("_refresh")
	await _settle()
	var home: Button = (app.get("root_ui") as Node).find_child("Tab_tracks",true,false)
	await _tap(home.get_global_rect().get_center())
	check(app.get("screen") == "tracks","shared Race tab reaches the library through viewport touch")

func _race_rectangles(browser: TrackBrowser) -> Dictionary:
	var result: Dictionary = {}
	for title: String in ["HeroSlot","RecordsSlot","GallerySlot","PersonalRecords","Standings","RaceComparison","PlayActions","LibraryRace"]:
		result[title] = (browser.find_child(title,true,false) as Control).get_global_rect()
		if title in ["PersonalRecords","Standings","RaceComparison"]:
			result[title].position.x -= browser._section_offset
	return result
