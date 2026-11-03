extends Node
## One native capture and one owned IO worker. Workers never access a view/node.
const Build = preload("res://core/build_identity.gd")
const Work = preload("res://editor/work_job.gd")
const VERSION: String = "garage-native-previews-v2"
const MAX_FILES: int = 14
static var factory_pictures: Dictionary={}
static var pending_pictures: Array[String]=[]
var directory: String = ""
var queued: Array[Dictionary] = []
var active: Dictionary = {}
var renderer: CarShowroom
var worker: RefCounted
var io: Dictionary = {}
var frames: int = 0
var renders: int = 0
var cache_hits: int = 0
var readback_us: int = 0
var file_io_us: int = 0
var can_render: Callable
var prepared_picture: Dictionary={}
var pending_writes: Array[Dictionary]=[]
var ready_pictures: Dictionary={}
var remember_pictures: bool=false
var immediate_reads: bool=false
var warm_views: Dictionary={}
var _last_input: int=0
var _touches: Dictionary={}
var idle_ms: int=750

func _ready() -> void:
	_last_input=Time.get_ticks_msec()
	preload("res://ui/preview_touch_input.gd").bind(self)
	if get_parent() is CanvasItem: get_parent().visibility_changed.connect(_visibility_changed)

func _release_preview_touch(index: int) -> void:
	if _touches.has(index):
		_touches.erase(index)
		_last_input=Time.get_ticks_msec()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled: _touches[event.index]=true
		else: _touches.erase(event.index)
	if event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventKey or event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value)>0.2) or (event is InputEventMouseMotion and event.button_mask!=0): _last_input=Time.get_ticks_msec()

func _render_allowed() -> bool:
	if not _touches.is_empty() or Input.is_anything_pressed() or Time.get_ticks_msec()-_last_input<idle_ms: return false
	var focus: Control=get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return false
	return not can_render.is_valid() or bool(can_render.call())

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_IN,NOTIFICATION_APPLICATION_RESUMED]:
		_touches.clear()
		_last_input=Time.get_ticks_msec()

func _visibility_changed() -> void:
	if get_parent() is CanvasItem and not get_parent().is_visible_in_tree(): suspend_previews()

func suspend_previews() -> void:
	# Parked Garage processing is disabled, so cancellation cannot depend on its
	# next _process callback. Keep only current queued work for a later revisit.
	if not active.is_empty() and _current(active): queued.push_front(active)
	_finish()
	if worker != null and io.get("read",false): worker.cancel()
var catalogue: Dictionary = {}

func catalogue_texture(vehicle: String) -> Texture2D:
	if not catalogue.has(vehicle):
		if factory_pictures.has(vehicle):
			catalogue[vehicle]=factory_pictures[vehicle]
			return catalogue[vehicle]
		var path: String = "res://assets/garage/previews_v1/"+vehicle+".png"
		if ResourceLoader.exists(path): catalogue[vehicle] = load(path)
	return catalogue.get(vehicle)

static func prefetch_catalogue(tree: SceneTree) -> void:
	# Only seven public stock photographs; no Garage world or account data.
	if not pending_pictures.is_empty() or factory_pictures.size()==VehicleCatalog.IDS.size(): return
	for id: String in VehicleCatalog.IDS:
		if factory_pictures.has(id): continue
		var path: String="res://assets/garage/previews_v1/"+id+".png"
		if ResourceLoader.exists(path) and ResourceLoader.load_threaded_request(path)==OK: pending_pictures.append(id)
	_poll_pictures(weakref(tree))

static func _poll_pictures(tree_ref: WeakRef) -> void:
	for index: int in range(pending_pictures.size()-1,-1,-1):
		var id: String=pending_pictures[index]
		var path: String="res://assets/garage/previews_v1/"+id+".png"
		var status: int=ResourceLoader.load_threaded_get_status(path)
		if status==ResourceLoader.THREAD_LOAD_IN_PROGRESS: continue
		if status==ResourceLoader.THREAD_LOAD_LOADED: factory_pictures[id]=ResourceLoader.load_threaded_get(path)
		pending_pictures.remove_at(index)
	var tree: Object=tree_ref.get_ref()
	if not pending_pictures.is_empty() and is_instance_valid(tree): tree.process_frame.connect(_poll_pictures.bind(tree_ref),CONNECT_ONE_SHOT)

