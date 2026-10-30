extends Node
## One reusable model on a cold miss; cached icons are ordinary 2D images.
const Profile = preload("res://ui/profile_car.gd")
const Work = preload("res://editor/work_job.gd")
const Build = preload("res://core/build_identity.gd")
const SIZE := Vector2i(224,152)
const CACHE_LIMIT: int = 24
const FILE_LIMIT: int = 196
const FILE_BYTES: int = 262144
const BATCH_SIZE: int = 8
const VERSION: String = "profile-paint-3"
static var images: Dictionary = {}
var cache_directory: String = ProjectSettings.globalize_path("user://cache/garage_paint_icons_v3")
var scroll: ScrollContainer
var busy: bool = false
var rendered: int = 0
var peak_worlds: int = 0
var active_worlds: int = 0
var studio: Control
var generation: int = 0
var model_builds: int = 0
var repaints: int = 0
var disk_hits: int = 0
var memory_hits: int = 0
var build_us: int = 0
var repaint_us: int = 0
var readback_us: int = 0
var io_us: int = 0
var _jobs: Array[Dictionary] = []
var _current: Dictionary = {}
var _draws: int = 0
var _stage: String = ""
var _studio_identity: Array = []
var _io: RefCounted
var _fit_pending: bool = false
var _draw_jobs: Array[Dictionary] = []
var _read_jobs: Array[Dictionary] = []
var _write_jobs: Array[Dictionary] = []
var _io_kind: String = ""
var read_batches: int = 0
var write_batches: int = 0
var peak_write_queue: int = 0
var _build_started: int = 0

func _ready() -> void:
	set_process(false)
	get_parent().visibility_changed.connect(func() -> void:
		if not get_parent().is_visible_in_tree(): _cancel())

func identity(vehicle: String, paint: Dictionary, parts: Dictionary) -> String:
	return JSON.stringify([VERSION,Build.ID,RenderingServer.get_current_rendering_method(),vehicle,paint,parts]).sha256_text()

func request(row: Button, vehicle: String, paint: Dictionary, parts: Dictionary) -> void:
	var key: String = identity(vehicle,paint,parts)
	if row.icon_key==key and (row.car_icon.texture!=null or row.get_meta("icon_generation",-1)==generation): return
	row.icon_key = key
	row.set_meta("icon_generation",generation)
	row.set_meta("icon_livery",paint.duplicate(true))
	row.set_meta("icon_parts",parts.duplicate(true))
	if images.has(key):
		row.car_icon.texture = images[key]
		memory_hits += 1
		return
	row.car_icon.texture = null
	if DisplayServer.get_name()=="headless": return
	for index: int in range(_jobs.size()-1,-1,-1):
		if _jobs[index].row.get_ref()==row: _jobs.remove_at(index)
	_jobs.append({"row":weakref(row),"vehicle":vehicle,"paint":paint.duplicate(true),"parts":parts.duplicate(true),"key":key,"generation":generation})
	if not busy:
		busy = true
		set_process(true)
		if not RenderingServer.frame_post_draw.is_connected(_after_draw): RenderingServer.frame_post_draw.connect(_after_draw)

func _visible(row: Control) -> bool:
	return is_instance_valid(row) and row.is_inside_tree() and row.is_visible_in_tree() and is_instance_valid(scroll) and scroll.get_global_rect().intersects(row.get_global_rect())

func _valid(job: Dictionary) -> bool:
	if job.is_empty(): return false
	var row: Button = job.row.get_ref()
	return job.generation==generation and _visible(row) and row.icon_key==job.key

