extends Node
## One account-bound, optional studio. Asset reads precede idle-only native work.
const Studio=preload("res://ui/garage_preloaded_studio.gd")
const Pictures=preload("res://ui/garage_preview_cache.gd")
const MAX_PENDING: int=4
var app: Node
var studio: CarShowroom
var idle_ms: int=250
var last_input: int=0
var foreground: bool=true
var evicted: bool=false
var _touches: Dictionary={}
var _pin: Dictionary={}
var _wanted: Array[String]=[]
var _pending: Array[String]=[]
var _resources: Dictionary={}
var _failed: Dictionary={}
var _next_audit: int=0
var _tree_ref: WeakRef
var _menu_drawn: bool=false
var picture_service: Node
var picture_records: LocalRecords
var _pictures_dirty: bool=true
var _picture_waiters: int=0

func _ready() -> void:
	_tree_ref=weakref(get_tree())
	last_input=Time.get_ticks_msec()
	foreground=app._publishing_slots_foreground
	if DisplayServer.get_name()=="headless": _menu_drawn=true
	else: RenderingServer.frame_post_draw.connect(_menu_presented,CONNECT_ONE_SHOT)

func _menu_presented() -> void:
	_menu_drawn=true

func _spec() -> Dictionary:
	var id: String=VehicleCatalog.selected
	return {"records":app.records,"profile":app.active_profile,"vehicle":id,"paint":VehicleLivery.for_car(app.records.settings,id),"parts":VehicleCustomisation.for_car(app.records.settings,id),"wear":VehicleCondition.read(app.records,id)}

func invalidate() -> void:
	_next_audit=0
	_pictures_dirty=true
	if not evicted: set_process(true)

func _sync_pictures() -> void:
	if not is_instance_valid(picture_service) or picture_records!=app.records:
		if picture_records!=null and picture_records.appearance_committed.is_connected(invalidate): picture_records.appearance_committed.disconnect(invalidate)
		if is_instance_valid(picture_service):
			picture_service.ready_pictures.clear()
			remove_child(picture_service)
			picture_service.queue_free()
		picture_records=app.records
		picture_records.appearance_committed.connect(invalidate)
		_pictures_dirty=true
		picture_service=Pictures.new()
		picture_service.can_render=_pictures_allowed
		add_child(picture_service)
	if _pictures_dirty:
		picture_service.warm_records(picture_records)
		_pictures_dirty=false

func _pictures_allowed() -> bool:
	if not is_instance_valid(app) or not app._publishing_slots_foreground or not app._background_work_allowed() or app.editor_memory.pressure_requested: return false
	if app.menu_page_motion!=null and app.menu_page_motion.is_running(): return false
	if not is_instance_valid(app._retained_garage) or not app._retained_garage.is_visible_in_tree(): return true
	var page: GaragePage=app._retained_garage
	return page.section!="cars" and is_instance_valid(page._preview_service) and page._preview_service.renderer==null and (page._menu_motion==null or not page._menu_motion.is_running())

func pictures_ready() -> bool:
	_pictures_dirty=true
	_sync_pictures()
	return is_instance_valid(picture_service) and picture_records==app.records and picture_service.pictures_ready()

func picture_pool() -> Dictionary:
	return picture_service.ready_pictures if is_instance_valid(picture_service) and picture_records==app.records else {}

func prepare_pictures(still_current: Callable=Callable()) -> bool:
	_pictures_dirty=true
	_sync_pictures()
	if DisplayServer.get_name()=="headless": return picture_service.pictures_ready()
	var current_service: Node=picture_service
	var current_records: LocalRecords=picture_records
	_picture_waiters+=1
	current_service.idle_ms=0
	var deadline: int=Time.get_ticks_msec()+45000
	while is_inside_tree() and is_instance_valid(current_service) and not current_service.pictures_ready():
		if app.records!=current_records or (still_current.is_valid() and not still_current.call()): break
		# Startup remains bounded. An explicit, cancellable navigation keeps its
		# request until the exact picture is ready rather than losing the click.
		if not still_current.is_valid() and Time.get_ticks_msec()>deadline: break
		await get_tree().process_frame
	_picture_waiters-=1
	if is_instance_valid(picture_service) and _picture_waiters==0: picture_service.idle_ms=750
	return is_instance_valid(current_service) and app.records==current_records and current_service.pictures_ready()

