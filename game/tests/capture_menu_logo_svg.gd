extends SceneTree
## Offline visual review of the shared menu brand with disposable app records.

var output: String

func _initialize() -> void:
	run.call_deferred()

func capture(id: String) -> void:
	for frame: int in range(12): await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(id + ".png")) == OK)

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	output = OS.get_environment("BMT_MENU_LOGO_OUTPUT")
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	var folder: String = "user://menu_logo_svg_" + TrackLibrary.unique_id()
	var app: Node = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	for dimensions: Vector2i in [Vector2i(1280,720), Vector2i(960,540), Vector2i(1920,1080)]:
		root.size = dimensions
		app._show_screen("tracks")
		await capture("menu-%dx%d" % [dimensions.x, dimensions.y])
		var loading: Node = load("res://ui/race_loading.gd").new()
		root.add_child(loading)
		loading.configure("Practice circuit", "pine", PackedVector2Array([Vector2(-30,-20),Vector2(30,-20),Vector2(30,20),Vector2(-30,20)]))
		await capture("loading-%dx%d" % [dimensions.x, dimensions.y])
		loading.queue_free()
		await process_frame
		app._show_screen("account")
		await capture("account-%dx%d" % [dimensions.x, dimensions.y])
	app.queue_free()
	await process_frame
	# A large native render makes the new curves and outlined letters reviewable.
	root.size = Vector2i(1800,600)
	var backdrop := ColorRect.new()
	backdrop.color = Color("101a26")
	backdrop.size = root.get_visible_rect().size
	root.add_child(backdrop)
	var brand := MenuBrand.new()
	root.add_child(brand)
	brand.position = Vector2(30,30)
	brand.size = root.get_visible_rect().size - Vector2(60,60)
	await capture("logo-detail")
	print("MENU_LOGO_CAPTURE: 10 native views saved")
	quit()
