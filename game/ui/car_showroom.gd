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
var framing_scale: float = 1.0
var livery: Dictionary = {}
var car: CarVisual
var camera: Camera3D
var showroom_viewport: SubViewport
var yaw: float = 0.70
var pointer: int = -1
var elevation: float = atan(0.32)
var zoom: float = 1.0
var touches: Dictionary = {}
var pinch_distance: float = 0.0
var resume_orbit: bool = false
const DEFAULT_YAW: float = 0.70
const MIN_ELEVATION: float = PI / 36.0 # 5 degrees, always above the floor.
const MAX_ELEVATION: float = PI * 4.0 / 9.0 # 80 degrees.
const MIN_ZOOM: float = 0.48
const MAX_ZOOM: float = 1.80

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE if read_only else Control.MOUSE_FILTER_STOP
	var viewport := SubViewport.new()
	showroom_viewport = viewport
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if read_only else SubViewport.UPDATE_WHEN_VISIBLE
	viewport.msaa_3d = Viewport.MSAA_2X if read_only else Viewport.MSAA_4X
	if read_only:
		# A standalone viewport avoids SubViewportContainer's continuous-update
		# policy. Cards display a real 3D render and refresh only when needed.
		var holder := Node.new()
		holder.name = "ThumbnailWorld"
		add_child(holder)
		holder.add_child(viewport)
		var image := TextureRect.new()
		image.name = "ModelRender"
		image.texture = viewport.get_texture()
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(image)
		MenuStyle.fill(image)
	else: add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	car = CarVisual.new()
	car.vehicle_id = vehicle_id
	car.livery = livery
	world.add_child(car)
	ShowroomStudio.build(world,car)
	weathering.configure(car, "pine", VehicleCatalog.config(vehicle_id))
	weathering.restore(condition)
	camera = Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 38.0
	camera.current = true
	_orbit()
	if not read_only: gui_input.connect(_drag)
	else:
		set_process(false)
		resized.connect(refresh_thumbnail)
		visibility_changed.connect(refresh_thumbnail)
	visibility_changed.connect(_clear_gesture)
	# The stretched container owns viewport dimensions, including phone resizes.
	camera.keep_aspect = Camera3D.KEEP_HEIGHT

func refresh_thumbnail() -> void:
	if not read_only or not is_instance_valid(showroom_viewport): return
	showroom_viewport.size = Vector2i(maxi(1, roundi(size.x)), maxi(1, roundi(size.y)))
	showroom_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if is_visible_in_tree() else SubViewport.UPDATE_DISABLED

func _orbit() -> void:
	var distance: float = (8.5 if vehicle_id == "pickup" else 5.5 if vehicle_id == "compact" else 7.1 if vehicle_id != "kart" else 4.9) * sqrt(1.0 + 0.32 * 0.32) * zoom * framing_scale
	var horizontal: float = cos(elevation) * distance
	camera.position = Vector3(sin(yaw)*horizontal, 0.55 + sin(elevation)*distance, -cos(yaw)*horizontal)
	camera.look_at(Vector3(0, 0.55, 0))

func _drag(event: InputEvent) -> void:
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
	elevation = atan(0.32)
	zoom = 1.0
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
	livery = value.duplicate(true)
	if is_instance_valid(car):
		car.apply_livery(livery)
		weathering.refresh_paint()
		refresh_thumbnail()

func set_wash_mode(enabled: bool) -> void:
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
	if not is_visible_in_tree():
		washing = false
		return
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
