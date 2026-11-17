extends SceneTree
## GP01-GP03: real Garage discovery, non-persistent previews and teardown.
const Fixture = preload("res://tests/test_customisation_carousel.gd")
const Icons = preload("res://ui/garage_paint_icons.gd")
var page: GaragePage
var checks: int = 0
var failures: int = 0
var output: String

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("PREMIUM_GARAGE_FAIL ",label)

func settle() -> void:
	var deadline: int = Time.get_ticks_msec()+30000
	while Time.get_ticks_msec()<deadline and (page.showroom.get("preparing")==true or page._workbench_focus_pending or page._menu_motion!=null or page.showroom.camera_motion!=null and page.showroom.camera_motion.is_running() or page.showroom.paint_motion!=null or page.showroom.car_motion!=null or page.showroom.kit_motion!=null): await process_frame
	check(page.showroom.get("preparing")!=true and page.showroom.car.model_ready,"live Garage model ready")
	check(page.showroom.paint_motion==null and page.showroom.car_motion==null and page.showroom.kit_motion==null,"native paint and model transitions have finished")
	for tick: int in range(8): await process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw

func icons_ready() -> void:
	await settle()
	var gallery: Control = page.livery_menu.premium_gallery
	var deadline: int = Time.get_ticks_msec()+30000
	while (gallery.icons.busy if gallery.visible else page.livery_menu.pattern_icons.busy) and Time.get_ticks_msec()<deadline: await process_frame
	check(not (gallery.icons.busy if gallery.visible else page.livery_menu.pattern_icons.busy),"visible paint icons settle")

func tap(button: Button, touch: bool = false) -> void:
	check(button.is_visible_in_tree(),"actual visible control "+str(button.name))
	var gallery: Control = page.livery_menu.premium_gallery
	if gallery.scroll.is_ancestor_of(button): gallery.scroll.ensure_control_visible(button)
	for tick: int in range(4): await process_frame
	var at: Vector2 = button.get_global_rect().get_center()
	for pressed: bool in [true,false]:
		if touch:
			var event := InputEventScreenTouch.new()
			event.index = 6
			event.position = at
			event.pressed = pressed
			root.push_input(event,true)
		else:
			var event := InputEventMouseButton.new()
			event.position = at
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			root.push_input(event,true)
		await process_frame
	await settle()

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	check(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"native Garage capture "+label)

