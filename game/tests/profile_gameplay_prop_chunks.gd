extends SceneTree
const OUTPUT: String = "res://../docs/evidence/gameplay-f05-f10-2026-10-23/prop-views"
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func frames(count: int) -> void:
	for index: int in range(count): await RenderingServer.frame_post_draw
func measure(viewport: RID) -> Dictionary:
	await frames(60)
	var gpu: Array[float] = []; var cpu: Array[float] = []
	for index: int in range(90):
		await RenderingServer.frame_post_draw
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport)); cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport))
	gpu.sort(); cpu.sort()
	return {"gpu_median_ms":gpu[45],"render_cpu_median_ms":cpu[45],"draws":RenderingServer.viewport_get_render_info(viewport,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),"primitives":RenderingServer.viewport_get_render_info(viewport,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)}
func run() -> void:
	assert(DisplayServer.get_name()!="headless"); root.size = Vector2i(1280,720); DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var folder: String = ProjectSettings.globalize_path(OUTPUT.path_join(RenderingServer.get_current_rendering_method())); DirAccess.make_dir_recursive_absolute(folder)
	var viewport: RID = root.get_viewport_rid(); RenderingServer.viewport_set_measure_render_time(viewport,true)
	var rows: Array = []
	for specification: Array in [["winter","snow_castle","WinterCraft"],["desert","egypt_obelisk","EgyptianStonework"],["night_city","abandoned_warehouse","NightFurniture"]]:
		var visual := NativeTrackVisual.new(); visual.theme_id = specification[0]; visual.colors = TrackTheme.palette(visual.theme_id); root.add_child(visual)
		var objects: Array = []
		for index: int in range(12): objects.append({"kind":specification[1],"position":[-80+(index%6)*32,-32+(index/6)*64],"rotation":index*15,"scale":0.75+(index%3)*0.25})
		var track := NativeTrack.new(); track.metadata = {"creator_document":{"objects":objects}}; await visual._build_placed_objects(track)
		var source: MeshInstance3D = visual.get_node(specification[2]); var reference: MeshInstance3D = source.duplicate(); visual.add_child(reference); source.hide()
		var lamp := DirectionalLight3D.new(); lamp.rotation_degrees = Vector3(-55,-25,0); lamp.shadow_enabled = true; visual.add_child(lamp)
		var environment := WorldEnvironment.new(); environment.environment = Environment.new(); environment.environment.background_mode = Environment.BG_COLOR; environment.environment.background_color = Color(0.1,0.12,0.14); environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; environment.environment.ambient_light_color = Color(0.7,0.75,0.8); environment.environment.ambient_light_energy = 0.5; visual.add_child(environment)
		var camera := Camera3D.new(); visual.add_child(camera); camera.current = true; camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 36; camera.look_at_from_position(Vector3(-16,42,2),Vector3(-16,0,-32))
		var before: Dictionary = await measure(viewport); var original_image: Image = root.get_texture().get_image()
		reference.free(); source.show(); await visual._partition_bank_meshes()
		var after: Dictionary = await measure(viewport); var final_image: Image = root.get_texture().get_image()
		var metrics: Dictionary = original_image.compute_image_metrics(final_image,false)
		if metrics.max>2.0:
			var count: int = 0
			for y: int in range(original_image.get_height()):
				for x: int in range(original_image.get_width()):
					var a: Color = original_image.get_pixel(x,y); var b: Color = final_image.get_pixel(x,y)
					if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>2.0/255.0:
						if count<8: print("PROP_PIXEL_DIFF ",Vector2i(x,y)," ",a," / ",b)
						count += 1
			print("PROP_CHANGED_PIXELS ",count)
		if metrics.max>2.0 or metrics.mean>0.05: failures += 1
		original_image.save_png(folder.path_join(specification[0]+"-before.png")); final_image.save_png(folder.path_join(specification[0]+"-after.png"))
		var row: Dictionary = {"theme":specification[0],"before":before,"after":after,"image_metrics":metrics}; rows.append(row); print("PROP_CHUNK_NATIVE ",JSON.stringify(row))
		visual.free(); await process_frame
	var file := FileAccess.open(folder.path_join("report.json"),FileAccess.WRITE); file.store_string(JSON.stringify({"rows":rows,"failures":failures,"scope":"Isolated desktop overhead views, twelve spaced static props per family, directional shadows; not full race/Android measurements."},"\t",true)+"\n"); file.close()
	quit(1 if failures else 0)
