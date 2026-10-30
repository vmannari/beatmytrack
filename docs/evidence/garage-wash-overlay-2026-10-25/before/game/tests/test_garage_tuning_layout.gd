extends SceneTree
## Actual Garage workbench, isolated from unrelated race/startup dependencies.
var page: GaragePage
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/garage-tuning-layout-2026-10-14/isolated"
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)
func settle() -> void:
	while page._menu_motion != null: await process_frame
	for frame: int in range(8): await process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	check(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"capture "+label)
func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-root="): output = arg.trim_prefix("--evidence-root=")
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var host := Control.new()
	host.theme = MenuStyle.theme()
	root.add_child(host)
	MenuStyle.fill(host)
	host.add_theme_stylebox_override("panel",MenuStyle.card(0))
	VehicleCatalog.selected = "compact"
	page = GaragePage.new()
	page.vehicle_id = "compact"
	page.records = LocalRecords.new("user://tuning_layout_"+TrackLibrary.unique_id()+".json")
	host.add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.offset_left = 20
	page.offset_top = 112
	page.offset_right = -20
	page.offset_bottom = -20
	await settle()
	page.open_car(0)
	page._show_section("customise")
	await settle()
	var actual: CarVisual = page.showroom.car
	var viewport: SubViewport = page.showroom.showroom_viewport
	var parent: Node = page.preview.get_parent()
	page.showroom.zoom = 0.70
	page.showroom._orbit()
	var camera: Transform3D = page.showroom.camera.transform
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,720)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		page._show_section("customise")
		await settle()
		var car_rect: Rect2 = page.preview.get_rect()
		var tools_rect: Rect2 = page.tools_panel.get_rect()
		await capture("painting-"+str(dimensions.x))
		page._show_section("tuning")
		await settle()
		check(page.preview.get_rect().is_equal_approx(car_rect) and page.tools_panel.get_rect().is_equal_approx(tools_rect),"Painting/Tuning pane positions and sizes match")
		check(page.preview.get_parent()==parent and page.showroom.car==actual and page.showroom.showroom_viewport==viewport and page.showroom.camera.transform==camera,"actual car, viewport, attachment and camera retained")
		check(page.tools_panel.position.x>=page.preview.get_rect().end.x,"workbench remains beside live car")
		check(page.get_global_rect().encloses(page.tools_panel.get_global_rect()) and page.get_global_rect().encloses(page.actions.get_global_rect()),"workbench and footer fit")
		check(page.kit_cards.columns==2 and page.kit_scroll.horizontal_scroll_mode==ScrollContainer.SCROLL_MODE_DISABLED,"two columns with no horizontal clipping")
		check(page.tools_panel.find_child("GarageResetKits",true,false)!=null and page.preview.get_node("GarageViewControls/GarageTopView").visible,"header reset and matching view tools available")
		for category: String in VehicleCustomisation.CATEGORIES:
			page._select_kit_category(category)
			await settle()
			check(page.kit_cards.get_child_count()==VehicleCustomisation.OPTIONS[category].size(),"all "+category+" choices")
			page.kit_scroll.scroll_vertical = 0
			var last: Control = page.kit_cards.get_child(page.kit_cards.get_child_count()-1)
			root.gui_release_focus()
			last.grab_focus()
			await settle()
			check(page.kit_scroll.get_global_rect().encloses(last.get_global_rect()),"focus reveals last "+category+" choice")
			check(CompactKitThumbnail.images.size()<=16,"native photo cache remains bounded")
		await capture("tuning-"+str(dimensions.x))
	page._show_section("care")
	await settle()
	check(page.customise_layout==null,"Care restores the full-width car layout")
	host.queue_free()
	await process_frame
	print("GARAGE_TUNING_LAYOUT: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
