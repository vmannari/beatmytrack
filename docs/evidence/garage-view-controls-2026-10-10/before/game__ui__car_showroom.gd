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
	# The stretched container owns viewport dimensions, including phone resizes.
	camera.keep_aspect = Camera3D.KEEP_HEIGHT

func _orbit() -> void:
	var distance: float = 8.5 if vehicle_id == "pickup" else 7.1 if vehicle_id != "kart" else 4.9
	camera.position = Vector3(sin(yaw)*distance, 0.55 + distance*0.32, -cos(yaw)*distance)
	camera.look_at(Vector3(0, 0.55, 0))

func _drag(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and pointer == -1: pointer = event.index
		elif not event.pressed and pointer == event.index: pointer = -1
	elif event is InputEventScreenDrag and event.index == pointer:
		yaw -= event.relative.x * 0.012
		_orbit()
	elif event is InputEventMouseMotion and pointer == -1 and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		yaw -= event.relative.x * 0.012
		_orbit()
	accept_event()

func apply_livery(value: Dictionary) -> void:
	livery = value.duplicate(true)
	if is_instance_valid(car): car.apply_livery(livery)
