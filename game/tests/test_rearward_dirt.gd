extends "res://tests/test_vehicle_weathering.gd"
## Inspect the actual shader's flow channel and both physical sides of the car.
func _initialize() -> void: verify.call_deferred()

func verify() -> void:
	OS.set_environment("BMT_API_URL", "")
	output = "res://../docs/evidence/settling-dirt-2026-10-11"
	if RenderingServer.get_current_rendering_method() == "mobile": output += "/mobile"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(512,128)
	var world := Node3D.new()
	root.add_child(world)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point: Vector3 in [Vector3(.9,.25,-2),Vector3(.9,1.25,-2),Vector3(.9,1.25,2),Vector3(.9,.25,-2),Vector3(.9,1.25,2),Vector3(.9,.25,2)]:
		tool.set_normal(Vector3.RIGHT)
		tool.add_vertex(point)
	var panel := MeshInstance3D.new()
	panel.mesh = tool.commit()
	world.add_child(panel)
	var surface := ShaderMaterial.new()
	var shader := Shader.new()
	var source: String = VehicleWeathering.FINISH.code.replace("render_mode diffuse_burley, specular_schlick_ggx;", "render_mode unshaded, cull_disabled;")
	var end: int = source.rfind("\n}")
	shader.code = source.substr(0,end) + "\n ALBEDO = vec3(streaks);\n}"
	surface.shader = shader
	surface.set_shader_parameter("mesh_to_body", Transform3D.IDENTITY)
	panel.material_override = surface
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.0
	camera.position = Vector3(4,.75,0)
	camera.look_at(Vector3(.9,.75,0))
	camera.current = true
	for frame: int in range(10): await RenderingServer.frame_post_draw
	var actual: Image = await save("shader-flow")
	var front: Vector2 = field_gradient(actual, camera, -1.9, -0.6)
	var rear: Vector2 = field_gradient(actual, camera, 1.35, 1.9)
	print("SETTLING_DIRT_GRADIENT: front=",front," rear=",rear)
	check(front.y > front.x * 2.5, "front/door streaks retain their mostly horizontal direction")
	check(rear.y > rear.x * 3.0 and rear.y/rear.x > front.y/front.x, "rear-quarter streaks flatten as the spray starts falling")
	var arc_shader := Shader.new()
	arc_shader.code = source.substr(0,end) + "\n ALBEDO = vec3(curved_rise);\n}"
	surface.shader = arc_shader
	var arc: Image = await save("shader-settling-arc")
	var launch: float = field_sample(arc,camera,-0.8)
	var crest: float = field_sample(arc,camera,1.28)
	var tail: float = field_sample(arc,camera,1.95)
	check(crest > launch + 0.1, "actual shader arc rises behind the tire")
	check(crest > tail + 0.005, "actual shader arc starts falling before the tail")
	world.queue_free()
	await process_frame
	root.size = Vector2i(1280,720)
	var view := CarShowroom.new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(view)
	view.set_process(false)
	for warm: int in range(60): await RenderingServer.frame_post_draw
	await create_timer(1.0).timeout
	for theme: String in ["desert", "pine", "storm"]:
		view.weathering.configure(view.car, theme, VehicleCatalog.config("compact"))
		view.weathering.dirt_amount = .85
		view.weathering.slow_dirt_amount = .15
		view.weathering.deposit_color = VehicleWeathering.COLORS[theme]
		view.weathering.mud_amount = 1.0 if theme != "desert" else 0.0
		view.weathering.smudge = .85
		view.weathering.wetness = .8 if theme == "storm" else 0.0
		view.weathering._update_finish()
		for yaw: float in [-PI*.5,PI*.5]:
			view.yaw = yaw
			view.elevation = .16
			view._orbit()
			await save(theme + ("-rear-right" if yaw<0 else "-rear-left"))
		view.yaw = -PI*.77
		view.elevation = .23
		view._orbit()
		await save(theme + "-rear-corner")
		view.weathering.reset()
	view.queue_free()
	await process_frame
	print("SETTLING_DIRT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func field_gradient(actual: Image, camera: Camera3D, start: float, end: float) -> Vector2:
	var scale: float = float(actual.get_width()) / camera.get_viewport().get_visible_rect().size.x
	var a: float = camera.unproject_position(Vector3(.9,.75,start)).x * scale
	var b: float = camera.unproject_position(Vector3(.9,.75,end)).x * scale
	var gradient := Vector2.ZERO
	for y: int in range(5,123):
		for x: int in range(maxi(5,floori(minf(a,b))),mini(507,ceili(maxf(a,b)))):
			var value: float = actual.get_pixel(x,y).r
			gradient.x += absf(value-actual.get_pixel(x+1,y).r)
			gradient.y += absf(value-actual.get_pixel(x,y+1).r)
	return gradient

func field_sample(actual: Image, camera: Camera3D, z: float) -> float:
	var pixel: Vector2 = camera.unproject_position(Vector3(.9,.75,z)) * Vector2(actual.get_size()) / camera.get_viewport().get_visible_rect().size
	return actual.get_pixelv(Vector2i(pixel)).r
