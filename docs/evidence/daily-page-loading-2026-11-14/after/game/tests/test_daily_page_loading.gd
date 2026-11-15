extends SceneTree
## Real App/page, delayed fixture reads, private records and no network.
const Cache = preload("res://persistence/daily_menu_cache.gd")
const IO = preload("res://backend/atomic_json.gd")
const DAY: int = 20771
const VERSION: String = "00000000-0000-4000-8000-000000000002"
var checks: int = 0
var failures: int = 0
var app: Node
var feed: Feed
var page: Node
var output: String
var timings: Dictionary = {}

class TestApp extends "res://core/app.gd":
	func _prepare_selected_event(_kind: String, _page: Control, _entry: Dictionary, _source: Dictionary = {}) -> void: pass

class Feed extends "res://backend/backend_client.gd":
	signal released
	var held: bool = false
	var delay: float = 0.2
	var origin: String = "http://daily-loading.invalid"
	var paths: Array[String] = []
	func _ready() -> void: pass
	func base_url() -> String: return origin
	func signed_in() -> bool: return not player.is_empty()
	func request_public(path: String, _owner: int) -> Dictionary: return await reply(path)
	func request_api(path: String, _method: HTTPClient.Method = HTTPClient.METHOD_GET, _payload: Dictionary = {}, _key: String = "", _authenticated: bool = false) -> Dictionary: return await reply(path)
	func reply(path: String) -> Dictionary:
		paths.append(path)
		if held: await released
		elif delay > 0: await get_tree().create_timer(delay).timeout
		var data := {"day":DAY,"server_now":DAY*86400+3600,"ends_at":(DAY+1)*86400}
		if path == "/track-of-the-day":
			var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/creator_tracks/lantern_village.json"))
			data.track = {"track_id":"00000000-0000-4000-8000-000000000001","version_id":VERSION,"content_hash":"a".repeat(64),"name":document.name,"creator":document.creator,"theme":"pine","points":document.points,"pieces":document.get("pieces",[]),"rating_average":4.7,"rating_count":128}
		else:
			var vehicle: String = "kart" if path.contains("vehicle_id=kart") else "compact"
			data.merge({"version_id":VERSION,"vehicle_id":vehicle,"population":1,"items":[{"player_id":"fixture","display_name":"Fixture driver","rank":1,"time_ticks":1800}],"cutoffs":[]})
			for percentile: int in [75,60,50,40,30,20,10,5,1]: data.cutoffs.append({"percentile":percentile,"lap_ticks":1800})
		return {"ok":true,"data":data}

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)

func settle() -> void:
	if app.menu_page_motion != null: app._finish_menu_page_slide()
	for index: int in range(5): await process_frame

func ready_page() -> void:
	var deadline: int = Time.get_ticks_msec()+10000
	while (page._busy or page._race_panel._loading) and Time.get_ticks_msec() < deadline: await process_frame
	check(not page.entry.is_empty() and not page._race_panel.summary.is_empty(),"page metadata and standings complete")
	await settle()

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)

func open_page() -> void:
	app._show_screen("daily")
	page = app.content.find_child("TrackOfDayPage",true,false)

