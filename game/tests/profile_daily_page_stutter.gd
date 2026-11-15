extends SceneTree
## Actual App, page and selected-event worker; local fixture transport only.
const Fixture = preload("res://tests/test_daily_page_loading.gd")
var app: Node
var frames: Array[float] = []
var samples: Array[Dictionary] = []
var last_frame: int = 0
var phase: String = "startup"
var output: String
var draw_began: int = 0

class ProfileApp extends "res://core/app.gd":
	func _wake_optional_work() -> void:
		super._wake_optional_work()
		if OS.get_environment("BMT_DAILY_STUTTER_NO_GARAGE") == "1" and is_instance_valid(_garage_preloader):
			_garage_preloader.set_process(false)
	func _process(delta: float) -> void:
		var began: int = Time.get_ticks_usec()
		super._process(delta)
		var elapsed: float = (Time.get_ticks_usec()-began)/1000.0
		if elapsed > 5: print("DAILY_SPAN app_process ",elapsed)
	func _feature_resource(path: String) -> Object:
		var began: int = Time.get_ticks_usec()
		var feature: Object = super._feature_resource(path)
		var elapsed: float = (Time.get_ticks_usec()-began)/1000.0
		if elapsed > 2: print("DAILY_SPAN feature ",path," ",elapsed)
		return feature
	func _ensure_track_catalog() -> void:
		var began: int = Time.get_ticks_usec()
		super._ensure_track_catalog()
		print("DAILY_SPAN ensure_catalog ",(Time.get_ticks_usec()-began)/1000.0)
	func _prepare_selected_event(kind: String, page: Control, entry: Dictionary, source: Dictionary = {}) -> void:
		var began: int = Time.get_ticks_usec()
		super._prepare_selected_event(kind,page,entry,source)
		print("DAILY_SPAN prepare_event ",(Time.get_ticks_usec()-began)/1000.0)
	func _poll_selected_preparation() -> void:
		var began: int = Time.get_ticks_usec()
		super._poll_selected_preparation()
		var elapsed: float = (Time.get_ticks_usec()-began)/1000.0
		if elapsed > 2: print("DAILY_SPAN poll_preparation ",elapsed)

class LocalCloud extends "res://backend/cloud_tracks.gd":
	func download_document(_entry: Dictionary, _cancelled: Callable = Callable()) -> Dictionary:
		await get_tree().process_frame
		return JSON.parse_string(FileAccess.get_file_as_string("res://resources/creator_tracks/lantern_village.json"))

func _initialize() -> void: run.call_deferred()

func frame() -> void:
	var now: int = Time.get_ticks_usec()
	if last_frame > 0:
		var elapsed: float = (now-last_frame)/1000.0
		frames.append(elapsed)
		if elapsed > 30: print("DAILY_FRAME ",phase," ",elapsed)
	last_frame = now

func draw_started() -> void:
	draw_began = Time.get_ticks_usec()
	var before_draw: float = (draw_began-last_frame)/1000.0
	if before_draw > 20: print("DAILY_BEFORE_DRAW ",phase," ",before_draw)

func draw_finished() -> void:
	var elapsed: float = (Time.get_ticks_usec()-draw_began)/1000.0
	if elapsed > 20: print("DAILY_DRAW ",phase," ",elapsed)

func sample(label: String, milliseconds: int) -> void:
	phase = label
	frames.clear()
	last_frame = Time.get_ticks_usec()
	var deadline: int = Time.get_ticks_msec()+milliseconds
	while Time.get_ticks_msec() < deadline: await process_frame
	var sorted: Array[float] = frames.duplicate()
	sorted.sort()
	var row: Dictionary = {"phase":label,"frames":sorted.size(),"max_ms":sorted[-1],"p95_ms":sorted[int(sorted.size()*0.95)],"over_30ms":frames.filter(func(ms: float) -> bool: return ms > 30).size()}
	samples.append(row)
	print("DAILY_SAMPLE ",JSON.stringify(row))

func run() -> void:
	create_timer(120).timeout.connect(func() -> void: push_error("Daily stutter deadline"); quit(1))
	OS.set_environment("BMT_API_URL","")
	output = OS.get_environment("BMT_DAILY_STUTTER_OUTPUT")
	root.size = Vector2i(1280,720)
	app = ProfileApp.new()
	var directory: String = "user://daily-stutter-"+TrackLibrary.unique_id()
	app.library = TrackLibrary.new(directory.path_join("tracks"))
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.records.settings.music_enabled = false
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var feed := Fixture.Feed.new()
	root.add_child(feed)
	app.online.client = feed
	var cloud := LocalCloud.new()
	cloud.client = feed
	cloud.root_override = directory.path_join("cloud")
	app.add_child(cloud)
	app.cloud = cloud
	var feature: Node = load("res://../build/daily-page-stutter-20261115/daily.gd").new()
	app.add_child(feature)
	app._feature_resources["res://core/features/daily.gd"] = feature
	app._garage_preloader.set_process(false)
	process_frame.connect(frame)
	RenderingServer.frame_pre_draw.connect(draw_started)
	RenderingServer.frame_post_draw.connect(draw_finished)
	phase = "cold_entry"
	last_frame = Time.get_ticks_usec()
	var began: int = Time.get_ticks_usec()
	app._show_screen("daily")
	print("DAILY_SPAN show_screen ",(Time.get_ticks_usec()-began)/1000.0)
	await sample("cold_entry",5000)
	var page: Node = app.content.find_child("TrackOfDayPage",true,false)
	if page == null or page.entry.is_empty() or page._race_panel.summary.is_empty():
		push_error("Daily page did not load"); quit(1); return
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("ready.png"))
	for index: int in range(3):
		phase = "activate"
		began = Time.get_ticks_usec()
		page.activate()
		print("DAILY_SPAN activate ",(Time.get_ticks_usec()-began)/1000.0)
		await sample("activate%d" % index,600)
	phase = "refresh"
	page._race_panel.refresh()
	await sample("refresh",1000)
	FileAccess.open(output.path_join("frames.json"),FileAccess.WRITE).store_string(JSON.stringify(samples,"\t"))
	process_frame.disconnect(frame)
	RenderingServer.frame_pre_draw.disconnect(draw_started)
	RenderingServer.frame_post_draw.disconnect(draw_finished)
	app.queue_free()
	feed.queue_free()
	for index: int in range(24): await process_frame
	quit()
