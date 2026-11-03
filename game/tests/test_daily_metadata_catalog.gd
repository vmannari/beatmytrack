extends SceneTree
## Exercise a direct Daily start before the Free Race catalogue has been opened.
const Cloud = preload("res://backend/cloud_tracks.gd")
const Rules = preload("res://race/daily_elimination.gd")
var checks: int = 0
var failures: int = 0

class FixtureCloud extends "res://backend/cloud_tracks.gd":
	var document: Dictionary = {}
	func _ready() -> void: pass
	func download_document(_entry: Dictionary, _cancelled: Callable = Callable()) -> Dictionary:
		return document.duplicate(true)

class DailyApp extends "res://core/app.gd":
	func _load_daily_limits(track: NativeTrack, vehicle: String, request: Dictionary) -> RefCounted:
		var data := {"policy":"daily-flying-elimination-v1","version_id":str(request.version_id),"vehicle_id":vehicle,"tick_rate":120,"population":1,"cutoffs":[]}
		for percentile: int in Rules.PERCENTILES: data.cutoffs.append({"percentile":percentile,"lap_ticks":3600})
		var rules := Rules.new()
		return rules if rules.configure(data,str(track.metadata.cloud_version),vehicle) else null

class FixtureBrowser extends "res://ui/track_browser.gd":
	func _ready() -> void: pass

class CompletedJob extends RefCounted:
	var done: bool = true
	var result: Variant = {}
	func cancel() -> void: pass

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: ",label)

func run() -> void:
	create_timer(100).timeout.connect(func() -> void: push_error("Daily metadata regression deadline"); quit(1))
	OS.set_environment("BMT_API_URL", "")
	VehicleCatalog.selected = "compact"
	var folder := "user://daily_metadata_catalog_"+TrackLibrary.unique_id()
	var app := DailyApp.new()
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app.race_area_mode = "daily"
	app._show_screen("daily")
	var source := TrackDocument.create_default()
	var entry := {"id":"cloud_daily_fixture","track_id":"daily_fixture","version_id":"00000000-0000-4000-8000-000000000001","content_hash":JSON.stringify(source).sha256_text(),"cache_path":folder.path_join("track.json"),"name":"Daily fixture","creator":"Fixture","theme":"pine","points":source.points}
	var fixture := FixtureCloud.new()
	fixture.client = app.cloud.client
	fixture.root_override = folder.path_join("fixture-cloud")
	fixture.document = source
	app.add_child(fixture)
	app.cloud = fixture
	app.track_catalog = null
	var selected: NativeTrack = Cloud.metadata_track(entry)
	app.selected_track = selected
	check(app.track_catalog == null and selected.metadata.metadata_only,"direct Daily starts without an initialized catalogue")
	app._start_race(selected,false,false,{},null,{"day":20757,"version_id":entry.version_id})
	var deadline: int = Time.get_ticks_msec()+30000
	while app.cloud_starting and Time.get_ticks_msec() < deadline: await process_frame
	check(app.game != null and app.game.preparation_complete and not app.cloud_starting,"metadata-only daily track reaches the actual game without timing out")
	check(app.track_catalog != null and app.track_catalog._resolved.get(entry.id) == selected,"compiled daily track is retained in the initialized catalogue")
	if app.game != null and app.game.track_session != null:
		check(app.game.daily_elimination != null and app.game.track_session.target_laps == 10,"daily rules reach the started game")
		app._leave_race()
	# A completed background selection can also arrive with no catalogue after
	# an account reset; it must publish and release the pending preparation.
	var browser := FixtureBrowser.new()
	app.add_child(browser)
	var pending: NativeTrack = Cloud.metadata_track(entry)
	browser.selected_track = pending
	browser.list_open = false
	app.screen = "tracks"
	app.selected_track = pending
	app.track_catalog = null
	app._selected_preparation_track = pending
	app._selected_preparation_browser = weakref(browser)
	app._selected_preparation_scope = app.lifecycle.scope()
	app._selected_preparation_navigation = app._navigation_generation
	app._selected_preparation_vehicle = VehicleCatalog.selected
	app._selected_preparation_serial = browser._selection_serial
	app._selected_preparation_entry = entry.duplicate(true)
	app._selected_preparation_pin = [pending.identity,pending.content_hash,pending.metadata.cloud_version,entry.content_hash]
	app._selected_preparation_pending = true
	var job := CompletedJob.new()
	job.result = {"track":selected}
	app._selected_preparation_job = job
	app._poll_selected_preparation()
	check(not app._selected_preparation_pending and app.track_catalog != null,"background preparation initializes the catalogue and releases its pending state")
	check(not pending.metadata.get("metadata_only",false) and app.track_catalog != null and app.track_catalog._resolved.get(entry.id) == pending,"background preparation retains the hydrated selection")
	if is_instance_valid(app.race_loading): app._close_race_loading()
	app.queue_free()
	await process_frame
	print("DAILY_METADATA_CATALOG: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
