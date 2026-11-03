extends SceneTree
## Evaluation probe: existing UI and disposable records only; no product changes.
var checks: int = 0
var failures: int = 0
var observations: Dictionary = {}
var output: String

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + message)

func settle() -> void:
	for frame: int in range(6): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func capture(label: String) -> void:
	await settle()
	if DisplayServer.get_name() != "headless":
		check(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK, "capture " + label)

func reload_settings(records: LocalRecords) -> Dictionary:
	var reopened := LocalRecords.new(records.path)
	reopened.load_records()
	return reopened.settings.duplicate(true)

func run() -> void:
	output = ProjectSettings.globalize_path("res://../docs/evidence/settings-harmonisation-2026-11-03/" + RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(output.path_join("profile"))
	var records := LocalRecords.new(output.path_join("profile/records.json"))
	records.settings = {"control_layout":ControlLayout.preset(), "music_volume":0.7, "vehicle_volume":1.0, "interface_volume":0.7}
	check(records.save_records() == OK, "disposable profile initialized")
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var page := SettingsPage.new()
	page.records = records
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.offset_left = 20
	page.offset_top = 20
	page.offset_right = -20
	page.offset_bottom = -20
	host.add_child(page)
	await settle()
	observations.main_categories = page.categories.keys()
	page.draft_audio.music_volume = 0.23
	check(is_equal_approx(float(reload_settings(records).music_volume),0.7), "main audio stages before Apply")
	check(page._apply(), "main Apply succeeds")
	check(is_equal_approx(float(reload_settings(records).music_volume),0.23), "main audio persists after Apply")
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = dimensions
		for category: String in ["controls","camera","audio","haptics","graphics"]:
			page._show_section(category)
			await capture("main-component-" + category + "-" + str(dimensions.x))
	host.queue_free()
	await process_frame
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = TrackCompiler.compile(TrackDocument.create_default())
	game.production_mode = true
	game.preference_records = records
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.hud.touch.layout = ControlLayout.from_settings(records.settings)
	game.toggle_pause(false)
	var state: Array = game.sim.state.snapshot()
	var menu: Control = game.hud.pause_menu
	menu._settings()
	await settle()
	var options: Array[OptionButton] = []
	for child: Node in menu.column.get_children():
		if child is OptionButton: options.append(child)
	var steering: OptionButton = options[-1]
	observations.pause_steering_titles = []
	for index: int in range(steering.item_count): observations.pause_steering_titles.append(steering.get_item_text(index))
	check(game.rating_records == null and game.preference_records == records, "cloud-style preference and rating stores are separate")
	steering.select(1)
	steering.item_selected.emit(1)
	check(game.hud.touch.layout.steering_type == "horizontal", "pause steering changes live controls")
	observations.cloud_steering_saved = reload_settings(records).control_layout.steering_type == "horizontal"
	check(not observations.cloud_steering_saved, "reproduced: cloud-style pause steering is not saved")
	var camera: OptionButton = menu.find_child("RaceCameraMode",true,false)
	camera.select(1)
	camera.item_selected.emit(1)
	check(reload_settings(records).camera_mode == "follow_car", "camera saves through preference store with no rating store")
	var ghost: OptionButton = menu.find_child("RaceGhostMode",true,false)
	check(ghost != null, "ordinary race exposes ghost selector")
	ghost.select(0)
	ghost.item_selected.emit(0)
	check(reload_settings(records).ghost_mode == "off", "ghost saves through preference store with no rating store")
	game.rating_records = records
	steering.select(2)
	steering.item_selected.emit(2)
	check(reload_settings(records).control_layout.steering_type == "joystick", "local-style pause steering does save")
	var saved_path: String = records.path
	records.path = output.path_join("missing/records.json")
	steering.select(0)
	steering.item_selected.emit(0)
	observations.failed_steering_live = game.hud.touch.layout.steering_type
	observations.failed_steering_stored = records.settings.control_layout.steering_type
	observations.failed_steering_status = menu.status.text
	check(observations.failed_steering_live == "buttons" and observations.failed_steering_stored == "joystick", "failed steering save leaves live preview and prior committed value")
	check(menu.status.text.contains("Could not save"), "steering save failure is visible")
	records.path = saved_path
	var sound: CheckButton = menu.column.get_child(2) as CheckButton
	check(sound != null and sound.text == "Sound", "pause has a master Sound toggle")
	sound.set_pressed_no_signal(false)
	sound.toggled.emit(false)
	GameSoundtrack.instance().apply_settings(records.settings)
	observations.master_still_muted_after_audio_apply = AudioServer.is_bus_mute(0)
	check(observations.master_still_muted_after_audio_apply, "reproduced: applying saved audio levels leaves pause master mute active")
	sound.set_pressed_no_signal(true)
	sound.toggled.emit(true)
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = dimensions
		menu._settings()
		await settle()
		var scroll: ScrollContainer = menu.drawer.get_child(0)
		scroll.scroll_vertical = 0
		await capture("pause-top-" + str(dimensions.x))
		scroll.scroll_vertical = 10000
		await capture("pause-bottom-" + str(dimensions.x))
	check(game.paused and not game.hud.touch.enabled and game.sim.state.snapshot() == state, "settings review retains pause, input block and canonical state")
	game.queue_free()
	await process_frame
	observations.checks = checks
	observations.failures = failures
	var result := FileAccess.open(output.path_join("observations.json"),FileAccess.WRITE)
	result.store_string(JSON.stringify(observations,"\t") + "\n")
	print("SETTINGS_REVIEW: %d checks, %d failures; %s" % [checks,failures,output])
	quit(1 if failures else 0)
