extends SceneTree

var checks: int = 0
var failures: int = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; print("FAIL: "+message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280,720)
	var folder: String = "user://road_approval_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.set("library",TrackLibrary.new(folder))
	app.set("records",LocalRecords.new(folder+"/records.json"))
	root.add_child(app)
	await process_frame
	var doc: Dictionary = TrackDocument.create_blank()
	var position := Vector2(-28,-18)
	var heading: float = 0
	for kind: String in ["straight","hairpin","straight","hairpin"]:
		var piece: Dictionary = RoadPieces.create(kind,position,heading)
		piece.length = 56.0 if kind == "straight" else 0.0
		piece.radius = 18.0
		doc.pieces.append(piece)
		var pose: Dictionary = RoadPieces.end_pose(piece)
		position = pose.position; heading = pose.heading
	doc = RoadPieces.route_from_pieces(doc).document
	app.set("document",doc)
	app.call("_show_screen","create")
	await process_frame
	var canvas: EditorCanvas = app.get("canvas")
	canvas.snap_enabled = false
	for i: int in range(3):
		canvas.choose_piece("curve")
		canvas.ghost = RoadPieces.create("curve",Vector2(-15+i*12,-8))
		var at: Vector2 = canvas.piece_accept_rect(canvas.ghost).get_center()
		var begin: int = Time.get_ticks_usec()
		for pressed: bool in [true,false]:
			var event := InputEventScreenTouch.new()
			event.position = at; event.index = 0; event.pressed = pressed
			canvas._gui_input(event)
		print("ROAD_APPROVAL click_ms=",(Time.get_ticks_usec()-begin)/1000.0," pieces=",doc.pieces.size())
		check(doc.pieces.size() == 5+i and canvas.ghost.is_empty(),"approval commits exactly one road and dismisses controls")
		check(not canvas.pending_road_pieces().is_empty(),"accepted roads remain visible while detailed geometry compiles")
		check(app.get("test_button").disabled,"practice waits for complete collision validation")
		check(app.get("library").load_wip(doc.id) == JSON.parse_string(JSON.stringify(doc)),"accepted road is autosaved before preview finishes")
		if DisplayServer.get_name() == "headless": await process_frame
		else: await RenderingServer.frame_post_draw
		print("ROAD_APPROVAL first_frame_ms=",(Time.get_ticks_usec()-begin)/1000.0)
	if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png("res://../build/road-approval-pending.png")
	var deadline: int = Time.get_ticks_msec()+15000
	while app.get("editor_preview_thread") != null and Time.get_ticks_msec()<deadline: await process_frame
	check(app.get("editor_preview_thread") == null,"latest background preview completes")
	check(canvas.pending_road_pieces().is_empty(),"temporary road drawing retires after the detailed scene arrives")
	var independent: NativeTrack = TrackCompiler.compile(doc)
	check(canvas.native_preview.content_hash == independent.content_hash and canvas.native_preview.cells == independent.cells,"rapid approvals produce exactly the independent compiled track")
	check(canvas.native_preview.metadata.creator_document.pieces == doc.pieces,"no intermediate preview can discard later approvals")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../build/road-approval-ready.png")
	canvas.choose_piece("straight")
	canvas.ghost = RoadPieces.create("straight",Vector2(-16,4))
	canvas.confirm_piece()
	app.call("_undo")
	check(app.get("document").pieces.size() == 7,"undo safely discards an in-flight road approval")
	app.call("_redo")
	check(app.get("document").pieces.size() == 8,"redo restores the approved road")
	app.call("_save_track_explicit")
	check(app.get("editor_preview_thread") == null,"explicit save drains pending preview work")
	app.queue_free()
	await process_frame
	for file: String in DirAccess.get_files_at(folder): DirAccess.remove_absolute(folder+"/"+file)
	DirAccess.remove_absolute(folder)
	print("ROAD_APPROVAL_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
