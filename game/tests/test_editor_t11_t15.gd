extends SceneTree
const SESSION = preload("res://editor/editor_session.gd")
const GESTURE = preload("res://editor/editor_gesture.gd")
const CATALOG = preload("res://editor/road_piece_catalog.gd")
var checks: int = 0
var failures: int = 0
var observations: Array = []
var evidence: String = ""

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func session_state() -> void:
	var session = SESSION.new()
	var document: Dictionary = TrackDocument.create_blank()
	var storage := TrackLibrary.new("user://editor_t11_t15/session")
	var other := TrackLibrary.new("user://editor_t11_t15/other")
	session.remember(document)
	document.name = "A"
	session.begin_gesture(document)
	document.name = "B"
	session.cancel_gesture()
	check(session.undo.size() == 1 and session.redo.is_empty(),"cancelled gesture restores both history stacks")
	document = session.restore(document,true)
	check(document.name == "My circuit" and session.redo.size() == 1,"session undo restores independent original document")
	document = session.restore(document,false)
	check(document.name == "B" and session.undo.size() == 1,"session redo restores the complete revision")
	session.enqueue(storage,document,"")
	session.commits.flush()
	var first: Dictionary = session.commits.completed.pop_front()
	check(session.accept(first,storage,document),"matching derived revision is accepted")
	check(session.derived_revision == session.revision and session.validated == first.document,"validation ownership follows accepted revision")
	session.enqueue(storage,document,"")
	check(not session.accept(first,storage,document),"identical document from an older analysis cannot win an ABA revision")
	session.commits.flush()
	var latest: Dictionary = session.commits.completed.pop_front()
	check(not session.accept(latest,other,document),"derived state cannot cross library ownership")
	document.name = "In progress"
	check(not session.accept(latest,storage,document),"uncommitted pointer edit fences a finished analysis")
	document = latest.source.duplicate(true)
	check(session.accept(latest,storage,document),"restored matching revision can own derived state")
	var copy: Dictionary = session.validated.duplicate(true)
	document.points[0][0] += 1.0
	check(session.validated == copy,"live document cannot mutate retained validation snapshot")

func gestures() -> void:
	for mode: String in GESTURE.DOMAINS:
		var gesture = GESTURE.new()
		var document: Dictionary = TrackDocument.create_blank()
		var original: Dictionary = document.duplicate(true)
		gesture.begin({"kind":"curve"},false)
		check(gesture.phase == GESTURE.Phase.POINTER and gesture.before.is_empty(),mode+" pointer begins without a document copy")
		gesture.capture(document,mode)
		check(gesture.phase == GESTURE.Phase.EDIT,mode+" first mutation enters editing")
		for key: String in GESTURE.DOMAINS[mode]:
			if document.has(key): document[key] = []
			else: document[key] = {"temporary":true}
		document.route_override = false
		check(gesture.rollback(document) and document == original,mode+" rollback restores its exact domains and absent fields")
		check(gesture.phase == GESTURE.Phase.NAVIGATION,mode+" pinch rollback becomes navigation")
		gesture.clear()
		check(gesture.phase == GESTURE.Phase.IDLE and gesture.ghost.is_empty() and gesture.before.is_empty(),mode+" interruption releases transaction state")
	var canvas := EditorCanvas.new(); canvas.document = TrackDocument.create_blank(); root.add_child(canvas)
	for kind: String in RoadPieces.KINDS:
		var piece: Dictionary = RoadPieces.create(kind,Vector2.ZERO)
		check(not CATALOG.title(kind).is_empty() and canvas.geometry_keys(piece) == CATALOG.handles(kind),kind+" palette and handles use the same descriptor")
		check(RoadPieces.validate(piece).is_empty(),kind+" descriptor defaults retain valid canonical geometry")
	canvas.queue_free()

