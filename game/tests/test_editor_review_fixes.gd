extends SceneTree
const WRITES = preload("res://editor/write_queue.gd")
const POPULATION_JOB = preload("res://editor/population_job.gd")
const BATCHES = preload("res://editor/placed_object_batches.gd")
const CLOUD = preload("res://backend/cloud_tracks.gd")
const BEFORE_BROWSER = preload("res://tests/fixtures/editor_draft_browser_before_review_fixes.gd")
var evidence: String
var observations: Dictionary = {}
var checks: int = 0
var failures: int = 0

class CountedLibrary extends TrackLibrary:
	var full_reads: int = 0
	func load_document(id: String, summary: bool = false) -> Dictionary:
		if not summary: full_reads += 1
		return super.load_document(id,summary)
	func load_wip(id: String) -> Dictionary:
		full_reads += 1
		return super.load_wip(id)

class CountingCloud extends Node:
	var client: Node
	var reads: int = 0
	func _read(path: String) -> Dictionary:
		reads += 1
		return CLOUD._read_file(path)

class RecordingLifecycle extends TrackLifecycle:
	var retried: Dictionary = {}
	func retry(doc: Dictionary) -> void: retried = doc.duplicate(true)

class Cancellation extends RefCounted:
	var calls: int = 0
	var stop_at: int = 4
	func cancelled() -> bool:
		calls += 1
		return calls >= stop_at

class FixedPopulation extends ObjectPopulation:
	func generate(_seed: int, _density: float, _reach: float) -> Array:
		return [{"kind":"tree","position":[90.0,90.0],"rotation":0.0}]

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",message)
func record(key: String, value: Variant) -> void:
	observations[key] = value; print("EDITOR_REVIEW_FIX ",key," ",JSON.stringify(value))

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

static func held_write(entry: Dictionary, started: Semaphore, release: Semaphore, block_next: bool) -> Dictionary:
	started.post(); release.wait()
	var receipt: Dictionary = WRITES.write(entry)
	if block_next: DirAccess.make_dir_recursive_absolute(entry.directory+"/wip/"+str(entry.document.id)+".json.tmp")
	return receipt

func close_notices(app: Node) -> void:
	for window: Node in app.find_children("*","Window",true,false):
		if window is Window: window.hide(); window.queue_free()

func autosaves() -> void:
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
	close_notices(app)
	for scenario: String in ["queued","active","failed_final"]:
		if app.screen != "create": app._show_screen("create")
		app.canvas.active_pointer = 0; app.document.objects[0].position = [2.0,0.0]
		check(app._save_draft(true) == OK,scenario+" move queues")
		var release := Semaphore.new()
		if scenario != "queued":
			var started := Semaphore.new()
			app.editor_writes.active = app.editor_writes.pending.pop_front()
			app.editor_writes.thread = Thread.new()
			check(app.editor_writes.thread.start(held_write.bind(app.editor_writes.active,started,release,scenario == "failed_final"),Thread.PRIORITY_LOW) == OK,"controlled real write starts")
			started.wait()
		app.document.objects[0].position = [0.0,0.0]
		check(app._save_draft(true) == OK,scenario+" return queues desired final state")
		check(app.editor_writes.pending.size() == 1 and app.editor_writes.pending[0].document.objects[0].position == [0.0,0.0],scenario+" obsolete queued state is superseded")
		app.canvas.active_pointer = -99
		if scenario != "queued": release.post()
		app._request_editor_exit()
		if scenario == "failed_final":
			check(app.screen == "create" and app.editor_save_error != OK,"failed final write prevents silently acknowledged exit")
			check(app.root_ui.find_child("SaveChangesDialog",true,false) != null,"failure retains the Save/Discard decision")
			check(storage.load_wip("save_order").objects[0].position == [2.0,0.0],"fixture really leaves the older WIP when final write fails")
			check(DirAccess.remove_absolute(storage.directory+"/wip/save_order.json.tmp") == OK,"remove only the empty fixture obstruction")
			close_notices(app)
			check(app._save_track_now(),"explicit retry commits the desired final state")
			close_notices(app); app._request_editor_exit()
		check(app.screen == "tracks" and app.editor_save_error == OK,scenario+" successful exit")
		check(storage.load_wip("save_order").objects[0].position == [0.0,0.0],scenario+" final WIP matches the returned position")
		check(storage.load_document("save_order").objects[0].position == [0.0,0.0],scenario+" original preserved")
		check(storage.editable_entries()[0].document.objects[0].position == [0.0,0.0],scenario+" reopening selects the correct final state")
		check(not app.editor_writes.unsettled(storage,"save_order"),scenario+" no writes remain")
		await process_frame
	record("autosaves",{"queued_return":true,"active_return":true,"failed_final_retry":true})
	app.queue_free(); await process_frame