func _process(_delta: float) -> void:
	if _io!=null and _io.done:
		var result: Dictionary = _io.result if _io.result is Dictionary else {}
		io_us += int(result.get("us",0))
		_io = null
		if _io_kind=="read":
			var decoded: Dictionary = result.get("images",{})
			for job: Dictionary in _read_jobs:
				if not _valid(job): continue
				if decoded.get(job.key) is Image:
					disk_hits += 1
					_publish(job,decoded[job.key])
				else: _draw_jobs.append(job)
			_read_jobs.clear()
		_io_kind = ""
	if _stage=="build" and is_instance_valid(studio) and studio.presentation_ready:
		Profile.apply_presentation(studio)
		build_us += Time.get_ticks_usec()-_build_started
		_fit_pending = true
		_draws = 5
		_stage = "draw"
	if _stage.is_empty() and _write_jobs.size()<BATCH_SIZE:
		while not _draw_jobs.is_empty():
			var job: Dictionary = _draw_jobs.pop_front()
			if not _valid(job): continue
			if images.has(job.key):
				job.row.get_ref().car_icon.texture = images[job.key]
				memory_hits += 1
				continue
			_current = job
			_render_current()
			break
	if _io==null:
		if _draw_jobs.is_empty() and not _jobs.is_empty():
			var keys: Array[String] = []
			while not _jobs.is_empty() and _read_jobs.size()<BATCH_SIZE:
				var job: Dictionary = _jobs.pop_front()
				if not _valid(job): continue
				if images.has(job.key):
					job.row.get_ref().car_icon.texture = images[job.key]
					memory_hits += 1
					continue
				if cache_directory.is_empty(): _draw_jobs.append(job)
				else:
					_read_jobs.append(job)
					keys.append(job.key)
			if not keys.is_empty():
				_io_kind = "read"
				read_batches += 1
				_io = Work.start(_read_batch.bind(cache_directory,keys),get_tree())
		if _io==null and not _write_jobs.is_empty() and ((_draw_jobs.is_empty() and _stage.is_empty()) or _write_jobs.size()>=BATCH_SIZE):
			var batch: Array[Dictionary] = _write_jobs.duplicate()
			_write_jobs.clear()
			_io_kind = "write"
			write_batches += 1
			_io = Work.start(_write_batch.bind(cache_directory,batch),get_tree())
	if _stage.is_empty() and _io==null and _jobs.is_empty() and _draw_jobs.is_empty() and _write_jobs.is_empty(): _stop()

func _render_current() -> void:
	if not _valid(_current):
		_current = {}
		_stage = ""
		return
	var signature: Array = [_current.vehicle,_current.parts]
	var at: int = Time.get_ticks_usec()
	if not is_instance_valid(studio) or signature!=_studio_identity:
		_release_studio()
		_studio_identity = signature.duplicate(true)
		studio = Profile.make_preview(_current.vehicle,_current.paint,_current.parts)
		studio.position = Vector2(-10000,-10000)
		studio.size = Vector2(SIZE)*0.5
		studio.cooperative_build = true
		studio.cache_rest_pose = false
		_build_started = at
		add_child(studio)
		active_worlds += 1
		studio.tree_exited.connect(func() -> void: active_worlds -= 1,CONNECT_ONE_SHOT)
		peak_worlds = maxi(peak_worlds,active_worlds)
		model_builds += 1
		_stage = "build"
		return
	else:
		Profile.repaint_preview(studio,_current.paint)
		repaints += 1
		repaint_us += Time.get_ticks_usec()-at
		_draws = 2
		studio.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_stage = "draw"

func _after_draw() -> void:
	if _stage!="draw" or not is_instance_valid(studio): return
	_draws -= 1
	if _draws==1:
		if _fit_pending or studio.viewport.size!=SIZE:
			studio.viewport.size = SIZE
			studio._fit_camera()
			_fit_pending = false
		studio.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	elif _draws==0:
		studio.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		if _valid(_current):
			var at: int = Time.get_ticks_usec()
			var pixels: Image = studio.viewport.get_texture().get_image()
			readback_us += Time.get_ticks_usec()-at
			if pixels!=null and not pixels.is_empty():
				var key: String = _current.key
				rendered += 1
				_publish(_current,pixels)
				_current = {}
				_stage = ""
				if not cache_directory.is_empty():
					_write_jobs.append({"key":key,"image":pixels})
					peak_write_queue = maxi(peak_write_queue,_write_jobs.size())
				return
		_current = {}
		_stage = ""

