extends SceneTree
const APP = preload("res://core/app.tscn")
const HISTORY = preload("res://editor/editor_history.gd")
const BEFORE_CANVAS = preload("res://tests/fixtures/editor_t05_t11_before/editor_canvas.gd")
const BEFORE_BORDERS = preload("res://tests/fixtures/editor_t05_t11_before/spline_borders.gd")
const COMPARE = preload("res://tests/fixtures/editor_t05_t11_before/prop_comparison.gd")
var checks: int = 0
var failures: int = 0
var rows: Array = []
var out: String = ""
var app: Node

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func record(label: String, data: Dictionary) -> void:
	data["operation"] = label; rows.append(data)
	print("EDITOR_T05_T11 ",JSON.stringify(data))
	if not out.is_empty():
		var mode: String = "headless" if DisplayServer.get_name() == "headless" else RenderingServer.get_current_rendering_method()
		var file := FileAccess.open(out+"/results-"+mode+".json",FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows},"\t"))

func painted() -> Dictionary:
	var doc: Dictionary = TrackDocument.create_blank()
	for stroke: int in range(32):
		var points: Array = []
		for i: int in range(512): points.append([-100.0+float(i)*0.39,-80.0+stroke*5.0+sin(i*0.1)])
		doc.paint.append({"surface":1,"width":2.0,"shape":"round","points":points})
	return doc

func history_and_navigation() -> void:
	var doc: Dictionary = painted()
	check(TrackDocument.validate(doc).is_empty(),"maximum paint fixture is valid")
	var old: Array = []
	var began: int = Time.get_ticks_usec(); var baseline_memory: int = OS.get_static_memory_usage()
	for i: int in range(40): old.append(doc.duplicate(true))
	var old_delta: int = OS.get_static_memory_usage()-baseline_memory
	var old_ms: float = (Time.get_ticks_usec()-began)/1000.0
	old.clear()
	var undo: Array[Dictionary] = []; var redo: Array[Dictionary] = []
	baseline_memory = OS.get_static_memory_usage(); began = Time.get_ticks_usec()
	for i: int in range(40):
		doc.name = "Revision "+str(i)
		undo.append(HISTORY.capture(doc,undo.back() if not undo.is_empty() else {}))
		HISTORY.trim(undo,redo)
	var delta: int = OS.get_static_memory_usage()-baseline_memory
	var capture_ms: float = (Time.get_ticks_usec()-began)/1000.0
	check(undo.size() == 40,"shared paint preserves forty undo steps within allowance")
	check(HISTORY.bytes_used([undo,redo]) <= HISTORY.BUDGET,"both stacks share one byte cap")
	for i: int in range(40):
		var restored: Dictionary = HISTORY.restore(undo[i])
		check(restored.paint == doc.paint and restored.name == "Revision "+str(i),"immutable snapshot "+str(i))
	var original: Dictionary = HISTORY.restore(undo[0])
	doc.paint[0].points[0][0] += 1
	check(HISTORY.restore(undo[0]) == original,"live nested mutation cannot alter history")
	for i: int in range(20): redo.append(undo.pop_back())
	HISTORY.trim(undo,redo,1024)
	check(HISTORY.bytes_used([undo,redo]) <= 1024,"pressure trims oldest states across undo and redo")
	var distinct: Array[Dictionary] = []
	for i: int in range(40):
		doc.paint[0].points[0][0] = -100.0+float(i)*0.01
		distinct.append(HISTORY.capture(doc,distinct.back() if not distinct.is_empty() else {}))
		HISTORY.trim(distinct,redo)
	check(distinct.size() < 40 and HISTORY.bytes_used([distinct,redo]) <= HISTORY.BUDGET,"distinct maximum-paint revisions obey the shared byte cap")
	check(HISTORY.restore(distinct.back()) == doc,"budget eviction keeps the newest exact revision")
	record("history_40",{"before_static_delta":old_delta,"after_static_delta":delta,"before_ms":old_ms,"after_ms":capture_ms})
	var old_canvas = BEFORE_CANVAS.new(); var canvas := EditorCanvas.new()
	root.add_child(old_canvas); root.add_child(canvas)
	old_canvas.document = doc; canvas.document = doc
	old_canvas.mode = "pan"; canvas.mode = "pan"
	began = Time.get_ticks_usec()
	for i: int in range(20): old_canvas._begin(Vector2(300,200),0); old_canvas._end(0)
	var old_begin_ms: float = (Time.get_ticks_usec()-began)/20.0/1000.0
	began = Time.get_ticks_usec()
	for i: int in range(20): canvas._begin(Vector2(300,200),0); canvas._end(0)
	var new_begin_ms: float = (Time.get_ticks_usec()-began)/20.0/1000.0
	check(canvas._gesture_document.is_empty(),"pan never snapshots authoring data")
	canvas.preparing = true; var pan: Vector2 = canvas.pan
	canvas._begin(Vector2(300,200),0); canvas._move(Vector2(330,220)); canvas._end(0)
	check(canvas.pan == pan+Vector2(30,20),"preparing canvas remains navigable")
	check(canvas.document == doc,"preparation navigation does not edit the track")
	canvas.preparing = false; canvas.mode = "objects"
	canvas.document = TrackDocument.create_blank()
	canvas.document.paint = doc.paint
	canvas.document.objects.append({"kind":"container","position":[0.0,0.0],"rotation":0.0})
	var before: Dictionary = canvas.document.duplicate(true)
	canvas._begin(canvas.to_screen(Vector2.ZERO),0)
	check(canvas._gesture_document.is_empty(),"object selection has no rollback copy")
	canvas._move(canvas.to_screen(Vector2(8,4)))
	check(canvas.changed_in_gesture and not canvas._gesture_document.has("paint"),"object drag captures only touched domains")
	canvas._rollback_navigation_edit(); canvas.cancel_gesture()
	check(canvas.document == before,"second-finger rollback restores exact full document")
	record("navigation_begin",{"before_mean_ms":old_begin_ms,"after_mean_ms":new_begin_ms})
	old_canvas.queue_free(); canvas.queue_free(); await process_frame

