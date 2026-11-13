extends SceneTree
## Native review views of the production Garage; persistence is isolated by the runner.
var output: String
var app: Node

func _initialize() -> void: run.call_deferred()

func settle() -> void:
	await create_timer(0.5).timeout
	for _frame: int in range(6): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func capture(label: String) -> void:
	await settle()
	var page: GaragePage = app._retained_garage
	var captions: Array[Dictionary] = []
	for card: Button in page.cards.get_children():
		var caption: Label = card.find_child("CarCardTitle_*",true,false)
		captions.append({"text":caption.text,"rect":str(caption.get_global_rect()),"center":caption.horizontal_alignment,"background_alpha":(card.get_theme_stylebox("normal") as StyleBoxFlat).bg_color.a})
	print("LABEL_REVIEW: ",JSON.stringify({"view":label,"viewport":str(root.size),"title":page.heading.text,"heading":str(page.heading.get_global_rect()),"preview":str(page.preview.get_global_rect()),"cards":captions}))
	if DisplayServer.get_name() != "headless":
		var error: Error = root.get_texture().get_image().save_png(output.path_join(label+".png"))
		if error != OK: push_error("Capture failed: "+str(error))

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	root.size = Vector2i(1280,720)
	app = load("res://core/app.tscn").instantiate()
	var folder: String = "user://carousel-label-review-"+TrackLibrary.unique_id()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.records.settings.music_enabled = false
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	GameSoundtrack.instance().music_enabled = false
	GameSoundtrack.instance().menu_player.stop()
	app._show_screen("garage")
	var page: GaragePage = app._retained_garage
	await capture("compact-1280x720")
	for index: int in range(1,VehicleCatalog.IDS.size()):
		page.preview_car(index)
		page.gallery.scroll_horizontal = index*page.tile_stride
		await capture(VehicleCatalog.IDS[index]+"-1280x720")
	page.preview_car(0)
	page.gallery.scroll_horizontal = 0
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1720,900),Vector2i(720,1280)]:
		root.size = dimensions
		await capture("compact-"+str(dimensions.x)+"x"+str(dimensions.y))
	root.size = Vector2i(1280,720)
	page.open_car(0)
	await capture("workshop")
	page._show_section("cars")
	await settle()
	var card := page.cards.get_child(0) as Button
	var hover := InputEventMouseMotion.new()
	DisplayServer.warp_mouse(Vector2i(0,0))
	hover.position = card.get_global_rect().get_center()
	root.push_input(hover,true)
	await capture("hover")
	card.grab_focus()
	await capture("keyboard-focus")
	app.queue_free()
	for _frame: int in range(4): await process_frame
	quit()
