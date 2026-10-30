extends Node
## One native capture and one owned IO worker. Workers never access a view/node.
const Build = preload("res://core/build_identity.gd")
const Work = preload("res://editor/work_job.gd")
const VERSION: String = "garage-native-previews-v1"
const MAX_FILES: int = 14
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

func _ready() -> void:
	if get_parent() is CanvasItem: get_parent().visibility_changed.connect(_visibility_changed)

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
		var path: String = "res://assets/garage/previews_v1/"+vehicle+".png"
		if ResourceLoader.exists(path): catalogue[vehicle] = load(path)
	return catalogue.get(vehicle)

func identity(view: CarShowroom) -> String:
	return JSON.stringify([VERSION,Build.ID,view.vehicle_id,view.livery,view.condition,view.customisation]).sha256_text()

func request(view: CarShowroom) -> void:
	var key: String = identity(view)
	if _default(view):
		var texture: Texture2D = catalogue_texture(view.vehicle_id)
		if texture != null:
			cache_hits += 1
			view.publish_preview(key,texture)
			return
	for index: int in range(queued.size()-1,-1,-1):
		if queued[index].view.get_ref() == view or not _current(queued[index]): queued.remove_at(index)
	if active.get("key") == key and active.view.get_ref() == view: return
	if io.get("key") == key and _view(io) == view: return
	queued.append({"view":weakref(view),"key":key,"vehicle":view.vehicle_id,"paint":view.livery.duplicate(true),"condition":view.condition.duplicate(true),"parts":view.customisation.duplicate(true),"read":true})

func _default(view: CarShowroom) -> bool:
	return view.livery == VehicleLivery.for_car({},view.vehicle_id) and view.condition.is_empty() and view.customisation == VehicleCustomisation.defaults()

func _current(job: Dictionary, visible: bool = false) -> bool:
	var view: Object = _view(job)
	return is_instance_valid(view) and view.preview_key == job.key and (not visible or _on_screen(view))

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
	if worker != null:
		if not worker.done: return
		var result: Dictionary = worker.result if worker.result is Dictionary else {}
		file_io_us += int(result.get("us",0))
		worker = null
		if io.get("read",false) and _current(io):
			if result.get("image") is Image and _current(io,true):
				cache_hits += 1
				io.view.get_ref().publish_preview(io.key,ImageTexture.create_from_image(result.image))
			else:
				io.read = result.get("image") is Image
				queued.push_front(io)
		io = {}
	if not active.is_empty():
		if not _current(active,true):
			if _current(active): queued.push_front(active)
			_finish()
			return
		if not renderer.showroom_ready: return
		frames -= 1
		if frames >= 0:
			renderer.showroom_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			renderer.reflections.request_draw()
		elif not RenderingServer.frame_post_draw.is_connected(_capture): RenderingServer.frame_post_draw.connect(_capture,CONNECT_ONE_SHOT)
		return
	for _index: int in range(queued.size()):
		var next: Dictionary = queued.pop_front()
		if not _current(next): continue
		if not _current(next,true): queued.append(next); continue
		if next.read and not directory.is_empty():
			io = next
			worker = Work.start(_read.bind(directory.path_join(next.key+".png")),get_tree())
			return
		if DisplayServer.get_name() == "headless": continue
		active = next
		renderer = CarShowroom.new()
		renderer.read_only = true; renderer.garage_mode = true
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
	if _current(active) and not _current(active,true): queued.push_front(active)
	if _current(active,true):
		var started: int = Time.get_ticks_usec()
		var image: Image = renderer.showroom_viewport.get_texture().get_image()
		readback_us += Time.get_ticks_usec()-started
		active.view.get_ref().publish_preview(active.key,ImageTexture.create_from_image(image))
		if not directory.is_empty():
			io = {"key":active.key,"read":false}
			worker = Work.start(_write.bind(directory,active.key,image),get_tree())
	_finish()

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
