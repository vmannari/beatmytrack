extends SceneTree
## MHS01–MHS04: shared header with the owner's original navigation button style.
var checks: int = 0
var failures: int = 0
var app: Node
var output: String
var header_measurements: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()

func check(ok: bool, caption: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",caption)

func settle(count: int = 10) -> void:
	for frame: int in range(count): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func check_header(selected: String, caption: String) -> void:
	var header: Control = app.root_ui.find_child("MenuHeader",true,false)
	var wallet: Control = header.get_node("GarageHeaderWallet")
	var profile_rect: Rect2 = app.account_button.get_global_rect()
	var gear_rect: Rect2 = header.get_node("MenuSettings").get_global_rect()
	check(is_equal_approx(profile_rect.size.y,gear_rect.size.y),"profile and Settings share a height "+caption)
	check(absf(profile_rect.get_center().y-wallet.get_global_rect().get_center().y) <= 1,"coins align with account centre "+caption)
	check(wallet.is_visible_in_tree(),"coin balance remains visible "+caption)
	check(header.get_global_rect().end.x <= root.size.x+1,"complete header fits viewport "+caption)
	if header.get_global_rect().end.x > root.size.x+1:
		print("HEADER_BOUNDS ",caption," header=",header.get_global_rect()," minimum=",header.get_combined_minimum_size()," layout minimum=",header.get_parent().get_combined_minimum_size())
		for child: Control in header.get_children(): print(child.name," size=",child.size," minimum=",child.get_combined_minimum_size())
		for tab: Button in header.get_node("MenuNavigation").get_children(): print(tab.name," ",tab.text," size=",tab.size," minimum=",tab.get_combined_minimum_size())
	var previous_end: float = header.get_global_rect().position.x
	for child: Control in header.get_children():
		check(child.get_global_rect().position.x >= previous_end-1,"header controls do not overlap "+caption+"/"+child.name)
		previous_end = child.get_global_rect().end.x
	for tab: Button in header.get_node("MenuNavigation").get_children():
		var active: bool = tab.name == "Tab_"+selected
		var style: StyleBoxFlat = tab.get_theme_stylebox("normal")
		check((style.border_width_bottom == 2) == active,"selected button follows page "+caption+"/"+tab.name)
		check((style.bg_color != Color.TRANSPARENT) == active,"only selected navigation button is filled "+caption+"/"+tab.name)
		check(tab.get_theme_color("font_color") == (MenuStyle.ACCENT if active else MenuStyle.MUTED),"tab colour follows page "+caption+"/"+tab.name)
		check(tab.size.y >= 52,"tab touch target "+caption+"/"+tab.name)
		check(is_equal_approx(tab.size.y,profile_rect.size.y),"navigation matches profile height "+caption+"/"+tab.name)
		check(absf(tab.get_global_rect().get_center().y-gear_rect.get_center().y) <= 1,"navigation aligns with Settings centre "+caption+"/"+tab.name)
	check(app.account_button.get_node("MenuProfileCar").get_global_rect().encloses(app.account_button.get_node("MenuProfileCar").preview.get_global_rect()),"profile car stays inside slot "+caption)
	check(app.account_button.get_node("MenuCarPicker").get_global_rect().end.x <= app.account_button.get_global_rect().end.x,"car selector fits account "+caption)
	if is_instance_valid(app.menu_body_slot):
		check(app.menu_body_slot.get_global_rect().position.y >= header.get_global_rect().end.y,"page starts below shared menu "+caption)
	header_measurements.append({"caption":caption,"header":var_to_str(header.get_global_rect()),"tab_height":header.get_node("MenuNavigation").get_child(0).size.y,"profile":var_to_str(profile_rect),"settings":var_to_str(gear_rect),"wallet":var_to_str(wallet.get_global_rect())})

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(2,root.size.y-2)
	root.push_input(motion,true)
	await settle(2)
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)

