extends SceneTree
const Support = preload("res://tests/test_daily_loading_overlap.gd")
const Events = preload("res://tests/test_selected_events.gd")
var checks: int = 0
var failures: int = 0
class Client extends Support.LimitsClient:
	var owner_ref: WeakRef
	var during_worker: bool = false
	func read(path: String, route: String) -> Dictionary:
		var app: Node = owner_ref.get_ref()
		if path.begins_with("/track-of-the-day/limits?"):
			during_worker = app._selected_preparation_pending and app._selected_preparation_job != null and not app._selected_preparation_job.done
		return await super.read(path,route)
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)
func run() -> void:
	create_timer(120).timeout.connect(func() -> void: push_error("Daily worker fixture deadline"); quit(1))
	var directory := "user://daily-worker-"+TrackLibrary.unique_id()
	NativeTrackVisual.ROAD_DISK_CACHE.directory = directory.path_join("roads")
	var app: Node = load("res://core/app.gd").new()
	app.records = LocalRecords.new(directory.path_join("records.json")); app.records.settings.music_enabled = false
	app.library = TrackLibrary.new(directory.path_join("tracks")); app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._garage_preloader.set_process(false)
	app._feature_resource("res://core/features/race.gd")
	var client := Client.new(); client.owner_ref = weakref(app); app.add_child(client)
	app.online.client = client; app.cloud.client = client
	app.screen = "daily"
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json"))
	var compiled: NativeTrack = TrackCompiler.compile(source)
	var fixture := Support.new()
	client.response = fixture.limits(compiled); fixture.free()
	var body := JSON.stringify(source)
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory.path_join("track.json"); FileAccess.open(path,FileAccess.WRITE).store_string(body)
	var entry := {"id":"cloud_daily_worker","track_id":"daily_worker","version_id":"daily-overlap","content_hash":body.sha256_text(),"cache_path":path,"name":"Daily overlap worker","creator":"Fixture","theme":"pine","points":source.points}
	var page := Events.Daily.new(); page.entry = entry; page._server_now = 20761*86400+10; page._ends_at = page._server_now+1000; page._sample_msec = Time.get_ticks_msec(); app.add_child(page)
	app._prepare_selected_event("daily",page,entry); app._selected_preparation_event.due = 0
	var deadline: int = Time.get_ticks_msec()+10000
	while app._selected_preparation_job == null and Time.get_ticks_msec()<deadline: await process_frame
	var selected: NativeTrack = app.selected_track
	check(app._selected_preparation_pending and selected.metadata.get("metadata_only",false),"real worker starts with the exact metadata selection")
	app._start_race(selected,false,false,{},null,{"day":20761,"version_id":"daily-overlap"})
	while client.flights.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	check(client.flights.size() == 1 and client.during_worker,"fresh limits read starts while the real CPU worker is unfinished")
	client.release()
	while app.cloud_starting and Time.get_ticks_msec()<deadline+45000: await process_frame
	check(is_instance_valid(app.game) and app.game.preparation_complete,"real worker and limits join into the actual Game")
	if is_instance_valid(app.game):
		app.game.set_physics_process(false)
		check(app.game.native_track == selected and not selected.metadata.get("metadata_only",false),"hydration preserves the selected track object")
		check(app.game.daily_elimination != null and app.game.track_session.target_laps == 10,"real worker handoff keeps fresh ten-lap limits")
		check(app.game.sim.state.tick == 0 and app.game.countdown_ticks == 360,"concurrent preparation advances no canonical time")
		check(client.flights.size() == 1,"metadata handoff never duplicates the read")
		app._leave_race()
	app.queue_free()
	for index: int in range(12): await process_frame
	var result := {"checks":checks,"failures":failures}
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("DAILY_LOADING_WORKER ",JSON.stringify(result))
	quit(1 if failures else 0)