func geometry() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 72511
	for trial: int in range(120):
		var polygon := PackedVector2Array()
		for i: int in range(12+trial%90):
			var angle: float = TAU*i/float(12+trial%90)
			polygon.append(Vector2.from_angle(angle)*(5.0+rng.randf()*15.0))
		check(SplineBorders.rounded(polygon,[]) == BEFORE_BORDERS.rounded(polygon,[]),"rounded perimeter exact "+str(trial))
	var endpoint_before = preload("res://tests/fixtures/editor_t05_t11_before/endpoints.gd")
	var pieces: Array = []
	for i: int in range(96): pieces.append(RoadPieces.create("straight",Vector2((i%3)*0.1499,(i%7)*0.025),0.0,8.0))
	var began: int = Time.get_ticks_usec()
	var expected_topology: Dictionary = endpoint_before.prepare_endpoints(pieces)
	var before_ms: float = (Time.get_ticks_usec()-began)/1000.0
	began = Time.get_ticks_usec()
	check(RoadPieces.prepare_endpoints(pieces) == expected_topology,"dense endpoint partners and ordering remain exact")
	record("crowded_endpoints",{"before_ms":before_ms,"after_ms":(Time.get_ticks_usec()-began)/1000.0})
	for edge: float in [-0.15001,-0.15,-0.14999,0.0,0.14999,0.15,0.15001]:
		pieces[0].position = [edge,edge]
		check(RoadPieces.prepare_endpoints(pieces) == endpoint_before.prepare_endpoints(pieces),"endpoint bucket boundary exact "+str(edge))
	var dense := PackedVector2Array()
	for i: int in range(512): dense.append(Vector2.from_angle(TAU*i/512.0)*(10.0 if i%2 else 15.0))
	began = Time.get_ticks_usec()
	var old_rounded: PackedVector2Array = BEFORE_BORDERS.rounded(dense,[])
	var old_rounded_ms: float = (Time.get_ticks_usec()-began)/1000.0
	began = Time.get_ticks_usec()
	check(SplineBorders.rounded(dense,[]) == old_rounded,"dense rounded corners remain exact")
	record("rounded_512",{"before_ms":old_rounded_ms,"after_ms":(Time.get_ticks_usec()-began)/1000.0})
	var spatial = preload("res://editor/spatial_bounds.gd").new()
	for i: int in range(96): spatial.add(Rect2(Vector2(i%12,i/12)*9.0,Vector2(6,8)))
	for i: int in range(96):
		var area: Rect2 = spatial.bounds[i].grow(3.0)
		var expected: Array = []; var found: Array = []
		for j: int in range(96):
			if area.intersects(spatial.bounds[j]): expected.append(j)
		for j: int in spatial.query(area):
			if area.intersects(spatial.bounds[j]): found.append(j)
		check(expected == found,"ordered broad phase retains every intersection "+str(i))

