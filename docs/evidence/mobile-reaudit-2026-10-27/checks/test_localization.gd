extends SceneTree
## Real login/Settings, durable installation preference and in-place text updates.
var checks: int = 0
var failures: int = 0
var app: Node
var language: Node
var directory: String
var capture_directory: String = ""

func _initialize() -> void: run.call_deferred()

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+description)

func run() -> void:
	print("AUDIT_PID ",OS.get_process_id())
	var audit_config := ConfigFile.new()
	audit_config.set_value("backend","url","")
	assert(audit_config.save("user://backend.cfg")==OK)
	OS.unset_environment("BMT_API_URL")

	language = root.get_node("Language")
	OS.set_environment("BMT_API_URL","")
	root.size = Vector2i(1280,720)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-localization="): capture_directory = argument.trim_prefix("--capture-localization=")
	directory = "user://localization_test_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	app = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(directory.path_join("local_records.json"))
	app.library = TrackLibrary.new(directory.path_join("tracks"))
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	var deadline: int = Time.get_ticks_msec()+20000
	while not app.startup_complete and Time.get_ticks_msec() < deadline: await process_frame
	check(app.startup_complete and app.screen == "account","fresh installation opens login")
	check(language.storage_path == directory.path_join("language.json"),"pre-login preference uses injected installation directory")
	check(language.preference == "system" and TranslationServer.get_locale() == language.resolve("system"),"missing preference safely resolves the system language")
	var picker: OptionButton = app.root_ui.find_child("LanguageChoice",true,false)
	check(picker != null and picker.item_count == language.locales.size()+1,"login offers system and every packaged language")
	await capture("login-en")
	root.size = Vector2i(960,540)
	await process_frame
	await process_frame
	check(picker.get_global_rect().size.y >= 36,"login language picker retains a touch target on the compact view")
	await capture("login-en-960")
	root.size = Vector2i(1280,720)
	await process_frame
	check(language.resolve("system","en_US") == "en" and language.resolve("system","ar_EG") == "en","regional and unsupported system locales have explicit fallback")
	var translation: Translation = load("res://tests/fixtures/localization/fr.po")
	check(translation != null,"native gettext fixture loads")
	TranslationServer.add_translation(translation)
	language.configure(language.storage_path)
	check(not language.locales.has("fr_CA"),"unapproved fixture never becomes a selectable shipping language")
	language.locales["fr_CA"] = "Français"
	check(language.resolve("system","fr_CA") == "fr_CA","system selection resolves an available base language")
	var original_root: Control = app.root_ui
	var generation: int = app._navigation_generation
	var username: LineEdit = app.root_ui.find_child("PlayerUsername",true,false)
	username.text = "Race"
	app.online.waiting_for_google = true
	check(language.choose("fr_CA") == OK,"language can be selected while provider sign-in waits")
	await process_frame
	check(app.root_ui == original_root and app._navigation_generation == generation,"language selection retains login and navigation identity")
	check(username.text == "Race" and app.online.waiting_for_google,"language selection preserves entered name and provider request")
	check(picker.get_item_text(picker.selected) == "Français","login picker synchronizes in place using language autonym")
	check(TranslationServer.translate("Sign in") == "Connexion","selected catalogue is active before authentication")
	check(GameText.message("Hello {name}, {count} laps remain.",{"name":"Language","count":3}) == "Encore 3 tours, Language.","translator may reorder placeholders without translating player names")
	check(GameText.plural("{count} collision","{count} collisions",0) == "0 collision","gettext applies French zero-count plural rule")
	check(GameText.plural("{count} collision","{count} collisions",2) == "2 collisions","gettext applies French multiple-count plural rule")
	var bound := Label.new()
	GameText.bind(bound,"Hello {name}, {count} laps remain.",{"name":"Language","count":2})
	root.add_child(bound)
	check(bound.text == "Encore 2 tours, Language.","bound message renders in selected language")
	check(language.choose("en") == OK and bound.text == "Hello Language, 2 laps remain.","existing bound message refreshes without reconstruction")
	root.remove_child(bound)
	check(language.choose("fr_CA") == OK,"language can change while a retained view is detached")
	root.add_child(bound)
	check(bound.text == "Encore 2 tours, Language.","detached retained messages refresh when reattached")
	bound.queue_free()
	var authored: Label = MenuStyle.user_label("Language")
	root.add_child(authored)
	check(authored.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED and authored.text == "Language","authored names matching catalogue keys are explicitly protected")
	authored.queue_free()
	app.online.waiting_for_google = false
	check(language.choose("en") == OK,"English restores before settings checks")
	app._show_screen("settings")
	await process_frame
	var settings: SettingsPage = app.root_ui.find_child("SettingsPage",true,false)
	check(settings != null,"real app Settings opens")
	settings.draft_haptics = 0.73
	settings._show_section("language")
	await process_frame
	check(not settings.apply_button.visible and not settings.reset_button.visible,"language choice saves directly with no unrelated Apply or Reset")
	var settings_picker: OptionButton = settings.find_child("LanguageChoice",true,false)
	check(settings_picker != null,"Settings provides the shared language picker")
	await tap(settings_picker.get_global_rect().get_center())
	check(settings_picker.get_popup().visible,"viewport-dispatched touch opens the language choices")
	settings_picker.get_popup().hide()
	settings_picker.item_selected.emit((settings_picker.get_parent().get_parent().get("codes") as Array).find("fr_CA"))
	await process_frame
	check(language.preference == "fr_CA" and settings_picker.get_item_text(settings_picker.selected) == "Français","Settings picker commits selected language immediately")
	check(is_instance_valid(settings) and is_equal_approx(settings.draft_haptics,0.73),"language change retains other unapplied settings")
	await capture("settings-fr-fixture")
	language.configure(language.storage_path)
	check(language.preference == "system","removed or unapproved saved locale safely falls back")
	check(language.choose("en") == OK,"explicit English preference saves")
	language.configure(language.storage_path)
	check(language.preference == "en","saved language survives reload before login")
	var saved: String = FileAccess.get_file_as_string(language.storage_path)
	check(language.choose("unavailable") == ERR_INVALID_PARAMETER,"unknown locale is rejected")
	check(FileAccess.get_file_as_string(language.storage_path) == saved and language.preference == "en","rejected locale changes neither disk nor current language")
	var original_path: String = language.storage_path
	var blocker := FileAccess.open(directory.path_join("blocked"),FileAccess.WRITE)
	blocker.store_string("file blocks directory")
	blocker.close()
	language.storage_path = directory.path_join("blocked/language.json")
	check(language.choose("system") != OK and language.preference == "en","failed atomic save retains the previous active preference")
	settings_picker.item_selected.emit(0)
	check(settings_picker.selected == 1 and settings.find_child("LanguageSaveStatus",true,false).visible,"failed picker save restores the previous choice and shows a retry message")
	language.storage_path = original_path
	settings._show_section("language")
	await process_frame
	await capture("settings-en")
	TranslationServer.pseudolocalization_enabled = true
	check(GameText.message("Language") != "Language","developer pseudolocalization expands source copy")
	check(GameText.message("Hello {name}, {count} laps remain.",{"name":"Race","count":3}).contains("Race"),"pseudolocalization preserves inserted player names and named placeholders")
	await process_frame
	check_sidebar(settings)
	await capture("settings-pseudo")
	root.size = Vector2i(960,540)
	await process_frame
	await process_frame
	await process_frame
	check_sidebar(settings)
	await capture("settings-pseudo-960")
	TranslationServer.pseudolocalization_enabled = false
	TranslationServer.remove_translation(translation)
	app.queue_free()
	await process_frame
	await process_frame
	print("LOCALIZATION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func check_sidebar(settings: SettingsPage) -> void:
	for id: String in settings.categories:
		var item: Dictionary = settings.categories[id]
		var button: Button = item.button
		var copy: Control = item.caption.get_parent()
		check(button.size.y >= copy.get_combined_minimum_size().y+23,"expanded category fits its button: "+id)

func tap(point: Vector2) -> void:
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

func capture(filename: String) -> void:
	if capture_directory.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_directory)
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(capture_directory.path_join(filename+".png")) == OK,"native capture "+filename)
