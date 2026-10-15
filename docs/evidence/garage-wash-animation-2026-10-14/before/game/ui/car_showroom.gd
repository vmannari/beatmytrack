class_name CarShowroom
extends SubViewportContainer
## Menu-only orbit camera over the actual race model. No simulation ownership.
signal condition_changed
var condition: Dictionary = {}
var weathering := VehicleWeathering.new()
var wash_mode: bool = false
var washing: bool = false
var wash_pointer := Vector2.ZERO
var wash_previous := Vector2.ZERO
var wash_pointer_valid: bool = false
var wash_elapsed: float = 0.0
var pick_meshes: Array[Dictionary] = []
var vehicle_id: String = "compact"
var read_only: bool = false
var garage_mode: bool = false
var turntable: Node3D
var roof: Node3D
var reflections: GarageReflections
var trophy_view: bool = false
var record_view: bool = false
var record_station: Node3D
var record_vinyl: Node3D
var _record_settings: PackedByteArray = PackedByteArray()
var camera_motion: Tween
var car_motion: Tween
var outgoing_pedestal: Node3D
var incoming_reveal: GarageCarReveal
var outgoing_reveal: GarageCarReveal
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
const DEFAULT_YAW: float = -0.70
const GARAGE_CAMERA_YAW: float = 0.0
const MIN_ELEVATION: float = PI / 36.0 # 5 degrees, always above the floor.
const MAX_ELEVATION: float = PI * 4.0 / 9.0 # 80 degrees.
const MIN_ZOOM: float = 0.48
const MAX_ZOOM: float = 1.80
const CAR_HIDE_SECONDS: float = 0.26
const CAR_REVEAL_SECONDS: float = 0.38

func _ready() -> void:
	if garage_mode: elevation = atan(0.16)
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE if read_only else Control.MOUSE_FILTER_STOP
	var viewport := SubViewport.new()
	showroom_viewport = viewport
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if read_only else SubViewport.UPDATE_WHEN_VISIBLE
	viewport.msaa_3d = Viewport.MSAA_2X if read_only else Viewport.MSAA_4X
	viewport.scaling_3d_scale = 1.0
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
	car.editable_kits = garage_mode and vehicle_id=="compact"
	car.livery = livery
	car.customisation = customisation
	world.add_child(car)
	if garage_mode: turntable = GarageEnvironment.build(world, car, read_only)
	else: ShowroomStudio.build(world,car)
	if garage_mode: roof = world.find_child("GarageRoof",true,false)
	if garage_mode and not read_only: record_station = world.find_child("GarageRecordStation",true,false)
	if record_station != null: record_vinyl = record_station.find_child("GarageVinyl",true,false)
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

func refresh_thumbnail() -> void:
	if not is_instance_valid(showroom_viewport): return
	var screen: Transform2D = get_viewport().get_stretch_transform() * get_screen_transform()
	var pixels := size * Vector2(screen.x.length(),screen.y.length())
	var limit: float = minf(1.0,minf(2560.0/maxf(1.0,pixels.x),1440.0/maxf(1.0,pixels.y)))
	showroom_viewport.size = Vector2i(maxi(1,roundi(pixels.x*limit)),maxi(1,roundi(pixels.y*limit)))
	if read_only: showroom_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
	if reflections != null: reflections.sync()

func replace_car(id: String, paint: Dictionary, wear: Dictionary, parts: Dictionary = {}) -> void:
	finish_car_transition()
	_clear_gesture()
	var previous_deck: Node3D = turntable
	previous_deck.name = "OutgoingTurntable"
	var previous_car: CarVisual = car
	var world: Node3D = camera.get_parent()
	vehicle_id = id
	livery = paint.duplicate(true)
	condition = wear.duplicate(true)
	customisation = parts.duplicate(true) if VehicleCustomisation.valid(parts) else VehicleCustomisation.defaults()
	car = CarVisual.new()
	car.vehicle_id = id
	car.editable_kits = garage_mode and id=="compact"
	car.livery = livery
	car.customisation = customisation
	world.add_child(car)
	turntable = GarageEnvironment.build_pedestal(world,car)
	if reflections != null: reflections.mark_stage(turntable)
	weathering = VehicleWeathering.new()
	weathering.configure(car,"pine",VehicleCatalog.config(id))
	weathering.restore(condition)
	pick_meshes.clear()
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

func apply_customisation(value: Dictionary) -> void:
	if vehicle_id != "compact" or not VehicleCustomisation.valid(value): return
	if customisation==value: return
	finish_car_transition()
	set_wash_mode(false)
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
	refresh_thumbnail()

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
	if incoming_reveal != null: incoming_reveal.restore()
	if outgoing_reveal != null: outgoing_reveal.restore()
	incoming_reveal = null
	outgoing_reveal = null
	if is_instance_valid(outgoing_pedestal): outgoing_pedestal.queue_free()
	outgoing_pedestal = null
	if is_instance_valid(turntable): turntable.show()

func _orbit() -> void:
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
	if not trophy_view and not record_view:
		if camera_motion != null and camera_motion.is_running(): camera_motion.kill()
		camera.position = Vector3(sin(angle)*horizontal, target_height + sin(elevation)*distance, -cos(angle)*horizontal)
		camera.look_at(Vector3(0, target_height, 0))
	_update_roof()
	if reflections != null: reflections.sync()

func _update_roof() -> void:
	if is_instance_valid(roof): roof.visible = camera.position.y < GarageEnvironment.ROOF_CUTAWAY_HEIGHT

func _reflection_visibility() -> void:
	if reflections != null: reflections.set_visible(is_visible_in_tree())

func set_trophy_view(active: bool) -> void:
	if not garage_mode or read_only or active == trophy_view: return
	_set_room_view("trophies" if active else "car")

