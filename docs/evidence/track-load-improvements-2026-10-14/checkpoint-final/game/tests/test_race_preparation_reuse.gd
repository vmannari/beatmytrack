extends SceneTree
const CLOUD = preload("res://backend/cloud_tracks.gd")
const DISK = preload("res://track/road_mesh_disk_cache.gd")
var checks: int = 0
var failures: int = 0
var overlay_ids: Dictionary = {}
var loading_frames: int = 0
var app: Node

class CountedCloud extends "res://backend/cloud_tracks.gd":
	var writes: int = 0
	func _write(path: String, value: Dictionary) -> bool:
		writes += 1
		return super._write(path,value)

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func observe() -> void:
	if not is_instance_valid(app) or not is_instance_valid(app.race_loading): return
	overlay_ids[app.race_loading.get_instance_id()] = true
	loading_frames += 1
	if is_instance_valid(app.game) and app.game.process_mode == Node.PROCESS_MODE_DISABLED:
		check(app.game.sim.state.tick == 0 and app.game.countdown_ticks == 360,"preparation keeps canonical time/countdown frozen")

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	var folder: String = ProjectSettings.globalize_path("res://../build/race-preparation-reuse-"+TrackLibrary.unique_id())
	DirAccess.make_dir_recursive_absolute(folder); DISK.directory = folder.path_join("roads")
	app = load("res://core/app.tscn").instantiate(); app.library = TrackLibrary.new(folder); app.records = LocalRecords.new(folder.path_join("records.json")); app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._show_screen("tracks")
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json"))
	var body: String = JSON.stringify(document)
	var path: String = folder.path_join("document.json")
	var file := FileAccess.open(path,FileAccess.WRITE); file.store_string(body); file.close()
	var entry: Dictionary = {"source":"cloud","cache_path":path,"content_hash":body.sha256_text(),"id":"cloud_reuse_fixture","name":"Loading fixture","version_id":"fixture-v1","track_id":"fixture-track","creator":"Fixture","theme":"pine","points":document.points}
	var counted := CountedCloud.new(); counted.client = app.online.client; counted.root_override = folder.path_join("counted")
	check(counted._retain_metadata(entry),"first retained metadata is saved")
	var writes: int = counted.writes
	check(writes == 2 and counted._retain_metadata(entry) and counted.writes == writes,"identical verified retained/alias files incur zero writes")
	var changed: Dictionary = entry.duplicate(true); changed.name = "Updated name"
	check(counted._retain_metadata(changed) and counted.writes == writes+1,"changed metadata writes once and keeps identical alias")
	var alias: String = counted.cache_root().path_join("retained").path_join(("cloud_"+str(entry.version_id)).sha256_text()+".json")
	file = FileAccess.open(alias,FileAccess.WRITE); file.store_string("corrupt"); file.close()
	check(counted._retain_metadata(changed) and counted.writes == writes+2,"corrupt alias is repaired rather than skipped")
	counted.free()
	var downloaded: Dictionary = await app.cloud.download_document(entry)
	check(not downloaded.is_empty(),"download returns a validated request snapshot")
	file = FileAccess.open(path,FileAccess.WRITE); file.store_string("corrupt"); file.close()
	check(CLOUD.compile_entry(entry) == null,"independent compilation still rejects corrupt actual file bytes")
	check(CLOUD.compile_document(entry,downloaded) != null,"in-flight verified snapshot remains independent of later disk damage")
	file = FileAccess.open(path,FileAccess.WRITE); file.store_string(body); file.close()
	app.selected_track = CLOUD.metadata_track(entry)
	check(NativeTrackVisual.race_roads_need_preparation(CLOUD.compile_entry(entry)),"cold published roads require CPU preparation")
	process_frame.connect(observe)
	var started: int = Time.get_ticks_usec()
	await app._start_race(app.selected_track,false,true)
	check(overlay_ids.size() == 1,"metadata hydration and start share one loading overlay")
	check(loading_frames >= 4,"CPU preparation allows loading frames to continue")
	check(is_instance_valid(app.game) and app.game.countdown_ticks == 360 and app.game.track_session.target_laps == 5,"prepared race starts with all five laps and full countdown")
	check(app.track_catalog.cached_track(entry) == app.selected_track and not app.selected_track.metadata.get("metadata_only",false),"hydrated selection is retained in the bounded catalog")
	check(not NativeTrackVisual.race_roads_need_preparation(app.selected_track),"completed roads skip another CPU preparation")
	app.game.set_physics_process(false); app._leave_race()
	document.pieces[0].width = float(document.pieces[0].width)+0.5
	for index: int in range(document.pieces[0].point_widths.size()): document.pieces[0].point_widths[index] = document.pieces[0].width
	var cold: NativeTrack = TrackCompiler.compile(document)
	check(cold != null,"changed-width cancellation fixture validates")
	cold.metadata.cloud_version = "fixture-v2"
	app.selected_track = cold
	app._start_race(cold,false,true)
	await process_frame; await process_frame
	app._show_screen("garage")
	for frame: int in range(12): await process_frame
	check(app.game == null and not is_instance_valid(app.race_loading) and not app.cloud_starting,"navigation cancels CPU preparation without publishing a stale race")
	var elapsed: float = (Time.get_ticks_usec()-started)/1000.0
	app.free(); await process_frame
	print("RACE_PREPARATION_REUSE: ",checks," checks, ",failures," failures; loading_frames=",loading_frames," ms=",elapsed)
	quit(1 if failures else 0)
