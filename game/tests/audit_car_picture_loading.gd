extends SceneTree
## CPI01-CPI03: loading audit only; private PNG fixtures, no production changes.
const Icons = preload("res://ui/header_car_icons.gd")
const Cache = preload("res://ui/header_car_appearance_cache.gd")
var output: String
var results: Array[Dictionary] = []
var failures: int = 0
var checks: int = 0

class TimedCache extends "res://ui/header_car_appearance_cache.gd":
	var origin: int
	var events: Array[Dictionary] = []
	var processing_us: int = 0
	var peak_processing_us: int = 0
	func _process(delta: float) -> void:
		var old_io: RefCounted = _io
		var started: int = Time.get_ticks_usec()
		super._process(delta)
		var duration: int=Time.get_ticks_usec()-started
		processing_us += duration
		peak_processing_us=maxi(peak_processing_us,duration)
		if _io != null and _io != old_io:
			events.append({"event":"dispatch","vehicle":_io_job.get("vehicle",""),"kind":_io_kind,"ms":float(Time.get_ticks_usec()-origin)/1000.0})

class ObservedApp extends "res://core/app.gd":
	var origin: int
	var picture_events: Array[Dictionary] = []
	func _header_car_capture_allowed(_id: String) -> bool: return false
	func _header_car_picture_ready(id: String) -> void:
		picture_events.append({"vehicle":id,"ms":float(Time.get_ticks_usec()-origin)/1000.0,"startup_complete":startup_complete,"screen":screen})
		super._header_car_picture_ready(id)

class BatchProbe extends TimedCache:
	# Audit-only hit-path prototype: selected file first, then one remaining batch.
	# At most two texture publications per frame. Miss/capture integration is excluded.
	var ready_packets: Array[Dictionary] = []
	var selected_dispatched: bool = false
	var coalesce_demand: bool = false
	func request_pictures(owner_records: LocalRecords) -> void:
		if coalesce_demand and owner_records==records:
			var all_ready: bool=true
			for id: String in VehicleCatalog.IDS:
				if not Icons.ready(id,records): all_ready=false; break
			if all_ready: return
		super.request_pictures(owner_records)
	func idle() -> bool: return super.idle() and ready_packets.is_empty()
	func reads_idle() -> bool: return super.reads_idle() and ready_packets.is_empty()
	func _process(_delta: float) -> void:
		var started: int=Time.get_ticks_usec()
		if _io!=null and _io.done:
			if _io.result is Array:
				for packet: Dictionary in _io.result: ready_packets.append(packet)
			_io=null; _io_job={}
		for _index: int in range(mini(2,ready_packets.size())):
			var packet: Dictionary=ready_packets.pop_front()
			if not _valid(packet.job) or not packet.image is Image: continue
			Icons.publish(packet.job.key,packet.image)
			disk_hits+=1
			changed.emit(packet.job.vehicle)
		if _io==null and not _jobs.is_empty():
			_jobs.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.vehicle==VehicleCatalog.selected and b.vehicle!=VehicleCatalog.selected)
			var batch: Array[Dictionary]=[]
			while not _jobs.is_empty() and batch.size()<(6 if selected_dispatched else 1):
				var job: Dictionary=_jobs.pop_front()
				if _valid(job) and not Icons.customized.has(job.key): batch.append(job)
			if not batch.is_empty():
				selected_dispatched=true
				_io_job=batch[0]; _io_kind="read"
				_io=Work.start(_read_packet.bind(directory,batch),get_tree())
				events.append({"event":"dispatch","vehicle":batch[0].vehicle,"kind":"read-batch","count":batch.size(),"ms":float(Time.get_ticks_usec()-origin)/1000.0})
		var duration: int=Time.get_ticks_usec()-started
		processing_us+=duration
		peak_processing_us=maxi(peak_processing_us,duration)
		if idle(): set_process(false)
	static func _read_packet(cancelled: Callable, path: String, jobs: Array[Dictionary]) -> Array[Dictionary]:
		var packets: Array[Dictionary]=[]
		for job: Dictionary in jobs:
			if cancelled.call(): break
			var result: Dictionary=Cache._read(cancelled,path.path_join(job.key+".png"))
			packets.append({"job":job,"image":result.get("image")})
		return packets

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures += 1; printerr("AUDIT_REJECT: ",label)
func frames(count: int = 4) -> void:
	for _frame: int in range(count): await process_frame
