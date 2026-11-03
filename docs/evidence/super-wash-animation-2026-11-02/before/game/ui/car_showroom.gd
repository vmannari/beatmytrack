class_name CarShowroom
extends SubViewportContainer
## Menu-only orbit camera over the actual race model. No simulation ownership.
signal condition_changed
signal trophy_tapped(position: Vector2)
const PaintTransition = preload("res://ui/garage_paint_transition.gd")
const KitTransition = preload("res://ui/garage_kit_transition.gd")
var _wall_press := Vector2.INF
var _wall_pointer: int = -2
var condition: Dictionary = {}
var weathering := VehicleWeathering.new()
var wash_mode: bool = false
var wash_tool: String = "mitt"
var washing: bool = false
var wash_pointer := Vector2.ZERO
var wash_previous := Vector2.ZERO
var wash_pointer_valid: bool = false
var wash_elapsed: float = 0.0
var wash_effect: Node3D
var pick_meshes: Array[Dictionary] = []
var vehicle_id: String = "compact"
var read_only: bool = false
var preview_live_lighting: bool = false
var cooperative_build: bool = false
var showroom_ready: bool = false
var garage_mode: bool = false
var turntable: Node3D
var roof: Node3D
var reflections: GarageReflections
var trophy_view: bool = false
var record_view: bool = false
var record_station: Node3D
var record_vinyl: Node3D
var record_sleeves: Node3D
var _record_settings: PackedByteArray = PackedByteArray()
var _browse_position: float = NAN
var camera_motion: Tween
var customisation_orbit: Callable
var car_motion: Tween
var outgoing_pedestal: Node3D
var incoming_reveal: GarageCarReveal
var outgoing_reveal: GarageCarReveal
var paint_motion: Tween
var paint_transition: PaintTransition
var kit_motion: Tween
var kit_transition: KitTransition
var interaction_inset_top: float = 0.0
var interaction_inset_bottom: float = 0.0
var framing_scale: float = 1.0
var livery: Dictionary = {}
var customisation: Dictionary = {}
var car: CarVisual
var camera: Camera3D
var showroom_viewport: SubViewport
var yaw: float = -0.70
var pointer: int = -1
var elevation: float = atan(0.32)
var zoom: float = 1.0
var garage_distance: float = 0.0
var touches: Dictionary = {}
var pinch_distance: float = 0.0
var resume_orbit: bool = false
var _render_dirty: bool = true
var _last_render_state: Array = []
var render_requests: int = 0
var _settle_draws: int = 0
var _reflection_settle_draws: int = 0
var _record_visibility_state: Array = []
var _record_visible: bool = true
var _weather_visibility_state: Array = []
var _weather_visible: bool = true
var _last_wash_cursor_state: Array = []
const DEFAULT_YAW: float = -0.70
const GARAGE_CAMERA_YAW: float = 0.0
const MIN_ELEVATION: float = PI / 36.0 # 5 degrees, always above the floor.
const MAX_ELEVATION: float = PI * 4.0 / 9.0 # 80 degrees.
const MIN_ZOOM: float = 0.48
const MAX_ZOOM: float = 1.80
const CAR_HIDE_SECONDS: float = 0.26
const CAR_REVEAL_SECONDS: float = 0.38

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
	car = CarVisual.new()
	car.vehicle_id = vehicle_id
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
	if garage_mode: turntable = GarageEnvironment.build(world, car, read_only and not preview_live_lighting)
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

func refresh_thumbnail() -> void:
	if not is_instance_valid(showroom_viewport): return
	var screen: Transform2D = get_viewport().get_stretch_transform() * get_screen_transform()
	var pixels := size * Vector2(screen.x.length(),screen.y.length())
	var limit: float = minf(1.0,minf(2560.0/maxf(1.0,pixels.x),1440.0/maxf(1.0,pixels.y)))
	showroom_viewport.size = Vector2i(maxi(1,roundi(pixels.x*limit)),maxi(1,roundi(pixels.y*limit)))
	if read_only: showroom_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
	invalidate_render()

