extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var folder: String = OS.get_environment("BMT_EDITOR_CAPTURE_DIR")
	var isolated: String = OS.get_environment("BMT_ISOLATED_APPDATA").replace("\\", "/")
	var userdata: String = OS.get_user_data_dir().replace("\\", "/")
	if folder.is_empty() or isolated.is_empty() or not userdata.begins_with(isolated):
		push_error("Capture requires an isolated user data directory")
		quit(2)
		return
	OS.set_environment("BMT_API_URL", "")
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	var state_dir: String = folder.path_join("state")
	DirAccess.make_dir_recursive_absolute(state_dir)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(state_dir.path_join("tracks"))
	app.records = LocalRecords.new(state_dir.path_join("records.json"))
	app.cloud_root_override = state_dir.path_join("cloud")
	root.add_child(app)
	var deadline: int = Time.get_ticks_msec() + 90000
	while not app.startup_complete and Time.get_ticks_msec() < deadline:
		await process_frame
	if not app.startup_complete or app.online.configured:
		push_error("Offline app failed to start")
		quit(3)
		return
	var raw: String = FileAccess.get_file_as_string(folder.path_join("blind-spot.json"))
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary:
		push_error("Blind Spot document failed to parse")
		quit(6)
		return
	var doc: Dictionary = parsed
	if doc.get("id", "") != "track_183e0afb5090a6eb" or doc.get("name", "") != "Blind spot" or doc.get("pieces", []).size() != 21 or doc.get("objects", []).size() != 3 or doc.get("points", []).size() != 96:
		push_error("Blind Spot document identity mismatch")
		quit(7)
		return
	app.document = doc.duplicate(true)
	app.call("_show_screen", "create")
	for frame: int in range(8): await process_frame
	deadline = Time.get_ticks_msec() + 90000
	while Time.get_ticks_msec() < deadline and (app.editor_preview_thread != null or app.editor_world._building):
		await process_frame
	if app.editor_preview_thread != null or app.editor_world._building:
		push_error("Editor preview did not finish")
		quit(4)
		return
	for frame: int in range(8): await RenderingServer.frame_post_draw
	var file: String = folder.path_join("editor-1280.png")
	var error: Error = root.get_texture().get_image().save_png(file)
	print("EDITOR_CAPTURE: path=", file, " pieces=", doc.pieces.size(), " objects=", doc.objects.size(), " error=", error)
	app.queue_free()
	await process_frame
	quit(0 if error == OK else 5)