func fixture(folder: String) -> LocalRecords:
	var records:=LocalRecords.new(folder.path_join("records.json"))
	var paints: Dictionary={}
	var parts: Dictionary={}
	for id: String in VehicleCatalog.IDS:
		var paint: Dictionary=VehicleLivery.defaults(id)
		paint.colors.body="3388aa"
		paints[id]=paint
		parts[id]=VehicleCustomisation.defaults()
	records.settings={"music_enabled":false,"selected_car":"super_rally","vehicle_liveries":paints,"vehicle_customisation":parts}
	var directory: String=folder.path_join("header_appearance_icons")
	DirAccess.make_dir_recursive_absolute(directory)
	for id: String in VehicleCatalog.IDS:
		# Use shipped PNG byte sizes/complexity; fixtures do not qualify appearance.
		var bytes: PackedByteArray=FileAccess.get_file_as_bytes(Icons.DIRECTORY+id+".png")
		FileAccess.open(directory.path_join(Icons.appearance_key(id,records)+".png"),FileAccess.WRITE).store_buffer(bytes)
	return records

func component(records: LocalRecords, fps: int, repetition: int, mode: String) -> void:
	Engine.max_fps=fps
	Icons.customized.clear()
	VehicleCatalog.selected="super_rally"
	var cache: TimedCache=TimedCache.new() if mode=="current" else BatchProbe.new()
	if mode=="batch-coalesced": cache.coalesce_demand=true
	cache.allowed=func() -> bool: return false
	cache.read_allowed=func() -> bool: return true
	root.add_child(cache)
	var shared: Node=load("res://ui/garage_shared_pictures.gd").new()
	shared.records=records; shared.header_cache=cache
	root.add_child(shared)
	var header: Control=load("res://ui/profile_car.gd").new()
	header.records=records
	root.add_child(header)
	var picker: MenuButton=load("res://ui/header_car_picker.gd").new()
	picker.records=records; picker.request_pictures=cache.request_pictures
	root.add_child(picker)
	var notifications: Array[int]=[0]
	cache.changed.connect(func(id: String) -> void:
		notifications[0]+=1
		cache.events.append({"event":"publish","vehicle":id,"ms":float(Time.get_ticks_usec()-cache.origin)/1000.0})
		if id==VehicleCatalog.selected: header.refresh()
		picker.refresh_picture(id))
	var cards: Array[Control]=[]
	for id: String in VehicleCatalog.IDS:
		var card: Control=load("res://ui/garage_cached_thumbnail.gd").new()
		card.vehicle_id=id; card.livery=VehicleLivery.for_car(records.settings,id)
		card.customisation=VehicleCustomisation.for_car(records.settings,id)
		card.preview_service=shared
		root.add_child(card); cards.append(card)
	cache.origin=Time.get_ticks_usec()
	cache.bind_records(records)
	var deadline: int=Time.get_ticks_msec()+10000
	while not cache.idle() and Time.get_ticks_msec()<deadline: await process_frame
	var elapsed: float=float(Time.get_ticks_usec()-cache.origin)/1000.0
	check(cache.disk_hits==VehicleCatalog.IDS.size() and cache.captures==0,"all six cached files restore")
	for card: Control in cards:
		check(card._image.texture==Icons.texture(card.vehicle_id,records),"same carousel texture "+card.vehicle_id)
	check(header.preview.texture==Icons.texture(VehicleCatalog.selected,records),"same selected header texture")
	var initial_events: Array=cache.events.duplicate(true)
	var initial_signals: int=notifications[0]
	var start: int=Time.get_ticks_usec()
	for _iteration: int in range(20): picker._populate()
	var warm_popup_us: int=Time.get_ticks_usec()-start
	var repeat_signals: int=notifications[0]-initial_signals
	var openings: Array[Dictionary]=[]
	if mode=="current" and repetition==0:
		picker.position=Vector2(16,16); picker.size=Vector2(100,56)
		for _opening: int in range(2):
			start=Time.get_ticks_usec()
			picker.show_popup()
			var synchronous: float=float(Time.get_ticks_usec()-start)/1000.0
			await RenderingServer.frame_post_draw
			var first_draw: float=float(Time.get_ticks_usec()-start)/1000.0
			var motion: Node=picker.get_node("HeaderCarMotion")
			var first_alpha: float=motion.progress
			while motion.tween!=null: await RenderingServer.frame_post_draw
			openings.append({"synchronous_ms":synchronous,"first_draw_ms":first_draw,"first_draw_alpha":first_alpha,"fully_opaque_ms":float(Time.get_ticks_usec()-start)/1000.0})
			picker.get_popup().hide()
			await create_timer(0.2).timeout
	var direct_reads: Array[Dictionary]=[]
	for id: String in VehicleCatalog.IDS:
		start=Time.get_ticks_usec()
		var pixels: Dictionary=Cache._read(func() -> bool: return false,cache.directory.path_join(Icons.appearance_key(id,records)+".png"))
		direct_reads.append({"vehicle":id,"read_decode_ms":float(Time.get_ticks_usec()-start)/1000.0,"bytes":FileAccess.get_file_as_bytes(Icons.DIRECTORY+id+".png").size()})
		check(pixels.get("image") is Image,"direct PNG decode "+id)
	start=Time.get_ticks_usec()
	for _iteration: int in range(100):
		for id: String in VehicleCatalog.IDS: Icons.appearance_key(id,records)
	var key_us: int=Time.get_ticks_usec()-start
	results.append({"case":"six-cached-files","mode":mode,"fps_cap":fps,"repetition":repetition,"elapsed_ms":elapsed,"cache_process_ms":float(cache.processing_us)/1000.0,"peak_cache_process_ms":float(cache.peak_processing_us)/1000.0,"events":initial_events,"initial_notifications":initial_signals,"warm_popup_average_ms":float(warm_popup_us)/20000.0,"warm_popup_extra_notifications":repeat_signals,"appearance_key_average_ms":float(key_us)/float(100*VehicleCatalog.IDS.size()*1000),"direct_reads":direct_reads,"popup_openings":openings})
	for card: Control in cards: card.queue_free()
	picker.queue_free(); header.queue_free(); shared.queue_free(); cache.queue_free()
	await frames()

