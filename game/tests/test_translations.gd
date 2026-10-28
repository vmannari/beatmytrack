extends SceneTree
## Real packaged catalogues, glyph coverage and both native language pickers.
var checks: int = 0
var failures: int = 0
var app: Node
var language: Node
var capture_directory: String = ""
var source_messages: int = 0
const CODES: Array[String] = ["en","fr","es","de","pt_BR","ja","ko","nl","it","fi","sv","nb"]
const LANGUAGE_LABELS: Array[String] = ["Language","Langue","Idioma","Sprache","Idioma","言語","언어","Taal","Lingua","Kieli","Språk","Språk"]

func _initialize() -> void: run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+message)

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	root.size = Vector2i(1280,720)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-translations="): capture_directory = argument.trim_prefix("--capture-translations=")
	language = root.get_node("Language")
	for resource: Translation in TranslationServer.get_translations():
		if resource.locale == "en": source_messages = resource.get_message_count()
	check(source_messages > 0,"the current English source inventory is packaged")
	var directory: String = "user://translations_test_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	app = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(directory.path_join("local_records.json"))
	app.library = TrackLibrary.new(directory.path_join("tracks"))
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	var deadline: int = Time.get_ticks_msec()+20000
	while not app.startup_complete and Time.get_ticks_msec() < deadline: await process_frame
	check(app.startup_complete,"real app reaches login")
	check(language.locales.size() == CODES.size(),"all twelve shipping languages are offered")
	var picker: OptionButton = app.root_ui.find_child("LanguageChoice",true,false)
	check(picker != null and picker.item_count == CODES.size()+1,"login picker includes system and every requested language")
	var original_ui: Control = app.root_ui
	for index: int in CODES.size():
		var code: String = CODES[index]
		check(language.choose(code) == OK,"login saves "+code)
		await process_frame
		await process_frame
		check(TranslationServer.get_locale() == code,"native locale is active: "+code)
		check(TranslationServer.translate("Language") == LANGUAGE_LABELS[index],"reviewed UI terminology: "+code)
		check(app.root_ui == original_ui,"login tree survives language change: "+code)
		check(picker.get_item_text(picker.selected) == str(language.locales[code]),"login selection uses native language name: "+code)
		await capture("login-"+code)
		check_fonts(code)
	var variants: Dictionary = {"fr_CA":"fr","es_MX":"es","de_AT":"de","pt_PT":"pt_BR","ja_JP":"ja","ko_KR":"ko","nl_BE":"nl","it_CH":"it","fi_FI":"fi","sv_FI":"sv","nb_NO":"nb","no_NO":"nb"}
	for system_locale: String in variants:
		check(language.resolve("system",system_locale) == variants[system_locale],"system region resolves: "+system_locale)
	var country: Button = preload("res://ui/country_picker.gd").new()
	country.theme = MenuStyle.theme()
	root.add_child(country)
	check(language.choose("fr") == OK,"French country names apply")
	country.set_country("FI")
	check(country.text == "Pays : Finlande","country caption uses its localized name")
	country._open()
	country.search.text = "finlande"
	country.search.text_changed.emit(country.search.text)
	check(country.matches.has("FI"),"country search accepts the localized name")
	var flag: TextureRect = PlayerCountry.flag("FI")
	root.add_child(flag)
	check(language.choose("fi") == OK,"Finnish country names apply")
	check(country.country_code == "FI" and country.text == "Maa: Suomi","language changes retain the canonical country code")
	flag.mouse_entered.emit()
	check(flag.tooltip_text == "Suomi","retained country flags refresh their tooltip on hover")
	country.search.text = "suomi"
	country.search.text_changed.emit(country.search.text)
	check(country.matches.has("FI"),"open country search updates with the new locale")
	country.dialog.hide()
	country.queue_free()
	flag.queue_free()
	await process_frame
	root.size = Vector2i(960,540)
	for code: String in ["de","fi","ja","ko"]:
		check(language.choose(code) == OK,"compact login language applies: "+code)
		for frame: int in range(4): await process_frame
		var bounds: Rect2 = picker.get_global_rect()
		check(bounds.position.y >= 0 and bounds.end.y <= root.size.y and bounds.end.x <= root.size.x,"compact login picker fits: "+code)
		await capture("login-"+code+"-960")
	root.size = Vector2i(1280,720)
	app._show_screen("settings")
	await process_frame
	var settings: SettingsPage = app.root_ui.find_child("SettingsPage",true,false)
	settings.draft_haptics = 0.68
	settings._show_section("language")
	await process_frame
	picker = settings.find_child("LanguageChoice",true,false)
	var codes: Array = picker.get_parent().get_parent().get("codes")
	for code: String in CODES:
		picker.item_selected.emit(codes.find(code))
		await process_frame
		await process_frame
		check(language.preference == code,"Settings selection applies: "+code)
		check(is_instance_valid(settings) and is_equal_approx(settings.draft_haptics,0.68),"staged settings survive: "+code)
		for id: String in settings.categories:
			var item: Dictionary = settings.categories[id]
			check(item.button.size.y >= item.caption.get_parent().get_combined_minimum_size().y+23,"category accommodates "+code+" / "+id)
		await capture("settings-"+code)
	root.size = Vector2i(960,540)
	for code: String in ["de","fi","ja","ko"]:
		check(language.choose(code) == OK,"compact language applies: "+code)
		await process_frame
		await process_frame
		await process_frame
		check(picker.size.y >= 36 and picker.get_global_rect().end.x <= app.root_ui.size.x,"compact picker fits "+code)
		await capture("settings-"+code+"-960")
	language.configure(language.storage_path)
	check(language.preference == "ko" and TranslationServer.get_locale() == "ko","selected language survives a pre-login reload")
	check(GameText.plural("{count} lap","{count} laps",1) != "1 lap","Korean counted message is translated")
	check(GameText.plural("{count} lap","{count} laps",2).contains("2"),"Korean one-form plural keeps the actual count")
	check(language.choose("fr") == OK,"French objective integration applies")
	var detail: GDScript = preload("res://ui/achievement_detail.gd")
	var family: Dictionary = {"metric":"races","description":"Complete {n} races."}
	check(detail.requirement(family,1) == "Terminez 1 course.","objective translates before singular count substitution")
	check(detail.requirement(family,2) == "Terminez 2 courses.","objective chooses a real translated plural")
	var results := RaceResults.new()
	check(results._retry_caption().contains("COURIR À NOUVEAU") and not results._retry_caption().contains("RACE AGAIN"),"Results action translates its heading independently")
	results.clean = true
	results.previous = 10
	results.total = 12
	check(results._retry_caption().contains("2.000 s pour battre votre record"),"Results action retains translated numeric motivation")
	results.free()
	check(GameText.message("{left} / {right}",{"left":"{right}","right":"raw"}) == "{right} / raw","player text cannot become another named placeholder")
	check(GameText.plural("{name}: {count} lap","{name}: {count} laps",2,{"name":"{count}"}).begins_with("{count}: 2"),"count substitution preserves a literal placeholder-shaped player name")
	check(language.choose("en") == OK,"test restores explicit English")
	app.queue_free()
	await process_frame
	await process_frame
	print("TRANSLATIONS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func check_fonts(code: String) -> void:
	var translated: String = ""
	for resource: Translation in TranslationServer.get_translations():
		if resource.locale == code:
			check(resource.get_message_count() == source_messages,"packaged source inventory matches English: "+code)
			translated = "".join(resource.get_translated_message_list())
	for country: Dictionary in PlayerCountry.countries(): translated += PlayerCountry.country_name(str(country.code))
	var available: String = MenuStyle.BODY.get_supported_chars()+GameFonts.JAPANESE.get_supported_chars()+GameFonts.KOREAN.get_supported_chars()
	var missing: Dictionary = {}
	for index: int in translated.length():
		var point: int = translated.unicode_at(index)
		if point >= 32 and not available.contains(String.chr(point)): missing[point] = true
	check(missing.is_empty(),"bundled fonts cover catalogue "+code+": "+str(missing.keys()))

func capture(filename: String) -> void:
	if capture_directory.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_directory)
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(capture_directory.path_join(filename+".png")) == OK,"native capture "+filename)