func set_record_view(active: bool) -> void:
	if not garage_mode or read_only or active == record_view: return
	_set_room_view("records" if active else "car")

func update_records(settings: Dictionary) -> void:
	var relevant: PackedByteArray = var_to_bytes([settings.get("music_record","exploration"),settings.get("music_records",[])])
	if not is_instance_valid(record_station) or relevant == _record_settings: return
	_record_settings = relevant
	preload("res://ui/garage_record_station.gd").update(record_station,settings)

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
	if reflections != null: reflections.sync()

func owns_gesture(location: Vector2) -> bool:
	var rect: Rect2 = get_global_rect()
	return rect.has_point(location) and location.y >= rect.position.y + interaction_inset_top and location.y <= rect.end.y - interaction_inset_bottom

func _drag(event: InputEvent) -> void:
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

func _clear_gesture() -> void:
	washing = false
	wash_pointer_valid = false
	touches.clear()
	pointer = -1
	pinch_distance = 0.0
	resume_orbit = false

func apply_livery(value: Dictionary) -> void:
	finish_car_transition()
	livery = value.duplicate(true)
	if is_instance_valid(car):
		car.apply_livery(livery)
		weathering.refresh_paint()
		refresh_thumbnail()

func set_wash_mode(enabled: bool) -> void:
	if enabled: finish_car_transition()
	_clear_gesture()
	washing = false
	wash_pointer_valid = false
	wash_mode = enabled
	queue_redraw()

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

func _process(delta: float) -> void:
	if reflections != null: reflections.sync()
	if not is_visible_in_tree():
		washing = false
		return
	if is_instance_valid(record_station):
		var music: GameSoundtrack = GameSoundtrack.instance()
		var bus: int = AudioServer.get_bus_index("Music")
		if music.mode == "menu" and music.music_enabled and music.menu_player.playing and not music.menu_player.stream_paused and not AudioServer.is_bus_mute(bus):
			if record_vinyl != null: record_vinyl.rotation.y = wrapf(record_vinyl.rotation.y + delta * TAU * (100.0/3.0) / 60.0,0,TAU)
	if weathering.snow_amount > 0.0 or weathering.slow_snow_amount > 0.0:
		weathering.melt(delta)
		wash_elapsed += delta
		if wash_elapsed >= 2.0 or (weathering.snow_amount == 0.0 and weathering.slow_snow_amount == 0.0):
			wash_elapsed = 0.0
			condition_changed.emit()
	if washing and wash_mode:
		# Interpolate a fast swipe to avoid unwashed gaps between render frames.
		var steps: int = clampi(ceili(wash_previous.distance_to(wash_pointer) / 12.0), 1, 32)
		for index: int in range(steps):
			wash_at(wash_previous.lerp(wash_pointer, float(index + 1) / steps), minf(delta, 0.1) / steps)
		wash_previous = wash_pointer
		wash_elapsed += delta
		if wash_elapsed >= 2.0:
			wash_elapsed = 0.0
			condition_changed.emit()
	if wash_mode: queue_redraw()

func _draw() -> void:
	if wash_mode and wash_pointer_valid:
		draw_circle(wash_pointer, 20.0, Color(0.5, 0.85, 1.0, 0.12 if not washing else 0.25))
		draw_arc(wash_pointer, 20.0, 0.0, TAU, 32, Color(0.65, 0.9, 1.0, 0.9), 2.0, true)

func _cache_pick_meshes(node: Node3D) -> void:
	if node is MeshInstance3D and node.mesh != null:
		var faces: PackedVector3Array = node.mesh.get_faces()
		if not faces.is_empty(): pick_meshes.append({"node": node, "faces": faces, "bounds": node.mesh.get_aabb()})
	for child: Node in node.get_children():
		if child is Node3D: _cache_pick_meshes(child)

func pick_body_point(location: Vector2) -> Variant:
	if camera == null or size.x <= 0.0 or size.y <= 0.0 or not Rect2(Vector2.ZERO, size).has_point(location): return null
	if pick_meshes.is_empty(): _cache_pick_meshes(car)
	var pixel: Vector2 = location * Vector2(showroom_viewport.size) / size
	var origin: Vector3 = camera.project_ray_origin(pixel)
	var direction: Vector3 = camera.project_ray_normal(pixel)
	var nearest: float = INF
	var result: Variant = null
	for entry: Dictionary in pick_meshes:
		var node: MeshInstance3D = entry.node
		var inverse: Transform3D = node.global_transform.affine_inverse()
		var local_origin: Vector3 = inverse * origin
		var local_direction: Vector3 = (inverse.basis * direction).normalized()
		if not (entry.bounds as AABB).intersects_ray(local_origin, local_direction): continue
		var faces: PackedVector3Array = entry.faces
		for index: int in range(0, faces.size(), 3):
			var hit: Variant = Geometry3D.ray_intersects_triangle(local_origin, local_direction, faces[index], faces[index+1], faces[index+2])
			if hit == null: continue
			var world: Vector3 = node.global_transform * (hit as Vector3)
			var distance: float = origin.distance_squared_to(world)
			if distance < nearest:
				nearest = distance
				result = weathering.wash_point(node, hit as Vector3)
	return result

func wash_at(location: Vector2, seconds: float) -> bool:
	var point: Variant = pick_body_point(location)
	if point == null: return false
	weathering.wash(point, seconds)
	return true

func _exit_tree() -> void:
	# Garage layout moves leave/re-enter the tree within the same call.
	# Keep captures through that transfer; release real detachments/destruction.
	_dispose_detached_reflections.call_deferred()

func _dispose_detached_reflections() -> void:
	if not is_inside_tree() and reflections != null: reflections.dispose()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and reflections != null: reflections.dispose()