func actual_app(records: LocalRecords, fps: int) -> void:
	Engine.max_fps=fps
	Icons.customized.clear()
	check(records.save_records()==OK,"save private actual-App fixture")
	var app:=ObservedApp.new()
	app.records=records
	app.library=TrackLibrary.new(records.path.get_base_dir().path_join("tracks"))
	app.cloud_root_override=records.path.get_base_dir().path_join("cloud")
	app.origin=Time.get_ticks_usec()
	root.add_child(app)
	var add_child_ms: float=float(Time.get_ticks_usec()-app.origin)/1000.0
	var deadline: int=Time.get_ticks_msec()+15000
	while (not app.startup_complete or not app.header_car_cache.idle()) and Time.get_ticks_msec()<deadline: await process_frame
	var elapsed: float=float(Time.get_ticks_usec()-app.origin)/1000.0
	check(app.header_car_cache.disk_hits==6 and app.header_car_cache.captures==0,"actual App restores all cached pictures without captures")
	results.append({"case":"actual-offline-App","fps_cap":fps,"ready_and_pictures_ms":elapsed,"synchronous_ready_ms":add_child_ms,"events":app.picture_events.duplicate(true),"disk_hits":app.header_car_cache.disk_hits,"captures":app.header_car_cache.captures})
	app.queue_free()
	await frames(12)

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-root="): output=arg.trim_prefix("--evidence-root=")
	DirAccess.make_dir_recursive_absolute(output)
	OS.set_environment("BMT_API_URL","")
	OS.set_environment("BMT_DEV_AUTH_KEY","")
	root.gui_embed_subwindows=true
	var folder: String="user://picture-loading-audit-"+TrackLibrary.unique_id()
	var records: LocalRecords=fixture(folder)
	for fps: int in [60,30]:
		for mode: String in ["current","batch","batch-coalesced"]:
			for repetition: int in range(3): await component(records,fps,repetition,mode)
	await actual_app(records,60)
	Engine.max_fps=0
	var report: Dictionary={"requirements":["CPI01","CPI02","CPI03"],"renderer":RenderingServer.get_current_rendering_method(),"checks":checks,"failures":failures,"results":results,"limits":"Desktop private warm-filesystem fixtures; no cold-disk, owner-save or phone latency claim."}
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("CAR_PICTURE_LOADING_AUDIT ",JSON.stringify(report))
	quit(1 if failures else 0)
