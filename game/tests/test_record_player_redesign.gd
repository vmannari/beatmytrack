extends SceneTree
const Library = preload("res://soundtrack/record_library.gd")
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)
func settle() -> void:
	await create_timer(0.8).timeout
	for i: int in range(4): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
func click(point: Vector2) -> void:
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event,true)
		await process_frame
func touch(point: Vector2) -> void:
	for down: bool in [true,false]:
		var event := InputEventScreenTouch.new()
		event.position = point
		event.index = 0
		event.pressed = down
		root.push_input(event,true)
		await process_frame
func run() -> void:
	OS.set_environment("BMT_API_URL","")
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var folder := "user://record_redesign_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var app = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.library = TrackLibrary.new(folder)
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._show_screen("garage")
	await settle()
	var page: GaragePage = app.root_ui.find_child("GaragePage",true,false)
	page._show_section("records")
	await settle()
	var menu = page.records_menu
	check(menu.track_rows.size()==14,"all tracks have a visible list action")
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,900)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await settle()
		var bounds := Rect2(Vector2.ZERO,Vector2(dimensions))
		for control: Control in [page.tools_panel,page.actions,menu,menu.track_scroll,menu.volume,menu.transport,menu.skip_previous,menu.skip_next]:
			check(bounds.encloses(control.get_global_rect()),"control fits " + control.name + " " + str(dimensions))
		check(menu.track_scroll.size.y >= (76 if dimensions.y < 650 else 104),"scrollable track list has room " + str(dimensions))
		if DisplayServer.get_name() != "headless":
			root.get_texture().get_image().save_png("res://../build/soundtrack-2026-test/redesign-"+str(dimensions.x)+".png")
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	await settle()
	var row: Button = menu.track_rows[1]
	await click(row.global_position+row.size*0.5)
	check(app.records.settings.get("music_record") == Library.CATALOG[1].id,"one click on a track starts it")
	check(menu.now_title.text == Library.CATALOG[1].title,"now playing identifies selected track")
	await click(menu.transport.global_position+menu.transport.size*0.5)
	check(not app.records.settings.get("music_enabled",true),"transport pauses selected track")
	await click(row.global_position+row.size*0.5)
	check(app.records.settings.get("music_enabled",false),"clicking paused track resumes it")
	var before_drag: String = app.records.settings.music_record
	menu.track_scroll.scroll_vertical = 0
	await process_frame
	var start: Vector2 = menu.track_scroll.global_position + Vector2(70,menu.track_scroll.size.y-20)
	var touch_down := InputEventScreenTouch.new()
	touch_down.index = 0
	touch_down.position = start
	touch_down.pressed = true
	root.push_input(touch_down,true)
	await process_frame
	for i: int in range(1,7):
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = start + Vector2(0,-i*25)
		drag.relative = Vector2(0,-25)
		root.push_input(drag,true)
		await process_frame
	var touch_up := InputEventScreenTouch.new()
	touch_up.index = 0
	touch_up.position = start + Vector2(0,-150)
	touch_up.pressed = false
	root.push_input(touch_up,true)
	await process_frame
	check(menu.track_scroll.scroll_vertical > 0,"touch drag scrolls the track list")
	check(app.records.settings.music_record == before_drag,"touch drag does not select a track")
	menu.track_scroll.ensure_control_visible(menu.track_rows[10])
	await settle()
	row = menu.track_rows[10]
	check(menu.track_scroll.get_global_rect().intersects(row.get_global_rect()),"later track can be scrolled into view")
	await click(row.global_position+row.size*0.5)
	check(app.records.settings.get("music_record") == Library.CATALOG[10].id,"direct selection works after scrolling")
	check(menu.track_states[10].text == "●","active track is clearly identified")
	menu.track_scroll.ensure_control_visible(menu.track_rows[9])
	await settle()
	row = menu.track_rows[9]
	await touch(row.global_position + row.size*0.5)
	check(app.records.settings.get("music_record") == Library.CATALOG[9].id, "touch selects a track directly")
	row = menu.track_rows[8]
	menu.track_scroll.ensure_control_visible(row)
	row.grab_focus()
	await process_frame
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	root.push_input(key,true)
	await process_frame
	key.pressed = false
	root.push_input(key,true)
	await process_frame
	check(app.records.settings.get("music_record") == Library.CATALOG[8].id, "keyboard activates a focused track")
	app.queue_free()
	await process_frame
	print("RECORD_PLAYER_REDESIGN: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
