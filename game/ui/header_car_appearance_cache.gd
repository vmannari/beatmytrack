extends Node
## One cooperative capture on an equipped-appearance miss, after the first menu.
signal changed(vehicle: String)
signal capture_started(vehicle: String)
signal capture_finished
const Icons = preload("res://ui/header_car_icons.gd")
const Work = preload("res://editor/work_job.gd")
const SIZE := Icons.SIZE
const FILE_LIMIT: int = 14
var records: LocalRecords
var allowed: Callable
# App admits captures in settled idle menus after the live Garage is hidden.
# Standalone tools retain their explicitly supplied `allowed` capture policy.
var capture_allowed: Callable
var directory: String
var captures: int = 0
var disk_hits: int = 0
var peak_worlds: int = 0
var active_worlds: int = 0
var canvas: SubViewport
var studio: Control
var _epoch: int = 0
var _jobs: Array[Dictionary] = []
var _current: Dictionary = {}
var _io: RefCounted
var _io_job: Dictionary = {}
var _io_kind: String = ""
var _draws: int = 0
var _stage: String = ""
var _cover_ready: bool = false
var _capture_announced: bool = false
var _capture_generation: int = 0
var _debounce: Timer
var _retry: Timer
var preparing_selected: bool = false

func _ready() -> void:
	_debounce = Timer.new()
	_debounce.one_shot = true
	_debounce.wait_time = 0.12
	_debounce.timeout.connect(_scan)
	add_child(_debounce)
	_retry = Timer.new()
	_retry.one_shot = true
	_retry.wait_time = 0.10
	_retry.timeout.connect(resume_pending)
	add_child(_retry)
	set_process(false)

func resume_pending() -> void:
	_retry.stop()
	set_process(not _jobs.is_empty() or _io != null or not _current.is_empty())

func _wait_for_opportunity() -> void:
	# Deferred appearances must not hash every saved design on every menu frame.
	set_process(false)
	_retry.start()

func bind_records(value: LocalRecords) -> void:
	if records == value: return
	if records != null and records.appearance_committed.is_connected(_committed): records.appearance_committed.disconnect(_committed)
	_epoch += 1
	_debounce.stop()
	_retry.stop()
	_jobs.clear()
	_current = {}
	_release()
	if _io != null: _io.cancel()
	_io_job = {}
	records = value
	if records != null:
		directory = records.path.get_base_dir().path_join("header_appearance_icons")
		records.appearance_committed.connect(_committed)
		_scan()

func _committed() -> void:
	# Stop displaying an obsolete saved design during the debounce/read window.
	for vehicle: String in VehicleCatalog.IDS: changed.emit(vehicle)
	_debounce.start()

func request_pictures(owner_records: LocalRecords) -> void:
	# A bounded memory entry may have been evicted since the last save/scan.
	# Opening the picker is fresh demand; recover it from disk or queue a capture.
	if owner_records != null and owner_records == records: _scan()

func _scan() -> void:
	if records == null: return
	for vehicle: String in VehicleCatalog.IDS:
		var paint: Dictionary = VehicleLivery.for_car(records.settings,vehicle)
		var parts: Dictionary = VehicleCustomisation.for_car(records.settings,vehicle)
		var key: String = Icons.appearance_key(vehicle,records)
		if paint == VehicleLivery.defaults(vehicle) and parts == VehicleCustomisation.defaults():
			changed.emit(vehicle)
			continue
		if Icons.customized.has(key):
			changed.emit(vehicle)
			continue
		if _current.get("key") == key or _io_job.get("key") == key: continue
		var pending: bool = false
		for job: Dictionary in _jobs:
			if job.key == key: pending = true
		if pending: continue
		for index: int in range(_jobs.size()-1,-1,-1):
			if _jobs[index].vehicle == vehicle: _jobs.remove_at(index)
		_jobs.append({"vehicle":vehicle,"paint":paint,"parts":parts,"key":key,"epoch":_epoch,"read":true})
	resume_pending()

func captures_pending() -> bool:
	# The cache validates queued keys when it wakes; idle coordination must not
	# rehash every saved appearance on every frame of a deferred capture.
	return not _current.is_empty() or not _jobs.is_empty()

func capture_active() -> bool:
	return not _current.is_empty()

func _valid(job: Dictionary) -> bool:
	return not job.is_empty() and records != null and job.epoch == _epoch and job.key == Icons.appearance_key(job.vehicle,records)

func idle() -> bool:
	return _jobs.is_empty() and _io == null and _current.is_empty() and canvas == null and _debounce.is_stopped()

func reads_idle() -> bool:
	return _io == null and _debounce.is_stopped() and not _jobs.any(func(job: Dictionary) -> bool: return bool(job.read))

