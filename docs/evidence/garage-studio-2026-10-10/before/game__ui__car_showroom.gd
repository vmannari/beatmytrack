class_name CarShowroom
extends SubViewportContainer
## Menu-only orbit camera over the actual race model. No simulation ownership.
var vehicle_id: String = "compact"
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
	mouse_filter = Control.MOUSE_FILTER_STOP
	var viewport := SubViewport.new()
	showroom_viewport = viewport
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("112734")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("bbccd1")
	environment.environment.ambient_light_energy = 0.65
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -28, 0)
	light.light_color = Color("eee2cd")
	light.shadow_enabled = true
	world.add_child(light)
	VisualGeometry.box(world, Vector3(60, 0.1, 60), Vector3(0, -0.11, 0), VisualGeometry.material(Color("233641")))
	VisualGeometry.cylinder(world, 3.8, 0.07, Vector3(0, -0.04, 0), VisualGeometry.material(Color("3c4b53")))
	car = CarVisual.new()
	car.vehicle_id = vehicle_id
	car.livery = livery
	world.add_child(car)
	camera = Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 38.0
	camera.current = true
	_orbit()
	gui_input.connect(_drag)
	visibility_changed.connect(_clear_gesture)
	# The stretched container owns viewport dimensions, including phone resizes.
	camera.keep_aspect = Camera3D.KEEP_HEIGHT

func _orbit() -> void:
	var distance: float = (8.5 if vehicle_id == "pickup" else 7.1 if vehicle_id != "kart" else 4.9) * sqrt(1.0 + 0.32 * 0.32) * zoom
	var horizontal: float = cos(elevation) * distance
	camera.position = Vector3(sin(yaw)*horizontal, 0.55 + sin(elevation)*distance, -cos(yaw)*horizontal)
	camera.look_at(Vector3(0, 0.55, 0))

func _drag(event: InputEvent) -> void:
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
	touches.clear()
	pointer = -1
	pinch_distance = 0.0
	resume_orbit = false

func apply_livery(value: Dictionary) -> void:
	livery = value.duplicate(true)
	if is_instance_valid(car): car.apply_livery(livery)
