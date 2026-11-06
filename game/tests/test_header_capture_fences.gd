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
	var section: String = "care"
	var _preview_service: Node
	var _menu_motion: Tween
class Pictures extends Node:
	var renderer: Node
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
	app._initial_menu_presented = true
	app._garage_preloader._menu_drawn = true
	app._garage_preloader.foreground = true
	app._garage_preloader.last_input = Time.get_ticks_msec()-1000
	check(not app.online.configured,"isolated offline App")
	check(app._header_car_capture_allowed("compact"),"settled initial menu can resolve its custom pictures")
	app._initial_menu_presented = false
	check(not app._header_car_capture_allowed("compact"),"first menu must actually draw before native preparation")
	app._initial_menu_presented = true
	app._garage_preloader.last_input = Time.get_ticks_msec()
	check(not app._header_car_capture_allowed("compact"),"recent deliberate input postpones native work")
	app._garage_preloader.last_input = Time.get_ticks_msec()-1000
	app._garage_preloader._touches[9] = true
	check(not app._header_car_capture_allowed("compact"),"held touch blocks native work past its idle deadline")
	app._garage_preloader._touches.clear()
	var edit := LineEdit.new()
	root.add_child(edit)
	edit.grab_focus()
	check(not app._header_car_capture_allowed("compact"),"text editing blocks native preparation")
	edit.release_focus()
	edit.queue_free()
	app.screen = "editor"
	check(not app._header_car_capture_allowed("compact"),"editor never admits optional header worlds")
	app.screen = "account"
	var garage := ReadyGarage.new()
	garage.records = app.records
	garage.showroom = ReadyShowroom.new()
	garage.add_child(garage.showroom)
	root.add_child(garage)
	app._retained_garage = garage
	app.screen = "garage"
	check(app._header_car_capture_allowed("compact"),"ready visible matching Garage is an eligible opportunity")
	check(not app._header_car_capture_allowed("kart"),"different vehicle cannot use the opportunity")
	var pictures := Pictures.new()
	root.add_child(pictures)
	garage._preview_service = pictures
	pictures.renderer = Node.new()
	check(not app._header_car_capture_allowed("compact"),"active carousel renderer finishes before a header can start")
	pictures.renderer.free()
	pictures.renderer = null
	app.header_car_cache._current = {"vehicle":"compact"}
	check(not app._garage_preloader._pictures_allowed(),"active header excludes carousel rendering")
	app.header_car_cache._current = {}
	app.header_car_cache._jobs.append({"vehicle":"kart","key":Icons.appearance_key("kart",app.records),"epoch":app.header_car_cache._epoch,"read":false})
	check(app._garage_preloader._pictures_allowed(),"unrelated deferred header cannot deadlock ready Garage pictures")
	app.header_car_cache._jobs.clear()
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
	# A cold selected-car render must also yield to a later cached car when
	# native work is eligible, as on a return from a long foreground race.
	app.screen = "settings"
	var paint: Dictionary = VehicleLivery.defaults("compact")
	paint.colors.body = "12ab34"
	app.records.settings.vehicle_liveries = {"compact":paint}
	var selected_key: String = Icons.appearance_key("compact",app.records)
	var kart_key: String = Icons.appearance_key("kart",app.records)
	DirAccess.make_dir_recursive_absolute(cache.directory)
	check(pixels.save_png(cache.directory.path_join(kart_key+".png"))==OK,"seed a real later-car disk hit")
	cache._jobs.assign([
		{"vehicle":"compact","key":selected_key,"epoch":cache._epoch,"read":false,"paint":paint,"parts":VehicleCustomisation.defaults()},
		{"vehicle":"kart","key":kart_key,"epoch":cache._epoch,"read":true}])
	cache._process(0.0)
	check(cache._io_kind=="read" and cache._io_job.get("vehicle")=="kart" and not cache.capture_active(),"cached car reads before an eligible selected-car native capture")
	cache._jobs.clear()
	cache.bind_records(null)
	app._retained_garage = null
	app.screen = "account"
	garage.queue_free()
	pictures.queue_free()
	Icons.customized.clear()
	app.queue_free()
	app = null
	for _i: int in range(12): await process_frame
	var result: Dictionary = {"checks":checks,"failures":failures}
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("HEADER_FENCES ",checks," checks ",failures," failures")
	quit(1 if failures else 0)