func identity(view: CarShowroom) -> String:
	# Older generated identities do not have a per-car revision. Keep their
	# conservative shared fingerprint until the next normal build refresh.
	var identity_script: Script = Build
	var revisions: Dictionary = identity_script.get_script_constant_map().get("GARAGE_PREVIEW_VEHICLE_SHA256",{})
	var revision: String = str(revisions.get(view.vehicle_id,Build.GARAGE_PREVIEW_SHA256))
	# A new prepared Volt mesh set must not reuse pictures from the prior model,
	# including in an editor session before the next generated build identity.
	if view.vehicle_id == "electric":
		revision += ":" + preload("res://vehicle/electric_reference_mesh.gd").ASSET_ROOT
		revision += ":" + preload("res://vehicle/electric_kits.gd").HOOD_REVISION
		revision += ":" + preload("res://vehicle/electric_body_kits.gd").REVISION
	return JSON.stringify([VERSION,revision,view.vehicle_id,view.livery,_visible_condition(view.condition),view.customisation]).sha256_text()

func _visible_condition(value: Dictionary) -> Dictionary:
	# A saved clean snapshot has the same original finish as an absent condition.
	if not value.is_empty() and value.get("version") != 1: return value
	for field: String in ["dirt","snow","slow_dirt","slow_snow","wetness","mud","smudge"]:
		if float(value.get(field,0.0)) != 0.0: return value
	return {}

func warm_records(records: LocalRecords, read_immediately: bool=true) -> void:
	remember_pictures=true
	immediate_reads=read_immediately
	directory=records.path+".garage-previews"
	for id: String in VehicleCatalog.IDS:
		var view: CarShowroom=warm_views.get(id)
		var fresh: bool=view==null
		if fresh:
			view=preload("res://ui/garage_cached_thumbnail.gd").new()
			view.vehicle_id=id
			view.preview_service=self
			view.hide()
			warm_views[id]=view
		view.livery=VehicleLivery.for_car(records.settings,id)
		view.condition=VehicleCondition.read(records,id)
		view.customisation=VehicleCustomisation.for_car(records.settings,id)
		if fresh: add_child(view)
		else: view.refresh_thumbnail()
		if view.displayed_key==view.preview_key and view._image.texture!=null: _publish(view,view.preview_key,view._image.texture)

func pictures_ready() -> bool:
	if warm_views.size()!=VehicleCatalog.IDS.size(): return false
	for view: CarShowroom in warm_views.values():
		if _remembered(view.vehicle_id,view.preview_key)==null: return false
	return true

func _remembered(vehicle: String,key: String) -> Texture2D:
	if not remember_pictures or directory.is_empty(): return null
	var picture: Dictionary=ready_pictures.get(vehicle,{})
	return picture.get("texture") if picture.get("key")==key else null

func _publish(view: CarShowroom,key: String,texture: Texture2D) -> void:
	if view.preview_key!=key or texture==null: return
	if remember_pictures and not directory.is_empty(): ready_pictures[view.vehicle_id]={"key":key,"texture":texture}
	view.publish_preview(key,texture)

func picture_bytes(seen: Dictionary) -> int:
	var bytes: int=0
	var textures: Array=[]
	for picture: Dictionary in ready_pictures.values(): textures.append(picture.texture)
	for view: CarShowroom in warm_views.values():
		if view._image!=null: textures.append(view._image.texture)
	for texture: Texture2D in textures:
		if texture==null or seen.has(texture.get_instance_id()): continue
		seen[texture.get_instance_id()]=true
		bytes+=texture.get_width()*texture.get_height()*4
	return bytes

