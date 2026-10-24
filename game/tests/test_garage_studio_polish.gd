extends SceneTree
## Native interaction and layout review using isolated local records.
var page: GaragePage
var checks: int = 0
var failures: int = 0
var output: String
var baseline: bool = false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)
func settle() -> void:
	while page._menu_motion != null: await process_frame
	for tick: int in range(10): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"native capture "+label)
func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	GameSoundtrack.instance().music_enabled = false
	output = "res://../docs/evidence/garage-studio-polish-2026-10-24/native"
	for argument: String in OS.get_cmdline_user_args():
		for token: String in argument.split(","):
			if token.begins_with("--evidence-root="): output = token.trim_prefix("--evidence-root=")
			if token == "--baseline": baseline = true
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	VehicleCatalog.selected = "compact"
	var host := Control.new()
	host.theme = MenuStyle.theme()
	root.add_child(host)
	MenuStyle.fill(host)
	page = GaragePage.new()
	page.records = LocalRecords.new("user://studio_polish_"+TrackLibrary.unique_id()+".json")
	host.add_child(page)
	MenuStyle.fill(page)
	page.offset_left = 20
	page.offset_right = -20
	page.offset_top = 112
	page.offset_bottom = -20
	await settle()
	page.open_car(0)
	await settle()
	var car: CarVisual = page.showroom.car
	var viewport: SubViewport = page.showroom.showroom_viewport
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,720)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		for section: String in ["care","customise","tuning"]:
			page._show_section(section)
			await settle()
			check(page.get_global_rect().encloses(page.actions.get_global_rect()),"footer fits "+section+str(dimensions.x))
			if page.tools_panel.visible: check(page.get_global_rect().encloses(page.tools_panel.get_global_rect()),"workbench fits "+section+str(dimensions.x))
			check(page.showroom.car == car and page.showroom.showroom_viewport == viewport,"same live car and viewport "+section)
			if section == "tuning":
				var chosen: Control = page.kit_cards.get_child(0)
				check(page.kit_scroll.get_global_rect().encloses(chosen.get_global_rect()),"selected part photograph fully visible "+str(dimensions.x))
			await capture(section+"-"+str(dimensions.x))
			if section == "customise":
				for tab: String in ["colours","stickers"]:
					page._set_customise_tab(tab)
					await settle()
					await capture(tab+"-"+str(dimensions.x))
				page._set_customise_tab("livery")
				await settle()
	if not baseline: await interactions()
	host.queue_free()
	await process_frame
	if not baseline: await actual_app()
	print("GARAGE_STUDIO_POLISH: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
func interactions() -> void:
	page._show_section("care")
	await settle()
	var controls: HBoxContainer = page.preview.get_node("GarageWashTools")
	var hose: Button = controls.get_node("GarageWashHose")
	var mitt: Button = controls.get_node("GarageWashMitt")
	var state: Dictionary = page.showroom.weathering.snapshot()
	check(hose.get_node("ToolPicture").texture != null and mitt.get_node("ToolPicture").texture != null,"both tool pictures loaded")
	for button: Button in [hose,mitt]:
		var texture: Texture2D = button.get_node("ToolPicture").texture
		check(texture.get_width() <= 512 and texture.get_height() <= 512,"bounded imported texture "+str(button.name))
		check(texture.get_image().has_mipmaps(),"mipmapped thumbnail "+str(button.name))
	check(page.preview.get_global_rect().encloses(controls.get_global_rect()),"picture dock stays inside car preview")
	check(hose.custom_minimum_size.y >= 52 and mitt.custom_minimum_size.y >= 52,"tool pictures are full touch targets")
	await click(hose)
	check(page.showroom.wash_mode and page.showroom.wash_tool == "hose","picture selects active hose")
	await click(mitt)
	check(page.showroom.wash_mode and page.showroom.wash_tool == "mitt","picture selects active mitt")
	check(mitt.button_pressed and not hose.button_pressed,"exclusive selected tool")
	check(page.showroom.weathering.snapshot() == state,"tool selection preserves condition")
	page._toggle_wash()
	check(not page.showroom.wash_mode,"Done finishes washing")
	page._show_section("customise")
	await settle()
	page._set_customise_tab("colours")
	await settle()
	page.livery_menu._palette_colour(Color("317573"))
	check(page.draft.colors.body == "317573","paint swatch applies colour")
	check(VehicleLivery.for_car(page.records.settings,"compact").colors.body == "317573","paint persists locally")
	page._show_section("tuning")
	await settle()
	page._select_kit("hood","scoop")
	check(page.kit_draft.hood == "scoop","part card fits selected hood")
	page._show_section("care")
	await settle()
	check(not page.showroom.wash_mode and not page.showroom.washing,"navigation ends active gesture")
	for index: int in range(VehicleCatalog.IDS.size()):
		page.preview_car(index)
		page.showroom.finish_car_transition()
		page.showroom.reset_view()
		await settle()
		var bounds: AABB = page.showroom.weathering.bounds
		var pixels := Rect2(Vector2.ZERO,Vector2(page.showroom.showroom_viewport.size))
		var visible: bool = true
		for x: float in [bounds.position.x,bounds.end.x]:
			for y: float in [bounds.position.y,bounds.end.y]:
				for z: float in [bounds.position.z,bounds.end.z]:
					var at: Vector3 = page.showroom.car.body.global_transform*Vector3(x,y,z)
					if not pixels.has_point(page.showroom.camera.unproject_position(at)): visible = false
		check(visible,VehicleCatalog.IDS[index]+" complete car fits tighter Garage framing")
		await capture("car-"+VehicleCatalog.IDS[index])
	page.preview_car(0)
	page.showroom.finish_car_transition()

func click(button: Button) -> void:
	var at: Vector2 = button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	Input.parse_input_event(motion)
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame

func actual_app() -> void:
	var directory: String = "user://studio_app_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.library = TrackLibrary.new(directory)
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._show_screen("garage")
	page = app.root_ui.find_child("GaragePage",true,false)
	page.open_car(0)
	await settle()
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,720)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		for section: String in ["care","customise","tuning"]:
			page._show_section(section)
			await settle()
			check(root.get_visible_rect().encloses(page.actions.get_global_rect()),"actual App footer fits "+section+str(dimensions.x))
			await capture("app-"+section+"-"+str(dimensions.x))
	app.queue_free()
	await process_frame