func formats() -> void:
	var storage := TrackLibrary.new("user://editor_t11_t15/imports")
	DirAccess.make_dir_recursive_absolute(storage.directory)
	var path: String = storage.directory.path_join("incoming.json")
	var current: Dictionary = TrackDocument.create_blank()
	current.creator = "Current creator"
	for schema: String in ["creator-track-v1","creator-track-v2","creator-track-v3","creator-track-v4","creator-track-v6","surface-grid-v1"]:
		var document: Dictionary = current.duplicate(true); document.schema = schema
		var file := FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(document)); file.close()
		check(storage.import_document(path).is_empty() and storage.last_error.contains("creator-track-v5"),schema+" import fails explicitly without conversion")
		check(TrackCompiler.compile(document) == null and TrackCatalog.local_metadata(document).is_empty(),schema+" cannot enter compiler or catalogue")
		check(JSON.parse_string(FileAccess.get_file_as_string(path)).schema == schema,schema+" rejected file remains untouched")
	for bad_schema: Variant in [null,0,1.5,true,[],{}]:
		var malformed: Dictionary = {"schema":bad_schema}
		check(not TrackDocument.validate(malformed,false).is_empty(),"malformed schema fails without dynamic comparison errors")
		check(TrackCatalog.local_metadata(malformed).is_empty(),"malformed schema cannot enter catalogue")
		check(NativeTrack.from_data(malformed,"invalid") == null,"malformed native schema fails without indexing payload")
	var coast: Dictionary = current.duplicate(true); coast.theme = "coast"
	check(not TrackDocument.validate(coast,false).is_empty() and TrackCompiler.compile(coast) == null and TrackCatalog.local_metadata(coast).is_empty(),"retired coast alias is rejected throughout the import path")
	check(NativeTrack.from_data({"schema":"surface-grid-v1"},"unsupported") == null,"native v1 data has no compatibility reader")
	var file := FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(current)); file.close()
	var imported: Dictionary = storage.import_document(path)
	check(imported == JSON.parse_string(JSON.stringify(current)),"current v5 import roundtrips exactly")
	check(storage.export_document(imported,storage.directory.path_join("export.json")) == OK,"current format remains exportable")
	check(NativeTrack.read("res://resources/tracks/starter_circuit.json") != null,"current native v2 circuit remains readable")

func current_budget() -> void:
	var limits = preload("res://editor/creator_limits.gd")
	var objects: Array = []
	for i: int in range(49): objects.append({"kind":"container","position":[0.0,0.0],"rotation":0.0})
	check(objects.size() <= 96 and not limits.error(objects,"pine").is_empty(),"small scenes have no legacy memory-budget exemption")
	var document: Dictionary = TrackDocument.create_blank(); document.objects = objects
	check(not TrackDocument.validate(document,false).is_empty(),"imports and drafts enforce the uniform current geometry budget")
	check(limits.take(objects.slice(0,48),[objects[-1]],"pine").is_empty(),"placement cannot cross the same budget below the former quota")
	check(limits.error([objects[0]],"pine").is_empty(),"ordinary small current scenes remain admitted")

func model(kind: String, theme: String, length: float, color: String) -> ArrayMesh:
	return CreatorPropVisual.pine_meshes[TrackTheme.foliage(theme).to_html()+"/true"] if kind == "tree" else CreatorPropVisual.meshes[CreatorPropVisual._key(kind,theme,length,color)]

func prop_preparation() -> void:
	var count: int = 0; var worker_ms: float = 0.0; var publish_ms: float = 0.0
	var timings: Array = []
	for theme: String in ["pine","desert","winter","night_city"]:
		var kinds: Array[String] = ["tree","container","barrier","cliff","shed"]
		if theme == "winter": kinds.append_array(PropWinterCraft.KINDS)
		if theme == "desert": kinds.append_array(PropEgypt.KINDS)
		if theme == "night_city": kinds.append_array(PropNight.KINDS)
		for kind: String in kinds:
			CreatorPropVisual.trim_cache()
			var kit := NativeTrackVisual.new(); kit.theme_id = theme; kit.colors = TrackTheme.palette(theme)
			var color: String = ContainerPaint.DEFAULT
			var length: float = 7.5 if kind == "barrier" else -1.0
			var before: int = CreatorPropVisual.cache_bytes
			var thread := Thread.new()
			var began: int = Time.get_ticks_usec()
			check(thread.start(CreatorPropVisual.warm.bind(Callable(),kind,theme,length,color),Thread.PRIORITY_LOW) == OK,"CPU preparation starts "+theme+"/"+kind)
			while thread.is_alive(): await process_frame
			var packet: Dictionary = thread.wait_to_finish()
			worker_ms += (Time.get_ticks_usec()-began)/1000.0
			check(CreatorPropVisual.cache_bytes == before and CreatorPropVisual.meshes.is_empty() and CreatorPropVisual.pine_meshes.is_empty(),"worker cannot publish or mutate model caches "+theme+"/"+kind)
			if kind == "burning_car":
				check(packet.is_empty(),"encoded wreck reader remains on main installation path")
				kit.free(); continue
			began = Time.get_ticks_usec()
			check(CreatorPropVisual.publish_warm(packet),"main thread publishes "+theme+"/"+kind)
			var elapsed: float = (Time.get_ticks_usec()-began)/1000.0
			publish_ms += elapsed
			timings.append({"theme":theme,"kind":kind,"publication_ms":elapsed})
			var prepared: ArrayMesh = model(kind,theme,length,color)
			var arrays: Array = prepared.surface_get_arrays(0)
			var hidden: PackedInt32Array = prepared.get_meta("prop_hidden_triangles",PackedInt32Array())
			CreatorPropVisual.trim_cache()
			var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			if kind == "tree": CreatorPropVisual.pine(tool,kit,Vector3.ZERO,1.25,0.0,TrackTheme.foliage(theme))
			else: CreatorPropVisual.append(tool,kit,kind,Vector3.ZERO,1.0,0.0,length,color)
			var cold: ArrayMesh = model(kind,theme,length,color)
			check(cold.surface_get_arrays(0) == arrays,"worker/main preparation preserves every encoded stream "+theme+"/"+kind)
			check(cold.get_meta("prop_hidden_triangles",PackedInt32Array()) == hidden,"preparation preserves hidden-face ordinals "+theme+"/"+kind)
			kit.free(); count += 1
			await process_frame
	check(CreatorPropVisual.warm(func() -> bool: return true,"igloo","winter").is_empty(),"cancelled CPU preparation retains nothing")
	observations.append({"operation":"prop_preparation","models":count,"worker_wall_ms":worker_ms,"main_publication_ms":publish_ms,"cases":timings})

