extends Control
## Static transparent render of the player's actual car and local cosmetics.
var vehicle_id: String = "compact"
var simple_model: bool = false
var podium_presentation: bool = false
var livery: Dictionary = {}
var customisation: Dictionary = {}
var condition: Dictionary = {}
var viewport: SubViewport
var car: CarVisual

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X if podium_presentation else Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	car = CarVisual.new()
	car.vehicle_id = vehicle_id
	car.simple_model = simple_model
	car.livery = livery
	car.customisation = customisation
	if podium_presentation: car.rotation.y = PI
	world.add_child(car)
	var weathering := VehicleWeathering.new()
	weathering.configure(car,"pine",VehicleCatalog.config(vehicle_id))
	weathering.restore(condition)
	if podium_presentation:
		preload("res://ui/rivalry_podium_studio.gd").build(world,car)
	else:
		_legacy_lighting(world)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.8 if vehicle_id == "pickup" else 1.9 if vehicle_id == "kart" else 2.4
	camera.position = Vector3(-5,2.5,6)
	if podium_presentation:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = rad_to_deg(2.0*atan(camera.size/(2.0*camera.position.distance_to(Vector3(0,0.65,0)))))
	world.add_child(camera)
	camera.look_at(Vector3(0,0.65,0))
	camera.current = true
	var render := TextureRect.new()
	render.name = "VictoryCarRender"
	render.texture = viewport.get_texture()
	render.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	render.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if podium_presentation:
		var composite := ShaderMaterial.new()
		composite.shader = preload("res://ui/rivalry_car_composite.gdshader")
		composite.set_shader_parameter("linear_resolve",RenderingServer.get_current_rendering_method() != "gl_compatibility")
		render.material = composite
		render.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(render)
	MenuStyle.fill(render)
	resized.connect(_refresh)
	visibility_changed.connect(_refresh)
	if podium_presentation: get_viewport().size_changed.connect(_refresh)
	_refresh()
	if podium_presentation and DisplayServer.get_name() != "headless": preload("res://ui/rivalry_podium_studio.gd").prepare(weakref(self))

func _legacy_lighting(world: Node3D) -> void:
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

func _refresh() -> void:
	var dimensions: Vector2 = size
	if podium_presentation:
		var screen: Transform2D = get_viewport().get_stretch_transform()*get_screen_transform()
		dimensions *= Vector2(screen.x.length(),screen.y.length())*2.0
		dimensions *= minf(1.0,minf(1536.0/maxf(dimensions.x,1.0),768.0/maxf(dimensions.y,1.0)))
	viewport.size = Vector2i(maxi(1,roundi(dimensions.x)),maxi(1,roundi(dimensions.y)))
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
