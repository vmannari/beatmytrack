extends SceneTree
const Fixture = preload("res://tests/test_customisation_carousel.gd")
var checks: int = 0
var failures: int = 0
var page: GaragePage
var output: String
var metrics: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+label)

func settle() -> void:
	while page._workbench_focus_pending or page._menu_motion!=null or page.showroom.camera_motion!=null and page.showroom.camera_motion.is_running(): await process_frame
	for tick: int in range(8): await process_frame

func draw() -> void:
	page.showroom.invalidate_render()
	for tick: int in range(5): await process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await draw()
	check(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"capture "+label)

func freeze() -> void:
	check(page.showroom.paint_transition!=null,"paint sweep is active")
	if page.showroom.paint_motion!=null: page.showroom.paint_motion.pause()

func sample(value: float) -> Image:
	page.showroom.paint_transition.set_progress(value)
	await draw()
	return page.showroom.showroom_viewport.get_texture().get_image()

func pixel_direction(id: String) -> void:
	var before: Image = await sample(0.0)
	await capture(id+"-00-rear-start")
	var middle: Image = await sample(0.5)
	await capture(id+"-50-sweep")
	var after: Image = await sample(1.0)
	await capture(id+"-100-front-finish")
	var bounds: Vector2 = page.showroom.paint_transition.z_bounds
	var body: Node3D = page.showroom.car.body
	var rear: Vector2 = page.showroom.camera.unproject_position(body.to_global(Vector3(0,0.8,bounds.y)))
	var front: Vector2 = page.showroom.camera.unproject_position(body.to_global(Vector3(0,0.8,bounds.x)))
	var axis: Vector2 = (rear-front).normalized()
	var centre: Vector2 = (rear+front)*0.5
	var rear_count: int = 0
	var rear_new: int = 0
	var front_count: int = 0
	var front_old: int = 0
	for y: int in range(0,before.get_height(),2):
		for x: int in range(0,before.get_width(),2):
			var a: Color = before.get_pixel(x,y)
			var b: Color = after.get_pixel(x,y)
			if Vector3(a.r-b.r,a.g-b.g,a.b-b.b).length()<0.22: continue
			var mid: Color = middle.get_pixel(x,y)
			var old_distance: float = Vector3(a.r-mid.r,a.g-mid.g,a.b-mid.b).length()
			var new_distance: float = Vector3(b.r-mid.r,b.g-mid.g,b.b-mid.b).length()
			var along: float = (Vector2(x,y)-centre).dot(axis)
			if along > rear.distance_to(front)*0.23:
				rear_count += 1
				if new_distance<old_distance*0.5: rear_new += 1
			elif along < -rear.distance_to(front)*0.23:
				front_count += 1
				if old_distance<new_distance*0.5: front_old += 1
	check(rear_count>30 and front_count>30,"visible changed paint at both ends: "+id)
	check(rear_new>rear_count*0.90,"rear already has new paint at halfway: "+id)
	check(front_old>front_count*0.90,"front retains old paint at halfway: "+id)
	metrics.append({"car":id,"rear_pixels":rear_count,"rear_new":rear_new,"front_pixels":front_count,"front_old":front_old})
	page.showroom.finish_paint_transition()
	await draw()
	await capture(id+"-restored")
	var restored: Image = page.showroom.showroom_viewport.get_texture().get_image()
	var difference: int = 0
	for y: int in range(0,after.get_height(),2):
		for x: int in range(0,after.get_width(),2):
			var a: Color = after.get_pixel(x,y)
			var b: Color = restored.get_pixel(x,y)
			if Vector3(a.r-b.r,a.g-b.g,a.b-b.b).length()>0.04: difference += 1
	check(difference<=12,"completed sweep restores exact appearance: "+id+" pixels="+str(difference))

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	GameSoundtrack.instance().music_enabled = false
	output = ProjectSettings.globalize_path("res://../docs/evidence/garage-paint-transition-2026-10-26/native")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	root.theme = MenuStyle.theme()
	VehicleCatalog.selected = "compact"
	var shop: Node = Fixture.Shop.new()
	root.add_child(shop)
	page = GaragePage.new()
	page.cached_carousel = true
	page.records = LocalRecords.new("user://paint_sweep_"+TrackLibrary.unique_id()+".json")
	page.economy = shop
	print("PAINT_STAGE: build Garage")
	root.add_child(page)
	MenuStyle.fill(page)
	page.offset_top = 110
	page.open_car(0)
	await settle()
	print("PAINT_STAGE: pattern preview")
	var saved: Dictionary = page.records.settings.duplicate(true)
	var model: CarVisual = page.showroom.car
	var viewport: SubViewport = page.showroom.showroom_viewport
	page._preview_livery(3)
	freeze()
	check(page.draft==page._livery_saved and page.records.settings==saved and shop.purchases==0,"preview never saves or purchases")
	check(page.showroom.car==model and page.showroom.showroom_viewport==viewport,"paint reuses actual car and world")
	await settle()
	var camera: Transform3D = page.showroom.camera.transform
	page.showroom.paint_transition.set_progress(0.5)
	await capture("garage-pattern-halfway")
	check(page.showroom.camera.transform==camera,"sweep keeps camera stable")
	if DisplayServer.get_name()!="headless":
		for frame: int in range(19):
			page.showroom.paint_transition.set_progress(float(frame)/18.0)
			await capture("motion-%02d" % frame)
	page._preview_livery(4)
	freeze()
	check(page.showroom.livery==page.livery_menu.option_livery(4),"rapid selection keeps latest target")
	var draws: int = page.showroom.render_requests
	var reflected_draws: int = page.showroom.reflections.draw_requests[1]
	page.showroom.paint_motion.play()
	await create_timer(0.95).timeout
	check(page.showroom.paint_motion==null and page.showroom.paint_transition==null,"sweep finishes naturally and releases temporary finishes")
	check(page.showroom.render_requests>draws+6 and page.showroom.reflections.draw_requests[1]>reflected_draws+6,"paint motion redraws car and its reflection")
	await draw()
	for tick: int in range(8): await process_frame
	draws = page.showroom.render_requests
	for tick: int in range(8): await process_frame
	check(page.showroom.render_requests==draws,"settled paint returns to retained rendering")
	page._set_part_compare(true)
	check(page.showroom.paint_transition==null and page.showroom.livery==page.draft,"hold compare shows exact equipped paint immediately")
	page._set_part_compare(false)
	check(page.showroom.livery==page.livery_menu.option_livery(4),"compare release restores current preview")
	page._preview_livery(5)
	freeze()
	page._show_section("care")
	check(page.showroom.paint_transition==null and page.showroom.livery==page.draft,"navigation cancels preview and transient finishes")
	await create_timer(0.8).timeout
	check(page.showroom.livery==page.draft,"cancelled tween never restores stale preview")
	page._show_section("customise")
	print("PAINT_STAGE: colour preview")
	page._set_customise_tab("colours")
	await settle()
	page._preview_color(Color("c52d43"),"body")
	freeze()
	check(page.records.settings==saved,"colour preview remains unsaved")
	page._save()
	check(page._livery_saved==page.draft,"saving colour uses authoritative local flow")
	page.showroom.finish_paint_transition()
	# Check every actual authored car with a side view, independent of screen yaw.
	page.showroom.customisation_orbit = Callable()
	for id: String in VehicleCatalog.IDS:
		print("PAINT_STAGE: direction "+id)
		var base: Dictionary = VehicleLivery.defaults(id)
		base.colors.body = "b52b3d"
		base.colors.accent = "b52b3d"
		base.colors.detail = "b52b3d"
		page.showroom.replace_car(id,base,{})
		page.showroom.finish_car_transition()
		page.showroom.yaw = PI*0.5
		page.showroom.elevation = 0.34
		page.showroom._orbit()
		var next: Dictionary = base.duplicate(true)
		next.colors.body = "245fd2"
		next.colors.accent = "245fd2"
		next.colors.detail = "245fd2"
		page.showroom.apply_livery(next,true)
		freeze()
		if DisplayServer.get_name()!="headless": await pixel_direction(id)
		page.showroom.finish_paint_transition()
		check(page.showroom.car.livery==next,"final paint exact: "+id)
		for binding: Dictionary in page.showroom.car.graphics.bindings:
			var active: Material = binding.node.get_active_material(binding.index)
			check(not active is ShaderMaterial or not active.shader.code.contains("garage_paint_progress"),"temporary shader removed: "+id)
	# A tolerated film must stay on top of both paints, with all wash data intact.
	var wear: Dictionary = page.showroom.weathering.snapshot()
	wear.dirt = 0.12
	wear.slow_dirt = 0.10
	wear.wetness = 0.20
	var decorated: Dictionary = VehicleLivery.defaults("compact")
	decorated.pattern = LiveryCatalog.patterns[2].id
	decorated.stickers.hood.id = LiveryCatalog.stickers[0].id
	page.showroom.replace_car("compact",decorated,wear)
	page.showroom.finish_car_transition()
	page.showroom._orbit()
	var retained_wear: Dictionary = page.showroom.weathering.snapshot()
	var wet_paint: Dictionary = decorated.duplicate(true)
	wet_paint.colors.body = "245fd2"
	wet_paint.pattern = LiveryCatalog.patterns[4].id
	page.showroom.apply_livery(wet_paint,true)
	freeze()
	if DisplayServer.get_name()!="headless": await pixel_direction("compact-weathered-sticker")
	page.showroom.finish_paint_transition()
	check(page.showroom.weathering.snapshot()==retained_wear,"paint leaves dirt, wetness and wash masks exact")
	check(preload("res://ui/garage_paint_transition.gd").shaders.size()<=6,"generated shader cache is bounded by finish variants")
	var next: Dictionary = page.showroom.livery.duplicate(true)
	next.pattern = LiveryCatalog.patterns[2].id
	page.showroom.apply_livery(next,true)
	freeze()
	page.hide()
	check(page.showroom.paint_transition==null and page.showroom.paint_motion==null,"hide frees transient paint materials")
	page.show()
	page.showroom.apply_livery(VehicleLivery.defaults(page.showroom.vehicle_id),true)
	freeze()
	page.queue_free()
	await process_frame
	await process_frame
	shop.queue_free()
	await process_frame
	var report: Dictionary = {"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"direction":metrics}
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("GARAGE_PAINT_TRANSITION: "+str(checks)+" checks, "+str(failures)+" failures")
	quit(1 if failures else 0)
