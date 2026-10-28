extends SceneTree
## Native visual review using disposable records and no remote service.

func _initialize() -> void: run.call_deferred()

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	var output: String = "res://../docs/evidence/menu-logo-2026-10-25"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	# Bound the engine splash to a landscape window without changing the artwork.
	var splash := Image.load_from_file("res://assets/menu/logo.png")
	splash.resize(640, 225, Image.INTERPOLATE_LANCZOS)
	assert(splash.save_png("res://assets/menu/boot_logo.png") == OK)
	var folder: String = "user://owner_brand_" + TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder)
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = dimensions
		app._show_screen("tracks")
		for frame: int in range(12): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("menu-%dx%d.png" % [dimensions.x,dimensions.y]))
		var loading: Node = load("res://ui/race_loading.gd").new()
		root.add_child(loading)
		loading.configure("Practice circuit", "pine", PackedVector2Array([Vector2(-30,-20),Vector2(30,-20),Vector2(30,20),Vector2(-30,20)]))
		for frame: int in range(6): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("loading-%dx%d.png" % [dimensions.x,dimensions.y]))
		loading.queue_free()
		await process_frame
	app.queue_free()
	await process_frame
	print("Owner brand menu/loading captures complete at two window sizes")
	quit()
