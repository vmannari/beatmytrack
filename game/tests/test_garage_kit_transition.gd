extends SceneTree
const Fixture = preload("res://tests/test_customisation_carousel.gd")
var page: GaragePage
var checks: int = 0
var failures: int = 0
var output: String
var metrics: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
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
	check(page.showroom.kit_transition!=null,"local kit sweep is active")
	if page.showroom.kit_motion!=null: page.showroom.kit_motion.pause()
func image_at(progress: float) -> Image:
	page.showroom.kit_transition.set_progress(progress)
	await draw()
	return page.showroom.showroom_viewport.get_texture().get_image()
func differences(a: Image, b: Image) -> int:
	var count: int = 0
	for y: int in range(0,a.get_height(),2):
		for x: int in range(0,a.get_width(),2):
			var c: Color = a.get_pixel(x,y)-b.get_pixel(x,y)
			if Vector3(c.r,c.g,c.b).length()>0.04: count += 1
	return count
func unchanged_nodes(category: String) -> Dictionary:
	var affected: Array = page.showroom.car.kit_frames.get(category,[])
	var nodes: Dictionary = {}
	for mesh: MeshInstance3D in page.showroom.car.find_children("*","MeshInstance3D",true,false):
		var changed: bool = false
		for frame: Node3D in affected:
			if frame==mesh or frame.is_ancestor_of(mesh): changed = true
		if not changed: nodes[mesh.get_instance_id()] = [mesh.transform,mesh.mesh]
	return nodes

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	GameSoundtrack.instance().music_enabled = false
	output = ProjectSettings.globalize_path("res://../docs/evidence/garage-kit-transition-2026-10-26/native")
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
	page.records = LocalRecords.new("user://kit_sweep_"+TrackLibrary.unique_id()+".json")
	page.economy = shop
	root.add_child(page)
	MenuStyle.fill(page)
	page.offset_top = 110
	page.open_car(0)
	page._show_section("tuning")
	await settle()
	var saved: Dictionary = page.records.settings.duplicate(true)
	var car: CarVisual = page.showroom.car
	var view: SubViewport = page.showroom.showroom_viewport
	for category: String in VehicleCustomisation.CATEGORIES:
		print("KIT_STAGE: "+category)
		page._select_kit_category(category)
		await settle()
		var camera: Transform3D = page.showroom.camera.transform
		for index: int in range(1,VehicleCustomisation.OPTIONS[category].size()):
			var option: String = VehicleCustomisation.OPTIONS[category][index][0]
			var retained: Dictionary = unchanged_nodes(category)
			var condition: Dictionary = page.showroom.weathering.snapshot()
			var before: Image
			if DisplayServer.get_name()!="headless" and index==1:
				await draw()
				before = view.get_texture().get_image()
			page._preview_kit(category,option)
			freeze()
			check(page.showroom.customisation[category]==option and page.kit_draft[category]=="stock","preview target and equipped kit stay separate: "+category+"/"+option)
			check(page.records.settings==saved and shop.purchases==0,"preview has no save/purchase: "+option)
			check(page.showroom.car==car and page.showroom.showroom_viewport==view,"preview retains car and viewport")
			check(page.showroom.kit_transition.categories==[category],"only changed category is animated")
			check(page.showroom.weathering.snapshot()==condition,"condition stays exact")
			check(page.showroom.camera.transform==camera,"part selection retains camera")
			for identity: int in retained:
				var mesh: MeshInstance3D = instance_from_id(identity) as MeshInstance3D
				check(is_instance_valid(mesh) and mesh.transform==retained[identity][0] and mesh.mesh==retained[identity][1],"unchanged geometry stays exact")
			check(page.showroom.kit_transition.outgoing_root.get_parent()==car.get_parent(),"one local snapshot shares existing world")
			if DisplayServer.get_name()!="headless" and index==1:
				var start: Image = await image_at(0.0)
				var start_difference: int = differences(before,start)
				check(start_difference<=12,"initial sweep matches previous kit: "+category+" pixels="+str(start_difference))
				var middle: Image = await image_at(0.5)
				await capture(category+"-halfway")
				var end: Image = await image_at(1.0)
				page.showroom.finish_kit_transition()
				await draw()
				var exact: Image = view.get_texture().get_image()
				var end_difference: int = differences(end,exact)
				check(end_difference<=12,"completed sweep matches exact kit: "+category+" pixels="+str(end_difference))
				check(differences(start,middle)>12 and differences(middle,end)>12,"mid-sweep visibly differs from both endpoints: "+category)
				metrics.append({"category":category,"start_difference":start_difference,"end_difference":end_difference})
			else: page.showroom.finish_kit_transition()
		# Include removal back to the stock fitting; stock aero/body can be empty.
		page._preview_kit(category,"stock")
		freeze()
		page.showroom.finish_kit_transition()
	# A tolerated film uses the weathering shader, with its existing wash data.
	var original_wear: Dictionary = page.showroom.weathering.snapshot()
	var film: Dictionary = original_wear.duplicate(true)
	film.dirt = 0.12
	film.slow_dirt = 0.05
	film.wetness = 0.20
	page.showroom.weathering.restore(film)
	var retained_film: Dictionary = page.showroom.weathering.snapshot()
	page._select_kit_category("hood")
	await settle()
	page._preview_kit("hood","scoop")
	freeze()
	var weathered_end: Image
	if DisplayServer.get_name()!="headless": weathered_end = await image_at(1.0)
	page.showroom.finish_kit_transition()
	check(page.showroom.weathering.snapshot()==retained_film,"kit sweep preserves tolerated dirt, wetness and wash masks")
	if DisplayServer.get_name()!="headless":
		await draw()
		check(differences(weathered_end,view.get_texture().get_image())<=12,"weathered finish matches exact completed kit")
	page.showroom.weathering.restore(original_wear)
	page._cancel_cosmetic_preview(false)
	page._select_kit_category("aero")
	await settle()
	page._preview_kit("aero","wing")
	freeze()
	var draws: int = page.showroom.render_requests
	var reflections: int = page.showroom.reflections.draw_requests[1]
	page.showroom.kit_motion.play()
	await create_timer(0.85).timeout
	check(page.showroom.kit_transition==null and page.showroom.kit_motion==null,"natural completion releases snapshot and shaders")
	check(page.showroom.render_requests>draws+6 and page.showroom.reflections.draw_requests[1]>reflections+6,"kit sweep refreshes main car and reflection")
	await draw()
	for tick: int in range(8): await process_frame
	draws = page.showroom.render_requests
	for tick: int in range(8): await process_frame
	check(page.showroom.render_requests==draws,"settled effect returns to retained rendering")
	page._preview_kit("aero","swan")
	freeze()
	page._set_part_compare(true)
	check(page.showroom.customisation==page.kit_draft and page.showroom.kit_transition==null,"compare shows exact equipped geometry immediately")
	page._set_part_compare(false)
	check(page.showroom.customisation.aero=="swan" and page.showroom.kit_transition==null,"compare restores preview immediately")
	page._preview_kit("aero","wing")
	freeze()
	page._preview_kit("aero","ducktail")
	freeze()
	check(page.showroom.customisation.aero=="ducktail" and car.get_parent().find_children("OutgoingGarageFittings","Node3D",false,false).size()==1,"latest selection owns one outgoing fitting snapshot")
	shop.scope = "fixture/bob"
	shop.changed.emit()
	check(page.showroom.kit_transition==null and page._cosmetic_preview.is_empty() and page.showroom.customisation==page.kit_draft,"account fence clears active transition")
	shop.scope = "fixture/alice"
	shop.changed.emit()
	page._preview_kit("aero","wing")
	freeze()
	page._show_section("customise")
	check(page.showroom.kit_transition==null and page.showroom.customisation==page.kit_draft,"navigation restores authoritative kit")
	await create_timer(0.65).timeout
	check(page.showroom.customisation==page.kit_draft,"cancelled tween cannot restore stale preview")
	page._show_section("tuning")
	page._select_kit_category("aero")
	await settle()
	page._preview_kit("aero","wing")
	freeze()
	if DisplayServer.get_name()!="headless":
		for frame: int in range(19):
			page.showroom.kit_transition.set_progress(float(frame)/18.0)
			await capture("motion-%02d" % frame)
	page.hide()
	check(page.showroom.kit_transition==null,"hide frees transient resources")
	page.show()
	page._preview_kit("aero","swan")
	freeze()
	var outgoing: WeakRef = weakref(page.showroom.kit_transition.outgoing_root)
	page.queue_free()
	await process_frame
	await process_frame
	check(outgoing.get_ref()==null,"free during transition releases outgoing geometry")
	shop.queue_free()
	await process_frame
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics,"renderer":RenderingServer.get_current_rendering_method()},"\t"))
	print("GARAGE_KIT_TRANSITION: "+str(checks)+" checks, "+str(failures)+" failures")
	quit(1 if failures else 0)
