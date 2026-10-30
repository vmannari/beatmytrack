extends Node
## Seven photos, one temporary native renderer only on a cache miss. No account IO.
const Build = preload("res://core/build_identity.gd")
const VERSION: String = "garage-native-previews-v1"
const MAX_FILES: int = 14
var directory: String
var queued: Array[Dictionary] = []
var active: Dictionary = {}
var renderer: CarShowroom
var frames: int = 0
var renders: int = 0
var cache_hits: int = 0

func identity(view: CarShowroom) -> String:
	return JSON.stringify([VERSION,Build.ID,view.vehicle_id,view.livery,view.condition,view.customisation]).sha256_text()

func request(view: CarShowroom) -> void:
	var key: String = identity(view)
	var saved: Texture2D = _cached(key)
	if saved == null and _default(view):
		var path: String = "res://assets/garage/previews_v1/"+view.vehicle_id+".png"
		if ResourceLoader.exists(path): saved = load(path)
	if saved != null:
		cache_hits += 1
		view.publish_preview(key,saved)
		return
	if DisplayServer.get_name() == "headless": return
	for job: Dictionary in queued:
		if job.key == key and job.view.get_ref() == view: return
	queued.append({"view":weakref(view),"key":key,"vehicle":view.vehicle_id,"paint":view.livery.duplicate(true),"condition":view.condition.duplicate(true),"parts":view.customisation.duplicate(true)})

func _default(view: CarShowroom) -> bool:
	return view.livery == VehicleLivery.for_car({},view.vehicle_id) and view.condition.is_empty() and view.customisation == VehicleCustomisation.defaults()

func _cached(key: String) -> Texture2D:
	if directory.is_empty(): return null
	var path: String = directory.path_join(key+".png")
	if not FileAccess.file_exists(path): return null
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > 8388608: return null
	file.close()
	var image := Image.new()
	if image.load(path) != OK or image.get_size() != Vector2i(2048,512): return null
	return ImageTexture.create_from_image(image)

func _process(_delta: float) -> void:
	if active.is_empty():
		while not queued.is_empty():
			var next: Dictionary = queued.pop_front()
			var view: Object = next.view.get_ref()
			if not is_instance_valid(view) or view.preview_key != next.key: continue
			if not view.is_visible_in_tree():
				queued.append(next)
				return
			active = next
			renderer = CarShowroom.new()
			renderer.read_only = true
			renderer.garage_mode = true
			renderer.vehicle_id = next.vehicle
			renderer.livery = next.paint
			renderer.condition = next.condition
			renderer.customisation = next.parts
			renderer.framing_scale = 0.84
			renderer.position = Vector2(-16384,-16384)
			renderer.size = Vector2(2048,512)
			add_child(renderer)
			frames = 4
			renders += 1
			break
		return
	var current: Object = active.view.get_ref()
	if not is_instance_valid(current) or current.preview_key != active.key:
		_finish()
		return
	frames -= 1
	if frames >= 0:
		renderer.showroom_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		renderer.reflections.request_draw()
	elif not RenderingServer.frame_post_draw.is_connected(_capture):
		RenderingServer.frame_post_draw.connect(_capture,CONNECT_ONE_SHOT)

func _capture() -> void:
	if active.is_empty() or not is_instance_valid(renderer): return
	var view: Object = active.view.get_ref()
	if is_instance_valid(view) and view.preview_key == active.key:
		var image: Image = renderer.showroom_viewport.get_texture().get_image()
		view.publish_preview(active.key,ImageTexture.create_from_image(image))
		if not directory.is_empty() and DirAccess.make_dir_recursive_absolute(directory) == OK:
			var temporary: String = directory.path_join(active.key+".tmp.png")
			if image.save_png(temporary) == OK: DirAccess.rename_absolute(temporary,directory.path_join(active.key+".png"))
			_trim()
	_finish()

func _finish() -> void:
	if RenderingServer.frame_post_draw.is_connected(_capture): RenderingServer.frame_post_draw.disconnect(_capture)
	if is_instance_valid(renderer):
		remove_child(renderer)
		renderer.queue_free()
	renderer = null
	active = {}

func _trim() -> void:
	var folder := DirAccess.open(directory)
	if folder == null: return
	var files: Array[Dictionary] = []
	for name: String in folder.get_files():
		if not name.ends_with(".png") or name.trim_suffix(".png").length()!=64 or not name.trim_suffix(".png").is_valid_hex_number(): continue
		files.append({"name":name,"at":FileAccess.get_modified_time(directory.path_join(name))})
	files.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.at < b.at)
	while files.size() > MAX_FILES: DirAccess.remove_absolute(directory.path_join(files.pop_front().name))