func cancellation() -> void:
	var doc: Dictionary = circuit(); doc.theme = "winter"
	var population := FixedPopulation.new()
	var token := Cancellation.new()
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = POPULATION_JOB.run(token.cancelled,doc,null,population,27,0.65,22)
	record("cancel_inside_compiler",{"ms":(Time.get_ticks_usec()-started)/1000.0,"guard_calls":token.calls})
	check(result.is_empty() and token.calls >= 4,"cancellation reaches the actual compiler, rather than only discarding its completed result")
	check(not population.cancelled.is_valid(),"compiled cancellation releases the retained callback")
	for stop_at: int in [1,2]:
		token = Cancellation.new(); token.stop_at = stop_at
		result = POPULATION_JOB.run(token.cancelled,doc,null,population,27,0.65,22)
		check(result.is_empty() and not population.cancelled.is_valid(),"early population cancellation also releases the callback")
	var mask := PackedInt32Array(); mask.resize(110*110); mask.fill(1); mask[0] = 0
	token = Cancellation.new(); token.stop_at = 8
	check(ObjectPopulation._distance_field(mask,Vector2i(110,110),token.cancelled).is_empty(),"distance preparation stops without publishing a partial field")

func await_scan(browser: Control) -> void:
	var deadline: int = Time.get_ticks_msec()+30000
	while browser.scanning and Time.get_ticks_msec()<deadline: await process_frame
	check(not browser.scanning,"draft scan settles")

func write_job(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(value)); file.close()

func button_with_text(browser: Control, text: String) -> Button:
	for node: Node in browser.find_children("*","Button",true,false):
		if node.text == text: return node
	return null

func gallery() -> void:
	var doc: Dictionary = maximum_paint()
	var storage := CountedLibrary.new(evidence+"/gallery")
	check(storage.save_document(doc) == OK,"maximum painted draft persists")
	var cloud := CountingCloud.new(); cloud.client = preload("res://backend/backend_client.gd").new()
	var lifecycle := RecordingLifecycle.new(); lifecycle.cloud = cloud; lifecycle.library = storage
	var path: String = lifecycle._path(doc); DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var job: Dictionary = {"schema":"track-lifecycle-1","scope":lifecycle.scope(),"library_directory":storage.directory,
		"fingerprint":TrackLibrary.draft_fingerprint(doc),"upload_key":"review","publish_key":"review","ticket_key":"review",
		"state":"local_ready","created_at":0,"document":doc,"proof_file":"review-only-no-proof"}
	write_job(path,job)
	var pixel_reference: Image
	for version: String in ["before","after"]:
		var browser: Control = BEFORE_BROWSER.new() if version == "before" else preload("res://ui/draft_browser.gd").new()
		browser.library = storage; browser.lifecycle = lifecycle; root.add_child(browser)
		browser.position = Vector2(20,30); browser.size = Vector2(1240,650)
		await await_scan(browser)
		check(browser.entries.size() == 1,"selected map retained")
		var samples: Array = []
		for index: int in range(5):
			cloud.reads = 0; storage.full_reads = 0
			var started: int = Time.get_ticks_usec(); browser._show_detail()
			samples.append({"ms":(Time.get_ticks_usec()-started)/1000.0,"workflow_reads":cloud.reads,"full_document_reads":storage.full_reads})
			if version == "after": check(cloud.reads == 0 and storage.full_reads == 0,"warm detail performs no main-thread file reads")
			await process_frame
		record("draft_detail_"+version,samples)
		if DisplayServer.get_name() != "headless":
			# Keep the same pointer state on both captures; desktop focus changes
			# otherwise leave Back hovered in only one of the two fresh controls.
			var motion := InputEventMouseMotion.new(); motion.position = Vector2(640,700); motion.global_position = motion.position
			root.push_input(motion)
			await process_frame
			await RenderingServer.frame_post_draw
			var pixels: Image = root.get_texture().get_image(); pixels.save_png(evidence+"/draft-"+version+".png")
			if version == "before": pixel_reference = pixels
			else: check(pixels.get_data() == pixel_reference.get_data(),"summary detail retains exact original rendered pixels")
		if version == "after":
			check(not browser.find_child("PublishDraft",true,false).disabled,"background status retains exact ready proof availability")
			check(not browser.selection.document.has("paint") and not browser.selection.lifecycle.has("document"),"retained detail holds summaries, not full map or workflow")
			job["publish_requested"] = true; job["state"] = "failed"; job["failure"] = "REVISION_CONFLICT"; job["publication_id"] = "review"; job["remote"] = {"retryable":true}
			write_job(path,job); lifecycle.changed.emit()
			check(browser.find_child("PublishDraft",true,false).disabled,"changed workflow disables stale publication while rescanning")
			await await_scan(browser)
			check(browser.find_child("PublishDraft",true,false).disabled,"refreshed workflow retains publication gate")
			check(button_with_text(browser,"Retry") != null and button_with_text(browser,"Save as new track") != null,"retry/conflict actions reflect the new workflow")
			storage.full_reads = 0
			button_with_text(browser,"Retry").pressed.emit()
			check(storage.full_reads == 1 and lifecycle.retried.paint == doc.paint,"Retry lazily loads the complete latest map")
			var forked: Array = []; browser.fork_requested.connect(func(value: Dictionary) -> void: forked.append(value))
			button_with_text(browser,"Save as new track").pressed.emit()
			check(forked.size() == 1 and forked[0].paint == doc.paint,"Fork lazily retains every authored paint point")
			var revised: Dictionary = doc.duplicate(true); revised.name = "New local revision"
			check(storage.save_document(revised) == OK,"selected document changes in the same library")
			browser._process(0); check(browser.find_child("PublishDraft",true,false).disabled,"automatic revision rescan disables old proof immediately")
			await await_scan(browser)
			check(browser.selection.document.name == revised.name and browser.selection.lifecycle.caption == "Saved on this device","library revision refreshes summary and exact current workflow")
		browser.queue_free(); await process_frame
	lifecycle.free(); cloud.client.free(); cloud.free()