func request(view: CarShowroom) -> void:
	var key: String = identity(view)
	var remembered: Texture2D=_remembered(view.vehicle_id,key)
	if remembered!=null:
		cache_hits+=1
		if prepared_picture.get("vehicle")==view.vehicle_id: prepared_picture={}
		view.publish_preview(key,remembered)
		return
	if prepared_picture.get("vehicle")==view.vehicle_id and prepared_picture.get("paint")==view.livery and prepared_picture.get("condition")==view.condition and prepared_picture.get("parts")==view.customisation:
		cache_hits+=1
		_publish(view,key,prepared_picture.texture)
		if not directory.is_empty() and prepared_picture.get("persisted_key","")!=key:
			pending_writes.append({"key":key,"texture":prepared_picture.texture})
			prepared_picture.persisted_key=key
		return
	if _default(view):
		var texture: Texture2D = catalogue_texture(view.vehicle_id)
		if texture != null:
			cache_hits += 1
			_publish(view,key,texture)
			return
	if immediate_reads and not directory.is_empty():
		var result: Dictionary=_read(func() -> bool: return false,directory.path_join(key+".png"))
		file_io_us+=int(result.us)
		if result.image is Image:
			cache_hits+=1
			_publish(view,key,ImageTexture.create_from_image(result.image))
			return
	for index: int in range(queued.size()-1,-1,-1):
		if queued[index].view.get_ref() == view or not _current(queued[index]): queued.remove_at(index)
	if active.get("key") == key and active.view.get_ref() == view: return
	if io.get("key") == key and _view(io) == view: return
	queued.append({"view":weakref(view),"key":key,"vehicle":view.vehicle_id,"paint":view.livery.duplicate(true),"condition":view.condition.duplicate(true),"parts":view.customisation.duplicate(true),"read":not immediate_reads})

func _default(view: CarShowroom) -> bool:
	return view.livery == VehicleLivery.for_car({},view.vehicle_id) and _visible_condition(view.condition).is_empty() and view.customisation == VehicleCustomisation.defaults()

func _current(job: Dictionary, visible: bool = false) -> bool:
	var view: Object = _view(job)
	return is_instance_valid(view) and view.preview_key == job.key and (not visible or warm_views.get(view.vehicle_id)==view or _on_screen(view))

func _on_screen(view: Control) -> bool:
	if not view.is_visible_in_tree(): return false
	var rect: Rect2 = view.get_global_rect().intersection(view.get_viewport_rect())
	var ancestor: Node = view.get_parent()
	while ancestor != null and rect.has_area():
		if ancestor is Control and ancestor.clip_contents:
			rect = rect.intersection(ancestor.get_global_rect())
		ancestor = ancestor.get_parent()
	return rect.has_area()

func _view(job: Dictionary) -> Object:
	var reference: WeakRef = job.get("view")
	return reference.get_ref() if reference != null else null

func _process(_delta: float) -> void:
	if worker != null and worker.done:
		var result: Dictionary = worker.result if worker.result is Dictionary else {}
		file_io_us += int(result.get("us",0))
		worker = null
		if io.get("read",false) and _current(io):
			if result.get("image") is Image and _current(io,true):
				cache_hits += 1
				_publish(io.view.get_ref(),io.key,ImageTexture.create_from_image(result.image))
			else:
				io.read = result.get("image") is Image
				queued.append(io)
		io = {}
	# A read can satisfy a queued view, so finish it before starting another
	# capture. A write owns only an Image and may run alongside the next world.
	if worker != null and io.get("read",false): return
	if worker == null and not active.is_empty() and not pending_writes.is_empty(): _start_write()
	if not active.is_empty():
		var remembered: Texture2D=_remembered(active.vehicle,active.key)
		if _current(active) and remembered!=null:
			_publish(active.view.get_ref(),active.key,remembered)
			_finish()
			return
		if not _current(active,true):
			if _current(active): queued.push_front(active)
			_finish()
			return
		if not renderer.showroom_ready: return
		if not _render_allowed():
			renderer.showroom_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
			for view: SubViewport in renderer.reflections.views: view.render_target_update_mode=SubViewport.UPDATE_DISABLED
			return
		frames -= 1
		if frames >= 0:
			renderer._submit_render()
		elif (worker == null or pending_writes.is_empty()) and not RenderingServer.frame_post_draw.is_connected(_capture): RenderingServer.frame_post_draw.connect(_capture,CONNECT_ONE_SHOT)
		return
	# Read every visible saved PNG before starting a missing car's native world.
	# A cold miss must not hold already stored pictures behind its construction.
	if worker == null and not directory.is_empty():
		for index: int in range(queued.size()):
			var next: Dictionary=queued[index]
			if next.read and _current(next,true):
				queued.remove_at(index)
				io=next
				worker=Work.start(_read.bind(directory.path_join(next.key+".png")),get_tree())
				return
	elif worker != null and not directory.is_empty():
		for next: Dictionary in queued:
			if next.read and _current(next,true): return
	if worker == null and not pending_writes.is_empty(): _start_write()
	for _index: int in range(queued.size()):
		var next: Dictionary = queued.pop_front()
		if not _current(next): continue
		if next.read and not directory.is_empty():
			queued.append(next)
			continue
		var remembered: Texture2D=_remembered(next.vehicle,next.key)
		if remembered!=null:
			_publish(next.view.get_ref(),next.key,remembered)
			continue
		if not _current(next,true): queued.append(next); continue
		if DisplayServer.get_name() == "headless": continue
		if not _render_allowed():
			queued.push_front(next)
			return
		active = next
		renderer = preload("res://ui/garage_preview_renderer.gd").new()
		renderer.read_only = true; renderer.garage_mode = true
		renderer.preview_live_lighting = true
		renderer.cooperative_build = true
		renderer.vehicle_id = next.vehicle; renderer.livery = next.paint
		renderer.condition = next.condition; renderer.customisation = next.parts
		renderer.framing_scale = 0.84
		renderer.position = Vector2(-16384,-16384); renderer.size = Vector2(2048,512)
		add_child(renderer)
		frames = 4; renders += 1
		return