func replace_car(id: String, paint: Dictionary, wear: Dictionary, parts: Dictionary = {}) -> void:
	finish_kit_transition()
	finish_paint_transition()
	finish_car_transition()
	_clear_gesture()
	var previous_deck: Node3D = turntable
	previous_deck.name = "OutgoingTurntable"
	var previous_car: CarVisual = car
	var world: Node3D = camera.get_parent()
	vehicle_id = id
	livery = paint.duplicate(true)
	condition = wear.duplicate(true)
	customisation = parts.duplicate(true) if VehicleCustomisation.valid(parts,id) else VehicleCustomisation.defaults()
	car = CarVisual.new()
	car.vehicle_id = id
	car.garage_template = garage_mode
	car.editable_kits = garage_mode and VehicleCustomisation.supported(id)
	car.livery = livery
	car.customisation = customisation
	world.add_child(car)
	turntable = GarageEnvironment.build_pedestal(world,car)
	if reflections != null: reflections.mark_stage(turntable)
	weathering = VehicleWeathering.new()
	weathering.configure(car,"pine",VehicleCatalog.config(id))
	weathering.restore(condition)
	pick_meshes.clear()
	# Garage browsing does not need wash collision triangles. Build them on the
	# first pick, just as the initial Garage showroom does.
	if not read_only and not garage_mode: _cache_pick_meshes(car)
	_orbit()
	if not is_visible_in_tree():
		previous_deck.queue_free()
		return
	outgoing_pedestal = previous_deck
	outgoing_reveal = GarageCarReveal.new()
	_prepare_car_reveal(outgoing_reveal,previous_car,previous_deck)
	incoming_reveal = GarageCarReveal.new()
	_prepare_car_reveal(incoming_reveal,car,turntable)
	incoming_reveal.set_visibility(0.0)
	turntable.hide()
	car_motion = create_tween()
	car_motion.tween_method(outgoing_reveal.set_visibility,1.0,0.0,CAR_HIDE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	car_motion.tween_callback(_exchange_pedestals)
	car_motion.tween_method(incoming_reveal.set_visibility,0.0,1.0,CAR_REVEAL_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	car_motion.tween_callback(finish_car_transition)
	if read_only: set_process(true)

func apply_customisation(value: Dictionary, animate_kit: bool = false) -> void:
	if not VehicleCustomisation.supported(vehicle_id) or not VehicleCustomisation.valid(value,vehicle_id): return
	if customisation==value:
		if not animate_kit: finish_kit_transition()
		return
	finish_kit_transition()
	finish_paint_transition()
	finish_car_transition()
	set_wash_mode(false)
	var sweep: KitTransition
	if animate_kit and garage_mode and not read_only and is_visible_in_tree() and car.editable_kits:
		sweep = KitTransition.new()
		sweep.capture(car,value)
	customisation = value.duplicate(true)
	condition = weathering.snapshot()
	if car.editable_kits:
		weathering.reset()
		car.graphics.restore_originals()
		car.change_kit_parts(value)
		if reflections!=null: reflections.mark_stage(turntable)
		weathering = VehicleWeathering.new()
		weathering.configure(car,"pine",VehicleCatalog.config(vehicle_id))
		weathering.restore(condition)
		pick_meshes.clear()
		if not read_only and not garage_mode: _cache_pick_meshes(car)
		if sweep!=null:
			kit_transition = sweep
			sweep.install(car)
			kit_motion = create_tween()
			kit_motion.tween_method(sweep.set_progress,0.0,1.0,KitTransition.SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			kit_motion.tween_callback(finish_kit_transition)
		refresh_thumbnail()
		return
	var previous: CarVisual = car
	car = CarVisual.new()
	car.vehicle_id = vehicle_id
	car.livery = livery
	car.customisation = customisation
	previous.get_parent().add_child(car)
	car.transform = previous.transform
	previous.get_parent().remove_child(previous)
	previous.queue_free()
	ShowroomStudio._studio_glass(car,{})
	if reflections != null: reflections.mark_stage(turntable)
	weathering = VehicleWeathering.new()
	weathering.configure(car,"pine",VehicleCatalog.config(vehicle_id))
	weathering.restore(condition)
	pick_meshes.clear()
	if not read_only and not garage_mode: _cache_pick_meshes(car)
	refresh_thumbnail()

func finish_kit_transition() -> void:
	if kit_motion!=null: kit_motion.kill()
	kit_motion = null
	if kit_transition!=null: kit_transition.restore()
	kit_transition = null
	invalidate_render()

func _prepare_car_reveal(reveal: GarageCarReveal, model: CarVisual, deck: Node3D) -> void:
	reveal.prepare(model)
	for child: Node in deck.get_children():
		if child is MeshInstance3D and child.position.y >= GarageEnvironment.DECK_HEIGHT:
			var material: Material = child.get_active_material(0)
			if material is ShaderMaterial and material.shader == preload("res://ui/studio_contact.gdshader"):
				reveal.prepare(child)

func _exchange_pedestals() -> void:
	if is_instance_valid(outgoing_pedestal): outgoing_pedestal.hide()
	turntable.show()

func finish_car_transition() -> void:
	if car_motion != null: car_motion.kill()
	car_motion = null
	if read_only: set_process(false)
	if incoming_reveal != null: incoming_reveal.restore()
	if outgoing_reveal != null: outgoing_reveal.restore()
	incoming_reveal = null
	outgoing_reveal = null
	if is_instance_valid(outgoing_pedestal): outgoing_pedestal.queue_free()
	outgoing_pedestal = null
	if is_instance_valid(turntable): turntable.show()
	invalidate_render()

func _orbit() -> void:
	if wash_effect != null: wash_effect.reset()
	var distance: float = (8.5 if vehicle_id == "pickup" else 5.5 if vehicle_id == "compact" else 7.1 if vehicle_id != "kart" else 4.9) * sqrt(1.0 + 0.32 * 0.32) * framing_scale
	if garage_mode:
		distance = (8.5 if read_only else 5.5 * 1.48) * sqrt(1.0 + 0.32 * 0.32) * framing_scale
		if garage_distance == 0.0: garage_distance = distance
		distance = garage_distance
	distance *= zoom
	var horizontal: float = cos(elevation) * distance
	var angle: float = GARAGE_CAMERA_YAW if garage_mode else yaw
	var target_height: float = 0.55 + (GarageEnvironment.DECK_HEIGHT if garage_mode else 0.0)
	if garage_mode and not read_only: target_height += 0.45
	if garage_mode and is_instance_valid(turntable): turntable.rotation.y = yaw - GARAGE_CAMERA_YAW
	if not trophy_view and not record_view and customisation_orbit.is_valid():
		if camera_motion != null and camera_motion.is_running(): camera_motion.kill()
		customisation_orbit.call()
		return
	if not trophy_view and not record_view:
		if camera_motion != null and camera_motion.is_running(): camera_motion.kill()
		camera.position = Vector3(sin(angle)*horizontal, target_height + sin(elevation)*distance, -cos(angle)*horizontal)
		camera.look_at(Vector3(0, target_height, 0))
	_update_roof()
	invalidate_render()

func _update_roof() -> void:
	if is_instance_valid(roof): roof.visible = camera.position.y < GarageEnvironment.ROOF_CUTAWAY_HEIGHT

func _reflection_visibility() -> void:
	if not is_visible_in_tree(): finish_kit_transition()
	if not is_visible_in_tree(): finish_paint_transition()
	if read_only and not is_visible_in_tree(): finish_car_transition()
	if reflections != null: reflections.set_visible(is_visible_in_tree())
	invalidate_render()

func set_trophy_view(active: bool) -> void:
	if not garage_mode or read_only or active == trophy_view: return
	_set_room_view("trophies" if active else "car")

func set_record_view(active: bool) -> void:
	if not garage_mode or read_only or active == record_view: return
	_set_room_view("records" if active else "car")

func update_records(settings: Dictionary) -> void:
	var relevant: PackedByteArray = var_to_bytes([preload("res://soundtrack/record_library.gd").selected(settings).id])
	if not is_instance_valid(record_station) or relevant == _record_settings: return
	_record_settings = relevant
	preload("res://ui/garage_record_station.gd").update(record_station,settings)
	if is_instance_valid(record_sleeves) and is_finite(_browse_position):
		preload("res://ui/garage_record_station.gd").present_browse(record_sleeves,_browse_position)
	invalidate_render()

func browse_records(position: float) -> void:
	if position == _browse_position: return
	_browse_position = position
	if is_instance_valid(record_sleeves): preload("res://ui/garage_record_station.gd").present_browse(record_sleeves,position)
	invalidate_render()

func _set_room_view(destination_view: String) -> void:
	finish_car_transition()
	_clear_gesture()
	set_wash_mode(false)
	if camera_motion != null: camera_motion.kill()
	trophy_view = destination_view == "trophies"
	record_view = destination_view == "records"
	var start: Transform3D = camera.transform
	var destination := Transform3D.IDENTITY
	if trophy_view:
		destination.origin = GarageDetails.TROPHY_CAMERA
		destination = destination.looking_at(GarageDetails.TROPHY_CENTER)
	elif record_view:
		destination.origin = preload("res://ui/garage_record_station.gd").CAMERA
		destination = destination.looking_at(preload("res://ui/garage_record_station.gd").CENTER)
	else:
		camera_motion = null
		_orbit()
		destination = camera.transform
	camera.transform = start
	camera_motion = create_tween()
	camera_motion.tween_method(_blend_camera.bind(start,destination),0.0,1.0,0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func _blend_camera(weight: float, start: Transform3D, destination: Transform3D) -> void:
	camera.transform = start.interpolate_with(destination,weight)
	camera.position.y += sin(weight * PI) * 1.1
	_update_roof()
	invalidate_render()

func owns_gesture(location: Vector2) -> bool:
	var rect: Rect2 = get_global_rect()
	return rect.has_point(location) and location.y >= rect.position.y + interaction_inset_top and location.y <= rect.end.y - interaction_inset_bottom

func _drag(event: InputEvent) -> void:
	if trophy_view and (camera_motion == null or not camera_motion.is_running()):
		_trophy_input(event)
		accept_event()
		return
	if trophy_view or record_view or (camera_motion != null and camera_motion.is_running()) or (car_motion != null and car_motion.is_running()):
		accept_event()
		return
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		if touches.is_empty() and not owns_gesture(get_global_rect().position + event.position): return
	if wash_mode and _wash_input(event):
		accept_event()
		return
	if event is InputEventScreenTouch:
		if event.canceled:
			_clear_gesture()
		elif event.pressed:
			if touches.size() < 2: touches[event.index] = event.position
			pointer = int(touches.keys()[0])
			pinch_distance = _finger_distance()
		else:
			touches.erase(event.index)
			pointer = int(touches.keys()[0]) if not touches.is_empty() else -1
			pinch_distance = _finger_distance()
			resume_orbit = not touches.is_empty()
	elif event is InputEventScreenDrag and touches.has(event.index):
		touches[event.index] = event.position
		if touches.size() == 2:
			var distance: float = _finger_distance()
			if distance > 1.0 and pinch_distance > 1.0: set_zoom(zoom * pinch_distance / distance)
			pinch_distance = distance
		elif resume_orbit:
			resume_orbit = false
		else:
			rotate_view(event.relative)
	elif event is InputEventMouseMotion and touches.is_empty() and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		rotate_view(event.relative)
	elif event is InputEventMouseButton and event.pressed and touches.is_empty():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: set_zoom(zoom * exp(-0.12 * event.factor))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: set_zoom(zoom * exp(0.12 * event.factor))
	elif event is InputEventMagnifyGesture and touches.is_empty() and event.factor > 0.0:
		set_zoom(zoom / event.factor)
	accept_event()

func rotate_view(movement: Vector2) -> void:
	yaw = wrapf(yaw - movement.x * 0.012, -PI, PI)
	elevation = clampf(elevation + movement.y * 0.008, MIN_ELEVATION, MAX_ELEVATION)
	_orbit()

func set_zoom(value: float) -> void:
	if not is_finite(value): return
	zoom = clampf(value, MIN_ZOOM, MAX_ZOOM)
	_orbit()

func zoom_by(factor: float) -> void:
	set_zoom(zoom * factor)

func reset_view() -> void:
	yaw = DEFAULT_YAW
	elevation = atan(0.16) if garage_mode else atan(0.32)
	zoom = 1.0
	garage_distance = 0.0
	_clear_gesture()
	_orbit()

func _finger_distance() -> float:
	if touches.size() != 2: return 0.0
	var points: Array = touches.values()
	return (points[0] as Vector2).distance_to(points[1] as Vector2)

func _trophy_input(event: InputEvent) -> void:
	# Godot can synthesize mouse events from a finger; the touch owns that tap.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION: return
	if event is InputEventScreenDrag or event is InputEventMouseMotion:
		if _wall_pointer != -2 and event.position.distance_to(_wall_press) > 12.0:
			_wall_press = Vector2.INF
		return
	if not (event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT)): return
	var index: int = event.index if event is InputEventScreenTouch else -1
	if event.pressed:
		if _wall_pointer != -2:
			# A second finger cancels this tap; its release cannot open a medal.
			_wall_press = Vector2.INF
			return
		_wall_pointer = index
		_wall_press = event.position
	elif index == _wall_pointer:
		var tapped: bool = event.position.distance_to(_wall_press) <= 12.0
		if event is InputEventScreenTouch and event.canceled: tapped = false
		_wall_pointer = -2
		_wall_press = Vector2.INF
		if tapped: trophy_tapped.emit(event.position)

func _clear_gesture() -> void:
	_wall_pointer = -2
	_wall_press = Vector2.INF
	washing = false
	wash_pointer_valid = false
	touches.clear()
	pointer = -1
	pinch_distance = 0.0
	resume_orbit = false
	if wash_effect != null: wash_effect.reset()
	queue_redraw()

func apply_livery(value: Dictionary, animate_paint: bool = false) -> void:
	finish_kit_transition()
	# The initial showroom value can share the draft being edited. Also verify
	# the car's owned copy before skipping a live sticker/colour update.
	if livery == value and (not is_instance_valid(car) or car.livery == value):
		if not animate_paint: finish_paint_transition()
		return
	finish_paint_transition()
	finish_car_transition()
	var sweep: PaintTransition
	if animate_paint and garage_mode and not read_only and is_visible_in_tree() and is_instance_valid(car):
		sweep = PaintTransition.new()
		sweep.capture(car)
	livery = value.duplicate(true)
	if is_instance_valid(car):
		car.apply_livery(livery)
		weathering.refresh_paint()
		if sweep != null and not sweep.bindings.is_empty():
			paint_transition = sweep
			sweep.install()
			paint_motion = create_tween()
			paint_motion.tween_method(sweep.set_progress,0.0,1.0,sweep.SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			paint_motion.tween_callback(finish_paint_transition)
		refresh_thumbnail()

func finish_paint_transition() -> void:
	if paint_motion != null: paint_motion.kill()
	paint_motion = null
	if paint_transition != null: paint_transition.restore()
	paint_transition = null
	invalidate_render()

func set_wash_mode(enabled: bool) -> void:
	if enabled: finish_kit_transition()
	if enabled: finish_paint_transition()
	if enabled: finish_car_transition()
	if enabled and wash_effect == null:
		wash_effect = preload("res://ui/garage_wash_effect.gd").new()
		camera.get_parent().add_child(wash_effect)
		wash_effect.visual_changed.connect(_wash_effect_changed)
	_clear_gesture()
	washing = false
	wash_pointer_valid = false
	wash_mode = enabled
	queue_redraw()

func set_wash_tool(tool: String) -> void:
	if tool not in ["mitt", "hose"] or tool == wash_tool: return
	_clear_gesture()
	wash_tool = tool
	condition_changed.emit()
	invalidate_render()

func _wash_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
		washing = event.pressed and touches.is_empty()
		wash_pointer = event.position
		wash_previous = wash_pointer
		wash_pointer_valid = washing
		if not washing: condition_changed.emit()
		queue_redraw()
		return true
	if event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION and touches.is_empty():
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			rotate_view(event.relative)
			return true
		wash_pointer = event.position
		wash_pointer_valid = true
		return true
	if event is InputEventScreenTouch:
		if event.canceled:
			_clear_gesture()
			washing = false
			wash_pointer_valid = false
			condition_changed.emit()
		elif event.pressed:
			if touches.size() < 2: touches[event.index] = event.position
			pointer = int(touches.keys()[0])
			washing = touches.size() == 1
			wash_pointer = event.position
			wash_previous = wash_pointer
			wash_pointer_valid = washing
			pinch_distance = _finger_distance()
		else:
			touches.erase(event.index)
			washing = false # Lift and press again after orbiting to resume washing.
			wash_pointer_valid = false
			pointer = int(touches.keys()[0]) if not touches.is_empty() else -1
			condition_changed.emit()
		return true
	if event is InputEventScreenDrag and touches.has(event.index):
		var previous: Vector2 = touches[event.index]
		touches[event.index] = event.position
		if touches.size() == 2:
			rotate_view((event.position - previous) * 0.5)
			var distance: float = _finger_distance()
			if distance > 1.0 and pinch_distance > 1.0: set_zoom(zoom * pinch_distance / distance)
			pinch_distance = distance
		elif washing:
			wash_pointer = event.position
		return true
	return false

func _wash_effect_changed() -> void:
	# Normal animation submits once at the end of _process. Explicit preview
	# tools can advance the same effect while showroom processing is paused.
	if is_processing(): _render_dirty = true
	else: invalidate_render()

func invalidate_render() -> void:
	_render_dirty = true
	_weather_visibility_state.clear()
	if is_instance_valid(showroom_viewport) and not is_visible_in_tree(): showroom_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if is_inside_tree() and is_visible_in_tree() and is_instance_valid(camera): _request_render()

func _request_render(reflection_changed: bool = true, room_animation: bool = false) -> void:
	_submit_render(reflection_changed,room_animation)
	# Match the existing podium's bounded radiance preparation. Native shadows,
	# sky filtering and resized targets must finish before retaining this image.
	_settle_draws = 3
	if reflection_changed: _reflection_settle_draws = 3
	_arm_render_settle()

func _arm_render_settle() -> void:
	if _settle_draws <= 0 or not is_inside_tree() or not is_visible_in_tree(): return
	if not read_only and DisplayServer.get_name()!="headless" and not RenderingServer.frame_post_draw.is_connected(_finish_render):
		RenderingServer.frame_post_draw.connect(_finish_render,CONNECT_ONE_SHOT)

func _finish_render() -> void:
	if _settle_draws <= 0 or not is_inside_tree() or not is_visible_in_tree(): return
	_settle_draws -= 1
	_submit_render(_reflection_settle_draws > 0)
	_reflection_settle_draws = maxi(0,_reflection_settle_draws-1)
	if _settle_draws > 0: _arm_render_settle.call_deferred()

func _submit_render(reflection_changed: bool = true, room_animation: bool = false) -> void:
	if reflections != null:
		reflections.sync()
		# The record belongs to the room; it cannot change the car-only capture.
		if reflection_changed: reflections.request_draw()
		elif room_animation: reflections.request_draw(true,false)
	showroom_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_render_dirty = false
	render_requests += 1

func _render_state() -> Array:
	var weather_visible: bool = _weathering_visible()
	return [camera.transform,camera.fov,camera.keep_aspect,showroom_viewport.size,car.get_instance_id(),turntable.transform if is_instance_valid(turntable) else car.transform,weathering.installed,weathering.parameter_uploads if weather_visible else 0,weathering.wash_mask_uploads if weather_visible else 0,is_instance_valid(wash_effect) and wash_effect.visible]

func _weathering_visible() -> bool:
	var state: Array = [camera.global_transform,camera.fov,camera.keep_aspect,showroom_viewport.size,car.get_instance_id(),car.global_transform,car.customisation.duplicate(),weathering.get_instance_id(),reflections != null and reflections.enabled]
	if state == _weather_visibility_state: return _weather_visible
	_weather_visibility_state = state
	_weather_visible = false
	var bounds := AABB()
	var first: bool = true
	# Use actual affected meshes, including fitted parts and wheel frames;
	# persisted wash-volume bounds intentionally exclude some fitted kits.
	for binding: Dictionary in weathering.bindings:
		var part: MeshInstance3D = binding.node
		if not is_instance_valid(part) or part.mesh == null: continue
		var box: AABB = part.global_transform * part.mesh.get_aabb().grow(part.extra_cull_margin)
		bounds = box if first else bounds.merge(box)
		first = false
	if first: return false
	var captures: Array[Camera3D] = [camera]
	if reflections != null and reflections.enabled:
		reflections.sync()
		captures.append_array(reflections.cameras)
	for capture: Camera3D in captures:
		var visible: bool = true
		for plane: Plane in capture.get_frustum():
			if plane.distance_to(bounds.get_support(-plane.normal)) > 0.0:
				visible = false
				break
		if visible:
			_weather_visible = true
			break
	return _weather_visible

func _record_animation_visible() -> bool:
	if record_vinyl == null or camera == null: return false
	var state: Array = [camera.global_transform,camera.fov,camera.keep_aspect,showroom_viewport.size,reflections != null and reflections.enabled]
	if state == _record_visibility_state: return _record_visible
	_record_visibility_state = state
	_record_visible = false
	var cameras: Array[Camera3D] = [camera]
	# The floor can show the record even when it is outside the main camera.
	if reflections != null and reflections.enabled:
		reflections.sync()
		cameras.append(reflections.cameras[0])
	# Bound the entire spinning disc, label and spindle through every rotation.
	var center: Vector3 = record_vinyl.global_position
	var radius: float = 0.18
	for capture: Camera3D in cameras:
		var visible: bool = true
		for plane: Plane in capture.get_frustum():
			if plane.distance_to(center) > radius:
				visible = false
				break
		if visible:
			_record_visible = true
			break
	return _record_visible

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		washing = false
		return
	var animated: bool = (camera_motion != null and camera_motion.is_running()) or (car_motion != null and car_motion.is_running()) or (paint_motion != null and paint_motion.is_running()) or (kit_motion != null and kit_motion.is_running())
	var reflection_animation: bool = animated
	var room_animation: bool = false
	if read_only:
		if animated or _render_dirty: _request_render()
		return
	if is_instance_valid(record_station):
		var music: GameSoundtrack = GameSoundtrack.instance()
		var bus: int = AudioServer.get_bus_index("Music")
		if music.mode == "menu" and music.music_enabled and music.menu_player.playing and not music.menu_player.stream_paused and not AudioServer.is_bus_mute(bus):
			if record_vinyl != null: record_vinyl.rotation.y = wrapf(record_vinyl.rotation.y + delta * TAU * (100.0/3.0) / 60.0,0,TAU)
			if _record_animation_visible():
				animated = true
				room_animation = true
	if weathering.snow_amount > 0.0 or weathering.slow_snow_amount > 0.0:
		weathering.melt(delta)
		wash_elapsed += delta
		if wash_elapsed >= 2.0 or (weathering.snow_amount == 0.0 and weathering.slow_snow_amount == 0.0):
			wash_elapsed = 0.0
			condition_changed.emit()
	if washing and wash_mode:
		if wash_effect != null: wash_effect.begin_frame()
		weathering.begin_wash_batch()
		# Interpolate a fast swipe to avoid unwashed gaps between render frames.
		var steps: int = clampi(ceili(wash_previous.distance_to(wash_pointer) / 12.0), 1, 32)
		for index: int in range(steps):
			wash_at(wash_previous.lerp(wash_pointer, float(index + 1) / steps), minf(delta, 0.1) / steps)
		weathering.end_wash_batch()
		wash_previous = wash_pointer
		wash_elapsed += delta
		if wash_elapsed >= 2.0:
			wash_elapsed = 0.0
			condition_changed.emit()
	if wash_effect != null and (wash_effect.visible or (washing and wash_mode)):
		var was_visible: bool = wash_effect.visible
		wash_effect.advance(delta, washing and wash_mode)
		if was_visible or wash_effect.visible:
			animated = true
			reflection_animation = true
	var state: Array = _render_state()
	if animated or _render_dirty or state != _last_render_state:
		_request_render(reflection_animation or _render_dirty or state != _last_render_state,room_animation)
	_last_render_state = state
	var cursor_state: Array = [wash_pointer,wash_pointer_valid,washing] if wash_mode else []
	if cursor_state != _last_wash_cursor_state:
		_last_wash_cursor_state = cursor_state
		queue_redraw()

func _draw() -> void:
	if wash_mode and wash_pointer_valid and not washing:
		draw_arc(wash_pointer, 17.0, 0.0, TAU, 32, Color(0.65, 0.9, 1.0, 0.65), 1.5, true)

func _cache_pick_meshes(node: Node3D) -> void:
	if node.has_meta("garage_opening_proxy"): return
	if node is MeshInstance3D and node.mesh != null:
		var triangles: TriangleMesh = node.mesh.generate_triangle_mesh()
		if triangles != null: pick_meshes.append({"node":node,"triangles":triangles,"bounds":node.mesh.get_aabb()})
	for child: Node in node.get_children():
		if child is Node3D: _cache_pick_meshes(child)

func pick_body_point(location: Vector2) -> Variant:
	var surface: Dictionary = pick_body_surface(location)
	return null if surface.is_empty() else surface.point

func pick_body_surface(location: Vector2) -> Dictionary:
	if camera == null or size.x <= 0.0 or size.y <= 0.0 or not Rect2(Vector2.ZERO, size).has_point(location): return {}
	if pick_meshes.is_empty(): _cache_pick_meshes(car)
	var pixel: Vector2 = location * Vector2(showroom_viewport.size) / size
	var origin: Vector3 = camera.project_ray_origin(pixel)
	var direction: Vector3 = camera.project_ray_normal(pixel)
	var nearest: float = INF
	var result: Dictionary = {}
	for entry: Dictionary in pick_meshes:
		var node: MeshInstance3D = entry.node
		var inverse: Transform3D = node.global_transform.affine_inverse()
		var local_origin: Vector3 = inverse * origin
		var local_direction: Vector3 = (inverse.basis * direction).normalized()
		if not (entry.bounds as AABB).intersects_ray(local_origin, local_direction): continue
		var hit: Dictionary = (entry.triangles as TriangleMesh).intersect_ray(local_origin,local_direction)
		if hit.is_empty(): continue
		var world: Vector3 = node.global_transform * (hit.position as Vector3)
		var distance: float = origin.distance_squared_to(world)
		if distance < nearest:
			nearest = distance
			var normal: Vector3 = (node.global_transform.basis.inverse().transposed() * (hit.normal as Vector3)).normalized()
			if normal.dot(direction) > 0.0: normal = -normal
			result = {"point":weathering.wash_point(node,hit.position),"position":world,"normal":normal}
	return result

func wash_at(location: Vector2, seconds: float) -> bool:
	var surface: Dictionary = pick_body_surface(location)
	if surface.is_empty(): return false
	var wash_normal: Vector3 = (weathering._body.global_transform.basis.transposed()*(surface.normal as Vector3)).normalized()
	weathering.wash(surface.point, seconds, wash_tool, wash_normal)
	if wash_tool == "hose":
		surface.radius = VehicleWeathering.HOSE_RADIUS*HandlingConfig.BODY_SCALE
		surface.car_bounds = weathering._body.global_transform*weathering.bounds
	if wash_effect != null: wash_effect.set_contact(surface, wash_tool)
	if not washing: invalidate_render()
	return true

func _exit_tree() -> void:
	finish_kit_transition()
	finish_paint_transition()
	# Garage layout moves leave/re-enter the tree within the same call.
	# Keep captures through that transfer; release real detachments/destruction.
	_dispose_detached_reflections.call_deferred()

func _dispose_detached_reflections() -> void:
	if not is_inside_tree() and reflections != null: reflections.dispose()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and reflections != null: reflections.dispose()