func prop_arrays() -> void:
	var retained: Array = [Vector3.ONE]
	var metadata_only := MeshInstance3D.new(); metadata_only.set_meta("editor_prop_arrays",retained)
	check(BATCHES._baked_arrays(metadata_only) == retained,"retained path works without any uploaded mesh to read back")
	metadata_only.free()
	var kit := NativeTrackVisual.new(); kit.colors = TrackTheme.palette("pine"); kit._capture_editor_prop_arrays = true
	var track := NativeTrack.new(); track.metadata = {"creator_document":{"objects":[{"kind":"container","position":[0.0,0.0],"rotation":0.0}]}}
	kit._build_placed_objects(track)
	var child: MeshInstance3D
	for candidate: Node in kit.get_children():
		if candidate is MeshInstance3D and candidate.has_meta("editor_prop_arrays"): child = candidate; break
	check(child != null,"actual container retains original CPU attributes")
	if child == null: kit.free(); return
	check(BATCHES._baked_arrays(child) == child.get_meta("editor_prop_arrays"),"actual pre-upload attributes preserved exactly")
	var fallback := MeshInstance3D.new(); fallback.mesh = child.mesh
	check(BATCHES._baked_arrays(fallback) == child.mesh.surface_get_arrays(0),"legacy unretained meshes preserve the original fallback")
	fallback.free()
	var samples: Array = []
	for sample: int in range(5):
		var arrays: Array
		var started: int = Time.get_ticks_usec()
		for index: int in range(96): arrays = child.get_meta("editor_prop_arrays",child.mesh.surface_get_arrays(0))
		var before: float = (Time.get_ticks_usec()-started)/1000.0
		started = Time.get_ticks_usec()
		for index: int in range(96): arrays = BATCHES._baked_arrays(child)
		samples.append({"before_ms":before,"after_ms":(Time.get_ticks_usec()-started)/1000.0})
		check(arrays == child.get_meta("editor_prop_arrays"),"measured access retains exact attributes")
	record("prop_array_access_96",samples)
	kit.free()

func run() -> void:
	root.size = Vector2i(1280,720)
	evidence = ProjectSettings.globalize_path("res://../build/editor-review-fixes-2026-10-14/")+RenderingServer.get_current_rendering_method()+"-"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(evidence)
	await autosaves(); cancellation(); await gallery(); prop_arrays()
	var file := FileAccess.open(evidence+"/results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"observations":observations},"\t")); file.close()
	print("EDITOR_REVIEW_FIXES: %d checks, %d failures; evidence=%s" % [checks,failures,evidence]); quit(1 if failures else 0)
