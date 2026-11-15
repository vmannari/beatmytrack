extends SceneTree
## Real Daily composition: cold browsing, first-tap handoff and warm CPU work.
const Probe = preload("res://tests/profile_daily_page_stutter.gd")
const Fixture = preload("res://tests/test_daily_page_loading.gd")
var checks: int = 0
var failures: int = 0
var app: Node

class DailyApp extends "res://core/app.gd":
	var preparation_calls: int = 0
	var handoffs: Array[Dictionary] = []
	func _prepare_selected_event(kind: String, page: Control, entry: Dictionary, source: Dictionary = {}) -> void:
		preparation_calls += 1
		super._prepare_selected_event(kind,page,entry,source)
	func _start_race(track: NativeTrack, _editor: bool, _offline: bool = false, _issued: Dictionary = {}, _loading: RaceLoading = null, daily: Dictionary = {}) -> void:
		handoffs.append({"track":track,"daily":daily})

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)

func wait_page(page: Node) -> void:
	var deadline: int = Time.get_ticks_msec()+10000
	while (page._busy or page._race_panel._loading) and Time.get_ticks_msec() < deadline: await process_frame
	check(not page.entry.is_empty() and not page._race_panel.summary.is_empty(),"Daily content and standings finish")

func run() -> void:
	create_timer(90).timeout.connect(func() -> void: push_error("Daily stutter regression deadline"); quit(1))
	OS.set_environment("BMT_API_URL","")
	VehicleCatalog.selected = "compact"
	root.size = Vector2i(1280,720)
	app = DailyApp.new()
	var directory: String = "user://daily-stutter-regression-"+TrackLibrary.unique_id()
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.records.settings.music_enabled = false
	app.library = TrackLibrary.new(directory.path_join("tracks"))
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var feed := Fixture.Feed.new()
	root.add_child(feed)
	app.online.client = feed
	var cloud := Probe.LocalCloud.new()
	cloud.client = feed
	cloud.root_override = directory.path_join("cloud")
	app.add_child(cloud)
	app.cloud = cloud
	var feature: Node = load("res://../build/daily-page-stutter-20261115/daily.gd").new()
	app.add_child(feature)
	app._feature_resources["res://core/features/daily.gd"] = feature
	for path: String in ["res://core/features/selected_track.gd","res://race/selected_track_preparation.gd","res://track/native_track_visual.gd"]:
		check(not ResourceLoader.has_cached(path),"cold fixture starts without "+path)
	app._show_screen("daily")
	var page: Node = app.content.find_child("TrackOfDayPage",true,false)
	await wait_page(page)
	await create_timer(0.85).timeout
	check(app._garage_preloader.Pictures == null,"Daily idle leaves unused Garage picture code unloaded")
	check(not ResourceLoader.has_cached("res://ui/garage_preview_cache.gd"),"Daily idle does not initialize the Garage picture/model graph")
	check(app.preparation_calls == 0 and not app._selected_preparation_pending,"cold Daily browsing does not initialize speculative compilation")
	for path: String in ["res://core/features/selected_track.gd","res://race/selected_track_preparation.gd","res://track/native_track_visual.gd"]:
		check(not ResourceLoader.has_cached(path),"displaying Daily does not load "+path)
	# Selecting the exact metadata object is also cheap before the loading cover.
	var selected: NativeTrack = app._selected_event_track(page.entry)
	check(selected.metadata.get("metadata_only",false),"cold handoff selects presentation without compiling")
	check(not ResourceLoader.has_cached("res://core/features/selected_track.gd"),"cold handoff keeps compiler feature lazy")
	app.selected_track = selected
	check(app._selected_event_track(page.entry) == selected,"exact selected event reuses its object")
	var changed: Dictionary = page.entry.duplicate(true)
	changed.content_hash = "b".repeat(64)
	check(app._selected_event_track(changed) != selected,"changed content cannot reuse the old object")
	feed.held = true
	page._request_race()
	check(page._busy and app.handoffs.is_empty(),"first race tap still waits for fresh authority")
	feed.held = false
	feed.released.emit()
	await wait_page(page)
	check(app.handoffs.size() == 1 and app.handoffs[0].track == selected,"fresh cold race hands off the exact selected metadata object")
	check(app.handoffs[0].daily == {"day":Fixture.DAY,"version_id":Fixture.VERSION},"first race preserves the exact Daily limits request")
	check(app.preparation_calls == 0,"fresh metadata response still avoids cold speculation")
	# Explicit race/Free Race initialization primes these resources. A partial
	# graph must remain insufficient, since the remaining import can still stall.
	var feature_script: Script = load("res://core/features/selected_track.gd")
	page.preparation_requested.emit(page.entry)
	check(app.preparation_calls == 0,"partially loaded feature does not trigger remaining imports")
	var worker_script: Script = load("res://race/selected_track_preparation.gd")
	page.preparation_requested.emit(page.entry)
	check(app.preparation_calls == 0,"worker without construction code does not trigger its import")
	var builder_script: Script = load("res://track/native_track_visual.gd")
	check(feature_script != null and worker_script != null and builder_script != null,"explicit race initialization primes all preparation code")
	page.preparation_requested.emit(page.entry)
	check(app.preparation_calls == 1 and app._selected_preparation_pending,"warm Daily still queues its existing selected-event worker")
	var generation: int = app._selected_preparation_generation
	page.preparation_requested.emit(page.entry)
	check(app._selected_preparation_generation == generation,"warm repeated presentation still coalesces work")
	var deadline: int = Time.get_ticks_msec()+45000
	while app._selected_preparation_pending and Time.get_ticks_msec() < deadline: await process_frame
	check(not app._selected_preparation_pending and not selected.metadata.get("metadata_only",false),"warm worker hydrates the exact selected object")
	check(app._selected_event_track(page.entry) == selected,"warm event handoff reuses completed geometry")
	app._garage_preloader._sync_pictures()
	check(app._garage_preloader.Pictures != null,"explicit Garage picture demand can still initialize on Daily")
	app.queue_free()
	feed.queue_free()
	for index: int in range(30): await process_frame
	print("DAILY_PAGE_STUTTER: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
