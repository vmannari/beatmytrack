extends CarShowroom
## Offline preview: same showroom, observed source construction.
func _ready() -> void:
	if read_only: set_process(false)
	if garage_mode: elevation = atan(0.16)
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE if read_only else Control.MOUSE_FILTER_STOP
	var viewport := SubViewport.new()
	showroom_viewport = viewport
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.msaa_3d = Viewport.MSAA_2X if read_only and not preview_live_lighting else Viewport.MSAA_4X
	viewport.scaling_3d_scale = 1.0
	# Prepared meshes retain full detail and use subpixel index-only LODs.
	viewport.mesh_lod_threshold = 0.5
	# Render at display pixel density, including canvas/window scaling.
	# The standalone viewport also keeps carousel renders genuinely one-shot.
	var holder := Node.new()
	holder.name = "ThumbnailWorld" if read_only else "ShowroomWorld"
	add_child(holder)
	holder.add_child(viewport)
	var image := TextureRect.new()
	image.name = "ModelRender"
	image.texture = viewport.get_texture()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(image)
	MenuStyle.fill(image)
	var world := Node3D.new()
	viewport.add_child(world)
	car = preload("res://tests/support/car_pass12_source.gd").new()
	car.vehicle_id = vehicle_id
	car.simple_model = simple_model
	car.garage_template = garage_mode
	car.editable_kits = garage_mode and VehicleCustomisation.supported(vehicle_id)
	car.livery = livery
	car.customisation = customisation
	car.cooperative_build = cooperative_build
	if cooperative_build: viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	world.add_child(car)
	while not car.model_ready:
		await get_tree().process_frame
		if not is_inside_tree() or is_queued_for_deletion(): return
	if garage_mode:
		turntable = GarageEnvironment.build(world, car, read_only and not preview_live_lighting)
		_configure_car_shadows()
	else: ShowroomStudio.build(world,car)
	if garage_mode: roof = world.find_child("GarageRoof",true,false)
	if garage_mode and not read_only: record_station = world.find_child("GarageRecordStation",true,false)
	if record_station != null: record_vinyl = record_station.find_child("GarageVinyl",true,false)
	if record_station != null: record_sleeves = record_station.find_child("GarageRecordSleeves",true,false)
	weathering.configure(car, "pine", VehicleCatalog.config(vehicle_id))
	weathering.restore(condition)
	camera = Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 40.0 if garage_mode and not read_only else 38.0
	camera.current = true
	_orbit()
	if garage_mode:
		reflections = GarageReflections.new()
		reflections.build(self,world,turntable)
	if not read_only: gui_input.connect(_drag)
	else:
		set_process(false)
	resized.connect(refresh_thumbnail)
	visibility_changed.connect(refresh_thumbnail)
	get_viewport().size_changed.connect(refresh_thumbnail)
	visibility_changed.connect(_clear_gesture)
	visibility_changed.connect(_reflection_visibility)
	refresh_thumbnail()
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	if not read_only and not garage_mode: _cache_pick_meshes(car)
	showroom_ready = true
