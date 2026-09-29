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
	var approval_started: int = Time.get_ticks_usec()
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
	var slowest_frame_ms: float = 0.0
	while (app.get("editor_preview_thread") != null or app.editor_world._building) and Time.get_ticks_msec()<deadline:
		var frame_started: int = Time.get_ticks_usec()
		await process_frame
		slowest_frame_ms = maxf(slowest_frame_ms,(Time.get_ticks_usec()-frame_started)/1000.0)
	print("ROAD_APPROVAL ready_ms=",(Time.get_ticks_usec()-approval_started)/1000.0," slowest_frame_ms=",slowest_frame_ms)
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
	var history_begin: int = Time.get_ticks_usec()
	app.call("_undo")
	print("EDITOR_HISTORY undo_ms=",(Time.get_ticks_usec()-history_begin)/1000.0)
	check(app.get("canvas") == canvas,"undo retains the canvas and viewport")
	check(app.get("document").pieces.size() == 7,"undo safely discards an in-flight road approval")
	history_begin = Time.get_ticks_usec()
	app.call("_redo")
	print("EDITOR_HISTORY redo_ms=",(Time.get_ticks_usec()-history_begin)/1000.0)
	check(app.get("canvas") == canvas,"redo retains the canvas and viewport")
	check(app.get("document").pieces.size() == 8,"redo restores the approved road")
	app.call("_save_track_explicit")
	check(app.get("editor_preview_thread") == null,"explicit save drains pending preview work")
	# Reproduce the old synchronous undo path on the same fixture for comparison.
	var before: int = Time.get_ticks_usec()
	app.redo_history.append(app.document.duplicate(true))
	app.document = app.history.pop_back()
	app.call("_save_draft")
	app.call("_show_screen","create")
	print("EDITOR_HISTORY legacy_undo_ms=",(Time.get_ticks_usec()-before)/1000.0)
	canvas = app.get("canvas")
	var world: EditorWorld = app.get("editor_world")
	var initial_visual: NativeTrackVisual = world.visual
	app.call("_redo")
	deadline = Time.get_ticks_msec()+15000
	while (app.get("editor_preview_thread") != null or app.editor_world._building) and Time.get_ticks_msec()<deadline: await process_frame
	check(app.get("editor_preview_thread") == null,"redo background preview completes")
	app.call("_undo")
	deadline = Time.get_ticks_msec()+15000
	while (app.get("editor_preview_thread") != null or app.editor_world._building) and Time.get_ticks_msec()<deadline: await process_frame
	check(world.visual == initial_visual,"undo reuses the previously built scenery mesh")
	check(canvas.native_preview.content_hash == TrackCompiler.compile(app.document).content_hash,"history preview matches independent compiler")
	check(canvas.preview.surface_texture == null,"3D editor skips the unused CPU map raster")
	var original_name: String = app.document.name
	app.call("_remember")
	app.document.name = "Temporary title"
	app.call("_undo")
	check((app.root_ui.find_child("TrackName",true,false) as Label).text == original_name,"undo refreshes the title without recreating controls")
	for command: String in ["_redo","_undo","_redo","_undo"]: app.call(command)
	deadline = Time.get_ticks_msec()+15000
	while (app.get("editor_preview_thread") != null or app.editor_world._building) and Time.get_ticks_msec()<deadline: await process_frame
	check(app.get("editor_preview_thread") == null and canvas.native_preview.content_hash == TrackCompiler.compile(app.document).content_hash,"rapid history supersession installs only the final document")
	check(app.editor_compiled_cache.size() <= 3 and world._visual_cache.size() <= 2,"history caches stay bounded")
	await _build_lifecycle(app)
	app.queue_free()
	await process_frame
	for file: String in DirAccess.get_files_at(folder): DirAccess.remove_absolute(folder+"/"+file)
	DirAccess.remove_absolute(folder)
	print("ROAD_APPROVAL_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _mesh_signature(node: Node) -> Array:
	var result: Array = []
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		if instance.mesh != null:
			for surface: int in range(instance.mesh.get_surface_count()):
				result.append([instance.transform,instance.mesh.surface_get_arrays(surface)])
	elif node is MultiMeshInstance3D:
		var instance := node as MultiMeshInstance3D
		if instance.multimesh != null: result.append([instance.transform,instance.multimesh.buffer])
	for child: Node in node.get_children(): result.append_array(_mesh_signature(child))
	return result

func _build_lifecycle(app: Node) -> void:
	var world: EditorWorld = app.editor_world
	var canvas: EditorCanvas = app.canvas
	var previous: NativeTrackVisual = world.visual
	var next_doc: Dictionary = TrackDocument.create_default()
	next_doc.pieces = [RoadPieces.create("curve",Vector2(-15,0))]
	var first: NativeTrack = TrackCompiler.compile(next_doc)
	world.show_track(first)
	check(world._building and world.visual == previous,"scenery replacement yields while retaining the complete old scene")
	var previous_zoom: float = canvas.zoom
	canvas.zoom_by(1.1)
	check(canvas.zoom > previous_zoom and world._building,"editor navigation remains usable during scenery construction")
	next_doc.pieces.append(RoadPieces.create("hairpin",Vector2(0,-20)))
	var latest: NativeTrack = TrackCompiler.compile(next_doc)
	world.show_track(latest)
	var deadline: int = Time.get_ticks_msec()+15000
	while world._building and Time.get_ticks_msec()<deadline: await process_frame
	check(not world._building and world._visual_track == latest,"superseded scenery cannot overwrite the newest track")
	var reference := NativeTrackVisual.new()
	reference.editor_preview = true
	reference.visible = false
	root.add_child(reference)
	reference.build(latest,BridgePresentation.new(latest))
	check(_mesh_signature(world.visual) == _mesh_signature(reference),"sliced build preserves every mesh array and transform")
	reference.free()
	for theme: String in ["desert","winter"]:
		next_doc.theme = theme
		var themed: NativeTrack = TrackCompiler.compile(next_doc)
		world.show_track(themed)
		deadline = Time.get_ticks_msec()+15000
		while world._building and Time.get_ticks_msec()<deadline: await process_frame
		check(not world._building and world._visual_track == themed,"sliced scenery completes in "+theme)
		reference = NativeTrackVisual.new()
		reference.editor_preview = true
		reference.visible = false
		root.add_child(reference)
		reference.build(themed,BridgePresentation.new(themed))
		check(_mesh_signature(world.visual) == _mesh_signature(reference),"sliced mesh equivalence in "+theme)
		reference.free()
	world.show_track(first)
	check(world._building,"leaving-editor regression starts with active scenery work")
	app.call("_show_screen","home")
	for frame: int in range(5): await process_frame
	check(app.screen == "home","leaving during a sliced build safely cancels the old scene")
