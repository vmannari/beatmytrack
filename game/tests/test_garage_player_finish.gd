extends SceneTree
## Native final finish: stable transport, exact cursor continuity, routing and framing.
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
	if DisplayServer.get_name() != "headless":
		root.grab_focus()
		await process_frame
		await RenderingServer.frame_post_draw
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
	output = "res://../docs/evidence/garage-player-finish-2026-10-24/final/app"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	# Exercise a real never-started player before App boot. stop() queues retirement
	# of an existing playback, so stopping a live player is not a fresh-start fixture.
	var initial_music: GameSoundtrack = GameSoundtrack.instance()
	if initial_music.output_enabled:
		initial_music._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		initial_music.apply_settings({"music_enabled":false})
		initial_music.show_menu()
		await create_timer(0.10).timeout
		check(not initial_music.menu_player.has_stream_playback(),"off-before-first-play has no decoder")
		initial_music.apply_settings({"music_enabled":true})
		check(initial_music.menu_player.has_stream_playback() and not initial_music.menu_player.stream_paused,"cold start works after an off-before-first-play state")
		await create_timer(0.15).timeout
		check(initial_music.menu_player.get_playback_position()>0.02,"cold-start music advances normally")
	var folder: String = "user://player_polish_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	app = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.library = TrackLibrary.new(folder)
	app.cloud_root_override = folder.path_join("cloud")
	app.records.settings.music_volume = 0.41
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
		for node: Control in [page,page.tools_panel,page.preview,page.actions,menu.crate,menu.volume,menu.transport,menu.previous_button,menu.next_button,menu.skip_previous,menu.skip_next]:
			check(bounds.encloses(node.get_global_rect()),"visible App control fits "+str(node.name)+" "+str(dimensions))
		check(menu.volume.size.y>=48 and menu.previous_button.size.y>=48 and menu.transport.size.y>=48,"touch targets "+str(dimensions))
		check(page.tools_panel.get_global_rect().encloses(menu.get_global_rect()),"all controls fit panel "+str(dimensions))
		var station: Node3D = page.showroom.record_station
		var render_bounds := Rect2(Vector2.ZERO,Vector2(viewport.size))
		for x: float in [-0.93,0.93]:
			for z: float in [-0.24,0.24]:
				var foot: Vector2 = page.showroom.camera.unproject_position(station.to_global(Vector3(x,0.015,z)))
				check(render_bounds.has_point(foot),"cabinet foot stays in the native camera "+str(dimensions)+str(Vector2(x,z)))
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
	await playback_checks(menu,stream)
	menu.transport.pressed.emit()
	check(not app.records.settings.music_enabled,"icon transport stops music while browsing placeholder")
	menu.transport.pressed.emit()
	check(app.records.settings.music_enabled,"icon transport restores music while browsing placeholder")
	menu._preview_volume(41)
	page._show_section("cars")
	await settle()
	var reload := LocalRecords.new(app.records.path)
	reload.load_records()
	check(reload.settings.music_volume==0.41,"navigation flushes delayed volume save")
	check(page.showroom.car==car and page.showroom.showroom_viewport==viewport,"same car and rendering viewport after listening")
	check(page.showroom.camera.transform.is_equal_approx(car_camera),"original car camera restored")
	check(page.showroom.weathering.snapshot()==condition,"listening leaves car condition intact")
	page._show_section("records")
	await settle()
	check(page.records_menu.browse_index==5,"return retains last sleeve")
	page.records_menu.crate.flip_to(6)
	await settle()
	await capture("app-final")
	app.queue_free()
	await process_frame
	GameSoundtrack.instance().apply_settings({"music_enabled":false})
	await create_timer(0.6).timeout
	print("GARAGE_PLAYER_FINISH: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func click(button: Button, touch: bool = false) -> void:
	var at: Vector2 = button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	root.push_input(motion,true)
	await process_frame
	for pressed: bool in [true,false]:
		if touch:
			var event := InputEventScreenTouch.new()
			event.index = 5
			event.position = at
			event.pressed = pressed
			root.push_input(event,true)
		else:
			await mouse(at,pressed)
		await process_frame

func glyph_center(button: Button, label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var pixels: Image = root.get_texture().get_image()
	var center: Vector2 = button.get_global_rect().get_center()
	var minimum := Vector2i(99999,99999)
	var maximum := Vector2i(-99999,-99999)
	var found: int = 0
	for y: int in range(roundi(center.y)-17,roundi(center.y)+18):
		for x: int in range(roundi(center.x)-17,roundi(center.x)+18):
			var color: Color = pixels.get_pixel(x,y)
			if minf(color.r,minf(color.g,color.b))<0.68: continue
			minimum = Vector2i(mini(minimum.x,x),mini(minimum.y,y))
			maximum = Vector2i(maxi(maximum.x,x),maxi(maximum.y,y))
			found += 1
	check(found>12,"native "+label+" glyph is visible")
	var offset: Vector2 = (Vector2(minimum)+Vector2(maximum))*0.5-center
	print("TRANSPORT_GLYPH ",label," offset=",offset," pixels=",found)
	check(absf(offset.x)<=2.5 and absf(offset.y)<=1.5,"actual "+label+" pixels are centered in the playback button")

func playback_checks(menu: VBoxContainer, stream: AudioStream) -> void:
	var music: GameSoundtrack = GameSoundtrack.instance()
	music._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	music.show_menu()
	music._process(1.0)
	var control: Button = menu.transport
	var bounds: Rect2 = control.get_global_rect()
	control.grab_focus()
	for index: int in [0,6,3,5]:
		menu.crate.flip_to(index)
		await settle()
		check(menu.transport==control and control.visible and not control.disabled,"same live playback control on sleeve "+str(index))
		check(control.get_global_rect().is_equal_approx(bounds),"playback control does not shift on sleeve "+str(index))
		check(control.has_focus(),"browsing preserves playback keyboard focus "+str(index))
		check("Exploration" in menu.status.text and "Playing" in menu.status.text,"visible status names the actual recording on sleeve "+str(index))
	check(menu.skip_previous.disabled and menu.skip_next.disabled,"skip excludes all six unreleased recordings")
	var selected: String = app.records.settings.music_record
	await click(menu.skip_next)
	menu._skip_record(1)
	menu._skip_record(-1)
	check(app.records.settings.music_record==selected and music.menu_player.stream==stream,"disabled/direct skip cannot load an unavailable LP or restart current music")
	var browse: int = menu.browse_index
	await click(menu.previous_button)
	await settle()
	check(menu.browse_index==browse-1 and music.menu_player.stream==stream,"header browse arrow changes only the sleeve")
	await click(menu.next_button,true)
	await settle()
	check(menu.browse_index==browse and music.menu_player.stream==stream,"touch header arrow browses without changing playback")
	await glyph_center(control,"pause")
	await click(control)
	await create_timer(1.05).timeout
	check(not app.records.settings.music_enabled and music.menu_target==0,"mouse playback control pauses actual music")
	check("Paused" in menu.status.text and "Exploration" in menu.status.text,"paused status identifies the actual recording")
	var held_position: float = -1.0
	if music.output_enabled:
		check(music.menu_player.stream_paused,"actual decoder is paused after the fade")
		var position: float = music.menu_player.get_playback_position()
		print("PAUSE_CURSOR held=",position," playing=",music.menu_player.playing," paused=",music.menu_player.stream_paused," playback=",music.menu_player.has_stream_playback())
		held_position = position
		await create_timer(0.20).timeout
		check(absf(music.menu_player.get_playback_position()-position)<0.01,"pause holds the actual music cursor")
	await glyph_center(control,"play")
	await capture("playback-paused")
	await click(control,true)
	await create_timer(0.25).timeout
	check(app.records.settings.music_enabled and music.menu_target==1.0,"touch playback control resumes actual music")
	check(music.menu_player.stream==stream and not music.menu_player.stream_paused if music.output_enabled else music.menu_player.stream==stream,"resume keeps the same stream and releases pause")
	if held_position>=0:
		var resumed_position: float = music.menu_player.get_playback_position()
		print("RESUME_CURSOR held=",held_position," resumed=",resumed_position)
		check(resumed_position>held_position+0.05 and resumed_position<held_position+0.60,"resume continues from the held music cursor")
	control.grab_focus()
	await key(KEY_SPACE)
	await key_release(KEY_SPACE)
	check(not app.records.settings.music_enabled,"keyboard activates the same playback control")
	await key(KEY_SPACE)
	await key_release(KEY_SPACE)
	check(app.records.settings.music_enabled,"keyboard resumes from the same control")
	menu.crate.flip_to(5)
	await settle()

func key_release(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = false
	root.push_input(event,true)
	await process_frame
