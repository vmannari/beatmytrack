extends "res://tests/test_biome_followup.gd"
## Freeze the actual material routines on deterministic cloud/snow/depth proxies.
func run() -> void:
	output += "/particles-" + RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(1600,900)
	root.content_scale_size = root.size
	root.msaa_3d = Viewport.MSAA_2X
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 40
	camera.position = Vector3(0,26,20)
	camera.look_at(Vector3.ZERO)
	var environment := WorldEnvironment.new()
	root.add_child(environment)
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.2,0.2,0.2)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_energy = 0.5
	var light := DirectionalLight3D.new()
	root.add_child(light)
	light.rotation_degrees = Vector3(-58,-35,0)
	var world := Node3D.new()
	root.add_child(world)
	VisualGeometry.box(world,Vector3(90,0.1,90),Vector3(0,-0.05,0),VisualGeometry.material(Color(0.6,0.64,0.67)))
	VisualGeometry.box(world,Vector3(6,1.8,5),Vector3(4,0.9,-2),VisualGeometry.material(Color(0.2,0.3,0.4)))
	var old_script: GDScript = legacy("game/vehicle/sand_dust.gd","SandDust")
	var old_dust: Node3D = old_script.new()
	var new_dust := SandDust.new()
	var viewport: RID = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport,true)
	var rows: Array[Dictionary] = []
	for kind: String in ["dust","wind","bank","air"]:
		var before: ShaderMaterial
		var after: ShaderMaterial
		var proxy := MultiMeshInstance3D.new()
		proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.use_custom_data = true
		instances.use_colors = true
		if kind == "dust":
			before = old_dust._particle_material(SandDust.MODE_DUST)
			after = new_dust._particle_material(SandDust.MODE_DUST)
			instances.mesh = new_dust._cloud_mesh(Vector2(10,10),after)
			instances.instance_count = 12
			for index: int in range(12):
				instances.set_instance_transform(index,Transform3D(Basis.IDENTITY,Vector3((index%4-1.5)*3,1.2+index*0.06,(index/4-1)*3)))
				instances.set_instance_color(index,Color(0.8,0.7,0.5,0.36))
		else:
			var filename: String = "winter_air_snow.gdshader" if kind == "air" else "winter_snow_wind.gdshader"
			before = ShaderMaterial.new()
			before.shader = Shader.new()
			before.shader.code = FileAccess.get_file_as_string(BEFORE+"game/track/"+filename)
			after = ShaderMaterial.new()
			after.shader = load("res://track/"+filename)
			var mesh := PlaneMesh.new()
			mesh.size = Vector2(0.16,0.08) if kind == "air" else Vector2(12,3)
			if kind == "bank": mesh.subdivide_width = 5
			instances.mesh = mesh
			instances.instance_count = 24 if kind == "air" else 20
			for index: int in range(instances.instance_count):
				instances.set_instance_transform(index,Transform3D(Basis.IDENTITY,Vector3((index%5-2)*7,0.6 if kind == "bank" else 0.065,(index/5-2)*5)))
				instances.set_instance_custom_data(index,Color(float(index)/instances.instance_count,float(index%4)/4.0,0.6,1))
		for material: ShaderMaterial in [before,after]:
			if kind == "dust": material.set_shader_parameter("billowing",true)
			else:
				material.set_shader_parameter("strength",0.85)
				material.set_shader_parameter("focus",Vector3.ZERO)
				material.set_shader_parameter("elapsed",2.3)
				material.set_shader_parameter("travel",11.7)
				if kind != "air":
					material.set_shader_parameter("bank",kind == "bank")
					material.set_shader_parameter("flow_texture",load("res://assets/textures/winter_wind_flow_v1.png"))
					material.set_shader_parameter("snow_albedo",NativeTrackVisual.WINTER_SNOW)
		proxy.multimesh = instances
		root.add_child(proxy)
		var images: Array[Image] = []
		var stages: Array[Dictionary] = []
		for mode: String in ["before","after","before","after"]:
			proxy.material_override = before if mode == "before" else after
			await measure(viewport,0.5)
			var stage: Dictionary = await measure(viewport,1.0)
			stage["mode"] = mode
			stages.append(stage)
			var captured: Image = root.get_texture().get_image()
			captured.convert(Image.FORMAT_RGBA8)
			captured.save_png(output+"/"+kind+"-"+mode+".png")
			if images.size() < 3: images.append(captured)
		var delta: Dictionary = pixel_delta(images[0],images[1])
		check(pixel_delta(images[0],images[2]).changed == 0,kind+" frozen reference is stable")
		check(delta.maximum <= 2,kind+" visible pixels preserved within 2/255")
		rows.append({"kind":kind,"pixels":delta,"stages":stages})
		print("FOLLOWUP_PARTICLE_STAGE: ",JSON.stringify(rows[-1]))
		proxy.free()
	old_dust.free()
	new_dust.free()
	FileAccess.open(output+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"))
	print("PARTICLE_FOLLOWUP: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
