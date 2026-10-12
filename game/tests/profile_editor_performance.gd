extends SceneTree
## Exact contract equivalence and real editor lifecycle/performance observations.

const BEFORE = preload("res://tests/fixtures/road_pieces_before_performance.gd")
var checks: int = 0
var failures: int = 0
var app: Node
var folder: String
var evidence: String

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func metric(label: String, started: int) -> void:
	print("EDITOR_PERFORMANCE ",label," ms=",(Time.get_ticks_usec()-started)/1000.0)

func settle() -> void:
	var deadline: int = Time.get_ticks_msec()+30000
	var started: int = Time.get_ticks_usec()
	var slowest: float = 0.0
	while (app.editor_preview_thread != null or app.editor_world._building) and Time.get_ticks_msec()<deadline:
		var before: int = Time.get_ticks_usec()
		await process_frame
		slowest = maxf(slowest,(Time.get_ticks_usec()-before)/1000.0)
	check(app.editor_preview_thread == null and not app.editor_world._building,"editor preparation completes by its deadline")
	metric("settled",started)
	print("EDITOR_PERFORMANCE maximum_frame_interval_ms=",slowest)
	check(app.canvas.native_preview != null,"completed preparation has compiled collision data")

func show(doc: Dictionary, label: String) -> void:
	app.canvas = null; app.editor_view.clear()
	app.document = doc.duplicate(true)
	app.history.clear(); app.redo_history.clear()
	var started: int = Time.get_ticks_usec()
	app.call("_show_screen","create")
	metric(label+"_open_handler",started)
	check(app.editor_preview_thread != null,"uncached opening queues a worker instead of blocking for compilation")
	check(app.canvas.native_preview == null and app.editor_loading.visible,"opening shows honest preparation state before collision/scenery are ready")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(evidence+"/"+label+"-preparing.png")
	await settle()
	await process_frame
	check(not app.editor_loading.visible,"preparation notice retires when compiler and scenery are ready")
	var independent: NativeTrack = TrackCompiler.compile(app.document)
	check(independent.content_hash == app.canvas.native_preview.content_hash and independent.cells == app.canvas.native_preview.cells,"prepared track exactly matches an independent compile")
	check(app.canvas.native_preview.editor_overlay_mask.get_data() == legacy_overlay(independent,app.document.paint).get_data(),"background overlay mask is byte-identical to original pixel construction")
	var road := Image.create(independent.grid_width,independent.grid_height,false,Image.FORMAT_L8)
	road.fill(Color.BLACK)
	for index: int in range(independent.cells.size()):
		if independent.cells[index] == 0: road.set_pixel(index%independent.grid_width,index/independent.grid_width,Color.WHITE)
	check(app.canvas.native_preview.editor_road_mask.get_data() == road.get_data(),"background road mask is byte-identical to original pixel construction")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(evidence+"/"+label+"-ready.png")

func circuit() -> Dictionary:
	var doc: Dictionary = TrackDocument.create_blank()
	doc.id = "performance_closed"; doc.name = "96 connected pieces"
	var position := Vector2(-47,-36)
	var heading: float = 0.0
	for side: int in range(2):
		for i: int in range(47):
			var piece: Dictionary = RoadPieces.create("straight",position,heading,6)
			piece.length = 2.0; doc.pieces.append(piece)
			position = RoadPieces.end_pose(piece).position
		var turn: Dictionary = RoadPieces.create("hairpin",position,heading,6)
		turn.radius = 36.0; doc.pieces.append(turn)
		var pose: Dictionary = RoadPieces.end_pose(turn)
		position = pose.position; heading = pose.heading
	return doc

