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
	var doc: Dictionary = TrackDocument.create_blank()
	doc.id = "website_editor_example"
	doc.name = "Club Circuit"
	var position := Vector2(-28, -18)
	var heading: float = 0.0
	for kind: String in ["straight", "hairpin", "straight", "hairpin"]:
		var piece: Dictionary = RoadPieces.create(kind, position, heading)
		piece.length = 56.0 if kind == "straight" else 0.0
		piece.radius = 18.0
		doc.pieces.append(piece)
		var pose: Dictionary = RoadPieces.end_pose(piece)
		position = pose.position
		heading = pose.heading
	doc = RoadPieces.route_from_pieces(doc).document
	doc["start_line"] = {"position": [-28.0, -18.0], "heading": 0.0}
	doc["automatic_scenery"] = false
	doc.objects = [
		{"kind":"tree", "position": [-29.0, -6.0], "rotation": 0.0},
		{"kind":"broadleaf", "position": [-20.0, 7.0], "rotation": 15.0},
		{"kind":"shed", "position": [23.0, -4.0], "rotation": 0.0},
		{"kind":"grandstand", "position": [0.0, 3.0], "rotation": 0.0},
		{"kind":"barrier", "position": [15.0, 4.0], "rotation": 0.0}
	]
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
