class_name CarShowroom
extends SubViewportContainer
## Menu-only camera over the same original production car geometry.

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.size = Vector2i(740, 430)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("202e35")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("bbccd1")
	environment.environment.ambient_light_energy = 0.55
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -28, 0)
	light.light_color = Color("eee2cd")
	light.shadow_enabled = true
	world.add_child(light)
	VisualGeometry.box(world, Vector3(60, 0.1, 60), Vector3(0, -0.11, 0), VisualGeometry.material(Color("37444a")))
	VisualGeometry.box(world, Vector3(7, 0.04, 7), Vector3(0, -0.04, 0), VisualGeometry.material(Color("465359")))
	for x: float in [-3.1, 3.1]:
		VisualGeometry.box(world, Vector3(0.04, 0.012, 6), Vector3(x, 0.0, 0), VisualGeometry.material(Color("929b98")))
	var car := CarVisual.new()
	world.add_child(car)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.2
	camera.position = Vector3(6, 4.4, -7)
	camera.look_at(Vector3(0, 0.5, 0))
	camera.current = true