func circuit() -> Dictionary:
	var doc: Dictionary = TrackDocument.create_blank(); doc.id = "editor_t05_t11"
	var position := Vector2(-30,-20); var heading: float = 0.0
	for side: int in range(2):
		var straight: Dictionary = RoadPieces.create("straight",position,heading,8.0); straight.length = 60.0
		doc.pieces.append(straight); position = RoadPieces.end_pose(straight).position
		var turn: Dictionary = RoadPieces.create("hairpin",position,heading,8.0); turn.radius = 20.0
		doc.pieces.append(turn); var end: Dictionary = RoadPieces.end_pose(turn); position = end.position; heading = end.heading
	return RoadPieces.route_from_pieces(doc).document

func settle() -> void:
	var deadline: int = Time.get_ticks_msec()+90000
	while Time.get_ticks_msec() < deadline:
		if not app.editor_commits.unsettled() and not app.editor_writes.unsettled(app.library,str(app.document.id)) and app.editor_preview_thread == null and not app.editor_world._building and not app.canvas.preparing: break
		await process_frame
	check(not app.editor_commits.unsettled() and app.editor_preview_thread == null and not app.editor_world._building,"latest editor work settles")
	await process_frame

func durable() -> bool:
	var path: String = app.library.directory.path_join("wip/"+str(app.document.id)+".json")
	return FileAccess.get_file_as_string(path) == JSON.stringify(app.document,"",true) and TrackLibrary.draft_fingerprint(app.library.load_wip(str(app.document.id))) == TrackLibrary.draft_fingerprint(app.document)

func application() -> void:
	var directory: String = "user://editor_t05_t11_"+TrackLibrary.unique_id()
	app = APP.instantiate(); app.library = TrackLibrary.new(directory); app.records = LocalRecords.new(directory+"/records.json")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app.document = circuit(); app._show_screen("create"); await settle()
	var measurements: Array = []
	for i: int in range(20):
		var began: int = Time.get_ticks_usec()
		app._remember(); app.document.pieces[0].width = 8.0+i*0.05
		app._save_draft(true)
		measurements.append((Time.get_ticks_usec()-began)/1000.0)
		check(app.test_button.disabled and app.publish_button.disabled,"pending analysis gates test and publish")
	check(app.editor_commits.unsettled(),"ordinary button edits use deferred analysis")
	app._flush_editor_writes()
	check(durable(),"flush saves exact latest normalized revision")
	await settle()
	var latest: Dictionary = app.document.duplicate(true)
	app._undo(); app._flush_editor_writes(); await settle()
	check(app.document != latest,"undo restores earlier binary snapshot")
	app._redo(); app._flush_editor_writes(); await settle()
	check(app.document == latest,"redo restores exact latest revision")
	app.document.name = "Committed before drag"; app._save_draft(true)
	app.document.name = "Uncommitted gesture"
	app.editor_commits.flush(); app._apply_editor_commits(); app.editor_writes.flush(); app._apply_editor_writes()
	check(app.document.name == "Uncommitted gesture" and app.library.load_wip(str(app.document.id)).name == "Committed before drag","older committed analysis saves recovery without overwriting a newer gesture")
	app.document.name = "Committed before drag"; app._save_draft(true); app._flush_editor_writes(); await settle()
	# Queued stale work cannot overwrite a newer document or cross a library.
	app.document.name = "Obsolete"; app._save_draft(true)
	app.document.name = "Latest"; app._save_draft(true)
	app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(durable(),"background interruption flushes latest revision")
	await settle()
	var visual: NativeTrackVisual = app.editor_world.visual
	var before: Dictionary = app.editor_world.memory_snapshot()
	app._notification(Node.NOTIFICATION_OS_MEMORY_WARNING)
	app.editor_memory.tick(app)
	check(app.editor_world.visual == visual,"pressure preserves active editor visual")
	check(app.editor_world.visual_cache_bytes == 0 and app.editor_compiled_cache.is_empty(),"pressure trims inactive scenes and compiled tracks")
	check(HISTORY.bytes_used([app.history,app.redo_history]) <= preload("res://editor/editor_memory.gd").PRESSURE_HISTORY,"pressure respects smaller shared history allowance")
	check(durable(),"pressure preserves durable document")
	record("ordinary_edits",{"handler_ms":measurements,"memory_before":before,"memory_after":app.editor_memory.telemetry,"preparation":app.editor_world.preparation_metrics})
	if DisplayServer.get_name() != "headless" and not out.is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out+"/"+RenderingServer.get_current_rendering_method()+"-editor.png")
	# Teardown drains analysis/writing without scheduling fresh scene work.
	var saved_library: TrackLibrary = app.library
	var saved_id: String = str(app.document.id)
	app.document.objects.append({"kind":"container","position":[0.0,5.0],"rotation":0.0})
	app._save_draft(true)
	app.free(); app = null
	check(saved_library.load_wip(saved_id).objects.size() == 1,"immediate editor destruction drains the final commit without preview work")
	await process_frame

