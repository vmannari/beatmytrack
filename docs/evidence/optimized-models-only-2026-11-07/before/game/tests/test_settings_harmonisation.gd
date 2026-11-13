extends SceneTree
## Actual shared settings, paused Game, atomic failure, nested editor and layouts.
var checks: int = 0
var failures: int = 0
var output: String
var records: LocalRecords
var game: Node
var captures: int = 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + message)

func settle() -> void:
	for frame: int in range(5): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	check(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK,"capture " + label)
	captures += 1

func reloaded() -> Dictionary:
	var saved := LocalRecords.new(records.path)
	saved.load_records()
	return saved.settings

func page() -> SettingsPage:
	return game.hud.pause_menu.settings_overlay.page

func press(id: String) -> void:
	var button: Button = game.hud.pause_menu.find_child(id,true,false)
	check(button != null,"button exists: " + id)
	if button != null: button.pressed.emit()

func run() -> void:
	output = ProjectSettings.globalize_path("res://../docs/evidence/settings-harmonisation-implementation-2026-11-03/" + DisplayServer.get_name() + "-" + RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(output.path_join("profile"))
	GameLanguage.instance().configure(output.path_join("profile/language.json"))
	GameLanguage.instance().choose("en")
	records = LocalRecords.new(output.path_join("profile/records.json"))
	records.settings = {"favorites":["ellipse"],"control_layout":ControlLayout.preset(),"steering_haptics":0.5,"drift_haptics":false,"ghost_mode":"off"}
	check(records.save_records() == OK,"disposable fixture saved")
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	game = load("res://core/game.tscn").instantiate()
	game.initial_track = TrackCompiler.compile(TrackDocument.create_default())
	game.production_mode = true
	game.hitch_diagnostics_enabled = false
	game.preference_records = records
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.hud.touch.layout = ControlLayout.from_settings(records.settings)
	game.hud.touch.haptic_strength = 0.5
	await settle()
	game.toggle_pause()
	var canonical: Array = game.sim.state.snapshot()
	var rules: Dictionary = RewindHistory.properties(game.track_session,true)
	var record_key: String = records.key_for(game.native_track,game.handling)
	press("Settings")
	await settle()
	check(game.rating_records == null and page().records == records,"pause uses preference owner without a rating store")
	check(page().categories.keys() == ["controls","camera","ghosts","audio","haptics","graphics","language"],"pause has all seven shared categories in order")
	check(not page().development_available and page().ad_adapter == null,"pause excludes development and its adapter")
	for section: String in ["account","privacy","help","licences","development"]:
		page()._show_section(section)
		check(page().section == "controls","main-only category cannot be entered: " + section)
	press("Steering_horizontal")
	check(game.hud.touch.layout.steering_type == "buttons" and reloaded().control_layout.steering_type == "buttons","steering stays staged until Apply")
	page().draft_labels = false
	page()._show_section("camera")
	press("Camera_follow_car")
	page().draft_speed_zoom = false
	page().draft_speed_zoom_strength = 0.43
	page()._show_section("haptics")
	press("HapticsStrong")
	page().draft_drift_haptics = true
	page()._show_section("audio")
	(page().find_child("AudioVolume_music_volume",true,false) as HSlider).value = 31
	AudioServer.set_bus_mute(0,true)
	check(page()._apply(),"one Apply commits shared drafts")
	var saved: Dictionary = reloaded()
	check(saved.control_layout.steering_type == "horizontal" and not saved.control_labels,"cloud-style controls persist after reload")
	check(game.hud.touch.layout.steering_type == "horizontal" and not game.hud.touch.show_labels,"saved controls update active race")
	check(game.camera.mode == "follow_car" and not game.camera.speed_zoom_enabled and is_equal_approx(game.camera.speed_zoom_strength,0.43),"saved camera and zoom update active race")
	check(is_equal_approx(game.hud.touch.haptic_strength,1.0) and game.drift_haptics_enabled,"both feedback preferences update active race")
	check(is_equal_approx(float(saved.music_volume),0.31) and not AudioServer.is_bus_mute(0),"saved audio clears legacy hidden Master mute")
	check(game.paused and not game.hud.touch.enabled,"Apply leaves race paused and input disabled")
	check(not page().dirty,"successful Apply clears draft status")
	page()._show_section("controls")
	page()._reset()
	check(page().draft_haptics == 1.0 and page().draft_drift_haptics,"Reset controls preserves Haptics draft")
	check(page().draft_layout.steering_type == "buttons" and saved.control_layout.steering_type == "horizontal","Reset controls is staged")
	page()._show_section("camera")
	check(page().status.text == "Unapplied changes","category navigation retains dirty status")
	var original_path: String = records.path
	records.path = output.path_join("missing/records.json")
	page().draft_camera = "look_ahead"
	check(not page()._apply(),"failed save is reported")
	check(game.camera.mode == "follow_car" and game.hud.touch.layout.steering_type == "horizontal","failed Apply preserves live preferences")
	check(page().draft_camera == "look_ahead" and page().dirty,"failed Apply retains retryable draft")
	check(records.settings.camera_mode == "follow_car","failed Apply preserves committed preferences")
	records.path = original_path
	press("Back")
	check(game.paused and not game.hud.pause_menu.settings_open(),"Back discards draft and returns to pause")
	press("Settings")
	check(page().draft_camera == "follow_car" and page().draft_layout.steering_type == "horizontal","reopening reloads committed values")
	page()._show_section("graphics")
	var active_graphics: Dictionary = game._graphics.duplicate(true)
	var active_model: bool = game.car.simple_model
	page().draft_graphics.shadow_quality = "off"
	page().draft_simple_models = not active_model
	check(page()._apply(),"graphics commit succeeds")
	check(game._graphics == active_graphics and game.car.simple_model == active_model,"graphics defer without rebuilding active world")
	game.opponent_ghost = true
	game.ghost_mode = "race"
	var opponent: Dictionary = {"race":{"marker":"opponent"}}
	game.ghost_bests = opponent.duplicate(true)
	press("Back")
	press("Settings")
	page()._show_section("ghosts")
	check(page().subtitle.text == "Personal ghost settings apply to your next race.","opponent context explains saved-only personal ghosts")
	press("Ghost_lap")
	check(page()._apply(),"personal preference can be saved in opponent context")
	check(game.ghost_mode == "race" and game.ghost_bests == opponent and reloaded().ghost_mode == "lap","opponent recording/mode remain intact while preference saves")
	game.opponent_ghost = false
	game.ghost_bests = {}
	game.apply_saved_driving_settings()
	check(game.ghost_mode == "lap","ordinary personal ghost mode applies live")
	page()._show_section("controls")
	press("CustomizeControls")
	await settle()
	var overlay: Control = game.hud.pause_menu.settings_overlay
	check(is_instance_valid(overlay.editor) and game.paused and not game.hud.touch.enabled,"layout editor opens above paused attempt")
	var edited: Dictionary = overlay.editor.touch.layout.duplicate(true)
	edited.steering_type = "joystick"
	overlay.editor.touch.layout = edited
	overlay.editor._changed()
	records.path = output.path_join("missing/records.json")
	game.toggle_pause(false)
	check(game.paused and is_instance_valid(overlay.editor) and overlay.editor.dirty,"failed editor save blocks external resume and retains edits")
	records.path = original_path
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	game._unhandled_key_input(esc)
	await settle()
	check(not is_instance_valid(overlay.editor) and overlay.page.visible,"Esc saves editor and returns to settings")
	check(game.hud.touch.layout.steering_type == "joystick" and page().draft_layout.steering_type == "joystick","editor autosave refreshes live controls and shared draft")
	check(reloaded().control_layout.steering_type == "joystick","nested layout persists")
	var retry_count: int = 0
	var retries: Array[int] = [retry_count]
	game.retry_requested.connect(func() -> void: retries[0] += 1)
	var key := InputEventKey.new()
	key.pressed = true
	for code: int in [KEY_C,KEY_R,KEY_BACKSPACE]:
		key.keycode = code
		key.physical_keycode = code
		game._unhandled_key_input(key)
	check(retries[0] == 0 and game.camera.mode == "follow_car" and not is_instance_valid(game.rewind_panel),"settings intercept race shortcuts without retry, camera mutation or rewind")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game._physics_process(1.0/120.0)
	check(game.paused and game.sim.state.snapshot() == canonical and RewindHistory.properties(game.track_session,true) == rules,"focus and settings leave canonical state and rules exact")
	check(records.key_for(game.native_track,game.handling) == record_key and reloaded().favorites == ["ellipse"],"record identity and unrelated preferences preserved")
	page()._show_section("language")
	var language_picker: Node = page().find_child("LanguagePicker",true,false)
	var german: int = language_picker.codes.find("de")
	language_picker.picker.item_selected.emit(german)
	check(GameLanguage.instance().preference == "de" and game.paused and game.hud.pause_menu.settings_open(),"real language selection saves immediately without leaving paused settings")
	check(page().draft_layout.steering_type == "joystick","language refresh retains preference drafts")
	GameLanguage.instance().choose("en")
	await layouts()
	GameLanguage.instance().choose("en")
	game._unhandled_key_input(esc)
	check(game.paused and not game.hud.pause_menu.settings_open(),"Esc from settings returns to pause without resuming")
	press("Resume")
	check(not game.paused and game.hud.touch.enabled,"explicit Resume restores driving")
	game.toggle_pause(false)
	press("Settings")
	page().draft_camera = "overhead"
	game.restart()
	check(not game.paused and not game.hud.pause_menu.settings_open(),"external restart removes settings and discards unapplied drafts")
	check(reloaded().camera_mode == "follow_car","external restart does not commit unapplied settings")
	game.queue_free()
	await process_frame
	await main_menu_parity()
	print("SETTINGS_HARMONISATION: %d checks, %d failures, %d captures" % [checks,failures,captures])
	var report := FileAccess.open(output.path_join("result.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures},"\t") + "\n")
	quit(1 if failures else 0)

func layouts() -> void:
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(540,960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await settle()
		for locale: String in ["en","de","fi","sv","nb","nl","fr","es","it","pt_BR","ja","ko"]:
			TranslationServer.set_locale(locale)
			GameText.refresh(self)
			for section: String in ["controls","camera","ghosts","audio","haptics","graphics","language"]:
				page()._show_section(section)
				await settle()
				var bounds: Rect2 = root.get_visible_rect().grow(1)
				check(bounds.encloses(page().get_global_rect()),"settings fit " + str(dimensions) + "/" + locale + "/" + section)
				check(bounds.encloses(game.hud.pause_menu.settings_overlay.back_button.get_global_rect()),"Back stays visible " + str(dimensions) + "/" + locale + "/" + section)
				if section != "language": check(bounds.encloses(page().apply_button.get_global_rect()),"Apply stays visible " + str(dimensions) + "/" + locale + "/" + section)
				check(page().body.size.x <= page().content_scroll.size.x + 1,"no horizontal content overflow " + str(dimensions) + "/" + locale + "/" + section)
				if locale == "en" or (section == "controls" and dimensions.x == 960): capture("pause-" + section + "-" + str(dimensions.x) + "-" + locale)

func main_menu_parity() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var main := SettingsPage.new()
	main.records = records
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(main)
	await settle()
	check(main.categories.has("account") and main.categories.has("privacy") and main.categories.has("help"),"main menu retains account, privacy and help")
	check(main.draft_layout.steering_type == "joystick" and main.draft_camera == "follow_car" and main.draft_ghost == "lap","main menu reflects saved pause preferences")
	check(main.draft_haptics == 1.0 and main.draft_drift_haptics and not main.draft_labels,"main menu reflects saved feedback and labels")
	main._show_section("audio")
	check(is_equal_approx(main.draft_audio.music_volume,0.31),"main menu shares saved audio levels")
	main.draft_audio.music_volume = 0.67
	check(main._apply() and is_equal_approx(float(reloaded().music_volume),0.67),"main Apply retains existing shared commit path")
	await settle()
	capture("main-audio-1280-en")
	main.queue_free()
	await process_frame
