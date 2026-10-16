extends SceneTree
## Real reflection pixels, moving car, drain construction and cached-page lifecycle.
var output: String = "res://../docs/evidence/garage-reflections-drain-2026-10-12/proof"
var checks: int = 0
var failures: int = 0
var record_motion: bool = false
var profile_views: bool = false
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)
func settle() -> void:
	for index: int in range(16): await process_frame
	await RenderingServer.frame_post_draw
func capture(label: String) -> void:
	await settle()
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)
func difference(a: Image, b: Image, rect: Rect2i) -> int:
	var changed: int = 0
	for y: int in range(rect.position.y,rect.end.y):
		for x: int in range(rect.position.x,rect.end.x):
			var ca: Color = a.get_pixel(x,y)
			var cb: Color = b.get_pixel(x,y)
			if absf(ca.r-cb.r)+absf(ca.g-cb.g)+absf(ca.b-cb.b)>0.025: changed += 1
	return changed
func _run() -> void:
	OS.set_environment("BMT_API_URL","")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
		if argument.begins_with("--capture-motion-output="):
			output = argument.trim_prefix("--capture-motion-output=")
			record_motion = true
		if argument.begins_with("--profile-output="):
			output = argument.trim_prefix("--profile-output=")
			profile_views = true
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	var folder: String = "user://garage_reflection_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.library = TrackLibrary.new(folder)
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	VehicleCatalog.selected = "compact"
	app._show_screen("garage")
	await settle()
	var page: GaragePage = app.root_ui.find_child("GaragePage",true,false)
	var view: CarShowroom = page.showroom
	var rig: GarageReflections = view.reflections
	check(rig != null and rig.views.size() == 2,"two bounded reflection captures")
	for index: int in range(2):
		check(rig.views[index].find_world_3d() == view.showroom_viewport.find_world_3d(),"capture shares actual scene world")
		check(rig.views[index].size.x <= 768 and rig.views[index].size.y < view.showroom_viewport.size.y,"capture size bounded below main viewport")
		check(rig.cameras[index].transform.basis.determinant() > 0.99,"reflection camera preserves face winding")
		check(rig.cameras[index].position.y < 0,"camera correctly mirrors below receiving plane")
	check(rig.floor_material.get_shader_parameter("reflection_enabled") and rig.deck_material.get_shader_parameter("reflection_enabled"),"floor and pedestal receive live images")
	var with_reflections: Image = view.showroom_viewport.get_texture().get_image()
	await capture("reflections-on")
	rig.set_enabled(false)
	await settle()
	var without: Image = view.showroom_viewport.get_texture().get_image()
	await capture("reflections-off-diagnostic")
	var w: int = with_reflections.get_width()
	var h: int = with_reflections.get_height()
	var deck_changed: int = difference(with_reflections,without,Rect2i(int(w*0.35),int(h*0.67),int(w*0.36),int(h*0.25)))
	var floor_changed: int = difference(with_reflections,without,Rect2i(int(w*0.05),int(h*0.65),int(w*0.24),int(h*0.25)))
	print("REFLECTION_PIXELS deck=",deck_changed," floor=",floor_changed)
	check(deck_changed > 100,"actual pedestal reflection changes visible pixels")
	check(floor_changed > 100,"actual floor reflection changes visible pixels")
	rig.set_enabled(true)
	await settle()
	var mirror_before: PackedByteArray = rig.views[1].get_texture().get_image().get_data()
	var camera_pose: Transform3D = view.camera.transform
	var condition: Dictionary = view.weathering.snapshot()
	view.rotate_view(Vector2(60,0))
	await settle()
	check(rig.views[1].get_texture().get_image().get_data() != mirror_before,"reflection follows actual turntable/car rotation")
	check(view.camera.transform == camera_pose and view.weathering.snapshot() == condition,"reflection preserves camera and cosmetic condition")
	await capture("reflections-turned")
	view.reset_view()
	page.preview_car(1)
	await create_timer(0.75).timeout
	check(rig == view.reflections and bool(rig.deck_material.get_shader_parameter("reflection_enabled")),"car replacement rebinds its pedestal to existing captures")
	await capture("pickup-reflections")
	page.hide()
	check(rig.views.all(func(v: SubViewport) -> bool: return v.render_target_update_mode == SubViewport.UPDATE_DISABLED),"hidden garage stops both reflection passes")
	page.show()
	await settle()
	check(rig.views.all(func(v: SubViewport) -> bool: return v.render_target_update_mode == SubViewport.UPDATE_ALWAYS),"visible garage resumes live reflections")
	var room: Node = view.showroom_viewport.find_child("GarageArchitecture",true,false)
	var drain: Node3D = room.find_child("GarageDrain",true,false)
	check(drain != null and drain.position.y < 0,"drain channel is inset below floor")
	page._confirm_car()
	page._show_section("care")
	view.camera.position = Vector3(-5.7,1.85,-4.3)
	view.camera.look_at(GarageDrain.CENTER)
	rig.sync()
	await capture("drain-closeup")
	view.camera.position = Vector3(0,2.4,-7.4)
	view.camera.look_at(Vector3(0,0.35,0))
	rig.sync()
	await capture("pedestal-closeup")
	check(app.records.settings.get("vehicle_conditions",{}).is_empty(),"rendering creates no cosmetic saves")
	if profile_views:
		page.open_car(0)
		page._show_section("cars")
		view.reset_view()
		await create_timer(0.8).timeout
		var targets: Array[RID] = [view.showroom_viewport.get_viewport_rid(),rig.views[0].get_viewport_rid(),rig.views[1].get_viewport_rid()]
		for target: RID in targets: RenderingServer.viewport_set_measure_render_time(target,true)
		var cpu: Array[float] = []
		var gpu: Array[float] = []
		for frame: int in range(150):
			view.rotate_view(Vector2(1.4,0))
			await process_frame
			if frame<30: continue
			var sum_cpu: float = 0
			var sum_gpu: float = 0
			for target: RID in targets:
				sum_cpu += RenderingServer.viewport_get_measured_render_time_cpu(target)
				sum_gpu += RenderingServer.viewport_get_measured_render_time_gpu(target)
			cpu.append(sum_cpu)
			gpu.append(sum_gpu)
		cpu.sort()
		gpu.sort()
		print("GARAGE_REFLECTION_RENDER_MS ",JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"main_pixels":var_to_str(view.showroom_viewport.size),"capture_pixels":var_to_str(rig.views[0].size),"views_measured":3,"samples":cpu.size(),"cpu_median_sum":cpu[cpu.size()/2],"cpu_p95_sum":cpu[int(cpu.size()*0.95)],"gpu_median_sum":gpu[gpu.size()/2],"gpu_p95_sum":gpu[int(gpu.size()*0.95)]}))
	if record_motion:
		root.size = Vector2i(960,540)
		page.open_car(0)
		page._show_section("cars")
		await create_timer(0.8).timeout
		view.reset_view()
		var frames: String = ProjectSettings.globalize_path("res://../build/garage-reflection-motion-2026-10-12")
		DirAccess.make_dir_recursive_absolute(frames)
		for frame: int in range(120):
			view.rotate_view(Vector2(TAU/(120.0*0.012),0))
			for index: int in range(2): await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(frames.path_join("turntable-%03d.png"%frame)) == OK,"actual reflected rotation frame "+str(frame))
	app.queue_free()
	for index: int in range(6): await process_frame
	print("GARAGE_REFLECTIONS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
