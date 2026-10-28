extends Node
## A single temporary studio prepares painted option photos, then releases its world.
const SIZE := Vector2i(320,208)
var _jobs: Array[Dictionary] = []
var busy: bool = false
var viewport: SubViewport
var car: CarVisual
var camera: Camera3D
var rendered: int = 0
var active_worlds: int = 0
var peak_worlds: int = 0

func request(card: CompactKitThumbnail, category: String, option: String, paint: Dictionary, fitted: Dictionary) -> void:
	var parts: Dictionary = fitted.duplicate(true)
	parts[category] = option
	var key: String = "painted-part-1/"+RenderingServer.get_current_rendering_method()+"/"+JSON.stringify([category,paint,parts]).sha256_text()
	card.cache_key = key
	card.set_meta("photo_livery",paint.duplicate(true))
	card.set_meta("photo_parts",parts)
	if CompactKitThumbnail.images.has(key):
		card.image.texture = CompactKitThumbnail.images[key]
		return
	if DisplayServer.get_name() == "headless": return
	# Avoid briefly showing a different paint job while this bounded job is pending.
	card.image.texture = null
	# Replace stale work for this card and discard detached category requests.
	for index: int in range(_jobs.size()-1,-1,-1):
		var waiting: CompactKitThumbnail = _jobs[index].card.get_ref()
		if not is_instance_valid(waiting) or not waiting.is_inside_tree() or waiting==card:
			_jobs.remove_at(index)
	_jobs.append({"card":weakref(card),"category":category,"paint":paint.duplicate(true),"parts":parts,"key":key})
	if not busy:
		busy = true
		_drain.call_deferred()

func _drain() -> void:
	while not _jobs.is_empty() and is_inside_tree() and (get_parent() as Control).is_visible_in_tree():
		var job: Dictionary = _jobs.pop_front()
		var tile: CompactKitThumbnail = job.card.get_ref()
		if not is_instance_valid(tile) or not tile.is_inside_tree(): continue
		if viewport == null: _create_studio(job.paint,job.parts)
		else:
			car.graphics.restore_originals()
			car.change_kit_parts(job.parts)
			car.apply_livery(job.paint)
			ShowroomStudio._studio_glass(car,{})
		pose(camera,str(job.category),Transform3D.IDENTITY)
		# One submission after transforms settle; no continuously rendered thumbnails.
		await RenderingServer.frame_post_draw
		if not is_inside_tree(): return
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		if not is_inside_tree(): return
		var pixels: Image = viewport.get_texture().get_image()
		if pixels == null or pixels.is_empty(): continue
		pixels.generate_mipmaps()
		var texture: ImageTexture = ImageTexture.create_from_image(pixels)
		if CompactKitThumbnail.images.size() >= CompactKitThumbnail.CACHE_LIMIT:
			CompactKitThumbnail.images.erase(CompactKitThumbnail.images.keys()[0])
		CompactKitThumbnail.images[job.key] = texture
		rendered += 1
		tile = job.card.get_ref()
		if is_instance_valid(tile) and tile.is_inside_tree() and tile.cache_key == job.key:
			tile.image.texture = texture
	_jobs.clear()
	_release_studio()
	busy = false

func _create_studio(paint: Dictionary, parts: Dictionary) -> void:
	viewport = SubViewport.new()
	viewport.name = "GarageOptionPhotoStudio"
	viewport.size = SIZE
	viewport.own_world_3d = true
	viewport.gui_disable_input = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	active_worlds += 1
	peak_worlds = maxi(peak_worlds,active_worlds)
	var world := Node3D.new()
	viewport.add_child(world)
	car = CarVisual.new()
	car.editable_kits = true
	car.livery = paint
	car.customisation = parts
	world.add_child(car)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("101b23")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d6dbe0")
	environment.environment.ambient_light_energy = 0.65
	world.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-55,-35,0)
	key.light_color = Color("fff2e0")
	key.light_energy = 0.9
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25,145,0)
	fill.light_color = Color("c5d3df")
	fill.light_energy = 0.32
	world.add_child(fill)
	ShowroomStudio._studio_glass(car,{})
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	world.add_child(camera)
	camera.current = true

static func pose(view: Camera3D, category: String, frame: Transform3D) -> void:
	var target: Vector3
	var direction: Vector3
	match category:
		"hood":
			target = Vector3(0,1.0,-1.45)
			direction = Vector3(1.8,2.5,-3.5)
			view.size = 1.15
		"aero":
			target = Vector3(0,1.39,1.84)
			direction = Vector3(3,0.95,3)
			view.size = 1.65
		"rims":
			target = Vector3(0.83,0.37,-1.28)
			direction = Vector3(4,0.8,-0.8)
			view.size = 0.95
		_:
			target = Vector3(0,0.45,0)
			direction = Vector3(3,1.1,-4)
			view.size = 1.85
	var world_target: Vector3 = frame*(target*HandlingConfig.BODY_SCALE)
	view.look_at_from_position(world_target+frame.basis*direction,world_target)
	view.keep_aspect = Camera3D.KEEP_HEIGHT

func _release_studio() -> void:
	if is_instance_valid(viewport):
		remove_child(viewport)
		viewport.queue_free()
	viewport = null
	car = null
	camera = null
	active_worlds = 0