func run() -> void:
	create_timer(180).timeout.connect(func() -> void: quit(1))
	OS.set_environment("BMT_API_URL","")
	output = "res://../docs/evidence/shared-menu-header-2026-11-15/"+RenderingServer.get_current_rendering_method()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	var folder: String = "user://shared-menu-header-"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	app = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.records.settings = {"music_enabled":false,"selected_car":"compact","tutorial_complete":true}
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	root.add_child(app)
	while not app.startup_complete: await process_frame
	check(not app.online.configured,"actual App uses isolated offline storage")
	app.race_area_mode = "free"
	var routes: Dictionary = {"tracks":"tracks","rivalry":"tracks","daily":"tracks","challenges":"tracks","biome":"create","drafts":"create","garage":"garage","store":"store","profile":"","settings":"","challenge_create":"tracks"}
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1720,900)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		for route: String in routes:
			app._show_screen(route)
			app._finish_menu_page_slide()
			await settle()
			check_header(routes[route],route+"/"+str(dimensions.x))
			var wallet: Control = app.root_ui.find_child("GarageHeaderWallet",true,false)
			check(wallet._amount.text == "—","guest balance stays unavailable "+route)
			if (dimensions.x == 1280 and route != "challenge_create") or (dimensions.x == 960 and route in ["tracks","store"]):
				await capture(route+"-"+str(dimensions.x))
	# Resize a retained shell in both directions, then navigate without rebuilding it.
	app._show_screen("tracks")
	app._finish_menu_page_slide()
	await settle(20)
	var shell: int = app.root_ui.get_instance_id()
	var header_rect: Rect2 = app.root_ui.find_child("MenuHeader",true,false).get_global_rect()
	app._navigate_menu_page("biome")
	check(app.root_ui.get_instance_id() == shell,"warm navigation retains the same header")
	var selected_tab: Button = app.root_ui.find_child("Tab_create",true,false)
	check(selected_tab.get_theme_stylebox("normal").bg_color != Color.TRANSPARENT,"retained navigation updates filled button in the input callback")
	app._finish_menu_page_slide()
	await settle()
	check(app.root_ui.find_child("MenuHeader",true,false).get_global_rect().is_equal_approx(header_rect),"header stays stationary across page changes")
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await settle()
		check_header("create","live resize "+str(dimensions.x))
		check(app.root_ui.get_instance_id() == shell,"live resize retains header")
	# Menu actions and profile/car controls keep their existing routing.
	app.root_ui.find_child("Tab_store",true,false).pressed.emit()
	app._finish_menu_page_slide()
	await settle()
	check(app.screen == "store","Store tab still navigates")
	check_header("store","Store button")
	app.account_button.pressed.emit()
	await settle()
	check(app.screen == "profile","account still opens Profile")
	check_header("","Profile button")
	app.root_ui.find_child("MenuSettings",true,false).pressed.emit()
	await settle()
	check(app.screen == "settings","gear still opens Settings")
	check_header("","Settings button")
	root.size = Vector2i(960,540)
	root.content_scale_size = root.size
	for locale: String in ["de","fr","es","fi","ja"]:
		GameFonts.configure(locale)
		TranslationServer.set_locale(locale)
		GameText.refresh(self)
		await settle()
		check_header("","localized compact "+locale)
	TranslationServer.set_locale("en")
	GameFonts.configure("en")
	GameText.refresh(self)
	# Stress a long driver name and grouped balance without losing header actions.
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1720,900)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		app._show_screen("tracks")
		app._finish_menu_page_slide()
		var name: String = "LongDriverName_123456789012345678901234567"
		GameText.user_text(app.account_button)
		app.account_button.text = name
		var wallet: Control = app.root_ui.find_child("GarageHeaderWallet",true,false)
		wallet._amount.text = "1,234,567"
		wallet.refresh()
		await settle()
		check_header("tracks","long name and balance "+str(dimensions.x))
		check(app.account_button.tooltip_text.contains(name),"complete driver name remains available "+str(dimensions.x))
		check(app.account_button.get_global_rect().encloses(app.account_button.get_node("MenuProfileCar").get_global_rect()),"profile car clears button edges "+str(dimensions.x))
		if dimensions.x == 960:
			await capture("long-name-balance-960")
			for locale: String in ["de","fr","es","fi","ja","ko"]:
				GameFonts.configure(locale)
				TranslationServer.set_locale(locale)
				GameText.refresh(self)
				await settle(3)
				check_header("tracks","long name and balance compact "+locale)
				if locale == "de": await capture("long-name-balance-de-960")
			TranslationServer.set_locale("en")
			GameFonts.configure("en")
			GameText.refresh(self)
	FileAccess.open(output.path_join("header-measurements.json"),FileAccess.WRITE).store_string(JSON.stringify(header_measurements,"\t"))
	app.queue_free()
	await settle(20)
	print("SHARED_MENU_HEADER ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
