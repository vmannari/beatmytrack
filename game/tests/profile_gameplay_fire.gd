extends SceneTree
const OUTPUT: String = "res://../docs/evidence/gameplay-f05-f10-2026-10-23/fire"
func _initialize() -> void: run.call_deferred()
func frames(count: int) -> void:
	for index: int in range(count): await RenderingServer.frame_post_draw
func stats(data: Array) -> Dictionary:
	data.sort(); return {"median_ms":data[data.size()/2],"p95_ms":data[mini(data.size()-1,ceili(data.size()*0.95)-1)]}
func run() -> void:
	assert(DisplayServer.get_name()!="headless")
	root.size = Vector2i(1280,720); DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var folder: String = ProjectSettings.globalize_path(OUTPUT.path_join(RenderingServer.get_current_rendering_method())); DirAccess.make_dir_recursive_absolute(folder)
	var world := Node3D.new(); root.add_child(world)
	var environment := WorldEnvironment.new(); environment.environment = Environment.new(); environment.environment.background_mode = Environment.BG_COLOR; environment.environment.background_color = Color(0.035,0.045,0.06); world.add_child(environment)
	var surface: ShaderMaterial = NightFireVolume.material()
	var old_shader := Shader.new(); old_shader.code = FileAccess.get_file_as_string("res://tests/fixtures/gameplay_f05_f10_before/night_fire_volume.gdshader.txt")
	var original: ShaderMaterial = surface.duplicate(); original.shader = old_shader
	original.set_shader_parameter("elapsed",3.25); surface.set_shader_parameter("elapsed",3.25)
	var box := BoxMesh.new(); box.size = Vector3.ONE
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_custom_data = true; mm.mesh = box; mm.instance_count = 32
	for index: int in range(32):
		mm.set_instance_transform(index,Transform3D(Basis.from_scale(Vector3(2,3,2)),Vector3((index%8)*3-10.5,1.5,(index/8)*3-4.5)))
		mm.set_instance_custom_data(index,Color(fposmod(index*0.618034,1),float(index%2),1,1))
	var flame := MultiMeshInstance3D.new(); flame.multimesh = mm; flame.material_override = original; flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; world.add_child(flame)
	var blocker := MeshInstance3D.new(); var blocked := BoxMesh.new(); blocked.size = Vector3(4,2,5); blocker.mesh = blocked; blocker.position = Vector3(-5,1,3); world.add_child(blocker)
	var camera := Camera3D.new(); world.add_child(camera); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.current = true; camera.look_at_from_position(Vector3(0,25,25),Vector3.ZERO)
	var viewport: RID = root.get_viewport_rid(); RenderingServer.viewport_set_measure_render_time(viewport,true)
	var rows: Array = []; var failures: int = 0
	for size: float in [30.0,12.0]:
		camera.size = size
		var images: Array[Image] = []
		for variant: int in range(2):
			flame.material_override = original if variant==0 else surface
			await frames(60)
			var gpu: Array = []; var cpu: Array = []
			for frame: int in range(90):
				await RenderingServer.frame_post_draw
				gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport)); cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport))
			var shot: Image = root.get_texture().get_image(); images.append(shot); shot.save_png(folder.path_join("size-"+str(int(size))+"-"+str(variant)+".png"))
			rows.append({"size":size,"variant":"before" if variant==0 else "after","gpu":stats(gpu),"render_cpu":stats(cpu)})
		var metrics: Dictionary = images[0].compute_image_metrics(images[1],false)
		print("FIRE_VOLUME_IMAGE ",size," ",JSON.stringify(metrics))
		# Godot metrics use 8-bit code values, not normalized colour units.
		if metrics.mean>0.05 or metrics.max>2.0: failures += 1
		rows.append({"size":size,"image_metrics":metrics})
	var file := FileAccess.open(folder.path_join("report.json"),FileAccess.WRITE); file.store_string(JSON.stringify({"samples":rows,"failures":failures,"scope":"isolated desktop 32-fire stage, native overhead camera, fixed noise/time; not Android/FPS/thermal data"},"\t",true)+"\n"); file.close()
	world.free(); await process_frame
	print("GAMEPLAY_FIRE_PROFILE ",JSON.stringify(rows)); quit(1 if failures else 0)