func _can_capture(job: Dictionary) -> bool:
	return not capture_allowed.is_valid() or bool(capture_allowed.call(str(job.get("vehicle",""))))

func _cover_drawn() -> void:
	_cover_ready = true

func prepare_selected() -> bool:
	if DisplayServer.get_name() == "headless": return Icons.ready(VehicleCatalog.selected,records)
	preparing_selected = true
	var target: String = ""
	var deadline: int = Time.get_ticks_msec()+45000
	while is_inside_tree() and records != null and not Icons.ready(VehicleCatalog.selected,records):
		if Time.get_ticks_msec() >= deadline: break
		var key: String = Icons.appearance_key(VehicleCatalog.selected,records)
		if key != target:
			target = key
			_scan()
			# The visible selection comes before other cars in the dropdown.
			for index: int in range(_jobs.size()):
				if _jobs[index].key == key:
					_jobs.push_front(_jobs.pop_at(index))
					break
		await get_tree().process_frame
	preparing_selected = false
	return Icons.ready(VehicleCatalog.selected,records)

func _process(_delta: float) -> void:
	var permitted: bool = allowed.is_valid() and bool(allowed.call())
	# Keep at most the existing completed job until its consumer is eligible.
	# Invalid owner/appearance results can be discarded without GPU publication.
	if _io != null and _io.done and (permitted or _io_job.is_empty() or _io_job.get("epoch",-1)!=_epoch):
		var result: Dictionary = _io.result if _io.result is Dictionary else {}
		_io = null
		if _valid(_io_job):
			if result.get("image") is Image:
				if _io_kind == "read": disk_hits += 1
				Icons.publish(_io_job.key,result.image)
				changed.emit(_io_job.vehicle)
			elif _io_kind == "read" and DisplayServer.get_name() != "headless":
				_io_job.read = false
				_jobs.push_front(_io_job)
		_io_job = {}
		_io_kind = ""
	if not permitted or (not _current.is_empty() and not _can_capture(_current)):
		if not _current.is_empty():
			if _valid(_current): _jobs.push_front(_current)
			_release()
		if not permitted:
			_wait_for_opportunity()
			return
	if not _current.is_empty() and not _valid(_current): _release()
	if _stage == "cover" and _cover_ready:
		canvas = SubViewport.new()
		canvas.size = SIZE
		canvas.disable_3d = true
		canvas.transparent_bg = true
		canvas.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(canvas)
		studio = load("res://ui/header_icon_renderer.gd").make_preview(_current.vehicle,_current.paint,_current.parts)
		studio.size = Vector2(SIZE)
		studio.cooperative_build = true
		studio.cache_rest_pose = false
		studio.deferred_render = true
		_stage = "build"
		canvas.add_child(studio)
		active_worlds += 1
		canvas.tree_exited.connect(func() -> void: active_worlds -= 1,CONNECT_ONE_SHOT)
		peak_worlds = maxi(peak_worlds,active_worlds)
		# Resource compilation and the first native program can each be costly.
		# Finish this owner-thread build interval before submitting a first draw.
		return
	if _stage == "build" and studio.presentation_ready:
		# One fixed unshaded finish needs no reflective studio/material queue.
		# The second draw lets the 2D canvas resolve the first 3D target.
		_stage = "draw"
		_draws = 2
		RenderingServer.frame_post_draw.connect(_after_draw)
	if _stage == "draw":
		canvas.render_target_update_mode = SubViewport.UPDATE_ONCE
		studio.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	if _current.is_empty() and _io == null:
		# Finish cheap reads before admitting a cold native world. Prioritize the
		# visible selected car within each group, including after foreground return.
		_jobs.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
			if bool(a.read)!=bool(b.read): return bool(a.read)
			return a.vehicle==VehicleCatalog.selected and b.vehicle!=VehicleCatalog.selected)
		# A deferred capture must not prevent another car's cheap disk read.
		var remaining: int = _jobs.size()
		while remaining > 0 and not _jobs.is_empty():
			remaining -= 1
			var job: Dictionary = _jobs.pop_front()
			if not _valid(job): continue
			if Icons.customized.has(job.key): changed.emit(job.vehicle); continue
			if job.read:
				_io_job = job
				_io_kind = "read"
				_io = Work.start(_read.bind(directory.path_join(job.key+".png")),get_tree())
			else:
				if not _can_capture(job):
					_jobs.append(job)
					continue
				_current = job
				_stage = "cover"
				_cover_ready = false
				_capture_announced = true
				capture_started.emit(str(job.vehicle))
				# Finish the settled menu's next draw before loading the renderer
				# resource or constructing its native model.
				RenderingServer.frame_post_draw.connect(_cover_drawn,CONNECT_ONE_SHOT)
			break
	if idle(): set_process(false)
	elif _current.is_empty() and _io == null: _wait_for_opportunity()