func grouped_winter() -> void:
	var helper = COMPARE.new()
	var track: NativeTrack = helper.props_fixture("winter")
	track.metadata.creator_document.objects = track.metadata.creator_document.objects.filter(func(object: Dictionary) -> bool: return CreatorCatalog.available(str(object.kind),"winter"))
	track.tyre_origins = LooseTyres.positions(track.metadata.creator_document)
	var grouped := NativeTrackVisual.new(); grouped.theme_id = "winter"; grouped.colors = TrackTheme.palette("winter")
	var original := NativeTrackVisual.new(); original.theme_id = "winter"; original.colors = grouped.colors
	root.add_child(grouped); root.add_child(original)
	await original._build_placed_objects(track); await grouped.refresh_editor_objects(track,false)
	check(helper.same_triangles(helper.triangles(original),helper.triangles(grouped)),"Winter-available grouped kit preserves exact original geometry")
	var batches: RefCounted = grouped.editor_objects._editor_authored_batches
	batches.models.clear(); batches.model_bytes = 0; batches.shared_vertices.clear(); batches.shared_vertex_bytes = 0
	track.metadata.creator_document.objects[0].position[0] += 0.5
	await grouped.refresh_editor_objects(track,false)
	original.free(); original = NativeTrackVisual.new(); original.theme_id = "winter"; original.colors = grouped.colors; root.add_child(original)
	await original._build_placed_objects(track)
	check(helper.same_triangles(helper.triangles(original),helper.triangles(grouped)),"post-pressure grouped rebuild preserves exact geometry")
	grouped.queue_free(); original.queue_free(); await process_frame

func independent_commits() -> void:
	var queue = preload("res://editor/commit_queue.gd").new()
	var first := TrackLibrary.new("user://independent_analysis_a")
	var second := TrackLibrary.new("user://independent_analysis_b")
	var a: Dictionary = circuit(); a.name = "A1"
	var b: Dictionary = circuit(); b.name = "B1"
	queue.enqueue(first,a,""); queue.enqueue(second,b,"")
	a.name = "A2"; queue.enqueue(first,a,"")
	queue.flush()
	check(queue.completed.size() == 2,"analysis coalesces within a draft and preserves other libraries")
	check(queue.completed[0].storage == second and queue.completed[0].document.name == "B1" and queue.completed[1].document.name == "A2","coalesced analysis retains exact storage and latest source")

func residency() -> void:
	var world := EditorWorld.new(); root.add_child(world)
	world.visual = NativeTrackVisual.new(); world.world.add_child(world.visual)
	var mesh := BoxMesh.new()
	var first := MeshInstance3D.new(); first.mesh = mesh; world.visual.add_child(first)
	var stage := NativeTrackVisual.new(); stage.set_meta("editor_transient",true); world.visual.add_child(stage)
	var second := MeshInstance3D.new(); second.mesh = mesh; stage.add_child(second)
	var state: Dictionary = world.memory_snapshot()
	check(state.transient_unique_scene_bytes > 0 and state.active_unique_scene_bytes > 0,"residency separates active and nested replacement scenes")
	check(state.resources == 1 and state.unique_scene_bytes == state.active_unique_scene_bytes+state.transient_unique_scene_bytes+state.idle_unique_scene_bytes,"shared scene mesh is counted once across owners")
	world.queue_free(); await process_frame

func run() -> void:
	root.size = Vector2i(1280,720)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--editor-evidence=" ): out = arg.trim_prefix("--editor-evidence=")
	await history_and_navigation(); geometry(); independent_commits(); await grouped_winter(); await residency(); await application()
	record("complete",{"checks":checks,"failures":failures,"static_bytes":OS.get_static_memory_usage()})
	GameSoundtrack.instance().queue_free()
	for i: int in range(3): await process_frame
	# AudioServer retires stopped decoder playbacks on its own mixing thread.
	# Let that thread quiesce before the SceneTree itself shuts down.
	await create_timer(0.25).timeout
	print("EDITOR_T05_T11_TESTS: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