func _publish(job: Dictionary, pixels: Image) -> void:
	pixels.generate_mipmaps()
	var texture := ImageTexture.create_from_image(pixels)
	if images.size()>=CACHE_LIMIT: images.erase(images.keys()[0])
	images[job.key] = texture
	if _valid(job): job.row.get_ref().car_icon.texture = texture

func _release_studio() -> void:
	if is_instance_valid(studio):
		remove_child(studio)
		studio.queue_free()
	studio = null
	_studio_identity = []
	_fit_pending = false

func _stop() -> void:
	busy = false
	set_process(false)
	if is_instance_valid(studio): studio.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if RenderingServer.frame_post_draw.is_connected(_after_draw): RenderingServer.frame_post_draw.disconnect(_after_draw)

func _cancel() -> void:
	generation += 1
	_jobs.clear()
	_draw_jobs.clear()
	_read_jobs.clear()
	_write_jobs.clear()
	_io_kind = ""
	_current = {}
	_stage = ""
	if _io!=null: _io.cancel()
	_io = null
	_release_studio()
	_stop()

func _exit_tree() -> void:
	_cancel()

static func _read(cancelled: Callable, path: String) -> Dictionary:
	var at: int = Time.get_ticks_usec()
	var image: Image
	var file := FileAccess.open(path,FileAccess.READ)
	if file!=null and file.get_length()<=FILE_BYTES and not cancelled.call():
		var bytes: PackedByteArray = file.get_buffer(file.get_length())
		if bytes.size()>=33 and bytes.slice(0,8)==PackedByteArray([137,80,78,71,13,10,26,10]) and bytes.slice(16,24)==PackedByteArray([0,0,0,224,0,0,0,152]):
			var candidate := Image.new()
			if candidate.load_png_from_buffer(bytes)==OK and candidate.get_size()==SIZE: image = candidate
	return {"image":image,"us":Time.get_ticks_usec()-at}

static func _write(cancelled: Callable, directory: String, key: String, image: Image, trim_cache: bool = true) -> Dictionary:
	var at: int = Time.get_ticks_usec()
	if not cancelled.call() and DirAccess.make_dir_recursive_absolute(directory)==OK:
		var destination: String = directory.path_join(key+".png")
		var temporary: String = directory.path_join(key+"-"+str(at)+".tmp")
		var bytes: PackedByteArray = image.save_png_to_buffer()
		var file := FileAccess.open(temporary,FileAccess.WRITE)
		if file!=null:
			file.store_buffer(bytes)
			file.close()
			if not cancelled.call():
				if FileAccess.file_exists(destination): DirAccess.remove_absolute(destination)
				DirAccess.rename_absolute(temporary,destination)
			else: DirAccess.remove_absolute(temporary)
		if trim_cache: _trim(directory)
	return {"us":Time.get_ticks_usec()-at}

static func _trim(directory: String) -> void:
	var folder := DirAccess.open(directory)
	if folder==null: return
	var files: Array[Dictionary] = []
	for name: String in folder.get_files():
		if not name.ends_with(".png") or name.trim_suffix(".png").length()!=64 or not name.trim_suffix(".png").is_valid_hex_number(): continue
		files.append({"name":name,"at":FileAccess.get_modified_time(directory.path_join(name))})
	files.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.at<b.at)
	while files.size()>FILE_LIMIT: DirAccess.remove_absolute(directory.path_join(files.pop_front().name))

static func _read_batch(cancelled: Callable, directory: String, keys: Array[String]) -> Dictionary:
	var at: int = Time.get_ticks_usec()
	var decoded: Dictionary = {}
	for key: String in keys:
		if cancelled.call(): break
		var result: Dictionary = _read(cancelled,directory.path_join(key+".png"))
		if result.image is Image: decoded[key] = result.image
	return {"images":decoded,"us":Time.get_ticks_usec()-at}

static func _write_batch(cancelled: Callable, directory: String, jobs: Array[Dictionary]) -> Dictionary:
	var at: int = Time.get_ticks_usec()
	for job: Dictionary in jobs:
		if cancelled.call(): break
		_write(cancelled,directory,job.key,job.image,false)
	_trim(directory)
	return {"us":Time.get_ticks_usec()-at}
