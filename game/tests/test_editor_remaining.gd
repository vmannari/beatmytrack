extends SceneTree
const BEFORE = preload("res://tests/fixtures/editor_compiler_before_remaining.gd")
const PREPARED = preload("res://editor/prepared_track_cache.gd")
const JOBS = preload("res://editor/work_job.gd")
var checks: int = 0
var failures: int = 0
var metrics: Array = []
var evidence: String

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",message)
func metric(label: String, started: int) -> void:
	var item: Dictionary = {"operation":label,"ms":(Time.get_ticks_usec()-started)/1000.0}
	metrics.append(item); print("EDITOR_REMAINING ",JSON.stringify(item))

func circuit() -> Dictionary:
	var doc: Dictionary = TrackDocument.create_blank(); doc.id = "remaining"; doc.name = "Remaining editor checks"
	var position := Vector2(-47,-36); var heading: float = 0
	for side: int in range(2):
		for index: int in range(47):
			var piece: Dictionary = RoadPieces.create("straight",position,heading,6); piece.length = 2
			doc.pieces.append(piece); position = RoadPieces.end_pose(piece).position
		var turn: Dictionary = RoadPieces.create("hairpin",position,heading,6); turn.radius = 36; doc.pieces.append(turn)
		var pose: Dictionary = RoadPieces.end_pose(turn); position = pose.position; heading = pose.heading
	return RoadPieces.route_from_pieces(doc).document

func equivalent(a: NativeTrack, b: NativeTrack, label: String) -> void:
	check(a != null and b != null,label+" compiles")
	if a == null or b == null: return
	check(PREPARED.fields(a) == PREPARED.fields(b),label+" exact canonical metadata/grids/deck/route/contact/hash")

func compiler() -> void:
	for theme: String in ["pine","desert","winter","night_city"]:
		var doc: Dictionary = circuit(); doc.theme = theme
		var cache: Dictionary = {"enabled":true}
		var started: int = Time.get_ticks_usec(); var reference: NativeTrack = BEFORE.compile(doc); metric(theme+"_original_compile",started)
		var fresh: NativeTrack = TrackCompiler.compile(doc,cache)
		equivalent(reference,fresh,theme+" direct prepared grid")
		var renamed: Dictionary = doc.duplicate(true); renamed.name = "Changed name"; renamed["creator"] = "Changed creator"; renamed.id = "renamed"
		started = Time.get_ticks_usec(); var retained: NativeTrack = TrackCompiler.compile(renamed,cache); metric(theme+"_metadata_compile",started)
		equivalent(BEFORE.compile(renamed),retained,theme+" prepared metadata reuse")
		check(int(cache.get("prepared_hits",0)) == 1,theme+" metadata uses the prepared snapshot")
		if retained == null: return
		retained.cells[0] = 0; retained.metadata.surfaces.clear()
		if not retained.kerbs.triangles.is_empty(): retained.kerbs.triangles[0].heights[0] = 100.0
		equivalent(BEFORE.compile(renamed),TrackCompiler.compile(renamed,cache),theme+" mutated result cannot poison prepared data")
		for mutation: String in ["paint","object","width","start"]:
			var changed: Dictionary = renamed.duplicate(true)
			match mutation:
				"paint": changed.paint.append({"surface":2,"width":4.0,"shape":"round","points":[[0.0,0.0]]})
				"object": changed.objects.append({"kind":"container","position":[0.0,0.0],"rotation":0.0})
				"width": changed.pieces[0].width += 1
				"start": changed["start_line"] = {"position":[0.0,-36.0],"heading":0.0}
			equivalent(BEFORE.compile(changed),TrackCompiler.compile(changed,cache),theme+" "+mutation+" invalidation")
		check(int(cache.get("prepared_bytes",0)) <= PREPARED.BUDGET,theme+" prepared bytes stay bounded")
		check(TrackCompiler.compile(doc,{"enabled":true},func() -> bool: return true) == null,theme+" cancelled compilation never publishes a partial track")
		CreatorPreviewMasks.prepare(fresh,doc.paint,cache); var original_mask: Image = cache.overlay_image
		CreatorPreviewMasks.prepare(fresh,doc.paint,cache)
		check(cache.overlay_image == original_mask,theme+" unchanged mask is retained")
		fresh.editor_overlay_mask.set_pixel(0,0,Color.RED)
		CreatorPreviewMasks.prepare(fresh,doc.paint,cache)
		check(fresh.editor_overlay_mask.get_data() == CreatorPreviewMasks.overlay(fresh,doc.paint).get_data(),theme+" returned masks own their mutable pixels")
	for id: String in BuiltinTracks.ids():
		var doc: Dictionary = TrackDocument.from_builtin(NativeTrack.read("res://resources/tracks/"+id+".json"))
		equivalent(BEFORE.compile(doc),TrackCompiler.compile(doc,{"enabled":true}),id+" native remix")

