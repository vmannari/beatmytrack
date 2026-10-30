extends SceneTree
const Fixture = preload("res://tests/test_customisation_carousel.gd")
const Icons = preload("res://ui/garage_paint_icons.gd")
const Profile = preload("res://ui/profile_car.gd")
var checks: int = 0
var failures: int = 0
var page: GaragePage
var output: String

func _initialize() -> void: run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+message)

func settle() -> void:
	while page._workbench_focus_pending or page._menu_motion!=null or page.showroom.camera_motion!=null and page.showroom.camera_motion.is_running(): await process_frame
	for tick: int in range(12): await process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw

func icons_ready() -> void:
	await settle()
	var deadline: int = Time.get_ticks_msec()+20000
	while page.livery_menu.pattern_icons.busy and Time.get_ticks_msec()<deadline: await process_frame
	check(not page.livery_menu.pattern_icons.busy,"visible icon jobs settle")

func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"capture "+name)

func tap_icon(index: int, touch: bool = false) -> void:
	var row: Button = page.livery_menu.pattern_tiles[index]
	page.livery_menu.pattern_scroll.ensure_control_visible(row)
	for tick: int in range(4): await process_frame
	var at: Vector2 = row.car_icon.get_global_rect().get_center()
	for pressed: bool in [true,false]:
		if touch:
			var event := InputEventScreenTouch.new()
			event.index = 6
			event.position = at
			event.pressed = pressed
			root.push_input(event,true)
		else:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.position = at
			event.pressed = pressed
			root.push_input(event,true)
		await process_frame

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	GameSoundtrack.instance().music_enabled = false
	output = "res://../docs/evidence/garage-paint-list-2026-10-26/native"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	Icons.images.clear()
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	root.theme = MenuStyle.theme()
	VehicleCatalog.selected = "compact"
	var host := Control.new()
	root.add_child(host)
	MenuStyle.fill(host)
	var shop: Node = Fixture.Shop.new()
	host.add_child(shop)
	page = GaragePage.new()
	page.records = LocalRecords.new("user://paint_rows_"+TrackLibrary.unique_id()+".json")
	page.economy = shop
	host.add_child(page)
	MenuStyle.fill(page)
	page.offset_top = 110
	page.open_car(0)
	await icons_ready()
	var menu: GarageLiveryMenu = page.livery_menu
	check(menu.pattern_tiles.size()==49 and menu.pattern_shelf.cards.columns==1,"all 49 paint options use one column")
	check(menu.pattern_shelf.find_child("CosmeticDetailPhoto",true,false)==null and menu.pattern_shelf.find_child("CosmeticCancelPreview",true,false)==null,"no large photo or redundant selected/cancel section")
	for index: int in menu.pattern_tiles:
		var row: Button = menu.pattern_tiles[index]
		check(row.number.text=="%02d" % (index+1),"paint option numbering")
		check(row.car_icon!=null and row.find_children("*","SubViewport",true,false).is_empty(),"tiny static icon has no per-row 3D world")
	var saved: Dictionary = page.records.settings.duplicate(true)
	page.showroom.rotate_view(Vector2(26,6))
	page.showroom.zoom_by(0.9)
	var camera: Transform3D = page.showroom.camera.transform
	await tap_icon(2,true)
	await icons_ready()
	check(page.showroom.livery.pattern==page._preset_value(2).pattern and page.draft==page._livery_saved and page.records.settings==saved,"paint previews immediately without equipping or saving")
	check(menu.pattern_tiles[2].selected and menu.pattern_tiles[2].status.text=="PREVIEWING" and menu.pattern_shelf.counter.text=="03 / 49","paint list has selected state and actual count")
	check(menu.pattern_tiles[0].checkmark.visible and menu.pattern_shelf.equip.text.contains("750"),"equipped check and explicit price remain")
	check(page.showroom.camera.transform.is_equal_approx(camera),"paint selection preserves Garage angle and zoom")
	var hold := InputEventScreenTouch.new()
	hold.index = 19
	hold.position = page._compare_button.get_global_rect().get_center()
	hold.pressed = true
	root.push_input(hold,true)
	check(page.showroom.livery==page.draft and not page._compare_livery.is_empty(),"paint compare shows equipped paint")
	await capture("paint-compare-equipped")
	hold = hold.duplicate() as InputEventScreenTouch
	hold.pressed = false
	hold.position = Vector2(3,3)
	root.push_input(hold,true)
	check(page.showroom.livery.pattern==page._preset_value(2).pattern and page._compare_livery.is_empty(),"outside release restores selected paint")
	hold = hold.duplicate() as InputEventScreenTouch
	hold.pressed = true
	hold.position = page._compare_button.get_global_rect().get_center()
	root.push_input(hold,true)
	menu.pattern_tiles[3].pressed.emit()
	hold = hold.duplicate() as InputEventScreenTouch
	hold.pressed = false
	root.push_input(hold,true)
	check(page.showroom.livery.pattern==page._preset_value(3).pattern and page._compare_livery.is_empty(),"new paint during hold cannot restore stale preview")
	menu.pattern_tiles[2].pressed.emit()
	hold = hold.duplicate() as InputEventScreenTouch
	hold.pressed = true
	root.push_input(hold,true)
	shop.scope = "fixture/bob"
	shop.changed.emit()
	hold = hold.duplicate() as InputEventScreenTouch
	hold.pressed = false
	root.push_input(hold,true)
	check(page._cosmetic_preview.is_empty() and page._compare_livery.is_empty() and page.showroom.livery==page.draft,"account change during paint comparison restores equipped paint")
	shop.scope = "fixture/alice"
	shop.changed.emit()
	menu.pattern_tiles[2].pressed.emit()
	page._set_customise_tab("livery")
	page._navigate_section("customise")
	check(page._cosmetic_preview.get("index",-1)==2,"active paint navigation preserves preview")
	page._equip_cosmetic_preview()
	check(is_instance_valid(page._purchase_dialog) and shop.purchases==0,"Buy and Equip retains explicit confirmation")
	page._purchase_dialog.hide()
	await process_frame
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1720,900)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await icons_ready()
		check(root.get_visible_rect().encloses(page.tools_panel.get_global_rect()),"paint panel fits "+str(dimensions))
		check(menu.pattern_scroll.get_global_rect().encloses(menu.pattern_tiles[2].get_global_rect()),"selected paint row stays visible")
		check(menu.pattern_tiles[2].get_global_rect().encloses(menu.pattern_tiles[2].description.get_global_rect()),"paint description stays inside the row")
		check(menu.pattern_tiles[2].car_icon.size.x<=64 and menu.pattern_tiles[2].car_icon.size.y<=40,"car icon stays tiny")
		await capture("paint-list-"+str(dimensions.x))
	check(page.records.settings==saved and shop.purchases==0,"layout and compare leave persistence/purchases unchanged")
	await tap_icon(0,true)
	await icons_ready()
	check(page.showroom.livery==page.draft and page._cosmetic_preview.is_empty() and not menu.pattern_shelf.equip.visible,"equipped row restores the actual saved paint without resetting its palette")
	check(menu.pattern_tiles[0].get_meta("icon_livery")==page.draft,"equipped tiny car matches the saved profile paint")
	await tap_icon(2)
	await icons_ready()
	if DisplayServer.get_name()!="headless": await profile_match()
	await tap_icon(48)
	await icons_ready()
	check(page.showroom.livery.pattern==page._preset_value(48).pattern and menu.pattern_tiles[48].selected,"last paint option is selectable by its tiny icon")
	check(menu.pattern_tiles[48].get_meta("icon_livery").pattern==page._preset_value(48).pattern,"last icon uses the correct candidate paint")
	check(Icons.images.size()<=Icons.CACHE_LIMIT,"scrolling the catalogue retains the cache bound")
	for index: int in range(VehicleCatalog.IDS.size()):
		page._show_section("cars")
		page.open_car(index)
		page._set_customise_tab("livery")
		await icons_ready()
		menu = page.livery_menu
		if DisplayServer.get_name()!="headless":
			var image: Image = menu.pattern_tiles[0].car_icon.texture.get_image()
			check(image.get_size()==Icons.SIZE and image.get_pixel(0,0).a<0.01,"profile icon is a fixed-size transparent cutout")
			check(menu.pattern_icons.peak_worlds<=1 and menu.pattern_icons.studio==null,"one temporary icon studio releases after use")
		check(Icons.images.size()<=Icons.CACHE_LIMIT,"icon cache stays bounded")
		await capture("paint-"+VehicleCatalog.IDS[index])
	page._set_customise_tab("colours")
	await settle()
	check(not page.livery_menu.pattern_icons.busy and page.livery_menu.pattern_icons.studio==null,"hidden paint list has no running icon world")
	if DisplayServer.get_name()!="headless":
		Icons.images.clear()
		page._set_customise_tab("livery")
		for tick: int in range(2): await process_frame
		check(page.livery_menu.pattern_icons.busy,"cold icons exercise in-flight teardown")
	host.queue_free()
	for tick: int in range(8): await process_frame
	if DisplayServer.get_name()!="headless": await actual_app_view()
	print("GARAGE_PAINT_LIST: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func profile_match() -> void:
	var row: Button = page.livery_menu.pattern_tiles[2]
	check(row.car_icon.texture!=null,"visible paint row has its profile-style icon")
	var reference: Control = Profile.make_preview(page.vehicle_id,row.get_meta("icon_livery"),page.kit_draft)
	reference.position = Vector2(-10000,-10000)
	reference.size = Vector2(88,56)
	root.add_child(reference)
	Profile.apply_presentation(reference)
	for tick: int in range(4): await RenderingServer.frame_post_draw
	reference.viewport.size = Icons.SIZE
	reference._fit_camera()
	reference.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var expected: Image = reference.viewport.get_texture().get_image()
	var actual: Image = row.car_icon.texture.get_image()
	var difference: float = 0.0
	for y: int in range(0,Icons.SIZE.y,2):
		for x: int in range(0,Icons.SIZE.x,2):
			var a: Color = actual.get_pixel(x,y)
			var b: Color = expected.get_pixel(x,y)
			difference += absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)+absf(a.a-b.a)
	difference /= float(Icons.SIZE.x*Icons.SIZE.y)
	check(difference<0.02,"tiny icon matches the actual profile presentation: "+str(difference))
	reference.queue_free()
	await process_frame

func actual_app_view() -> void:
	var directory: String = "user://paint_list_app_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.library = TrackLibrary.new(directory)
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	VehicleCatalog.selected = "compact"
	app._show_screen("garage")
	var deadline: int = Time.get_ticks_msec()+30000
	page = null
	while Time.get_ticks_msec()<deadline:
		if is_instance_valid(app.root_ui): page = app.root_ui.find_child("GaragePage",true,false)
		if app.screen=="garage" and is_instance_valid(page) and page.is_visible_in_tree(): break
		await process_frame
	var ready: bool = app.screen=="garage" and is_instance_valid(page) and page.is_visible_in_tree()
	check(ready,"actual App prepares the Garage")
	if not ready:
		app.queue_free()
		await process_frame
		return
	page.open_car(0)
	await icons_ready()
	await tap_icon(2,true)
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1720,900)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await icons_ready()
		if dimensions.y>=650:
			page.livery_menu.pattern_scroll.scroll_vertical = 0
			await icons_ready()
		check(page.showroom.livery.pattern==page._preset_value(2).pattern and page._cosmetic_preview.get("index",-1)==2,"actual App keeps the live paint preview")
		await capture("paint-app-"+str(dimensions.x))
	app.queue_free()
	await process_frame
