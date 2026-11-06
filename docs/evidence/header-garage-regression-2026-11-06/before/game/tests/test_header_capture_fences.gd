extends SceneTree
## Exercise the production policy and a race-entry draw boundary without a race.
const Icons = preload("res://ui/header_car_icons.gd")
var checks: int = 0
var failures: int = 0
class ReadyShowroom extends Control:
	var showroom_ready: bool = true
	var vehicle_id: String = "compact"
	var preparing: bool = false
class ReadyGarage extends Control:
	var records: LocalRecords
	var showroom: Control
	var progressive_entry: bool = true
class CompletedRead extends RefCounted:
	var done: bool = true
	var result: Dictionary
	func cancel() -> void: pass
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("HEADER_FENCE_FAIL ",label)
func run() -> void:
	var app: Node = load("res://core/app.gd").new()
	app.records = LocalRecords.new("user://capture-fences/records.json")
	app.records.settings.music_enabled = false
	app.library = TrackLibrary.new("user://capture-fences/tracks")
	app.cloud_root_override = "user://capture-fences/cloud"
	root.add_child(app)
	while not app.startup_complete:
		app._publishing_slots_foreground = true
		await process_frame
	app._garage_preloader.set_process(false)
	check(not app.online.configured,"isolated offline App")
	var garage := ReadyGarage.new()
	garage.records = app.records
	garage.showroom = ReadyShowroom.new()
	garage.add_child(garage.showroom)
	root.add_child(garage)
	app._retained_garage = garage
	app.screen = "garage"
	check(app._header_car_capture_allowed("compact"),"ready visible matching Garage is an eligible opportunity")
	check(not app._header_car_capture_allowed("kart"),"different vehicle cannot use the opportunity")
	garage.showroom.preparing = true
	check(not app._header_car_capture_allowed("compact"),"opening Garage preparation takes priority")
	garage.showroom.preparing = false
	garage.showroom.showroom_ready = false
	check(not app._header_car_capture_allowed("compact"),"unfinished showroom is ineligible")
	garage.showroom.showroom_ready = true
	garage.hide()
	check(not app._header_car_capture_allowed("compact"),"hidden retained Garage is ineligible")
	garage.show()
	garage.records = LocalRecords.new("user://capture-fences/other.json")
	check(not app._header_car_capture_allowed("compact"),"different Garage owner is ineligible")
	garage.records = app.records
	app.editor_memory.pressure_requested = true
	check(not app._header_car_capture_allowed("compact"),"memory pressure prevents capture")
	app.editor_memory.pressure_requested = false
	app._publishing_slots_foreground = false
	check(not app._header_car_work_allowed() and not app._header_car_capture_allowed("compact"),"backgrounding blocks reads and captures")
	app._publishing_slots_foreground = true
	app.cloud_starting = true
	check(not app._header_car_work_allowed(),"race CPU/network join blocks optional work")
	app.cloud_starting = false
	app.race_loading = preload("res://ui/race_loading.gd").new()
	check(not app._header_car_work_allowed(),"race loading cover blocks optional work")
	app.race_loading.free()
	app.race_loading = null
	app.menu_page_motion = app.create_tween()
	app.menu_page_motion.tween_interval(1.0)
	check(not app._header_car_capture_allowed("compact"),"page transition blocks capture")
	app.menu_page_motion.kill()
	app.menu_page_motion = null
	# Close the policy between cache processing and its actual draw callback.
	var cache: Node = app.header_car_cache
	var key: String = Icons.appearance_key("compact",app.records)
	cache.canvas = SubViewport.new()
	cache.add_child(cache.canvas)
	cache._current = {"vehicle":"compact","key":key,"epoch":cache._epoch,"read":false}
	cache._stage = "draw"
	cache._draws = 1
	app.game = Node.new()
	check(not app._header_car_work_allowed(),"installed game closes optional work")
	cache._after_draw()
	check(cache.canvas==null and cache._io==null and cache.captures==0,"late draw never reads back or writes after race entry")
	check(cache._jobs.size()==1 and cache._jobs[0].key==key,"interrupted capture keeps exactly one pinned retry")
	cache._jobs.clear()
	# A completed read is held until permission returns, without mipmap/upload.
	var pixels := Image.create(176,112,false,Image.FORMAT_RGBA8)
	pixels.fill(Color("32b5d7"))
	cache._io = CompletedRead.new()
	cache._io.result = {"image":pixels}
	cache._io_job = {"vehicle":"compact","key":key,"epoch":cache._epoch}
	cache._io_kind = "read"
	cache._process(0.0)
	check(cache._io!=null and not Icons.customized.has(key) and not pixels.has_mipmaps(),"completed read cannot publish during a race")
	check(not cache.is_processing(),"blocked service sleeps instead of polling every frame")
	app.game.free()
	app.game = null
	cache._process(0.0)
	check(cache._io==null and cache.disk_hits==1 and Icons.customized.has(key),"eligible read publishes once after the gate opens")
	cache._process(0.0)
	check(cache.disk_hits==1,"completed read never publishes twice")
	app._retained_garage = null
	app.screen = "account"
	garage.queue_free()
	Icons.customized.clear()
	app.queue_free()
	app = null
	for _i: int in range(12): await process_frame
	var result: Dictionary = {"checks":checks,"failures":failures}
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("HEADER_FENCES ",checks," checks ",failures," failures")
	quit(1 if failures else 0)
