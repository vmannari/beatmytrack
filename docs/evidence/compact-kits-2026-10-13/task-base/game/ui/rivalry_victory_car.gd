extends Control
## Static transparent render of the player's actual car and local cosmetics.
var vehicle_id: String = "compact"
var livery: Dictionary = {}
var condition: Dictionary = {}
var viewport: SubViewport
var car: CarVisual

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	car = CarVisual.new()
	car.vehicle_id = vehicle_id
	car.livery = livery
	world.add_child(car)
	var weathering := VehicleWeathering.new()
	weathering.configure(car,"pine",VehicleCatalog.config(vehicle_id))
	weathering.restore(condition)
	for wheel: Vector3 in car.wheel_rest_positions:
		ShowroomStudio._contact(world,Vector3(wheel.x*HandlingConfig.BODY_SCALE,0.007,wheel.z*HandlingConfig.BODY_SCALE),Vector2(0.60,0.8),0.55)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color.TRANSPARENT
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c0cbe1")
	environment.environment.ambient_light_energy = 0.65
	world.add_child(environment)
	for light_data: Array in [[Vector3(-32,-55,0),Color("ffdfa5"),1.0],[Vector3(-25,125,0),Color("c0d7ee"),0.45]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = light_data[0]
		light.light_color = light_data[1]
		light.light_energy = light_data[2]
		world.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.8 if vehicle_id == "pickup" else 1.9 if vehicle_id == "kart" else 2.4
	camera.position = Vector3(-5,2.5,6)
	world.add_child(camera)
	camera.look_at(Vector3(0,0.65,0))
	camera.current = true
	var render := TextureRect.new()
	render.name = "VictoryCarRender"
	render.texture = viewport.get_texture()
	render.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	render.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(render)
	MenuStyle.fill(render)
	resized.connect(_refresh)
	visibility_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	viewport.size = Vector2i(maxi(1,roundi(size.x)),maxi(1,roundi(size.y)))
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
