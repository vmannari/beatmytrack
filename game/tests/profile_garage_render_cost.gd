extends SceneTree
## Isolated Garage component: no account, owner records or network adapters.
var output: String = "res://../build/garage-render-cost"
var report: Dictionary = {}
var view: CarShowroom
var control: bool = false
var captures: Dictionary = {}

func _initialize() -> void: run.call_deferred()

func frames(count: int = 12) -> void:
	for tick: int in range(count): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func geometry(node: Node) -> Dictionary:
	var result: Dictionary = {"meshes":0,"surfaces":0,"vertices":0,"triangles":0,"unindexed_vertices":0}
	for part: Node in node.find_children("*","MeshInstance3D",true,false):
		if part.mesh == null: continue
		result.meshes += 1
		for surface: int in range(part.mesh.get_surface_count()):
			var arrays: Array = part.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			result.surfaces += 1
			result.vertices += vertices.size()
			result.triangles += (vertices.size() if indices.is_empty() else indices.size())/3
			if indices.is_empty(): result.unindexed_vertices += vertices.size()
	return result

func sample(label: String, moving: bool = false) -> Dictionary:
	await frames()
	var start_requests: int = view.render_requests
	var reflections: PackedInt64Array = view.reflections.draw_requests.duplicate()
	var samples: Array[float] = []
	var draws: Array[float] = []
	var primitives: Array[float] = []
	for tick: int in range(60):
		if moving: view.rotate_view(Vector2(1.5,0))
		var began: int = Time.get_ticks_usec()
		await process_frame
		samples.append((Time.get_ticks_usec()-began)/1000.0)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	samples.sort(); draws.sort(); primitives.sort()
	var result: Dictionary = {"requests":view.render_requests-start_requests,"reflection_requests":[view.reflections.draw_requests[0]-reflections[0],view.reflections.draw_requests[1]-reflections[1]],"frame_median_ms":samples[30],"frame_p95_ms":samples[57],"draws_median":draws[30],"primitives_median":primitives[30]}
	print("GARAGE_SAMPLE ",label," ",JSON.stringify(result))
	return result

func capture(label: String) -> void:
	if DisplayServer.get_name() != "headless" and not control:
		view.showroom_viewport.mesh_lod_threshold = 0.0
		for reflection: SubViewport in view.reflections.views: reflection.mesh_lod_threshold = 0.0
		view.invalidate_render()
		await frames()
		view.showroom_viewport.get_texture().get_image().save_png(output.path_join("full-"+label+".png"))
		captures["full-"+label] = await render_counts()
		view.showroom_viewport.mesh_lod_threshold = 0.5
		for reflection: SubViewport in view.reflections.views: reflection.mesh_lod_threshold = 0.5
	view.invalidate_render()
	await frames()
	if DisplayServer.get_name() != "headless":
		view.showroom_viewport.get_texture().get_image().save_png(output.path_join(label+".png"))
		captures[label] = await render_counts()

func render_counts() -> Dictionary:
	var views: Array[SubViewport] = [view.showroom_viewport]
	views.append_array(view.reflections.views)
	for capture_view: SubViewport in views: capture_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await frames(5)
	var result: Dictionary = {}
	for index: int in range(views.size()):
		var rid: RID = views[index].get_viewport_rid()
		result[["main","floor_reflection","car_reflection"][index]] = RenderingServer.viewport_get_render_info(rid,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
		views[index].render_target_update_mode = SubViewport.UPDATE_DISABLED
	return result

func run() -> void:
	create_timer(240).timeout.connect(func() -> void: print("FAIL: Garage render profile deadline"); quit(1))
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		if argument == "--control": control = true
	if control:
		var script: Script = load("res://ui/car_showroom.gd")
		script.source_code = script.source_code.replace("if _record_animation_visible():","if true:").replace("viewport.mesh_lod_threshold = 0.5","viewport.mesh_lod_threshold = 0.0")
		assert(script.reload(true) == OK)
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	Engine.max_fps = 60
	var music: GameSoundtrack = GameSoundtrack.instance()
	music.music_enabled = false
	view = CarShowroom.new()
	view.garage_mode = true
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(view)
	while not view.showroom_ready: await process_frame
	if control:
		for reflection: SubViewport in view.reflections.views: reflection.mesh_lod_threshold = 0.0
	report = {"renderer":RenderingServer.get_current_rendering_method(),"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"resolution":[1280,720],"note":"Desktop component samples, not tablet FPS; capped at 60, cache and host load sensitive.","room":geometry(view.camera.get_parent().find_child("GarageArchitecture",true,false)),"cars":{}}
	for id: String in VehicleCatalog.IDS:
		if id != view.vehicle_id: view.replace_car(id,VehicleLivery.defaults(id),{})
		view.finish_car_transition()
		await capture(id+"-front")
		report.cars[id] = geometry(view.car)
		view.rotate_view(Vector2(180,0))
		await capture(id+"-rear")
		view.reset_view()
		if not control:
			view.set_zoom(CarShowroom.MIN_ZOOM)
			await capture(id+"-close")
			view.reset_view()
		await frames()
	report.idle = await sample("silent_idle")
	var silence := AudioStreamWAV.new()
	silence.mix_rate = 22050
	silence.loop_mode = AudioStreamWAV.LOOP_FORWARD
	silence.loop_end = 22050
	var data := PackedByteArray(); data.resize(44100); silence.data = data
	music.music_enabled = true
	music.mode = "menu"
	music.menu_target = 1.0
	music.menu_player.stream = silence
	music.menu_player.play()
	music.menu_player.stream_paused = false
	await frames()
	report.music_car_view = await sample("music_car_view")
	view.set_record_view(true)
	await create_timer(1.0).timeout
	report.music_record_view = await sample("music_record_view")
	music.music_enabled = false
	music.menu_target = 0.0
	music.menu_player.stop()
	view.set_record_view(false)
	await create_timer(1.0).timeout
	report.orbit = await sample("orbit",true)
	report.captures = captures
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("GARAGE_GEOMETRY ",JSON.stringify({"room":report.room,"cars":report.cars}))
	view.free()
	await process_frame
	quit()
