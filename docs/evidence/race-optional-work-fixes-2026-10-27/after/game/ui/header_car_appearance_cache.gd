extends Node
## One cooperative capture on an equipped-appearance miss; menu visits read PNGs.
signal changed(vehicle: String)
const Icons = preload("res://ui/header_car_icons.gd")
const Work = preload("res://editor/work_job.gd")
const SIZE := Vector2i(176,112)
const FILE_LIMIT: int = 14
var records: LocalRecords
var allowed: Callable
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
var _debounce: Timer

func _ready() -> void:
	_debounce = Timer.new()
	_debounce.one_shot = true
	_debounce.wait_time = 0.35
	_debounce.timeout.connect(_scan)
	add_child(_debounce)
	set_process(false)

func bind_records(value: LocalRecords) -> void:
	if records == value: return
	if records != null and records.appearance_committed.is_connected(_committed): records.appearance_committed.disconnect(_committed)
	_epoch += 1
	_debounce.stop()
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
	_debounce.start()

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
	set_process(not _jobs.is_empty() or _io != null or canvas != null)

func _valid(job: Dictionary) -> bool:
	return not job.is_empty() and records != null and job.epoch == _epoch and job.key == Icons.appearance_key(job.vehicle,records)

func idle() -> bool:
	return _jobs.is_empty() and _io == null and canvas == null and _debounce.is_stopped()

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
	if not permitted:
		if canvas != null:
			if _valid(_current): _jobs.push_front(_current)
			_release()
		return
	if canvas != null and not _valid(_current): _release()
	if _stage == "build" and studio.presentation_ready:
		load("res://ui/profile_car.gd").apply_presentation(studio)
		_stage = "draw"
		_draws = 5
		RenderingServer.frame_post_draw.connect(_after_draw)
	if _stage == "draw":
		canvas.render_target_update_mode = SubViewport.UPDATE_ONCE
		studio.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	if canvas == null and _io == null:
		while not _jobs.is_empty():
			var job: Dictionary = _jobs.pop_front()
			if not _valid(job): continue
			if Icons.customized.has(job.key): changed.emit(job.vehicle); continue
			if job.read:
				_io_job = job
				_io_kind = "read"
				_io = Work.start(_read.bind(directory.path_join(job.key+".png")),get_tree())
			else:
				_current = job
				canvas = SubViewport.new()
				canvas.size = SIZE
				canvas.disable_3d = true
				canvas.transparent_bg = true
				canvas.render_target_update_mode = SubViewport.UPDATE_DISABLED
				add_child(canvas)
				studio = load("res://ui/profile_car.gd").make_preview(job.vehicle,job.paint,job.parts)
				studio.size = Vector2(SIZE)
				studio.cooperative_build = true
				studio.cache_rest_pose = false
				_stage = "build"
				canvas.add_child(studio)
				active_worlds += 1
				canvas.tree_exited.connect(func() -> void: active_worlds -= 1,CONNECT_ONE_SHOT)
				peak_worlds = maxi(peak_worlds,active_worlds)
			break
	if idle(): set_process(false)

func _after_draw() -> void:
	if canvas == null or _stage != "draw": return
	if not allowed.is_valid() or not bool(allowed.call()):
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
		_io = Work.start(_write.bind(directory,_current.key,pixels),get_tree())
	_release()

func _release() -> void:
	if RenderingServer.frame_post_draw.is_connected(_after_draw): RenderingServer.frame_post_draw.disconnect(_after_draw)
	if is_instance_valid(canvas):
		remove_child(canvas)
		canvas.queue_free()
	canvas = null
	studio = null
	_current = {}
	_stage = ""

func _exit_tree() -> void:
	if records != null and records.appearance_committed.is_connected(_committed): records.appearance_committed.disconnect(_committed)
	if is_instance_valid(_debounce): _debounce.stop()
	_release()
	if _io != null: _io.cancel()
	_io = null
	_io_job.clear()
	_jobs.clear()
	records = null
	allowed = Callable()

static func _read(cancelled: Callable, path: String) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > 131072 or cancelled.call(): return {}
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	if bytes.size()<33 or bytes.slice(0,8)!=PackedByteArray([137,80,78,71,13,10,26,10]) or bytes.slice(16,24)!=PackedByteArray([0,0,0,176,0,0,0,112]): return {}
	var pixels := Image.new()
	if pixels.load_png_from_buffer(bytes)!=OK or pixels.get_size()!=SIZE: return {}
	return {"image":pixels}

static func _write(cancelled: Callable, path: String, key: String, pixels: Image) -> Dictionary:
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
	while files.size()>FILE_LIMIT: DirAccess.remove_absolute(path.path_join(files.pop_front().name))
	return {} if cancelled.call() else {"image":pixels}