func run() -> void:
	create_timer(90).timeout.connect(func() -> void: push_error("Daily page loading deadline"); quit(1))
	OS.set_environment("BMT_API_URL","")
	VehicleCatalog.selected = "compact"
	root.size = Vector2i(1280,720)
	output = OS.get_environment("BMT_DAILY_PAGE_OUTPUT")
	var directory: String = "user://daily-page-loading-"+TrackLibrary.unique_id()
	var phase: String = OS.get_environment("BMT_DAILY_PAGE_PHASE")
	if phase in ["seed","restore"]: directory = "user://daily-page-process-restart"
	app = TestApp.new()
	app.library = TrackLibrary.new(directory.path_join("tracks"))
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	feed = Feed.new()
	root.add_child(feed)
	app.online.client = feed
	app.cloud.client = feed
	if OS.get_environment("BMT_DAILY_PAGE_CONTROL") == "1":
		var source: String = FileAccess.get_file_as_string("res://../docs/evidence/daily-page-loading-2026-11-14/before/game/core/features/daily.gd")
		source = source.replace("res://ui/track_of_day_page.gd","res://../build/daily-page-loading-20261114/control_page.gd")
		var script := GDScript.new()
		script.source_code = source
		check(script.reload() == OK,"task-start feature compiles")
		var feature: Node = script.new()
		app.add_child(feature)
		app._feature_resources["res://core/features/daily.gd"] = feature
	var began: int = Time.get_ticks_usec()
	if phase == "restore":
		feed.held = true
		open_page()
		timings.process_restart_visible_ms = (Time.get_ticks_usec()-began)/1000.0
		check(not page.entry.is_empty() and not page._race_panel.summary.is_empty(),"new process restores the page while all requests are held")
		check(feed.paths.size() == 1 and feed.paths[0].begins_with("/track-of-the-day/lap-standings?"),"new process performs only the background standings read")
		await capture("process-restart-before-network")
		feed.held = false
		feed.released.emit()
		await ready_page()
		finish()
		return
	open_page()
	await ready_page()
	timings.cold_ready_ms = (Time.get_ticks_usec()-began)/1000.0
	check(feed.paths.size() == 2,"cold page reads metadata and standings once")
	await capture("cold-ready")
	if phase == "seed":
		finish()
		return
	var count: int = feed.paths.size()
	feed.held = true
	page._race_panel.refresh()
	check(feed.paths.size() == count+1,"explicit refresh starts a fresh request")
	page.activate()
	page.activate()
	check(feed.paths.size() == count+1,"activation coalesces the existing standings read")
	feed.held = false
	feed.released.emit()
	await ready_page()
	count = feed.paths.size()
	began = Time.get_ticks_usec()
	open_page()
	check(not page._race_panel.summary.is_empty(),"warm page immediately restores matching standings")
	check(feed.paths.size() == count,"warm page reuses fresh standings without a new request")
	timings.warm_visible_ms = (Time.get_ticks_usec()-began)/1000.0
	await ready_page()
	# Clear every Daily RAM cache, as a fresh process would. The only remaining
	# source is the small file next to these private records.
	app._daily_track_cache.clear()
	app._daily_track_cache_scope = ""
	feed.remove_meta("daily_card_standings")
	count = feed.paths.size()
	began = Time.get_ticks_usec()
	open_page()
	check(not page.entry.is_empty() and not page._race_panel.summary.is_empty(),"recreated App state displays the saved track and standings before network completion")
	check(feed.paths.size() == count+1 and feed.paths[-1].begins_with("/track-of-the-day/lap-standings?"),"disk restore refreshes standings in the background")
	var deadline: int = Time.get_ticks_msec()+5000
	while (page.entry.is_empty() or page._race_panel.summary.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	timings.disk_visible_ms = (Time.get_ticks_usec()-began)/1000.0
	await capture("disk-ready")
	await ready_page()
	var preview: Node = page.get_script().new()
	preview.client = feed
	preview.cloud = app.cloud
	preview.records = app.records
	preview.page_preview = true
	preview.cached_state = app._daily_track_cache.duplicate(true)
	count = feed.paths.size()
	root.add_child(preview)
	check(feed.paths.size() == count,"neighbor preview never dispatches background reads")
	preview.queue_free()
	count = feed.paths.size()
	var memory: Dictionary = feed.get_meta("daily_card_standings",{})
	for key: String in memory: memory[key].sample_msec = Time.get_ticks_msec()-31000
	feed.held = true
	page.activate()
	page.activate()
	check(feed.paths.size() == count+1,"stale RAM snapshot refreshes once across repeated activation")
	feed.held = false
	feed.released.emit()
	await ready_page()
	# Race still performs the original fresh authority check.
	var raced: Array = []
	for connection: Dictionary in page.race_requested.get_connections(): page.race_requested.disconnect(connection.callable)
	page.race_requested.connect(func(value: Dictionary) -> void: raced.append(value))
	feed.held = true
	page._request_race()
	check(page._busy and raced.is_empty(),"cached presentation cannot start a race before revalidation")
	feed.held = false
	feed.released.emit()
	check(raced.size() == 1 and raced[0].version_id == VERSION,"fresh authority emits the exact race revision")
	await ready_page()
	# A different vehicle/account/origin and malformed/old/expired files cannot
	# borrow the previous request or expose its presentation.
	feed.held = true
	page._race_panel.vehicle = "kart"
	page._race_panel.configure(DAY,VERSION,(DAY+1)*86400)
	check(page._race_panel.summary.is_empty(),"a different car cannot reuse the saved standings")
	page._race_panel.vehicle = "compact"
	page._race_panel.configure(DAY,VERSION,(DAY+1)*86400)
	check(not page._race_panel.summary.is_empty(),"switching back restores the matching car immediately")
	feed.player = {"id":"different-account"}
	app._daily_track_cache.clear()
	app._daily_track_cache_scope = ""
	open_page()
	check(page.entry.is_empty(),"another account cannot reuse the saved daily track")
	feed.player = {}
	feed.origin = "http://different-origin.invalid"
	open_page()
	check(page.entry.is_empty(),"another server cannot reuse the saved daily track")
	feed.held = false
	feed.released.emit()
	await ready_page()
	if OS.get_environment("BMT_DAILY_PAGE_CONTROL") == "1":
		finish()
		return
	var path: String = app.records.path+".daily-menu.json"
	var scope: String = app._daily_cache_scope()
	var packet: Dictionary = IO.read(path)
	check(not Cache.read(app.records,scope,"track").is_empty(),"persisted metadata has a readable bounded envelope")
	for item: Dictionary in packet.items: item.sample_unix -= 301
	IO.write(path,packet)
	check(Cache.read(app.records,scope,"track").is_empty(),"older than five minutes is rejected")
	for item: Dictionary in packet.items: item.sample_unix = int(Time.get_unix_time_from_system())+60
	IO.write(path,packet)
	check(Cache.read(app.records,scope,"track").is_empty(),"backwards wall clock is rejected")
	for item: Dictionary in packet.items:
		item.sample_unix = int(Time.get_unix_time_from_system())
		item.data.ends_at = item.data.server_now
	IO.write(path,packet)
	check(Cache.read(app.records,scope,"track").is_empty(),"expired server day is rejected")
	IO.write(path,{"schema":1,"items":[null,{"scope":scope,"kind":"track","sample_unix":[],"data":{}}]})
	check(Cache.read(app.records,scope,"track").is_empty(),"malformed cache is ignored")
	page.cached_state = {"entry":[],"server_now":DAY*86400,"ends_at":(DAY+1)*86400,"sample_msec":Time.get_ticks_msec()}
	check(not page._restore_cached_track(),"malformed saved track falls back to a fresh metadata request")
	var oversized := FileAccess.open(path,FileAccess.WRITE)
	oversized.store_string(" ".repeat(Cache.MAX_BYTES+1))
	oversized.close()
	check(Cache.read(app.records,scope,"track").is_empty(),"oversized cache is ignored")
	for index: int in range(12): Cache.write(app.records,str(index),"track",{"server_now":DAY*86400,"ends_at":(DAY+1)*86400})
	check(IO.read(path).items.size() == Cache.MAX_ITEMS,"disk cache retains at most eight snapshots")
	Cache.erase(app.records,"11","track")
	check(Cache.read(app.records,"11","track").is_empty(),"explicit metadata invalidation removes its saved snapshot")
	finish()

func finish() -> void:
	app.queue_free()
	feed.queue_free()
	for index: int in range(16): await process_frame
	print("DAILY_PAGE_TIMINGS ",JSON.stringify(timings))
	print("DAILY_PAGE_LOADING: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
