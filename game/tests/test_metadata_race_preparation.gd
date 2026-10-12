extends SceneTree
const Cloud = preload("res://backend/cloud_tracks.gd")
var checks: int = 0
var failures: int = 0
class HeldCloud extends "res://backend/cloud_tracks.gd":
	signal released
	var downloads: int = 0
	func _ready() -> void: pass
	func download(_entry: Dictionary) -> bool:
		downloads += 1
		await released
		return true
class ProbeAccount extends "res://backend/account_controller.gd":
	func _ready() -> void: add_child(client)
class ProbeApp extends "res://core/app.gd":
	var prepared: NativeTrack
	var notices: Array[String] = []
	func _ready() -> void:
		root_ui = Control.new();add_child(root_ui)
		online = ProbeAccount.new();add_child(online)
		online.client.configure("http://127.0.0.1:18181")
		cloud = HeldCloud.new();cloud.client = online.client;add_child(cloud)
		lifecycle = TrackLifecycle.new();lifecycle.cloud = cloud;add_child(lifecycle)
	func _notice(message: String) -> void: notices.append(message)
	func _start_race(track: NativeTrack, _editor: bool, _offline: bool = false, _issued: Dictionary = {}) -> void:
		prepared = track # Actual ticket/world integration remains covered by TestApp.
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1;print("FAIL: ",label)
func begin(app: Node, track: NativeTrack, state: Dictionary) -> void:
	await app._prepare_metadata_race(track,false,false,{})
	state.done = true
func run() -> void:
	VehicleCatalog.selected = "compact"
	var folder: String = ProjectSettings.globalize_path("res://../build/card-selection-latency/preparation-"+TrackLibrary.unique_id())
	DirAccess.make_dir_recursive_absolute(folder)
	var doc: Dictionary = TrackDocument.create_default()
	var body: String = JSON.stringify(doc)
	var path: String = folder.path_join("track.json")
	var file := FileAccess.open(path,FileAccess.WRITE);file.store_string(body);file.close()
	var entry: Dictionary = {"id":"cloud_fixture","track_id":"fixture","version_id":"00000000-0000-4000-8000-000000000001","content_hash":body.sha256_text(),"cache_path":path,"name":"Metadata fixture","creator":"Fixture","theme":"pine","points":doc.points}
	var native: NativeTrack = Cloud.compile_entry(entry)
	check(native != null and not native.content_hash.is_empty(),"integrity-checked race fixture compiles")
	for scenario: String in ["ready","navigation","car","account","selection","cancel-new-overlay","invalid-document"]:
		VehicleCatalog.selected = "compact"
		var app := ProbeApp.new();root.add_child(app)
		app.cloud.root_override = folder.path_join(scenario)
		var source: Dictionary = entry.duplicate(true)
		if scenario == "invalid-document": source.content_hash = "0".repeat(64)
		var track: NativeTrack = Cloud.metadata_track(source)
		app.selected_track = track
		check(track.cells.is_empty() and track.metadata.metadata_only,"browsing object has no compiled geometry: "+scenario)
		var state: Dictionary = {"done":false}
		begin(app,track,state)
		while app.cloud.downloads == 0: await process_frame
		match scenario:
			"navigation": app._navigation_generation += 1
			"car": VehicleCatalog.selected = "kart"
			"account": app.online.client.player = {"id":"another-account"}
			"selection": app.selected_track = Cloud.metadata_track(entry)
			"cancel-new-overlay":
				app._close_race_loading()
				app._open_race_loading(track)
				app.cloud_starting = true
		app.cloud.released.emit()
		while not state.done: await process_frame
		if scenario == "ready":
			check(app.prepared == track and not track.metadata.get("metadata_only",false) and track.content_hash == native.content_hash and track.cells.size() == native.cells.size(),"Race hydrates the same selection with the exact pinned native geometry")
			var restored: NativeTrack = app.cloud.presentation_track(entry.duplicate(true))
			check(restored.content_hash == native.content_hash and restored.cells.is_empty(),"restart retains PB contract hint without compiling a track")
			var refreshed: Dictionary = entry.duplicate(true);app.cloud._retain_metadata(refreshed)
			check(app.cloud.retained_entry(entry.id).get("_compiled_hash","") == native.content_hash,"metadata refresh preserves an unchanged pinned PB hint")
			refreshed.content_hash = "1".repeat(64);app.cloud._retain_metadata(refreshed)
			check(app.cloud.retained_entry(entry.id).get("_compiled_hash","").is_empty(),"changed document identity drops the old PB hint")
		else:
			check(app.prepared == null and track.metadata.metadata_only and track.cells.is_empty(),"stale or invalid preparation cannot enter a race: "+scenario)
			if scenario in ["car","account","selection"]:
				check(app.notices.size() == 1 and app.notices[0].contains("changed"),"cancelled start explains the changed prerequisite: "+scenario)
			elif scenario in ["navigation","cancel-new-overlay"]:
				check(app.notices.is_empty(),"departed or superseded preparation shows no stale notice: "+scenario)
			if scenario == "cancel-new-overlay": check(app.cloud_starting and is_instance_valid(app.race_loading),"late cancelled download cannot close or clear the newer loading operation")
			else: check(not app.cloud_starting and not is_instance_valid(app.race_loading),"rejected preparation releases its loading gate: "+scenario)
		app.queue_free();await process_frame
	VehicleCatalog.selected = "compact"
	print("METADATA_RACE_PREPARATION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
