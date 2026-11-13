extends SceneTree
const Notices = preload("res://legal/third_party_notices.gd")
var checks: int = 0
var failures: int = 0
var page: SettingsPage
var shell: Control
var output: String

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func settle() -> void:
	for frame: int in range(5): await process_frame

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	output = ProjectSettings.globalize_path("res://../docs/evidence/licences-page-2026-10-25/"+DisplayServer.get_name()+"-"+RenderingServer.get_current_rendering_method())
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = ProjectSettings.globalize_path(argument.trim_prefix("--evidence-root="))
	DirAccess.make_dir_recursive_absolute(output)
	content()
	shell = Control.new()
	shell.theme = MenuStyle.theme()
	root.add_child(shell)
	MenuStyle.fill(shell)
	var background := ColorRect.new()
	background.color = Color("0b1922")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.add_child(background)
	MenuStyle.fill(background)
	var margin := MarginContainer.new()
	shell.add_child(margin)
	MenuStyle.fill(margin)
	for edge: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,24)
	page = SettingsPage.new()
	page.records = LocalRecords.new("user://licences_read_only_"+str(OS.get_process_id())+".json")
	page.records.settings = {"steering_haptics":0.37, "favorites":["ellipse"]}
	page.development_available = false
	margin.add_child(page)
	await settle()
	check(page.find_child("SettingsCategory_development",true,false) == null,"release navigation excludes Development")
	var category: Button = page.find_child("SettingsCategory_licences",true,false)
	check(category != null,"licences available to a signed-out release profile")
	var before: Dictionary = page.records.settings.duplicate(true)
	page.draft_haptics = 0.73
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,720)]:
		root.size = dimensions
		var sidebar: ScrollContainer = page.find_child("SettingsCategoryScroll",true,false)
		sidebar.ensure_control_visible(category)
		await settle()
		if DisplayServer.get_name() == "headless": category.pressed.emit(); await settle()
		else: await tap(category.get_global_rect().get_center())
		check(page.section == "licences","touch opens licence category")
		if page.section != "licences":
			await capture("failed-navigation")
			quit(1)
			return
		check(not page.apply_button.is_visible_in_tree() and not page.reset_button.is_visible_in_tree() and not page.status.is_visible_in_tree(),"read-only page hides preference actions")
		var panel: Control = page.licences_panel
		var selector: OptionButton = panel.get("selector")
		var document: RichTextLabel = panel.get("document")
		check(root.get_visible_rect().encloses(document.get_global_rect()),"document fits "+str(dimensions))
		check(selector.size.y >= 52 and document.size.y >= 200,"usable selector and scroll area "+str(dimensions))
		check(not selector.get_global_rect().intersects(document.get_global_rect()),"fixed selector stays above document")
		panel.call("_select",0)
		await settle()
		check(document.get_parsed_text().contains(Engine.get_license_text()),"engine notice is verbatim")
		await capture("engine-"+str(dimensions.x))
		panel.call("_select",1)
		await settle()
		check(document.get_v_scroll_bar().max_value > document.size.y,"long engine notices can scroll")
		if DisplayServer.get_name() != "headless":
			await drag(document.get_global_rect().get_center()+Vector2(0,70),Vector2(0,-140))
			check(document.get_v_scroll_bar().value > 0,"finger drag scrolls licence document")
		document.get_v_scroll_bar().value = document.get_v_scroll_bar().max_value
		await settle()
		check(document.get_v_scroll_bar().value > 0,"last part of engine notices is reachable")
		check(selector.get_global_rect().position.y < document.get_global_rect().position.y,"scrolling keeps selector fixed")
		panel.call("_select",4)
		await settle()
		check(document.get_parsed_text() == Notices.text_for(Notices.COMMON[4]),"clickable URLs preserve exact audio notice")
		check(document.get_v_scroll_bar().value == 0,"changing notice returns to the beginning")
		await capture("audio-"+str(dimensions.x))
		page._show_section("controls")
		await settle()
		check(page.content_scroll.is_visible_in_tree() and not panel.is_visible_in_tree(),"return to preferences restores normal content")
	check(page.records.settings == before and is_equal_approx(page.draft_haptics,0.73),"browsing notices preserves committed settings and pending drafts")
	check(not FileAccess.file_exists(page.records.path),"read-only browsing writes no preferences")
	page._show_section("licences")
	var legal_before: String = (page.licences_panel.get("document") as RichTextLabel).get_parsed_text()
	for locale: String in ["fr","es","de","pt_BR","ja","ko","nl","it","fi","sv","nb"]:
		TranslationServer.set_locale(locale)
		GameText.refresh(self)
		await settle()
		check(page.heading.tr(page.heading.text) == TranslationServer.translate("Licences"),"localized heading "+locale)
		var selector: OptionButton = page.licences_panel.get("selector")
		check(selector.get_item_text(2) == TranslationServer.translate("Fonts"),"localized notice selector "+locale)
		check((page.licences_panel.get("document") as RichTextLabel).get_parsed_text() == legal_before,"legal body remains verbatim in "+locale)
	TranslationServer.set_locale("en")
	var panel: Control = page.licences_panel
	panel.set("entries",Notices.entries("Android",false))
	panel.call("_refresh_titles")
	var android_entries: Array[Dictionary] = panel.get("entries")
	for index: int in range(android_entries.size()):
		if android_entries[index].id == "android": panel.call("_select",index)
	await settle()
	var android_document: RichTextLabel = panel.get("document")
	check(android_document.get_parsed_text().contains(FileAccess.get_file_as_string("res://legal/GOOGLEID-NOTICES.txt")),"complete Android SDK notices render verbatim")
	check(android_document.get_v_scroll_bar().max_value > android_document.size.y,"complete Android SDK notices remain scrollable")
	await capture("android-notices")
	for index: int in range(android_entries.size()):
		if android_entries[index].id == "kart_driver": panel.call("_select",index)
	await settle()
	check(android_document.get_parsed_text() == FileAccess.get_file_as_string("res://legal/kart_driver_notices.txt"),"complete kart creator credit and modifications render verbatim")
	await capture("kart-driver")
	await capture("final")
	shell.queue_free()
	await settle()
	await actual_app()
	print("LICENCES_PAGE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func content() -> void:
	for platform: String in ["Windows","Android","Linux"]:
		for debug_build: bool in [true,false]:
			var entries: Array[Dictionary] = Notices.entries(platform,debug_build)
			var ids: Array[String] = []
			for entry: Dictionary in entries:
				ids.append(str(entry.id))
				var text: String = Notices.text_for(entry)
				check(text.length() > 200,"offline notice present: "+str(entry.id))
				for path: String in entry.get("files",[]):
					check(text.contains(FileAccess.get_file_as_string(path)),"bundled text retained exactly: "+path)
			check(("admob" in ids) == (platform == "Android" and debug_build),"AdMob notice follows build availability")
			check(("windows" in ids) == (platform == "Windows"),"Windows notices follow platform")
	var engine_text: String = Notices.text_for({"id":"engine_libraries"})
	for component: Dictionary in Engine.get_copyright_info():
		check(engine_text.contains(str(component.name)),"engine component included: "+str(component.name))
		for part: Dictionary in component.parts:
			for owner: String in part.copyright: check(engine_text.contains(owner),"engine copyright preserved")
	for text: String in Engine.get_license_info().values(): check(engine_text.contains(text),"engine licence text preserved")

func tap(point: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = point
	event.pressed = true
	root.push_input(event,true)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	root.push_input(event,true)
	await settle()

func drag(point: Vector2, delta: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = point
	down.pressed = true
	root.push_input(down,true)
	await process_frame
	for step: int in range(1,6):
		var motion := InputEventScreenDrag.new()
		motion.index = 0
		motion.position = point+delta*step/5.0
		motion.relative = delta/5.0
		root.push_input(motion,true)
		await process_frame
	down.position = point+delta
	down.pressed = false
	root.push_input(down,true)
	await settle()

func actual_app() -> void:
	var directory: String = "user://licences_app_"+str(OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(directory)
	var app: Node = (load("res://core/app.tscn") as PackedScene).instantiate()
	app.set("records",LocalRecords.new(directory.path_join("records.json")))
	app.set("library",TrackLibrary.new(directory.path_join("tracks")))
	root.add_child(app)
	while not app.get("startup_complete"): await process_frame
	app.call("_show_screen","settings")
	await settle()
	var settings: SettingsPage = app.get("root_ui").find_child("SettingsPage",true,false)
	check(settings != null,"actual App mounts Settings")
	var category: Button = settings.find_child("SettingsCategory_licences",true,false)
	(settings.find_child("SettingsCategoryScroll",true,false) as ScrollContainer).ensure_control_visible(category)
	await settle()
	if DisplayServer.get_name() == "headless": category.pressed.emit(); await settle()
	else: await tap(category.get_global_rect().get_center())
	check(settings.section == "licences" and settings.licences_panel.is_visible_in_tree(),"actual App opens licences through category")
	await capture("actual-app")
	app.queue_free()
	await settle()

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"native screenshot "+label)