func meshes() -> Array:
	var result: Array = []
	for node: MeshInstance3D in page.showroom.car.find_children("*","MeshInstance3D",true,false): result.append([node.mesh.get_instance_id(),node.transform])
	return result

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	GameSoundtrack.instance().music_enabled = false
	var mode: String = "headless" if DisplayServer.get_name()=="headless" else RenderingServer.get_current_rendering_method()
	output = ProjectSettings.globalize_path("res://../docs/evidence/garage-premium-2026-11-16/"+mode)
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	root.theme = MenuStyle.theme()
	VehicleCatalog.selected = "compact"
	var host := Control.new()
	root.add_child(host)
	MenuStyle.fill(host)
	var shop := Fixture.Shop.new()
	host.add_child(shop)
	page = GaragePage.new()
	page.records = LocalRecords.new("user://garage_premium_"+TrackLibrary.unique_id()+".json")
	var saved_paint: Dictionary = VehicleLivery.defaults("compact")
	saved_paint.pattern = "apex_twin"
	saved_paint.colors.body = "49283d"
	saved_paint.stickers.hood.id = "crest"
	page.records.settings.vehicle_liveries = {"compact":saved_paint}
	page.economy = shop
	host.add_child(page)
	MenuStyle.fill(page)
	page.offset_top = 100
	for car_index: int in range(VehicleCatalog.IDS.size()):
		page._show_section("cars")
		page.open_car(car_index)
		page._set_customise_tab("livery")
		await icons_ready()
		var menu: GarageLiveryMenu = page.livery_menu
		check(menu.pattern_tiles.size()==49,"all existing standard patterns retained")
		var choices: Array = LiveryCatalog.premium_for(page.vehicle_id)
		check(menu.premium_gallery.rows.size()==3,"three premium rows for "+page.vehicle_id)
		if car_index==0:
			await capture("standard-discovery")
			await tap(menu._collection_tabs.premium,true)
		check(page._livery_collection=="premium" and menu.premium_gallery.is_visible_in_tree() and not menu.pattern_shelf.visible,"Premium collection is discoverable and retained across cars")
		var original: Dictionary = page.draft.duplicate(true)
		var settings: Dictionary = page.records.settings.duplicate(true)
		var original_meshes: Array = meshes()
		var camera: Transform3D = page.showroom.camera.transform
		for item: Dictionary in choices:
			var row: Button = menu.premium_gallery.rows[item.id]
			await tap(row,true)
			await icons_ready()
			check(page.showroom.livery.pattern==item.id and page._cosmetic_preview.get("id","")==item.id,"actual row previews "+item.id)
			check(row.selected and row.status.text=="PREVIEWING" and not row.price.visible and not row.checkmark.visible,"premium state has no price or ownership claim")
			check(page.draft==original and page.records.settings==settings,"premium click leaves saved paint and records unchanged")
			check(meshes()==original_meshes and page.showroom.camera.transform.is_equal_approx(camera),"preview preserves exact model and camera")
			check(row.get_meta("icon_livery").pattern==item.id,"matching native icon paint")
			if DisplayServer.get_name()!="headless": check(row.car_icon.texture!=null and row.car_icon.texture.get_size()==Vector2(Icons.SIZE),"premium native icon is ready")
			page._equip_cosmetic_preview()
			check(shop.purchases==0 and not is_instance_valid(page._purchase_dialog) and page.records.settings==settings,"premium cannot invoke coin purchase or save")
			await capture(item.id)
		var current: Dictionary = page.showroom.livery.duplicate(true)
		page._preview_premium_livery("unknown")
		page._preview_premium_livery(str(LiveryCatalog.premium_for("kart" if page.vehicle_id!="kart" else "compact")[0].id))
		check(page.showroom.livery==current,"unknown and other-car premium IDs cannot preview")
		for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720)]:
			root.size = dimensions
			root.content_scale_size = dimensions
			await icons_ready()
			var selected: Button = menu.premium_gallery.rows[choices[2].id]
			check(root.get_visible_rect().encloses(page.tools_panel.get_global_rect()),"premium panel fits "+str(dimensions))
			check(menu.premium_gallery.scroll.get_global_rect().encloses(selected.get_global_rect()),"selected premium row is reachable "+str(dimensions))
			check(selected.get_global_rect().encloses(selected.description.get_global_rect()),"premium description stays in row")
			if car_index==0: await capture("premium-"+str(dimensions.x))
		await tap(menu.premium_gallery.restore)
		var restored: bool = page._cosmetic_preview.is_empty() and page.showroom.livery==original and page.records.settings==settings
		check(restored,"restore recovers exact saved palette and stickers "+page.vehicle_id)
		if not restored:
			print("RESTORE_DETAIL ",JSON.stringify({"vehicle":page.vehicle_id,"preview":page._cosmetic_preview,"paint_exact":page.showroom.livery==original,"settings_exact":page.records.settings==settings,"button_rect":str(menu.premium_gallery.restore.get_global_rect())}))
			await capture("restore-failure-"+page.vehicle_id)
		await tap(menu.premium_gallery.rows[choices[0].id])
		await tap(menu._collection_tabs.standard)
		check(page.showroom.livery==original and page._cosmetic_preview.is_empty(),"Standard switch clears premium preview")
		check(not menu.premium_gallery.icons.busy and menu.premium_gallery.icons.studio==null,"hidden premium icons release the temporary studio")
		await tap(menu._collection_tabs.premium)
		await tap(menu.premium_gallery.rows[choices[0].id])
		shop.scope = "fixture/other"
		shop.changed.emit()
		check(page._cosmetic_preview.is_empty() and page.showroom.livery==original,"account change cancels premium preview")
		shop.scope = "fixture/alice"
		shop.changed.emit()
		await tap(menu.premium_gallery.rows[choices[0].id])
		page._set_customise_tab("colours")
		await settle()
		check(page.showroom.livery==original and page._cosmetic_preview.is_empty(),"leaving Patterns restores saved paint")
		check(menu.premium_gallery.icons.studio==null and not menu.premium_gallery.icons.busy,"leaving Patterns releases premium icon work")
		check(Icons.images.size()<=Icons.CACHE_LIMIT and LiveryCatalog.mask_order.size()<=4,"existing icon and texture cache bounds retained")
	host.queue_free()
	for tick: int in range(8): await process_frame
	if "--app" in OS.get_cmdline_user_args(): await actual_app()
	var report: Dictionary = {"checks":checks,"failures":failures,"renderer":mode,"owner_profile_used":false}
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")+"\n")
	print("PREMIUM_GARAGE ",checks," checks, ",failures," failures (",mode,")")
	quit(1 if failures else 0)

func actual_app() -> void:
	var directory: String = "user://premium_garage_app_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.library = TrackLibrary.new(directory)
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	var deadline: int = Time.get_ticks_msec()+120000
	while not app.startup_complete and Time.get_ticks_msec()<deadline: await process_frame
	check(app.startup_complete,"actual App starts")
	if app.startup_complete:
		app._show_screen("garage")
		deadline = Time.get_ticks_msec()+60000
		page = null
		while Time.get_ticks_msec()<deadline:
			if is_instance_valid(app.root_ui): page = app.root_ui.find_child("GaragePage",true,false)
			if app.screen=="garage" and is_instance_valid(page) and page.is_visible_in_tree(): break
			await process_frame
		var ready: bool = app.screen=="garage" and is_instance_valid(page) and page.is_visible_in_tree()
		check(ready,"actual App opens Garage")
		if ready:
			page.open_car(0)
			await settle()
			await tap(page.livery_menu._collection_tabs.premium,true)
			await tap(page.livery_menu.premium_gallery.rows.rally_ruta_sol,true)
			await icons_ready()
			check(page.showroom.livery.pattern=="rally_ruta_sol" and page.draft.pattern=="plain","actual App previews premium without equipping")
			check(page.showroom.car.graphics.bindings.all(func(binding: Dictionary) -> bool: return binding.finish.get_shader_parameter("premium_bus_paint")==true),"actual App applies premium art to every paint binding")
			await capture("app-premium-1280")
	app.queue_free()
	for tick: int in range(8): await process_frame