func persistence() -> void:
	var doc: Dictionary = circuit()
	for stroke_index: int in range(32):
		var points: Array = []
		for index: int in range(512): points.append([-100.0+index*0.39,-100.0+stroke_index*6.0])
		doc.paint.append({"surface":2,"width":2.0,"shape":"round","points":points})
	check(TrackDocument.validate(doc,false).is_empty(),"maximum supported painted map is valid")
	check(JSON.stringify(doc,"\t",true).to_utf8_buffer().size() > TrackDocument.MAX_BYTES,"maximum fixture exercises the former pretty-JSON failure")
	var storage := TrackLibrary.new(evidence+"/drafts")
	var started: int = Time.get_ticks_usec(); check(storage.save_document(doc) == OK,"maximum supported map saves as bounded compact JSON"); metric("maximum_paint_save",started)
	check(storage.load_document(doc.id) == JSON.parse_string(JSON.stringify(doc,"",true)),"maximum map round trips exactly")
	var queue = preload("res://editor/write_queue.gd").new()
	for revision: int in range(20):
		var edit: Dictionary = doc.duplicate(true); edit.name = "Revision "+str(revision)
		check(queue.enqueue(storage,edit) == OK,"queued write accepted")
	check(queue.pending.size() == 1,"only superseded queued revisions of the same draft coalesce")
	queue.flush()
	check(queue.completed.size() == 1 and queue.completed[0].error == OK,"flush waits for the required durable write")
	check(storage.load_wip(doc.id).name == "Revision 19","latest queued revision persists")
	var failed := TrackLibrary.new(evidence+"/failed_write")
	DirAccess.make_dir_recursive_absolute(failed.directory+"/wip/"+str(doc.id)+".json.tmp")
	queue.completed.clear(); queue.enqueue(failed,doc); queue.flush()
	check(queue.completed[0].error != OK,"actual asynchronous temporary-file failures remain visible")
	check(DirAccess.dir_exists_absolute(failed.directory+"/wip/"+str(doc.id)+".json.tmp"),"failed writer preserves obstructing user data")
	var committed: Dictionary = storage.load_document(doc.id)
	var revised: Dictionary = committed.duplicate(true); revised.name = "Next committed revision"
	check(storage.save_document(revised) == OK,"compact writer retains a previous committed backup")
	var corrupt := FileAccess.open(storage.directory+"/"+doc.id+".json",FileAccess.WRITE); corrupt.store_string("{broken}"); corrupt.close()
	check(storage.load_document(doc.id) == committed,"corrupt primary recovers the exact previous committed compact map")

func drawing() -> void:
	var canvas := EditorCanvas.new(); canvas.document = circuit(); canvas.world_backdrop = true; canvas.size = Vector2(1280,720); root.add_child(canvas)
	canvas.prepared_route(); canvas.prepared_joins(); canvas._object_run(Vector2(-20,-30),Vector2(20,-30))
	var counts: Dictionary = canvas.preparation_counts.duplicate()
	var started: int = Time.get_ticks_usec()
	for index: int in range(100):
		canvas.pan += Vector2.ONE; canvas.prepared_route(); canvas.prepared_joins(); canvas._object_run(Vector2(-20,-30),Vector2(20,-30))
	metric("hundred_navigation_preparations",started)
	check(canvas.preparation_counts == counts,"panning and roadside runs retain source geometry")
	canvas.document.pieces[0].length += 1; canvas.prepared_joins()
	check(canvas.preparation_counts.joins == counts.joins+1,"editing a road invalidates retained joins")
	canvas.document.objects = [{"kind":"container","position":[0.0,0.0],"rotation":0.0}]
	canvas.mode = "objects"; canvas.selected_object = 0; canvas.dragging = true; canvas.changed_in_gesture = true; canvas.drag_origin = Vector2.ZERO; canvas.pointer_origin = Vector2.ZERO
	var edits: Array = []; canvas.document_changed.connect(func() -> void: edits.append(true))
	for index: int in range(10): canvas._move(canvas.to_screen(Vector2(2.1,0.1)))
	check(edits.size() == 1,"unchanged snapped drag position emits only its first edit")
	canvas.queue_free(); await process_frame

static func cancellable(cancelled: Callable) -> bool:
	while not cancelled.call(): OS.delay_usec(1000)
	return true

