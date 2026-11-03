extends SceneTree
const DISK = preload("res://track/road_mesh_disk_cache.gd")
const ROADS = preload("res://editor/road_preparation.gd")
const SELECTED = preload("res://race/selected_track_preparation.gd")
const CLOUD = preload("res://backend/cloud_tracks.gd")
var checks: int = 0
var failures: int = 0
var folder: String
var app: Node
var browser: TrackBrowser
var race_done: bool = false

class DeferredDocumentClient extends "res://backend/backend_client.gd":
	var calls: int = 0
	var body: String
	func _ready() -> void: pass
	func request_api(_path: String, _method: HTTPClient.Method = HTTPClient.METHOD_GET, _payload: Dictionary = {}, _key: String = "", _authenticated: bool = false) -> Dictionary:
		calls += 1
		await get_tree().create_timer(0.15).timeout
		return {"ok":true,"body":body,"data":JSON.parse_string(body)}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func write(path: String, value: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE); file.store_string(value); file.close()

func cache_contract() -> void:
	DISK.directory = folder.path_join("cache-contract")
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point: Vector3 in [Vector3.ZERO,Vector3(0,0,2),Vector3(2,0,0)]: tool.set_normal(Vector3.UP); tool.add_vertex(point)
	var arrays: Array = tool.commit_to_arrays()
	var packet: Dictionary = {"key":"geometry-fixture","parts":[{"role":"road","arrays":arrays,"arguments":[Color.WHITE,Vector2(8,8),false,false,false,true,false,false]}],"metadata":{}}
	var key: Array = ["content-fixture",NativeTrackVisual.VERSION]
	var receipt: Dictionary = DISK.stage_arrays(key,packet,Callable())
	check(not receipt.is_empty(),"CPU geometry stages in local storage")
	check(DISK.read_arrays(key,packet.key).is_empty(),"unpublished worker output cannot become a cache hit")
	check(DISK.publish_arrays(receipt),"current selection publishes completed arrays")
	check(DISK.read_arrays(key,packet.key) == packet,"local CPU geometry round trips exact typed arrays")
	check(DISK.read_arrays(key,"changed-geometry").is_empty(),"geometry revision rejects incompatible arrays")
	check(DISK.read_arrays(["changed-content",NativeTrackVisual.VERSION],packet.key).is_empty(),"content revision rejects incompatible arrays")
	var file_path: String = DISK.directory.path_join(DISK.identity(key)+".arrays")
	write(file_path,"corrupt")
	check(DISK.read_arrays(key,packet.key).is_empty(),"checksum rejects corrupt local geometry")
	receipt = DISK.stage_arrays(key,packet,Callable())
	DISK.discard_arrays(receipt)
	check(not FileAccess.file_exists(str(receipt.path)),"cancelled preparation discards its private staging file")
	check(DISK.stage_arrays(key,packet,func() -> bool: return true).is_empty(),"cancelled preparation cannot stage geometry")
	for i: int in range(11):
		receipt = DISK.stage_arrays(["bounded",i],packet,Callable())
		check(DISK.publish_arrays(receipt),"bounded CPU artifact publishes")
	var directory := DirAccess.open(DISK.directory)
	var count: int = 0; var bytes: int = 0
	for name: String in directory.get_files():
		if not DISK._artifact_filename(name): continue
		count += 1
		var file := FileAccess.open(DISK.directory.path_join(name),FileAccess.READ); bytes += file.get_length(); file.close()
	check(count <= DISK.MAX_FILES and bytes <= DISK.MAX_TOTAL_BYTES,"CPU artifacts share the existing disk count and byte budgets")
	check(DISK._artifact_filename("a".repeat(64)+".res") and DISK._artifact_filename("a".repeat(64)+".arrays"),"both local artifact representations participate in pruning")

func settle_view() -> void:
	if browser._view_motion != null: browser._view_motion.kill(); browser._finish_view_transition()
	if browser._section_motion != null: browser._section_motion.kill(); browser._section_motion = null
	browser._poll_preparation_hint()
	browser._preparation_since = Time.get_ticks_msec()-TrackBrowser.PREPARATION_SETTLE_MS-1
	browser._poll_preparation_hint()