func generation_fences() -> void:
	CreatorPropVisual.trim_cache()
	var world := EditorWorld.new(); world.theme_id = "winter"; root.add_child(world)
	var canvas := EditorCanvas.new(); canvas.document = TrackDocument.create_blank(); root.add_child(canvas); world.canvas = canvas
	world.warm_prop("snow_castle")
	await process_frame
	world.warm_prop("cone")
	while world._prop_job != null or not world._prop_request.is_empty(): await process_frame
	check(not CreatorPropVisual.warmed("snow_castle","winter",-1.0,"") and CreatorPropVisual.warmed("cone","winter",-1.0,""),"superseded selection cannot upload stale prop geometry")
	CreatorPropVisual.trim_cache()
	canvas.active_pointer = 0
	world.warm_prop("igloo")
	await process_frame
	while world._prop_job != null and not world._prop_job.done: await process_frame
	check(not CreatorPropVisual.warmed("igloo","winter",-1.0,""),"completed CPU work cannot publish under an active finger")
	canvas.active_pointer = -99
	while world._prop_job != null: await process_frame
	check(CreatorPropVisual.warmed("igloo","winter",-1.0,""),"deferred publication resumes after gesture ends")
	CreatorPropVisual.trim_cache()
	world.warm_prop("snowman"); await process_frame
	world.theme_id = "pine"
	while world._prop_job != null or not world._prop_request.is_empty(): await process_frame
	check(not CreatorPropVisual.warmed("snowman","winter",-1.0,""),"biome change discards former biome CPU result")
	world.theme_id = "winter"
	canvas.active_pointer = 0
	world.warm_prop("snow_castle"); await process_frame
	var abandoned: RefCounted = world._prop_job
	root.remove_child(world)
	check(world._prop_job == null and abandoned.aborted,"detaching the retained editor releases optional job ownership")
	root.add_child(world)
	world.warm_prop("cone")
	canvas.active_pointer = -99
	while world._prop_job != null or not world._prop_request.is_empty(): await process_frame
	check(CreatorPropVisual.warmed("cone","winter",-1.0,""),"returning from a detached editor can warm a new selection")
	check(not CreatorPropVisual.warmed("snow_castle","winter",-1.0,""),"abandoned job cannot publish into the resumed editor")
	world.queue_free(); canvas.queue_free(); await process_frame

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--editor-evidence="): evidence = arg.trim_prefix("--editor-evidence=")
	session_state(); gestures(); formats(); current_budget()
	await prop_preparation(); await generation_fences()
	if not evidence.is_empty():
		var mode: String = "headless" if DisplayServer.get_name() == "headless" else RenderingServer.get_current_rendering_method()
		var file := FileAccess.open(evidence+"/results-"+mode+".json",FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"observations":observations},"\t")); file.close()
	print("EDITOR_T11_T15_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