func cancellation() -> void:
	var job = JOBS.start(cancellable,self)
	var started: int = Time.get_ticks_usec(); job.cancel(); metric("cancel_handler",started)
	var deadline: int = Time.get_ticks_msec()+5000
	while not job.done and Time.get_ticks_msec()<deadline: await process_frame
	check(job.done and job.result == true,"cancelled worker is reaped without joining its caller")
	var panel := ObjectPopulationPanel.new(); panel.source = circuit(); panel.terrain = TrackCompiler.compile(panel.source); root.add_child(panel)
	panel.worker = JOBS.start(cancellable,self); var pending_job = panel.worker
	panel.pending = false; started = Time.get_ticks_usec(); panel.queue_free(); await process_frame; metric("population_panel_close",started)
	deadline = Time.get_ticks_msec()+5000
	while not pending_job.done and Time.get_ticks_msec()<deadline: await process_frame
	check(pending_job.done and pending_job.cancelled(),"closing population cancels and retires its worker")

func actual_editor() -> void:
	var app: Node = load("res://core/app.tscn").instantiate()
	var storage := TrackLibrary.new(evidence+"/app_drafts")
	app.library = storage; app.records = LocalRecords.new(evidence+"/app_records.json"); app.cloud_root_override = evidence+"/cloud"
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app.document = circuit(); app.canvas = null; app._show_screen("create")
	var deadline: int = Time.get_ticks_msec()+30000
	var maximum: float = 0.0
	while (app.editor_preview_thread != null or app.editor_world._building) and Time.get_ticks_msec()<deadline:
		var frame: int = Time.get_ticks_usec(); await process_frame; maximum = maxf(maximum,(Time.get_ticks_usec()-frame)/1000.0)
	check(app.editor_preview_thread == null and not app.editor_world._building,"actual initial editor preparation settles")
	metrics.append({"operation":"maximum_initial_editor_frame_interval","ms":maximum})
	app.canvas.active_pointer = 0; app.document.name = "Gesture revision"
	var started: int = Time.get_ticks_usec(); check(app._save_draft(true) == OK,"gesture save queues the immutable revision"); metric("actual_gesture_save_handler",started)
	check(app.editor_writes.pending.size() == 1,"gesture save defers disk work out of its handler")
	app.canvas.active_pointer = -99
	check(app._save_track_now(),"explicit Save drains the required pending WIP before acknowledging the original")
	check(storage.load_document(app.document.id).name == "Gesture revision" and storage.load_wip(app.document.id).name == "Gesture revision","both durable boundaries contain the acknowledged revision")
	for window: Node in app.find_children("*","Window",true,false):
		if window is Window: window.hide(); window.queue_free()
	app.canvas.active_pointer = 0; app.document.name = "Exit revision"; app._save_draft(true); app.canvas.active_pointer = -99
	app._show_screen("drafts")
	check(storage.load_wip(app.document.id).name == "Exit revision","navigation drains the final queued gesture revision")
	app.queue_free(); await process_frame

func thumbnails() -> void:
	if DisplayServer.get_name() == "headless": return
	var hidden: Button = ObjectThumbnail.make("container","Container",false,func() -> void: pass)
	root.add_child(hidden); hidden.hide()
	for index: int in range(3): await process_frame
	check(hidden._viewport == null,"hidden cold card never creates a viewport")
	var first: Button = ObjectThumbnail.make("container","Container",false,func() -> void: pass)
	var second: Button = ObjectThumbnail.make("container","Container",false,func() -> void: pass)
	first.position = Vector2(10,10); second.position = Vector2(130,10); root.add_child(first); root.add_child(second)
	var deadline: int = Time.get_ticks_msec()+10000
	while (first._image.texture == null or second._image.texture == null or first._viewport != null or second._viewport != null) and Time.get_ticks_msec()<deadline: await process_frame
	check(first._image.texture != null and first._image.texture == second._image.texture,"same-key visible cards share one completed bake")
	check(ObjectThumbnail.cache_bytes <= ObjectThumbnail.CACHE_BUDGET,"thumbnail CPU/GPU estimate stays within bytes")
	hidden.queue_free(); first.queue_free(); second.queue_free(); await process_frame

func run() -> void:
	root.size = Vector2i(1280,720)
	evidence = ProjectSettings.globalize_path("res://../build/editor-remaining-2026-10-14/")+RenderingServer.get_current_rendering_method()+"-"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(evidence)
	compiler(); persistence(); await drawing(); await cancellation(); await thumbnails(); await actual_editor()
	var file := FileAccess.open(evidence+"/results.json",FileAccess.WRITE); file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t")); file.close()
	print("EDITOR_REMAINING_TESTS: %d checks, %d failures; evidence=%s" % [checks,failures,evidence]); quit(1 if failures else 0)
