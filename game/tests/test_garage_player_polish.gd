extends SceneTree
## Actual App layout and native slider input, with isolated persistence and no API.
var checks: int = 0
var failures: int = 0
var output: String
var app: Node
var page: GaragePage

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)
func settle() -> void:
	await create_timer(0.85).timeout
	for frame: int in range(8): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	check(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"native capture "+label)
func mouse(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event,true)
	await process_frame
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event,true)
	await process_frame

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	output = "res://../docs/evidence/garage-player-polish-2026-10-24/final/app"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var folder: String = "user://player_polish_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	app = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.library = TrackLibrary.new(folder)
	app.cloud_root_override = folder.path_join("cloud")
	app.records.settings.music_volume = 0.07
	app.records.settings.music_enabled = true
	app.records.settings.music_record = "exploration"
	check(app.records.save_records()==OK,"save isolated listening preferences before App startup reload")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._show_screen("garage")
	await settle()
	page = app.root_ui.find_child("GaragePage",true,false)
	var car: CarVisual = page.showroom.car
	var viewport: SubViewport = page.showroom.showroom_viewport
	var car_camera: Transform3D = page.showroom.camera.transform
	var condition: Dictionary = page.showroom.weathering.snapshot()
	page._show_section("records")
	await settle()
	var menu: VBoxContainer = page.records_menu
	var stream: AudioStream = GameSoundtrack.instance().menu_player.stream
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,720),Vector2i(1720,914)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await settle()
		var bounds := Rect2(Vector2.ZERO,Vector2(dimensions))
		for node: Control in [page,page.tools_panel,page.preview,page.actions,menu.crate,menu.volume,menu.play_button,menu.previous_button,menu.next_button]:
			check(bounds.encloses(node.get_global_rect()),"visible App control fits "+str(node.name)+" "+str(dimensions))
		check(menu.volume.size.y>=48 and menu.previous_button.size.y>=48 and menu.play_button.size.y>=48,"touch targets "+str(dimensions))
		check(page.tools_panel.get_global_rect().encloses(menu.get_global_rect()),"all controls fit panel "+str(dimensions))
		await capture("app-record-player-"+str(dimensions.x))
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	await settle()
	# Real engine mouse routing and native HSlider keyboard handling.
	var slider: HSlider = menu.volume
	var point: Vector2 = slider.global_position+Vector2(slider.size.x*0.50,slider.size.y*0.5)
	await mouse(point,true)
	await mouse(point,false)
	check(absf(app.records.settings.music_volume-0.5)<0.03,"clicking native metal slider changes actual audio preference")
	check(GameSoundtrack.instance().menu_player.stream==stream,"volume adjustment preserves current stream")
	slider.grab_focus()
	await key(KEY_END)
	check(slider.value==100 and app.records.settings.music_volume==1.0,"native keyboard reaches full volume")
	await capture("volume-full-focus")
	await key(KEY_HOME)
	check(slider.value==0 and app.records.settings.music_volume==0,"native keyboard reaches mute")
	await key(KEY_RIGHT)
	check(slider.value==1 and app.records.settings.music_volume==0.01,"native keyboard adjusts volume precisely")
	menu.crate.flip_to(5)
	await settle()
	check(menu.play_button.disabled and menu.transport.visible,"unavailable sleeve retains current-record transport")
	check(GameSoundtrack.instance().menu_player.stream==stream and app.records.settings.music_record=="exploration","placeholder browsing preserves real playing LP")
	await capture("night-drive-placeholder")
	menu.transport.pressed.emit()
	check(not app.records.settings.music_enabled,"icon transport stops music while browsing placeholder")
	menu.transport.pressed.emit()
	check(app.records.settings.music_enabled,"icon transport restores music while browsing placeholder")
	menu._preview_volume(7)
	page._show_section("cars")
	await settle()
	var reload := LocalRecords.new(app.records.path)
	reload.load_records()
	check(reload.settings.music_volume==0.07,"navigation flushes delayed volume save")
	check(page.showroom.car==car and page.showroom.showroom_viewport==viewport,"same car and rendering viewport after listening")
	check(page.showroom.camera.transform.is_equal_approx(car_camera),"original car camera restored")
	check(page.showroom.weathering.snapshot()==condition,"listening leaves car condition intact")
	page._show_section("records")
	await settle()
	check(page.records_menu.browse_index==5,"return retains last sleeve")
	page.records_menu.crate.flip_to(0)
	await settle()
	await capture("app-final")
	app.queue_free()
	await process_frame
	GameSoundtrack.instance().apply_settings({"music_enabled":false})
	await create_timer(0.6).timeout
	print("GARAGE_PLAYER_POLISH: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
