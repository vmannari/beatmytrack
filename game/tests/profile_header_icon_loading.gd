extends SceneTree
## Time actual cache misses, including renderer loading, while keeping user data private.
var checks: int = 0
var failures: int = 0
var evidence: String
var began: int
var rows: Array = []
var frame_started: int
var frames_ms: Array[float] = []
var current: String = ""
var item_started: int
var service: Node

func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: ",label)
func frame() -> void:
	var now: int = Time.get_ticks_usec()
	if frame_started>0: frames_ms.append((now-frame_started)/1000.0)
	frame_started = now
func started(id: String) -> void:
	current = id
	item_started = Time.get_ticks_usec()
func finished() -> void:
	rows.append({"vehicle":current,"capture_ms":(Time.get_ticks_usec()-item_started)/1000.0,"elapsed_ms":(Time.get_ticks_usec()-began)/1000.0})

func run() -> void:
	if DisplayServer.get_name()=="headless": quit(1); return
	var procedural_control: bool = OS.get_environment("BMT_HEADER_PROCEDURAL_CONTROL")=="1"
	if procedural_control:
		preload("res://vehicle/modular_car_base.gd").enabled = false
		preload("res://vehicle/modular_car_kits.gd").enabled = false
		preload("res://ui/header_simple_cache.gd").enabled = false
	OS.set_environment("BMT_API_URL","")
	evidence = OS.get_environment("BMT_RIVALRY_CARS_EVIDENCE_DIR")
	DirAccess.make_dir_recursive_absolute(evidence)
	root.size = Vector2i(1280,720)
	var records := LocalRecords.new("user://header-performance/records.json")
	var paints: Dictionary = {}
	var parts: Dictionary = {}
	for id: String in VehicleCatalog.IDS:
		var paint: Dictionary = VehicleLivery.defaults(id)
		paint.colors.body = "278da3"
		paint.pattern = "apex_twin"
		paint.stickers.hood.id = str(LiveryCatalog.stickers[3].id)
		paints[id] = paint
		var kit: Dictionary = VehicleCustomisation.defaults()
		for category: String in VehicleCustomisation.CATEGORIES:
			var options: Array = VehicleCustomisation.options(category,id)
			kit[category] = options[mini(2,options.size()-1)][0]
		parts[id] = kit
	records.settings = {"vehicle_liveries":paints,"vehicle_customisation":parts}
	var icons: Script = load("res://ui/header_car_icons.gd")
	icons.customized.clear()
	process_frame.connect(frame)
	began = Time.get_ticks_usec()
	service = load("res://ui/header_car_appearance_cache.gd").new()
	service.allowed = func() -> bool: return true
	service.capture_started.connect(started)
	service.capture_finished.connect(finished)
	root.add_child(service)
	service.bind_records(records)
	var deadline: int = Time.get_ticks_msec()+150000
	while not service.idle() and Time.get_ticks_msec()<deadline: await process_frame
	var total_ms: float = (Time.get_ticks_usec()-began)/1000.0
	check(service.idle(),"all six equipped icon captures finish")
	check(service.captures==VehicleCatalog.IDS.size() and service.peak_worlds==1 and service.canvas==null,"bounded one-at-a-time capture lifetime")
	for id: String in VehicleCatalog.IDS:
		var picture: Texture2D = icons.texture(id,records)
		check(picture!=null and picture.get_size()==Vector2(176,112),id+" publishes an equipped icon")
		if picture!=null: check(picture.get_image().save_png(evidence.path_join(id+".png"))==OK,id+" save icon evidence")
	frames_ms.sort()
	var result: Dictionary = {"checks":checks,"failures":failures,"total_ms":total_ms,"captures":service.captures,"peak_worlds":service.peak_worlds,"rows":rows,"max_frame_ms":frames_ms.back(),"p95_frame_ms":frames_ms[floori((frames_ms.size()-1)*0.95)],"renderer":RenderingServer.get_current_rendering_method()}
	result.prepared_base_hits = load("res://vehicle/modular_car_base.gd").hits
	result.prepared_kit_hits = load("res://vehicle/modular_car_kits.gd").hits
	result.header_template_hits = load("res://ui/header_simple_cache.gd").hits
	result.procedural_control = procedural_control
	if not procedural_control:
		check(result.prepared_base_hits==VehicleCatalog.IDS.size(),"every timed icon restores its current prepared base")
		check(result.prepared_kit_hits==VehicleCatalog.IDS.size()*VehicleCustomisation.CATEGORIES.size(),"every timed icon restores all selected prepared parts")
	result.checks = checks
	result.failures = failures
	FileAccess.open(evidence.path_join("timings.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("HEADER_ICON_METRICS ",JSON.stringify(result))
	process_frame.disconnect(frame)
	service.queue_free()
	for _i: int in range(8): await process_frame
	print("HEADER_ICON_LOADING: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