func run() -> void:
	root.size = Vector2i(1280,720)
	evidence = ProjectSettings.globalize_path("res://").path_join("../docs/evidence/editor-performance-2026-10-05").simplify_path()
	DirAccess.make_dir_recursive_absolute(evidence)
	var closed: Dictionary = circuit()
	var corpus: Array = [[],closed.pieces]
	for count: int in [4,24,48,96]:
		var pieces: Array = []
		for i: int in range(count):
			var piece: Dictionary = RoadPieces.create("straight",Vector2(-100+(i%12)*17,-94+(i/12)*24),0,6)
			piece.length = 12.0; pieces.append(piece)
		corpus.append(pieces)
	# Includes ambiguous joins, near bucket boundaries, reversed and tapered widths.
	for offset: float in [-0.150001,-0.15,-0.149999,0.0,0.149999,0.15,0.150001]:
		var first: Dictionary = RoadPieces.create("taper",Vector2(-28,0))
		var at: Vector2 = RoadPieces.end_pose(first).position
		corpus.append([first,RoadPieces.create("straight",at+Vector2(offset,0),180,14),RoadPieces.create("curve",at+Vector2(0,offset),90)])
	for pieces: Array in corpus:
		var topology: Dictionary = RoadPieces.prepare_endpoints(pieces)
		check(RoadPieces.joins(pieces) == BEFORE.joins(pieces),"indexed issue ordering/positions match frozen contract")
		check(RoadPieces.connected_route(pieces) == BEFORE.connected_route(pieces),"indexed route widths/points match frozen contract")
		for index: int in range(pieces.size()):
			for endpoint: int in range(2):
				check(RoadPieces._matches(topology,index,endpoint) == BEFORE._partner(pieces,index,endpoint),"endpoint membership and ordering match frozen scan")
			check(RoadPieces.section_geometry(pieces,index,topology) == BEFORE.section_geometry(pieces,index),"section widths and samples remain exact")
			check(RoadPieces.section_outline(pieces,index,0.0,topology) == BEFORE.section_outline(pieces,index),"canonical outline remains exact")
		var doc: Dictionary = TrackDocument.create_blank(); doc.pieces = pieces
		var started: int = Time.get_ticks_usec()
		RoadPieces.route_from_pieces(doc); RoadPieces.joins(pieces)
		metric("route_and_issues_%d" % pieces.size(),started)
	closed = RoadPieces.route_from_pieces(closed).document
	folder = "user://editor_performance_"+TrackLibrary.unique_id()
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder)
	app.records = LocalRecords.new(folder+"/records.json")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	await show(closed,"closed-96")
	var world: EditorWorld = app.editor_world
	var original_visual: NativeTrackVisual = world.visual
	app.call("_remember")
	app.document.name = "Changed closed title"
	var started: int = Time.get_ticks_usec()
	app.call("_save_draft",true); metric("closed_title_edit",started)
	started = Time.get_ticks_usec()
	check(app.call("_save_track_now"),"explicit Save succeeds while preview is pending")
	metric("closed_explicit_save",started)
	check(app.library.load_document(app.document.id) == JSON.parse_string(JSON.stringify(app.document)),"explicit Save durably commits exact current authoring data")
	for notice: Node in app.root_ui.find_children("*","AcceptDialog",true,false): notice.confirmed.emit()
	await process_frame
	await settle()
	check(world.visual == original_visual,"metadata-only changes retain all scenery")
	started = Time.get_ticks_usec(); app.call("_undo"); metric("closed_undo",started)
	started = Time.get_ticks_usec(); app.call("_redo"); metric("closed_redo",started)
	await settle()
	check(app.canvas.native_preview.content_hash == TrackCompiler.compile(app.document).content_hash,"rapid history supersession retains exact latest collision identity")
	# Uncached road approval while a large connected map is shown.
	app.canvas.choose_piece("curve")
	app.canvas.ghost = RoadPieces.create("curve",Vector2(-15,0))
	started = Time.get_ticks_usec(); app.canvas.confirm_piece(); metric("large_road_approval",started)
	check(app.document.pieces.size() == 96 and not app.canvas.ghost.is_empty(),"road capacity is still enforced")
	app.canvas.ghost.clear()
	# Select/delete a road then approve its replacement at the legal 96-piece cap.
	app.call("_remember"); app.document.pieces.remove_at(0); app.call("_save_draft",true)
	app.canvas.choose_piece("straight")
	app.canvas.ghost = closed.pieces[0].duplicate(true)
	started = Time.get_ticks_usec(); app.canvas.confirm_piece(); metric("large_legal_road_approval",started)
	check(app.document.pieces.size() == 96,"legal road placement commits immediately")
	await settle()
	# Object placement and thumbnail selection use the actual canvas/browser.
	app.call("_editor_category","objects")
	await process_frame
	var browser: ObjectBrowser = app.object_browser
	var cards: Array[Node] = browser.tiles.get_children()
	started = Time.get_ticks_usec(); browser.choose("rock"); metric("object_selection",started)
	check(browser.tiles.get_children() == cards,"selection retains visible thumbnail controls")
	for repetition: int in range(3):
		started = Time.get_ticks_usec(); browser.refresh(); metric("browser_refresh",started)
	if DisplayServer.get_name() != "headless":
		for frame: int in range(3): await RenderingServer.frame_post_draw
		check(ObjectThumbnail._images.size() > 0 and ObjectThumbnail._images.size() <= ObjectThumbnail.CACHE_LIMIT,"rendered thumbnails enter a bounded texture cache")
		root.get_texture().get_image().save_png(evidence+"/objects-cached.png")
	app.call("_choose_object","tyre_stack")
	started = Time.get_ticks_usec(); app.canvas._place(app.canvas.to_screen(Vector2(0,0))); metric("object_placement",started)
	check(app.document.objects.size() == 1,"placing an object updates authored data immediately")
	await settle()
	# The real saved-draft load path includes local read/validation and reset.
	var saved: Dictionary = app.library.load_document("performance_closed")
	started = Time.get_ticks_usec(); app.call("_load_saved_document","performance_closed"); metric("saved_track_load",started)
	check(app.document == saved,"loading reads the exact saved original rather than later unsaved geometry")
	await settle()
	app.call("_editor_category","paint")
	app.canvas.paint_mode = "free"
	app.canvas.brush_surface = 2
	app.canvas.paint_points = [[-8.0,0.0],[0.0,0.0],[8.0,0.0]]
	started = Time.get_ticks_usec(); app.canvas.confirm_paint(); metric("paint_commit",started)
	check(app.document.paint.size() == 1,"surface gesture commits immediately")
	await settle()
	var painted: NativeTrack = TrackCompiler.compile(app.document)
	check(app.canvas.native_preview.content_hash == painted.content_hash and app.canvas.native_preview.cells == painted.cells,"paint collision remains exactly independently compiled")
	check(app.canvas.native_preview.editor_overlay_mask.get_data() == legacy_overlay(painted,app.document.paint).get_data(),"painted mask bytes match the original protected-road algorithm")
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(960,540)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(evidence+"/paint-ready-compact.png")
	# Navigation does not wait for an obsolete compiler job.
	app.call("_remember"); app.document.pieces[0].width = 7.0
	app.call("_save_draft",true)
	started = Time.get_ticks_usec(); app.call("_show_screen","tracks"); metric("leave_with_pending_preview",started)
	check(app.screen == "tracks","navigation completes while obsolete work retires")
	app.queue_free(); await process_frame
	cleanup(folder)
	print("EDITOR_PERFORMANCE_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func cleanup(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path): return
	for child: String in DirAccess.get_directories_at(path): cleanup(path.path_join(child))
	for file: String in DirAccess.get_files_at(path): DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)

func legacy_overlay(track: NativeTrack, paint: Array) -> Image:
	var excluded: PackedByteArray = RoadKerbs.exclusion_mask(track,paint)
	var painted := PackedInt32Array(); painted.resize(track.cells.size()); painted.fill(-1)
	var protection := PackedInt32Array(); protection.resize(track.cells.size()); protection.fill(1)
	var overlays: Array = paint.duplicate(true)
	for stroke: Dictionary in overlays: stroke.protect_road = false
	TrackCompiler._paint(overlays,painted,Vector2i(track.grid_width,track.grid_height),track.half_extent,track.cell_size,protection)
	var mask := Image.create(track.grid_width,track.grid_height,false,Image.FORMAT_RGB8)
	for index: int in range(track.cells.size()):
		mask.set_pixel(index%track.grid_width,index/track.grid_width,Color(1.0 if excluded[index] == 0 else 0.0,1.0 if painted[index] in [-1,1] else 0.0,1.0 if painted[index] == 2 else 0.0,1.0))
	return mask
