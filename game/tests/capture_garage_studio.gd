extends SceneTree
## Actual app captures, isolated owner-independent storage and disabled API.
func _initialize() -> void: _capture.call_deferred()
func _capture() -> void:
	OS.set_environment("BMT_API_URL","")
	var directory: String = "user://garage_studio_capture_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records=LocalRecords.new(directory.path_join("records.json"))
	app.library=TrackLibrary.new(directory)
	app.cloud_root_override=directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	VehicleCatalog.selected="compact"
	app._show_screen("garage")
	await create_timer(0.45).timeout
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,720)]:
		root.size=dimensions
		for frame: int in range(12): await process_frame
		await RenderingServer.frame_post_draw
		if root.get_texture().get_image().save_png("res://../docs/evidence/garage-studio-2026-10-10/garage-app-"+str(dimensions.x)+".png") != OK:
			quit(1)
			return
	app.queue_free()
	await process_frame
	print("GARAGE_STUDIO_APP_CAPTURE: 3 views saved")
	quit()
