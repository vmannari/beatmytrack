extends SceneTree
## Native visual review only; isolated records, actual selection and live locales.
var app: Node
var page: GaragePage
var output: String
var observations: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()

func settle() -> void:
	for frame: int in range(10): await process_frame
	await RenderingServer.frame_post_draw

func capture(label: String) -> void:
	var pixels: Image = root.get_texture().get_image()
	pixels.save_png(output.path_join(label+".png"))
	var card: Control = page.cards.get_child(VehicleCatalog.IDS.find(page._selected_vehicle_id))
	var bounds: Rect2i = Rect2i(card.get_global_rect())
	if Rect2i(Vector2i.ZERO,root.size).encloses(bounds):
		pixels.get_region(bounds).save_png(output.path_join(label+"-card.png"))

func observe(label: String) -> void:
	var states: Array[Dictionary] = []
	for card: Control in page.cards.get_children():
		var id: String = VehicleCatalog.IDS[card.get_index()]
		var badge: Control = card.find_child("CarEquipped_"+id,true,false)
		var title: Control = card.find_child("CarCardTitle_"+id,true,false)
		states.append({"car":id,"visible":badge.visible,"fits":not badge.visible or card.get_global_rect().grow(-7).encloses(badge.get_global_rect()),"clears_title":not badge.visible or not badge.get_global_rect().intersects(title.get_global_rect()),"badge_bounds":str(badge.get_global_rect()),"card_bounds":str(card.get_global_rect()),"accessible_name":card.accessibility_name,"badge_size":str(badge.size),"badge_has_text":not badge.find_children("*","Label",true,false).is_empty(),"picture_tint":str(page.thumbnails[id]._image.self_modulate),"frame_color":str(card.get_theme_stylebox("normal").border_color)})
	observations.append({"label":label,"size":str(root.size),"locale":TranslationServer.get_locale(),"equipped":page._selected_vehicle_id,"browsed":page.vehicle_id,"states":states})

func equip(index: int) -> void:
	page.open_car(index)
	page._show_section("cars")
	page._finish_menu_move()
	page.showroom.finish_car_transition()
	page.gallery.ensure_control_visible(page.cards.get_child(index))
	await settle()

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	output = ProjectSettings.globalize_path("res://../docs/evidence/garage-selected-reference-2026-11-15/review")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = ProjectSettings.globalize_path(argument.trim_prefix("--evidence-root="))
	DirAccess.make_dir_recursive_absolute(output)
	var folder: String = ProjectSettings.globalize_path("res://../build/garage-selected-reference-2026-11-15/review-"+TrackLibrary.unique_id())
	DirAccess.make_dir_recursive_absolute(folder)
	VehicleSimulation.new(VehicleCatalog.config("compact")).step(DriveFrame.sample(0,1,0))
	app = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.records.settings = {"music_enabled":false,"selected_car":"compact","tutorial_complete":true}
	app.library = TrackLibrary.new(folder)
	app.cloud_root_override = folder.path_join("cloud")
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._show_screen("garage")
	page = app.root_ui.find_child("GaragePage",true,false)
	while page == null or not page.showroom.showroom_ready:
		await process_frame
		page = app.root_ui.find_child("GaragePage",true,false)
	await settle()
	for index: int in range(VehicleCatalog.IDS.size()):
		await equip(index)
		observe(VehicleCatalog.IDS[index]+"-1280")
		await capture(VehicleCatalog.IDS[index]+"-1280")
	await equip(1)
	page.preview_car(3)
	page.showroom.finish_car_transition()
	await settle()
	observe("kart-equipped-browsing-volt")
	await capture("kart-equipped-browsing-volt")
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1720,900),Vector2i(2560,1354)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await settle()
		await equip(1)
		observe("kart-"+str(dimensions.x))
		await capture("kart-"+str(dimensions.x))
	root.size = Vector2i(960,540)
	root.content_scale_size = root.size
	await settle()
	for locale: String in ["en","fr","es","de","pt_BR","ja","ko","nl","it","fi","sv","nb"]:
		GameFonts.configure(locale)
		TranslationServer.set_locale(locale)
		GameText.refresh(self)
		await settle()
		observe("kart-960-"+locale)
		if locale in ["en","de","ja"]: await capture("kart-960-"+locale)
	TranslationServer.set_locale("en")
	GameFonts.configure("en")
	GameText.refresh(self)
	FileAccess.open(output.path_join("observations.json"),FileAccess.WRITE).store_string(JSON.stringify(observations,"\t"))
	app.queue_free()
	await settle()
	print("GARAGE_SELECTED_REVIEW ",observations.size()," states recorded")
	quit()
