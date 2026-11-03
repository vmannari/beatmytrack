extends SceneTree
## Saved playlist membership, real input, transport and end-of-record behavior.
const Library = preload("res://soundtrack/record_library.gd")
var checks: int = 0
var failures: int = 0
var output: String = OS.get_environment("BMT_PLAYLIST_EVIDENCE")

func _initialize() -> void: run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: " + message)

func settle() -> void:
	await create_timer(0.8).timeout
	for i: int in range(4): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func tap(control: Control, touch: bool = false) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	for down: bool in [true,false]:
		if touch:
			var event := InputEventScreenTouch.new()
			event.position = point
			event.index = 0
			event.pressed = down
			root.push_input(event,true)
		else:
			var event := InputEventMouseButton.new()
			event.position = point
			event.global_position = point
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = down
			root.push_input(event,true)
		await process_frame

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	check(Library.playlist({}).size() == 14,"existing saves include every record by default")
	for invalid: Variant in [null,{},"blacktop_thunder",[],[Library.DEFAULT_ID,Library.DEFAULT_ID],["missing"],[2]]:
		check(not Library.valid_playlist(invalid),"invalid playlist rejected: " + str(invalid))
	var folder: String = "user://record_playlist_" + TrackLibrary.unique_id()
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
	var music: GameSoundtrack = GameSoundtrack.instance()
	music._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	app.records.settings.music_record = Library.DEFAULT_ID
	check(menu._commit(),"initial selected-record preference saves")
	check(menu.playlist_checks.size() == 14,"each record has a playlist checkbox")
	check(menu.playlist_checks.all(func(button: CheckBox) -> bool: return button.button_pressed),"all records initially checked")
	menu._select_record(0)
	await settle()
	if DisplayServer.get_name() != "headless" and not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		check(root.get_texture().get_image().save_png(output.path_join("playlist-all-included.png")) == OK,"native all-included playlist screenshot")
		menu.playlist_checks[1].grab_focus()
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join("playlist-keyboard-focus.png")) == OK,"native playlist focus screenshot")
	var original_stream: AudioStream = music.menu_player.stream
	await tap(menu.playlist_checks[1])
	check(not menu.playlist_checks[1].button_pressed and Library.playlist(app.records.settings).size() == 13,"mouse removes a record from playlist")
	check(app.records.settings.music_record == Library.DEFAULT_ID and music.menu_player.stream == original_stream,"membership changes leave current playback alone")
	await tap(menu.playlist_checks[0],true)
	check(not menu.playlist_checks[0].button_pressed,"touch removes the playing record without selecting another")
	check(app.records.settings.music_record == Library.DEFAULT_ID,"checkbox tap does not trigger direct play")
	var reload := LocalRecords.new(app.records.path)
	reload.load_records()
	check(Library.playlist(reload.settings).size() == 12 and Library.DEFAULT_ID not in reload.settings.music_playlist,"playlist survives disk reload")
	music._menu_finished()
	check(music.menu_record == Library.CATALOG[2].id and menu.now_title.text == Library.CATALOG[2].title,"automatic advance skips excluded records and updates UI")
	menu._skip_record(-1)
	music._process(1.0)
	check(music.menu_record == Library.CATALOG[13].id,"previous wraps over excluded records")
	menu._skip_record(1)
	music._process(1.0)
	check(music.menu_record == Library.CATALOG[2].id,"next wraps over excluded records")
	menu._select_record(1)
	music._process(1.0)
	check(music.menu_record == Library.CATALOG[1].id and not menu.playlist_checks[1].button_pressed,"excluded record can still be played directly")
	menu._skip_record(-1)
	music._process(1.0)
	check(music.menu_record == Library.CATALOG[13].id,"previous from an excluded record finds the prior included record")
	# A later atomic save replaces settings; auto advance must use the bound current dictionary.
	check(app.records.save_records() == OK,"unrelated save preserves playlist")
	music._menu_finished()
	check(music.menu_record == Library.CATALOG[2].id,"automatic advance reads membership after settings replacement")
	if music.output_enabled:
		music.menu_player.seek(maxf(0.0,music.menu_player.stream.get_length()-0.2))
		await create_timer(0.8).timeout
		check(music.menu_record == Library.CATALOG[3].id,"actual native finished signal advances within playlist")
	menu._toggle_play()
	menu._set_in_playlist(true,Library.DEFAULT_ID)
	check(not music.music_enabled,"editing playlist retains paused music")
	menu._toggle_play()
	for index: int in range(1,14): menu._set_in_playlist(false,Library.CATALOG[index].id)
	check(app.records.settings.music_playlist == [Library.DEFAULT_ID],"one-record playlist is valid")
	check(menu.playlist_checks[0].disabled and menu.playlist_checks[0].button_pressed,"last included record stays selected with an explanation")
	menu._set_in_playlist(false,Library.DEFAULT_ID)
	check(app.records.settings.music_playlist == [Library.DEFAULT_ID],"empty selection cannot replace last valid playlist")
	menu._select_record(0)
	music._process(1.0)
	music._menu_finished()
	check(music.menu_record == Library.DEFAULT_ID,"single-record playlist repeats that record")
	music.mode = "race"
	music._menu_finished()
	check(music.menu_record == Library.DEFAULT_ID,"race context cannot advance menu music")
	music.show_menu()
	var saved_path: String = app.records.path
	app.records.path = folder.path_join("missing/records.json")
	menu._set_in_playlist(true,Library.CATALOG[1].id)
	check(app.records.settings.music_playlist == [Library.DEFAULT_ID] and not menu.playlist_checks[1].button_pressed,"failed save restores membership and checkbox")
	check(menu.status.text.contains("Could not save"),"failed save is visible")
	for dialog: Node in app.root_ui.find_children("*","FaultDialog",true,false):
		dialog.confirmed.emit()
	await process_frame
	app.records.path = saved_path
	menu._set_in_playlist(true,Library.CATALOG[2].id)
	check(app.records.settings.music_playlist.size() == 2 and menu.playlist_checks[2].button_pressed,"playlist can be edited again after save recovery")
	var committed: Dictionary = app.records.settings.duplicate(true)
	app.records.settings.music_playlist = ["missing"]
	check(app.records.save_records() == ERR_INVALID_DATA and app.records.settings == committed,"save validation rejects malformed playlist and retains preferences")
	menu._refresh()
	root.gui_release_focus()
	var pointer := InputEventMouseMotion.new()
	pointer.position = Vector2(200,200)
	pointer.global_position = pointer.position
	root.push_input(pointer,true)
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,900)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		menu.track_scroll.scroll_vertical = 0
		await settle()
		var bounds := Rect2(Vector2.ZERO,Vector2(dimensions))
		for control: Control in [menu,menu.track_scroll,menu.playlist_heading,menu.playlist_checks[0],menu.track_rows[0],menu.transport]:
			check(bounds.encloses(control.get_global_rect()),"control fits " + control.name + " " + str(dimensions))
		check(menu.playlist_checks[0].size.x >= 52 and menu.playlist_checks[0].size.y >= 52,"playlist checkbox has a touch-sized target")
		check(menu.track_rows[0].get_global_rect().end.x <= menu.playlist_checks[0].global_position.x,"play and membership targets do not overlap")
		if DisplayServer.get_name() != "headless" and not output.is_empty():
			DirAccess.make_dir_recursive_absolute(output)
			check(root.get_texture().get_image().save_png(output.path_join("playlist-%dx%d.png" % [dimensions.x,dimensions.y])) == OK,"native playlist screenshot")
	app.queue_free()
	await process_frame
	music.menu_player.stop()
	if music.output_enabled: await create_timer(0.3).timeout
	print("RECORD_PLAYLIST: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
