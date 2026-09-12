class_name MenuStage
extends SubViewportContainer
## Original static pit scene. Independent menu camera; no simulation or car edits.

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	resized.connect(func() -> void: viewport.render_target_update_mode = SubViewport.UPDATE_ONCE)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("171d21")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("aebac1")
	environment.environment.ambient_light_energy = 0.32
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48,-38,0)
	light.light_color = Color("eee4ce")
	light.light_energy = 0.9
	light.shadow_enabled = true
	world.add_child(light)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-3,3,-2)
	fill.light_color = Color("a5baca")
	fill.light_energy = 0.8
	fill.omni_range = 11
	world.add_child(fill)
	var floor_material := VisualGeometry.material(Color("31393b"))
	var concrete := VisualGeometry.material(Color("555c5b"))
	var dark := VisualGeometry.material(Color("1c2529"))
	var paint := VisualGeometry.material(Color("babfb4"))
	VisualGeometry.box(world,Vector3(60,0.1,60),Vector3(0,-0.13,0),floor_material)
	VisualGeometry.box(world,Vector3(32,6,0.5),Vector3(0,2.8,7),concrete)
	for x: float in [-9,-3,3,9]:
		VisualGeometry.box(world,Vector3(0.28,6,0.6),Vector3(x,2.8,6.6),dark)
		VisualGeometry.box(world,Vector3(4.9,3.8,0.12),Vector3(x+3,1.8,6.6),dark)
		for height: float in [0.7,1.3,1.9,2.5,3.1]:
			VisualGeometry.box(world,Vector3(4.8,0.045,0.03),Vector3(x+3,height,6.49),concrete)
	for x: float in [-2.0,2.0]:
		VisualGeometry.box(world,Vector3(0.07,0.012,8),Vector3(x,-0.065,0),paint)
	VisualGeometry.box(world,Vector3(4,0.012,0.07),Vector3(0,-0.065,-3.5),paint)
	VisualGeometry.box(world,Vector3(4,0.012,0.07),Vector3(0,-0.065,3.5),paint)
	# Pit-wall stripe and equipment keep the setting grounded and unbranded.
	VisualGeometry.box(world,Vector3(32,0.15,0.1),Vector3(0,1.0,6.4),paint)
	for level: int in range(3):
		VisualGeometry.cylinder(world,0.43,0.25,Vector3(3.7,0.13+level*0.25,3.4),dark)
	VisualGeometry.box(world,Vector3(1.2,0.9,0.6),Vector3(5,0.45,5.8),dark)
	var car := CarVisual.new()
	world.add_child(car)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = 7.4
	camera.h_offset = -2.2
	camera.position = Vector3(7,4.1,-9)
	camera.look_at(Vector3(0,0.5,0))
	camera.current = true
