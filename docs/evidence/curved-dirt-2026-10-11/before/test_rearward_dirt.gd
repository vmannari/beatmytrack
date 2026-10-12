extends "res://tests/test_vehicle_weathering.gd"
## Inspect the actual shader's flow channel and both physical sides of the car.
func _initialize() -> void: verify.call_deferred()

func verify() -> void:
	OS.set_environment("BMT_API_URL", "")
	output = "res://../docs/evidence/rearward-dirt-2026-10-11"
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
	var horizontal: float = 0.0
	var vertical: float = 0.0
	for y: int in range(5,123):
		for x: int in range(5,507):
			var value: float = actual.get_pixel(x,y).r
			horizontal += absf(value-actual.get_pixel(x+1,y).r)
			vertical += absf(value-actual.get_pixel(x,y+1).r)
	print("DIRT_FLOW_GRADIENT: horizontal=",horizontal," vertical=",vertical)
	check(vertical > horizontal * 2.5, "actual shader streaks extend horizontally with a shallow slope")
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
	print("REARWARD_DIRT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