func _process(_delta: float) -> void:
	_poll_loads()
	if evicted:
		set_process(not _pending.is_empty())
		return
	if _pictures_dirty or picture_records!=app.records: _sync_pictures()
	if is_instance_valid(picture_service):
		var allowed: bool=app._background_work_allowed() and app._publishing_slots_foreground and not app.editor_memory.pressure_requested
		if not allowed: picture_service.suspend_previews()
		picture_service.set_process(allowed)
	if not is_instance_valid(app) or not app.startup_complete: return
	if DisplayServer.get_name()!="headless" and is_instance_valid(picture_service) and not picture_service.pictures_ready(): return
	if is_instance_valid(app.game) or is_instance_valid(app.race_loading) or app.cloud_starting or is_instance_valid(app._retained_garage):
		_reset()
		# Consume outstanding threaded reads before sleeping. Menu/lifecycle
		# events wake us; active racing does not need an empty reset each frame.
		set_process(not _pending.is_empty())
		return
	var now: int=Time.get_ticks_msec()
	if now>=_next_audit or _pin.get("records")!=app.records or _pin.get("vehicle")!=VehicleCatalog.selected or _pin.get("profile")!=app.active_profile:
		_next_audit=now+250
		var current: Dictionary=_spec()
		if current!=_pin:
			_reset()
			_pin=current
			_wanted.assign(["res://assets/garage/cars_v1/"+current.vehicle+".scn",GarageEnvironment.PREPARED_ARCHITECTURE])
			if current.paint.pattern!="plain": _wanted.append(LiveryCatalog.ROOT+current.paint.pattern+".svg")
			if current.paint.stickers.hood.id!="none" or current.paint.stickers.roof.id!="none": _wanted.append(LiveryCatalog.ROOT+"stickers.svg")
	for path: String in _wanted:
		if _pending.size()>=MAX_PENDING: break
		if _resources.has(path) or _pending.has(path) or _failed.has(path): continue
		if not ResourceLoader.exists(path): continue
		# The dummy backend's mesh RID allocator cannot overlap worker loads
		# with scene construction. Native renderers retain threaded asset reads.
		if DisplayServer.get_name()=="headless": _resources[path]=load(path)
		elif ResourceLoader.load_threaded_request(path)==OK: _pending.append(path)
	if not _allowed(false): return
	if studio==null:
		for path: String in _wanted:
			if not _resources.has(path): return
		studio=Studio.new()
		studio.name="PreloadedGarageStudio"
		studio.vehicle_id=_pin.vehicle
		studio.garage_mode=true
		studio.framing_scale=0.84
		studio.livery=_pin.paint.duplicate(true)
		studio.customisation=_pin.parts.duplicate(true)
		studio.condition=_pin.wear.duplicate(true)
		studio.record_settings={"music_record":app.records.settings.get("music_record",preload("res://soundtrack/record_library.gd").DEFAULT_ID)}
		studio.achievement_service=app.achievements
		studio.permitted=_allowed
		studio.position=Vector2(-16384,-16384)
		var pixels: Vector2=app.get_viewport().get_visible_rect().size
		studio.size=Vector2(maxf(1,pixels.x-112),maxf(250,pixels.y-360))
		add_child(studio)
	if studio.showroom_ready and not studio.warming and not studio.prepared: studio.warm()

func _allowed(for_render: bool=true) -> bool:
	if evicted or not foreground or not is_inside_tree() or is_queued_for_deletion() or _pin.is_empty(): return false
	if not is_instance_valid(app) or not app.startup_complete or not app._background_work_allowed(): return false
	if app.records!=_pin.records or app.active_profile!=_pin.profile or VehicleCatalog.selected!=_pin.vehicle: return false
	if is_instance_valid(app.game) or is_instance_valid(app._retained_garage) or app.online.busy: return false
	if app.screen not in ["account","tracks","rivalry","challenges","settings","profile"]: return false
	if app.menu_page_motion!=null and app.menu_page_motion.is_running(): return false
	if app.editor_memory.pressure_requested or not _touches.is_empty() or Input.is_anything_pressed(): return false
	var focus: Control=get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return false
	# Decode/build ahead of an early Garage click; expensive first draws still
	# wait for the full deliberate-input idle window after the menu is visible.
	return _menu_drawn and Time.get_ticks_msec()-last_input>=(idle_ms if for_render else mini(idle_ms,150))