func _capture() -> void:
	if active.is_empty() or not is_instance_valid(renderer): return
	if not _render_allowed(): return
	if _current(active) and not _current(active,true): queued.push_front(active)
	if _current(active,true):
		var started: int = Time.get_ticks_usec()
		var image: Image = renderer.showroom_viewport.get_texture().get_image()
		readback_us += Time.get_ticks_usec()-started
		_publish(active.view.get_ref(),active.key,ImageTexture.create_from_image(image))
		if not directory.is_empty():
			pending_writes.append({"key":active.key,"image":image})
	_finish()

func _start_write() -> void:
	var picture: Dictionary=pending_writes.pop_front()
	if directory.is_empty(): return
	var image: Image=picture.get("image")
	if image==null: image=picture.texture.get_image()
	io={"key":picture.key,"read":false}
	worker=Work.start(_write.bind(directory,picture.key,image),get_tree())

func _finish() -> void:
	if RenderingServer.frame_post_draw.is_connected(_capture): RenderingServer.frame_post_draw.disconnect(_capture)
	if is_instance_valid(renderer):
		remove_child(renderer)
		renderer.queue_free()
	renderer = null; active = {}

func _exit_tree() -> void:
	_finish()
	if worker != null: worker.cancel()
	queued.clear()
	pending_writes.clear()

static func _read(cancelled: Callable, path: String) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var image: Image
	var file := FileAccess.open(path,FileAccess.READ)
	if file != null and file.get_length() <= 8388608 and not cancelled.call():
		var bytes: PackedByteArray = file.get_buffer(file.get_length())
		if bytes.size() >= 33 and bytes.slice(0,8) == PackedByteArray([137,80,78,71,13,10,26,10]) and bytes.slice(16,24) == PackedByteArray([0,0,8,0,0,0,2,0]):
			var decoded := Image.new()
			if decoded.load_png_from_buffer(bytes) == OK and decoded.get_size() == Vector2i(2048,512): image = decoded
	return {"image":image,"us":Time.get_ticks_usec()-started}

static func _write(cancelled: Callable, directory: String, key: String, image: Image) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	if not cancelled.call() and DirAccess.make_dir_recursive_absolute(directory) == OK:
		var temporary: String = directory.path_join(key+".tmp.png")
		if image.save_png(temporary) == OK:
			if cancelled.call(): DirAccess.remove_absolute(temporary)
			else: DirAccess.rename_absolute(temporary,directory.path_join(key+".png"))
		_trim(directory)
	return {"us":Time.get_ticks_usec()-started}

static func _trim(directory: String) -> void:
	var folder := DirAccess.open(directory)
	if folder == null: return
	var files: Array[Dictionary] = []
	for name: String in folder.get_files():
		if not name.ends_with(".png") or name.trim_suffix(".png").length()!=64 or not name.trim_suffix(".png").is_valid_hex_number(): continue
		files.append({"name":name,"at":FileAccess.get_modified_time(directory.path_join(name))})
	files.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.at < b.at)
	while files.size() > MAX_FILES: DirAccess.remove_absolute(directory.path_join(files.pop_front().name))
