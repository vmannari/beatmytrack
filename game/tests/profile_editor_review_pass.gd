extends SceneTree
## Review diagnostics: record current behavior without changing runtime code.
const JOBS = preload("res://editor/work_job.gd")
const POPULATION_JOB = preload("res://editor/population_job.gd")
const CLOUD = preload("res://backend/cloud_tracks.gd")
var evidence: String
var observations: Dictionary = {}
var checks: int = 0
var failures: int = 0

class CountingCloud extends Node:
	var client: Node
	var reads: int = 0
	var existing_reads: int = 0
	func _read(path: String) -> Dictionary:
		reads += 1
		if FileAccess.file_exists(path): existing_reads += 1
		return CLOUD._read_file(path)

class TimedCancellation extends RefCounted:
	var deadline: int = 0
	var calls: int = 0
	func cancelled() -> bool:
		calls += 1
		return deadline > 0 and Time.get_ticks_usec() >= deadline

class TimedPopulation extends ObjectPopulation:
	var token: TimedCancellation
	func generate(_seed: int, _density: float, _reach: float) -> Array:
		# Model cancellation arriving just after the generation guard, while
		# the actual compiler is running. Other population work is excluded.
		token.deadline = Time.get_ticks_usec()+1000
		return [{"kind":"tree","position":[90.0,90.0],"rotation":0.0}]

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",message)

func record(key: String, value: Variant) -> void:
	observations[key] = value
	print("EDITOR_REVIEW ",key," ",JSON.stringify(value))

func circuit() -> Dictionary:
	var doc: Dictionary = TrackDocument.create_blank(); doc.id = "review"; doc.name = "Editor review"
	var position := Vector2(-47,-36); var heading: float = 0
	for side: int in range(2):
		for index: int in range(47):
			var piece: Dictionary = RoadPieces.create("straight",position,heading,6); piece.length = 2
			doc.pieces.append(piece); position = RoadPieces.end_pose(piece).position
		var turn: Dictionary = RoadPieces.create("hairpin",position,heading,6); turn.radius = 36; doc.pieces.append(turn)
		var pose: Dictionary = RoadPieces.end_pose(turn); position = pose.position; heading = pose.heading
	return RoadPieces.route_from_pieces(doc).document

func maximum_paint() -> Dictionary:
	var doc: Dictionary = circuit()
	for stroke_index: int in range(32):
		var points: Array = []
		for index: int in range(512): points.append([-100.0+index*0.39,-100.0+stroke_index*6.0])
		doc.paint.append({"surface":2,"width":2.0,"shape":"round","points":points})
	return JSON.parse_string(JSON.stringify(doc))

func stale_autosave() -> void:
	var app: Node = load("res://core/app.tscn").instantiate()
	var storage := TrackLibrary.new(evidence+"/app_drafts")
	app.library = storage; app.records = LocalRecords.new(evidence+"/records.json"); app.cloud_root_override = evidence+"/cloud"
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app.document = TrackDocument.create_default(); app.document.id = "save_order"; app.document.name = "Save ordering"
	app.document.objects = [{"kind":"container","position":[0.0,0.0],"rotation":0.0}]
	app.canvas = null; app._show_screen("create")
	var deadline: int = Time.get_ticks_msec()+30000
	while (app.editor_preview_thread != null or app.editor_world._building) and Time.get_ticks_msec()<deadline: await process_frame
	check(app.editor_preview_thread == null and not app.editor_world._building,"initial editor settles")
	check(app._save_track_now(),"baseline original and WIP are durable")
	var baseline: Dictionary = app.document.duplicate(true)
	for window: Node in app.find_children("*","Window",true,false):
		if window is Window: window.hide(); window.queue_free()
	# Two rapid finished gestures: first move away, then return to the saved
	# position before the low-priority writer starts. No frame is advanced.
	app.canvas.active_pointer = 0; app.document.objects[0].position = [2.0,0.0]
	check(app._save_draft(true) == OK,"changed gesture enqueues")
	check(app.editor_writes.pending.size() == 1,"first revision remains queued")
	app.document.objects[0].position = [0.0,0.0]
	check(app._save_draft(true) == OK,"return gesture accepted")
	var queued_after_return: int = app.editor_writes.pending.size()
	app.canvas.active_pointer = -99
	var unsaved: bool = app._editor_has_unsaved_changes()
	var status: String = app.editor_save_button.text
	app._request_editor_exit()
	var on_disk: Dictionary = storage.load_wip("save_order")
	var entries: Array[Dictionary] = storage.editable_entries()
	record("autosave_return_to_saved",{"current_position":baseline.objects[0].position,"queued_after_return":queued_after_return,
		"unsaved_before_exit":unsaved,"save_status":status,"screen_after_exit":app.screen,"wip_position":on_disk.objects[0].position,
		"reopened_position":entries[0].document.objects[0].position,"save_error":app.editor_save_error})
	check(app.screen == "tracks","exit proceeds through the actual UI path")
	app.queue_free(); await process_frame