func take() -> CarShowroom:
	if studio==null or not studio.showroom_ready or _pin!=_spec():
		# Keep decoded public assets alive through the synchronous normal entry.
		# The next process tick releases them after Garage has loaded its nodes.
		_reset(true)
		return null
	var result: CarShowroom=studio
	studio=null
	result.adopt()
	remove_child(result)
	_resources.clear()
	_pin.clear()
	_wanted.clear()
	return result

func evict() -> void:
	evicted=true
	if is_instance_valid(picture_service):
		picture_service.ready_pictures.clear()
		remove_child(picture_service)
		picture_service.queue_free()
		picture_service=null
	_pictures_dirty=true
	_reset()
	set_process(not _pending.is_empty())

func _reset(retain_assets_for_entry: bool=false) -> void:
	if is_instance_valid(studio):
		studio.release_geometry()
		studio.permitted=Callable()
		remove_child(studio)
		studio.queue_free()
	studio=null
	_pin.clear()
	_wanted.clear()
	if not retain_assets_for_entry: _resources.clear()
	_failed.clear()

func has_work() -> bool:
	return studio!=null or not _resources.is_empty() or not _pending.is_empty() or is_instance_valid(picture_service)

func residency(seen: Dictionary={}) -> Dictionary:
	var result: Dictionary={"preload_asset_bytes":32*1024*1024 if not _resources.is_empty() or not _pending.is_empty() else 0,"preload_scene_bytes":0,"preload_viewport_gpu_bytes":0}
	if is_instance_valid(picture_service):
		result.preload_picture_gpu_bytes=picture_service.picture_bytes(seen)
		result.preload_picture_io_cpu_bytes=16*1024*1024 if picture_service.worker!=null or not picture_service.pending_writes.is_empty() else 0
		if picture_service.renderer!=null:
			result.preload_picture_scene_bytes=preload("res://track/prepared_world_cache.gd")._resource_bytes(picture_service.renderer,{})
			var pixels: int=0
			for viewport: SubViewport in picture_service.renderer.find_children("*","SubViewport",true,false): pixels+=viewport.size.x*viewport.size.y*16
			result.preload_picture_viewport_gpu_bytes=pixels
	if is_instance_valid(studio):
		result.preload_asset_bytes=4*1024*1024
		if studio.carousel_texture!=null: result.preload_asset_bytes+=2048*512*4
		result.preload_scene_bytes=preload("res://track/prepared_world_cache.gd")._resource_bytes(studio,{})
		for view: SubViewport in studio.find_children("*","SubViewport",true,false): result.preload_viewport_gpu_bytes+=view.size.x*view.size.y*16
	return result

func _poll_loads() -> void:
	for index: int in range(_pending.size()-1,-1,-1):
		var path: String=_pending[index]
		var status: int=ResourceLoader.load_threaded_get_status(path)
		if status==ResourceLoader.THREAD_LOAD_IN_PROGRESS: continue
		if status==ResourceLoader.THREAD_LOAD_LOADED:
			var resource: Resource=ResourceLoader.load_threaded_get(path)
			if not evicted and _wanted.has(path): _resources[path]=resource
		else: _failed[path]=true
		_pending.remove_at(index)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled: _touches[event.index]=true
		else: _touches.erase(event.index)
	var active: bool=event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventKey or event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value)>0.2) or (event is InputEventMouseMotion and event.button_mask!=0)
	if active: last_input=Time.get_ticks_msec()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
		foreground=false
		_touches.clear()
	if what in [NOTIFICATION_APPLICATION_FOCUS_IN,NOTIFICATION_APPLICATION_RESUMED]:
		foreground=true
		last_input=Time.get_ticks_msec()
		invalidate()
	if what==NOTIFICATION_PREDELETE and not _pending.is_empty():
		_retire(_pending.duplicate(),_tree_ref)
		_pending.clear()

static func _retire(paths: Array[String],tree_ref: WeakRef) -> void:
	var pending: Array[String]=[]
	for path: String in paths:
		var status: int=ResourceLoader.load_threaded_get_status(path)
		if status==ResourceLoader.THREAD_LOAD_IN_PROGRESS: pending.append(path)
		elif status==ResourceLoader.THREAD_LOAD_LOADED: ResourceLoader.load_threaded_get(path)
	var tree: Object=tree_ref.get_ref() if tree_ref!=null else null
	if not pending.is_empty() and is_instance_valid(tree): tree.process_frame.connect(_retire.bind(pending,tree_ref),CONNECT_ONE_SHOT)
