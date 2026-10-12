extends SceneTree

var checks: int = 0
var failures: int = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; print("FAIL: "+message)

func settled(app: Node) -> void:
	var deadline: int = Time.get_ticks_msec()+10000
	while app.get("editor_preview_thread") != null and Time.get_ticks_msec()<deadline:
		await process_frame
	check(app.get("editor_preview_thread") == null,"background compilation completes")

func rendered_frame() -> void:
	if DisplayServer.get_name() == "headless": await process_frame
	else: await RenderingServer.frame_post_draw

func capture(name: String) -> void:
	if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png("res://../build/"+name+".png")

func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280,720)
	var folder: String = "user://placement_profile_"+TrackLibrary.unique_id()
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
	await settled(app)
	var initial_deadline: int = Time.get_ticks_msec()+15000
	while app.editor_world._building and Time.get_ticks_msec()<initial_deadline: await process_frame
	check(not app.editor_world._building,"initial editor scenery completes before placement measurements")
	var canvas: EditorCanvas = app.get("canvas")
	app.call("_choose_object","tyre_stack")
	var baseline: bool = "--baseline" in OS.get_cmdline_user_args()
	if baseline:
		# Reproduce the former synchronous full compile + full scene rebuild.
		app.set("editor_raster_cache",{})
		for connection: Dictionary in canvas.edit_finished.get_connections():
			canvas.edit_finished.disconnect(connection.callable)
		canvas.edit_finished.connect(func() -> void:
			app.get("editor_world").track = null
			app.call("_save_draft"))
	var begin: int = Time.get_ticks_usec()
	var track: NativeTrack = TrackCompiler.compile(doc)
	print("PLACEMENT compile_ms=",(Time.get_ticks_usec()-begin)/1000.0)
	begin = Time.get_ticks_usec()
	canvas.show_native(track)
	print("PLACEMENT visual_ms=",(Time.get_ticks_usec()-begin)/1000.0)
	while app.editor_world._building and Time.get_ticks_msec()<initial_deadline: await process_frame
	var initial_visual: NativeTrackVisual = app.get("editor_world").visual
	for i: int in range(3):
		var point: Vector2 = canvas.to_screen(Vector2(-10+i*4,0))
		begin = Time.get_ticks_usec()
		for pressed: bool in [true,false]:
			var event := InputEventScreenTouch.new()
			event.index=0; event.position=point; event.pressed=pressed
			canvas._gui_input(event)
		print("PLACEMENT click_ms=",(Time.get_ticks_usec()-begin)/1000.0," objects=",doc.objects.size())
		var rendered: MultiMeshInstance3D = app.get("editor_world").visual.editor_objects.tyre_instances
		check(rendered != null and rendered.multimesh.instance_count == doc.objects.size(),"tyres rendered before compiler completion")
		if not baseline: check(app.get("test_button").disabled,"practice waits for collision validation")
		await rendered_frame()
		print("PLACEMENT click_to_frame_ms=",(Time.get_ticks_usec()-begin)/1000.0)
	capture("placement-profile")
	await settled(app)
	await rendered_frame()
	capture("placement-settled")
	if not baseline: check(app.get("editor_world").visual == initial_visual,"tyre edits retain terrain and road meshes even when scenery trees are suppressed")
	var independent: NativeTrack = TrackCompiler.compile(doc)
	check(canvas.native_preview.cells == independent.cells and canvas.native_preview.content_hash == independent.content_hash,"latest rapid placement matches independent compile")
	check(canvas.native_preview.tyre_origins == independent.tyre_origins,"all rapid placements have collision bodies")
	check(app.get("library").load_wip(doc.id) == JSON.parse_string(JSON.stringify(doc)),"rapid placements autosave latest document")
	# Undo while a worker is pending must never resurrect its discarded objects.
	app.call("_choose_object","tyre_stack")
	canvas._place(Vector2(8,0))
	app.call("_undo")
	await process_frame
	canvas = app.get("canvas")
	doc = app.get("document")
	check(doc.objects.size() == 3 and canvas.native_preview.tyre_origins.size() == 3,"undo safely retires an outstanding preview")
	# Raster cache must be exact across object/terrain/extent/road changes.
	var cache: Dictionary = {"enabled":true}
	for change: String in ["initial","water","paint","road","extent","theme"]:
		match change:
			"water": doc.objects.append({"kind":"water","position":[0,0],"rotation":0.0})
			"paint": doc.paint.append({"surface":2,"width":5.0,"shape":"round","points":[[0,0],[6,0]]})
			"road": doc.pieces[0].width = 12.0
			"extent": doc.objects.append({"kind":"tyre_stack","position":[90,0],"rotation":0.0})
			"theme": doc.theme = "desert"
		var cached: NativeTrack = TrackCompiler.compile(doc,cache)
		var fresh: NativeTrack = TrackCompiler.compile(doc)
		check(cached != null and fresh != null,"valid cache fixture: "+change)
		if cached != null and fresh != null:
			check(cached.cells == fresh.cells and cached.deck_cells == fresh.deck_cells and cached.content_hash == fresh.content_hash and cached.metadata == fresh.metadata,"cache matches uncached content: "+change)
	app.queue_free()
	await process_frame
	for file: String in DirAccess.get_files_at(folder): DirAccess.remove_absolute(folder+"/"+file)
	DirAccess.remove_absolute(folder)
	print("PLACEMENT_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