func _after_draw() -> void:
	if canvas == null or _stage != "draw": return
	if not allowed.is_valid() or not bool(allowed.call()) or not _can_capture(_current):
		if _valid(_current): _jobs.push_front(_current)
		_release()
		return
	_draws -= 1
	if _draws > 0: return
	if _valid(_current):
		var pixels: Image = canvas.get_texture().get_image()
		captures += 1
		_io_job = _current
		_io_kind = "write"
		_io = Work.start(_write.bind(directory,_current.key,pixels,_saved_picture_keys()),get_tree())
	_release()

func _saved_picture_keys() -> PackedStringArray:
	# Keep every current car when one design creates many historical versions.
	# Snapshot on the owner thread; the file worker never reads player records.
	var keys := PackedStringArray()
	if records != null:
		for vehicle: String in VehicleCatalog.IDS: keys.append(Icons.appearance_key(vehicle,records))
	return keys

func _release() -> void:
	_capture_generation += 1
	if RenderingServer.frame_post_draw.is_connected(_cover_drawn): RenderingServer.frame_post_draw.disconnect(_cover_drawn)
	if RenderingServer.frame_post_draw.is_connected(_after_draw): RenderingServer.frame_post_draw.disconnect(_after_draw)
	if is_instance_valid(canvas):
		remove_child(canvas)
		canvas.queue_free()
	canvas = null
	studio = null
	_current = {}
	_stage = ""
	_cover_ready = false
	if _capture_announced:
		_capture_announced = false
		capture_finished.emit()

func _exit_tree() -> void:
	preparing_selected = false
	if records != null and records.appearance_committed.is_connected(_committed): records.appearance_committed.disconnect(_committed)
	if is_instance_valid(_debounce): _debounce.stop()
	if is_instance_valid(_retry): _retry.stop()
	_release()
	if _io != null: _io.cancel()
	_io = null
	_io_job.clear()
	_jobs.clear()
	records = null
	allowed = Callable()
	capture_allowed = Callable()

static func _read(cancelled: Callable, path: String) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > SIZE.x*SIZE.y*4+65536 or cancelled.call(): return {}
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	if bytes.size()<33 or bytes.slice(0,8)!=PackedByteArray([137,80,78,71,13,10,26,10]) or bytes.slice(16,24)!=PackedByteArray([0,0,2,0,0,0,1,32]): return {}
	var pixels := Image.new()
	if pixels.load_png_from_buffer(bytes)!=OK or pixels.get_size()!=SIZE: return {}
	return {"image":pixels}

static func _write(cancelled: Callable, path: String, key: String, pixels: Image, saved_keys: PackedStringArray = PackedStringArray()) -> Dictionary:
	pixels.convert(Image.FORMAT_RGBA8)
	for y: int in range(SIZE.y):
		if cancelled.call(): return {}
		for x: int in range(SIZE.x):
			var color: Color = pixels.get_pixel(x,y)
			if color.a > 0 and color.a < 1:
				pixels.set_pixel(x,y,Color(minf(1,color.r/color.a),minf(1,color.g/color.a),minf(1,color.b/color.a),color.a))
	if DirAccess.make_dir_recursive_absolute(path)!=OK: return {"image":pixels}
	var destination: String = path.path_join(key+".png")
	var temporary: String = path.path_join(key+"-"+str(Time.get_ticks_usec())+".tmp.png")
	if pixels.save_png(temporary)==OK:
		if cancelled.call():
			DirAccess.remove_absolute(temporary)
			return {}
		if FileAccess.file_exists(destination): DirAccess.remove_absolute(destination)
		if DirAccess.rename_absolute(temporary,destination)!=OK: DirAccess.remove_absolute(temporary)
	var folder := DirAccess.open(path)
	if folder == null: return {} if cancelled.call() else {"image":pixels}
	var files: Array[Dictionary] = []
	for name: String in folder.get_files():
		if name.ends_with(".png") and name.trim_suffix(".png").length()==64 and name.trim_suffix(".png").is_valid_hex_number(): files.append({"name":name,"time":FileAccess.get_modified_time(path.path_join(name))})
	files.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.time<b.time)
	var excess: int = files.size()-FILE_LIMIT
	for file: Dictionary in files:
		if excess <= 0: break
		if file.name.trim_suffix(".png") in saved_keys: continue
		if DirAccess.remove_absolute(path.path_join(file.name)) == OK: excess -= 1
	return {} if cancelled.call() else {"image":pixels}