func finish_race(track: NativeTrack) -> void:
	await app._start_race(track,false,true)
	race_done = true

func cancellation(entry: Dictionary, kind: String) -> void:
	app._show_screen("tracks")
	await process_frame
	browser = app.content.find_child("TrackBrowser",true,false)
	browser._set_list_open(false,false)
	var candidate: NativeTrack = CLOUD.metadata_track(entry)
	browser.selected_track = candidate; app.selected_track = candidate
	app._prepare_selected_track(candidate,browser)
	var job: RefCounted = app._selected_preparation_job
	check(app._selected_preparation_pending,kind+" starts selected preparation")
	match kind:
		"close": browser._close_track_view()
		"car": VehicleCatalog.selected = "kart"
		"selection": app.selected_track = NativeTrack.new()
		"version": candidate.metadata.cloud_version = "different-version"
		"content": candidate.content_hash = "changed-content"
		"scope": app._selected_preparation_scope += "/changed"
		"navigation": app._show_screen("garage")
	app._poll_selected_preparation()
	check(not app._selected_preparation_pending and app._selected_preparation_job == null,kind+" cancels preparation")
	if job != null:
		var deadline: int = Time.get_ticks_msec()+30000
		while not job.done and Time.get_ticks_msec()<deadline: await process_frame
		SELECTED.reap_discarded()
		check(job.done and job.result == null,kind+" reaps cancelled worker output")
	VehicleCatalog.selected = "compact"

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	folder = ProjectSettings.globalize_path("res://../build/device-track-loading/selection-"+TrackLibrary.unique_id())
	DirAccess.make_dir_recursive_absolute(folder)
	cache_contract()
	DISK.directory = folder.path_join("roads")
	app = before_app()
	app.library = TrackLibrary.new(folder.path_join("tracks")); app.records = LocalRecords.new(folder.path_join("records.json")); app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._show_screen("tracks")
	await process_frame
	browser = app.content.find_child("TrackBrowser",true,false)
	check(browser != null,"actual Free Race browser is available")
	if browser == null: app.free(); quit(1); return
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../backend/tests/fixtures/verified_oval.json"))
	document = document.get("document",document)
	document.theme = "desert"
	var body: String = JSON.stringify(document)
	var path: String = folder.path_join("document.json"); write(path,body)
	var entry: Dictionary = {"source":"cloud","cache_path":path,"content_hash":body.sha256_text(),"id":"cloud_device_fixture","name":"Device loading fixture","version_id":"device-v1","track_id":"device-track","creator":"Fixture","theme":"desert","points":document.points}
	var selected: NativeTrack = CLOUD.metadata_track(entry)
	app.selected_track = selected; browser.selected_track = selected
	browser._poll_preparation_hint()
	check(not app._selected_preparation_pending,"full track list starts no geometry work")
	browser._set_list_open(false,false)
	browser._poll_preparation_hint()
	check(not app._selected_preparation_pending,"detail view waits for its settle interval")
	settle_view()
	check(app._selected_preparation_pending,"settled selected detail starts CPU preparation")
	var original_job: RefCounted = app._selected_preparation_job
	check(original_job != null,"selected cached document enters the real tree-owned worker")
	# Race during preparation must consume that job, rather than launch a build
	# for the same selected track beside it.
	finish_race(selected)
	var frames: int = 0
	var deadline: int = Time.get_ticks_msec()+60000
	while not race_done and Time.get_ticks_msec()<deadline:
		await process_frame; frames += 1
	check(race_done and app.game != null,"race starts after selected preparation handoff")
	check(frames > 2,"selected preparation and handoff permit process frames")
	check(not selected.metadata.get("metadata_only",false) and app.selected_track == selected,"preparation hydrates the selected object without replacing its identity")
	check(app.track_catalog.cached_track(entry) == selected,"compiled selection enters the bounded catalog")
	if app.game != null:
		app.game.set_physics_process(false)
		check(app.game.sim.state.tick == 0 and app.game.countdown_ticks == 360 and app.game.track_session.target_laps == 5,"handoff retains tick zero, full countdown and five laps")
		var road_path: String = DISK.directory.path_join(DISK.identity(ROADS.disk_key_for(selected)))
		check(FileAccess.file_exists(road_path+".res") and not FileAccess.file_exists(road_path+".arrays"),"installed road artifact supersedes its CPU staging representation")
		app._leave_race()
	for kind: String in ["close","car","selection","version","content","scope","navigation"]: await cancellation(entry,kind)
	# Delayed document response exercises the real downloader's scope fence.
	app._show_screen("tracks"); await process_frame
	browser = app.content.find_child("TrackBrowser",true,false)
	browser._set_list_open(false,false)
	var previous_client: Node = app.cloud.client
	var delayed := DeferredDocumentClient.new(); delayed.body = body; root.add_child(delayed)
	app.cloud.client = delayed
	var uncached: Dictionary = entry.duplicate(true); uncached.cache_path = folder.path_join("not-downloaded.json"); uncached.version_id = "delayed-version"
	selected = CLOUD.metadata_track(uncached); app.selected_track = selected; browser.selected_track = selected
	app._prepare_selected_track(selected,browser)
	check(app._selected_preparation_pending and delayed.calls == 1,"settled uncached selection requests its document once")
	browser._close_track_view(); app._poll_selected_preparation()
	await create_timer(0.25).timeout
	check(not FileAccess.file_exists(uncached.cache_path),"obsolete document response cannot write its cache file")
	check(not app._selected_preparation_pending and app._selected_preparation_job == null,"obsolete document response cannot launch CPU preparation")
	app.cloud.client = previous_client; delayed.free()
	app._show_screen("tracks"); await process_frame
	browser = app.content.find_child("TrackBrowser",true,false)
	browser._set_list_open(false,false)
	selected = CLOUD.metadata_track(entry); app.selected_track = selected; browser.selected_track = selected
	app._prepare_selected_track(selected,browser)
	# Keep the transport alive beyond its owning UI to check delayed teardown.
	app._cancel_selected_preparation()
	var teardown_client := DeferredDocumentClient.new(); teardown_client.body = body; root.add_child(teardown_client)
	app.cloud.client = teardown_client
	var teardown_entry: Dictionary = entry.duplicate(true); teardown_entry.cache_path = folder.path_join("teardown-document.json"); teardown_entry.version_id = "teardown-version"
	selected = CLOUD.metadata_track(teardown_entry); app.selected_track = selected; browser.selected_track = selected
	app._prepare_selected_track(selected,browser)
	app.free(); app = null
	await create_timer(0.25).timeout
	check(not FileAccess.file_exists(teardown_entry.cache_path),"delayed teardown response cannot publish player files")
	teardown_client.free()
	var finish_deadline: int = Time.get_ticks_msec()+30000
	while not preload("res://editor/work_job.gd").pending.is_empty() and Time.get_ticks_msec()<finish_deadline: await process_frame
	SELECTED.reap_discarded()
	check(preload("res://editor/work_job.gd").pending.is_empty() and SELECTED.discarded.is_empty(),"teardown cancels/reaps preparation without retaining its UI")
	var file := FileAccess.open(folder.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"loading_frames":frames},"\t")); file.close()
	print("DEVICE_RACE_PREPARATION: ",checks," checks, ",failures," failures; frames=",frames," report=",folder.path_join("report.json"))
	quit(1 if failures else 0)

func before_app() -> Node:
	var source: String = FileAccess.get_file_as_string("res://core/app.gd")
	source = source.replace('const SELECTED_PREPARATION = preload("res://race/selected_track_preparation.gd")','const SELECTED_PREPARATION = preload("res://../docs/evidence/race-loading-implementation-2026-11-02/before/game/race/selected_track_preparation.gd")')
	var script := GDScript.new()
	script.source_code = source
	assert(script.reload() == OK)
	return script.new()