func population_cancellation() -> void:
	var doc: Dictionary = circuit(); doc.theme = "winter"
	var token := TimedCancellation.new()
	var population := TimedPopulation.new(); population.token = token
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = POPULATION_JOB.run(token.cancelled,doc,null,population,27,0.65,22)
	var elapsed: float = (Time.get_ticks_usec()-started)/1000.0
	check(result.is_empty() and token.cancelled(),"expired population result is discarded")
	record("population_cancel_during_compile",{"ms":elapsed,"guard_calls":token.calls-1,"cancel_due_ms":1.0})
	var compiler_token := TimedCancellation.new(); compiler_token.deadline = Time.get_ticks_usec()+1000
	started = Time.get_ticks_usec()
	var compiled: NativeTrack = TrackCompiler.compile(doc,{},compiler_token.cancelled)
	record("compiler_with_cancellation",{"ms":(Time.get_ticks_usec()-started)/1000.0,"guard_calls":compiler_token.calls,"returned_null":compiled == null})
	check(compiled == null,"compiler itself supports prompt cancellation")

func draft_detail() -> void:
	var doc: Dictionary = maximum_paint()
	var storage := TrackLibrary.new(evidence+"/gallery")
	check(storage.save_document(doc) == OK,"large draft is valid and durable")
	var cloud := CountingCloud.new(); cloud.client = preload("res://backend/backend_client.gd").new()
	var lifecycle := TrackLifecycle.new(); lifecycle.cloud = cloud; lifecycle.library = storage
	var path: String = lifecycle._path(doc)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var job: Dictionary = {"schema":"track-lifecycle-1","scope":lifecycle.scope(),"library_directory":storage.directory,
		"fingerprint":TrackLibrary.draft_fingerprint(doc),"upload_key":"review","publish_key":"review","ticket_key":"review",
		"state":"local_ready","created_at":0,"document":doc,"proof_file":"review-only-no-proof"}
	var file := FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(job)); file.close()
	var browser: Control = preload("res://ui/draft_browser.gd").new(); browser.library = storage; browser.lifecycle = lifecycle
	root.add_child(browser)
	var deadline: int = Time.get_ticks_msec()+30000
	while browser.scanning and Time.get_ticks_msec()<deadline: await process_frame
	check(not browser.scanning and browser.entries.size() == 1,"large draft scan settles")
	var samples: Array = []
	for index: int in range(5):
		cloud.reads = 0; cloud.existing_reads = 0
		var started: int = Time.get_ticks_usec(); browser._show_detail()
		samples.append({"ms":(Time.get_ticks_usec()-started)/1000.0,"workflow_reads":cloud.reads,"existing_workflow_reads":cloud.existing_reads})
		check(cloud.existing_reads > 0,"detail uses the actual saved workflow")
		await process_frame
	record("warm_selected_draft_detail",{"paint_points":16384,"workflow_bytes":FileAccess.get_file_as_bytes(path).size(),"samples":samples})
	browser.queue_free(); await process_frame
	lifecycle.free(); cloud.client.free(); cloud.free()

func prop_readbacks() -> void:
	var kit := NativeTrackVisual.new(); kit.colors = TrackTheme.palette("pine"); kit._capture_editor_prop_arrays = true
	var track := NativeTrack.new(); track.metadata = {"creator_document":{"objects":[{"kind":"container","position":[0.0,0.0],"rotation":0.0}]}}
	kit._build_placed_objects(track)
	var child: MeshInstance3D
	for candidate: Node in kit.get_children():
		if candidate is MeshInstance3D and candidate.has_meta("editor_prop_arrays"): child = candidate; break
	check(child != null,"actual prop retains pre-upload CPU arrays")
	if child == null: kit.free(); return
	var samples: Array = []
	for sample: int in range(5):
		var started: int = Time.get_ticks_usec()
		for index: int in range(96):
			var arrays: Array = child.get_meta("editor_prop_arrays",child.mesh.surface_get_arrays(0))
			check(not arrays.is_empty(),"eager arrays available")
		var eager: float = (Time.get_ticks_usec()-started)/1000.0
		started = Time.get_ticks_usec()
		for index: int in range(96):
			var arrays: Array = child.get_meta("editor_prop_arrays")
			check(not arrays.is_empty(),"retained arrays available")
		samples.append({"eager_ms":eager,"retained_ms":(Time.get_ticks_usec()-started)/1000.0})
	record("prop_eager_readbacks",{"vertices":child.mesh.surface_get_array_len(0),"accesses_per_sample":96,"samples":samples})
	kit.free()

func run() -> void:
	root.size = Vector2i(1280,720)
	evidence = ProjectSettings.globalize_path("res://../build/editor-review-pass-2026-10-14/")+RenderingServer.get_current_rendering_method()+"-"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(evidence)
	await stale_autosave(); population_cancellation(); await draft_detail(); prop_readbacks()
	var result: Dictionary = {"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"observations":observations}
	var file := FileAccess.open(evidence+"/results.json",FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close()
	print("EDITOR_REVIEW_PASS: %d checks, %d probe failures; evidence=%s" % [checks,failures,evidence])
	quit(1 if failures else 0)
