extends Node
## Profile-style icons: visible rows only, one temporary world, a bounded cache.
const Profile = preload("res://ui/profile_car.gd")
const SIZE := Vector2i(224,152)
const CACHE_LIMIT: int = 24
static var images: Dictionary = {}
var scroll: ScrollContainer
var busy: bool = false
var rendered: int = 0
var peak_worlds: int = 0
var active_worlds: int = 0
var studio: Control
var generation: int = 0
var _jobs: Array[Dictionary] = []
var _current: Dictionary = {}
var _draws: int = 0

func _ready() -> void:
	set_process(false)
	get_parent().visibility_changed.connect(func() -> void:
		if not get_parent().is_visible_in_tree():
			generation += 1
			_jobs.clear()
			_release_studio()
			_stop())

func request(row: Button, vehicle: String, paint: Dictionary, parts: Dictionary) -> void:
	var key: String = "profile-paint-2/"+RenderingServer.get_current_rendering_method()+"/"+JSON.stringify([vehicle,paint,parts]).sha256_text()
	if row.icon_key==key and (row.car_icon.texture!=null or row.get_meta("icon_generation",-1)==generation): return
	row.icon_key = key
	row.set_meta("icon_generation",generation)
	row.set_meta("icon_livery",paint.duplicate(true))
	row.set_meta("icon_parts",parts.duplicate(true))
	if images.has(key):
		row.car_icon.texture = images[key]
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

func _process(_delta: float) -> void:
	if studio!=null: return
	while not _jobs.is_empty():
		var job: Dictionary = _jobs.pop_front()
		var row: Button = job.row.get_ref()
		if job.generation!=generation or not _visible(row) or row.icon_key!=job.key: continue
		if images.has(job.key):
			row.car_icon.texture = images[job.key]
			continue
		_current = job
		studio = Profile.make_preview(job.vehicle,job.paint,job.parts)
		studio.position = Vector2(-10000,-10000)
		studio.size = Vector2(SIZE)*0.5
		add_child(studio)
		active_worlds += 1
		studio.tree_exited.connect(func() -> void: active_worlds -= 1,CONNECT_ONE_SHOT)
		Profile.apply_presentation(studio)
		peak_worlds = maxi(peak_worlds,active_worlds)
		_draws = 5
		return
	_stop()

func _after_draw() -> void:
	if studio==null: return
	_draws -= 1
	if _draws==1:
		# The profile presentation has settled its three radiance draws.
		studio.viewport.size = SIZE
		studio._fit_camera()
		studio.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	elif _draws==0:
		var row: Button = _current.row.get_ref()
		if _current.generation==generation and _visible(row) and row.icon_key==_current.key:
			var pixels: Image = studio.viewport.get_texture().get_image()
			if pixels!=null and not pixels.is_empty():
				pixels.generate_mipmaps()
				var texture := ImageTexture.create_from_image(pixels)
				if images.size()>=CACHE_LIMIT: images.erase(images.keys()[0])
				images[_current.key] = texture
				row.car_icon.texture = texture
				rendered += 1
		_release_studio()

func _release_studio() -> void:
	if is_instance_valid(studio):
		remove_child(studio)
		studio.queue_free()
	studio = null
	_current = {}
	_draws = 0

func _stop() -> void:
	busy = false
	set_process(false)
	if RenderingServer.frame_post_draw.is_connected(_after_draw): RenderingServer.frame_post_draw.disconnect(_after_draw)

func _exit_tree() -> void:
	if RenderingServer.frame_post_draw.is_connected(_after_draw): RenderingServer.frame_post_draw.disconnect(_after_draw)
