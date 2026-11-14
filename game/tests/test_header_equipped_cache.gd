extends SceneTree
## Equipped picture correctness, bounded cold work and warm/disk/account behavior.
const Icons = preload("res://ui/header_car_icons.gd")
const Profile = preload("res://ui/profile_car.gd")
var checks: int = 0
var failures: int = 0
var app: Node
var output: String

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func frames(count: int = 5) -> void:
	for _frame: int in range(count): await process_frame

func ready_cache() -> void:
	print("HEADER_PHASE wait screen=",app.screen," stage=",app.header_car_cache._stage," jobs=",app.header_car_cache._jobs.size())
	var deadline: int = Time.get_ticks_msec()+60000
	while not app.header_car_cache.idle() and Time.get_ticks_msec()<deadline: await process_frame
	check(app.header_car_cache.idle(),"equipped picture work completes within deadline")
	await create_timer(0.3).timeout
	await frames()

func picture() -> Texture2D:
	return app.account_button.get_node("MenuProfileCar").preview.texture

func save_look(paint: Dictionary, parts: Dictionary) -> void:
	app.records.settings.vehicle_liveries = {"compact":paint.duplicate(true)}
	app.records.settings.vehicle_customisation = {"compact":parts.duplicate(true)}
	check(app.records.save_records()==OK,"save isolated equipped appearance")

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"native "+label)

func compare_reference(paint: Dictionary, parts: Dictionary) -> void:
	var canvas := SubViewport.new()
	canvas.size = Icons.SIZE
	canvas.disable_3d = true
	canvas.transparent_bg = true
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var reference: Control = load("res://ui/header_icon_renderer.gd").make_preview("compact",paint,parts)
	reference.size = Vector2(Icons.SIZE)
	canvas.add_child(reference)
	while not reference.presentation_ready: await process_frame
	for _frame: int in range(7): await RenderingServer.frame_post_draw
	var expected: Image = canvas.get_texture().get_image()
	var actual: Image = picture().get_image()
	var difference: float = 0
	for y: int in range(0,Icons.SIZE.y,2):
		for x: int in range(0,Icons.SIZE.x,2):
			var a: Color = actual.get_pixel(x,y)
			var b: Color = expected.get_pixel(x,y)
			if b.a>0 and b.a<1: b = Color(minf(1,b.r/b.a),minf(1,b.g/b.a),minf(1,b.b/b.a),b.a)
			difference += absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)+absf(a.a-b.a)
	check(difference/float(Icons.SIZE.x*Icons.SIZE.y)<0.02,"cached image matches actual current paint AND fitted-kit reference: "+str(difference))
	canvas.queue_free()
	await frames()

func run() -> void:
	if DisplayServer.get_name()=="headless": quit(1); return
	OS.set_environment("BMT_API_URL","")
	root.size = Vector2i(1280,720)
	root.gui_embed_subwindows = true
	output = OS.get_environment("BMT_RIVALRY_CARS_EVIDENCE_DIR").path_join(RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(output)
	Icons.customized.clear()
	var folder: String = "user://header-equipped-"+TrackLibrary.unique_id()
	app = load("res://core/app.gd").new()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	print("HEADER_PHASE startup ready")
	app.race_area_mode = "free"
	app._show_screen("tracks")
	print("HEADER_PHASE tracks requested")
	app._select_header_vehicle(0)
	await ready_cache()
	var cache: Node = app.header_car_cache
	check(cache.captures==0,"stock pictures require no runtime captures")
	print("HEADER_PHASE stock ready")
	var paint: Dictionary = VehicleLivery.defaults("compact")
	paint.colors.body = "c82e37"
	paint.pattern = str(LiveryCatalog.patterns[3].id)
	var parts: Dictionary = VehicleCustomisation.defaults()
	parts.hood = "cowl"
	parts.aero = "splitwing"
	save_look(paint,parts)
	print("HEADER_PHASE custom saved")
	await ready_cache()
	var key: String = Icons.appearance_key("compact",app.records)
	check(Icons.customized.has(key) and picture()==Icons.texture("compact",app.records),"header receives the exact equipped appearance")
	check(picture()!=Icons.texture("compact"),"customized car does not use the stock picture")
	check(cache.captures==1 and cache.peak_worlds==1 and cache.canvas==null,"one cold capture, with no retained renderer")
	check(app.account_button.find_children("*","Node3D",true,false).is_empty() and app.account_button.find_children("*","SubViewport",true,false).is_empty(),"header and dropdown stay pure 2D")
	await shot("equipped-header")
	await compare_reference(paint,parts)
	var first_texture: Texture2D = picture()
	var captures: int = cache.captures
	for _repeat: int in range(30):
		app.account_button.get_node("MenuCarPicker")._populate()
		app._refresh_account_car()
	await ready_cache()
	check(cache.captures==captures and picture()==first_texture,"menu refreshes reuse the exact cached image without rendering")
	app._select_header_vehicle(1)
	await create_timer(0.3).timeout
	var picker: MenuButton = app.account_button.get_node("MenuCarPicker")
	picker.show_popup()
	await create_timer(0.3).timeout
	var popup: PopupMenu = picker.get_popup()
	var row: int = popup.get_item_index(0)
	check(row>=0 and popup.get_item_icon(row)==first_texture,"dropdown uses the same equipped picture")
	check(popup.item_count==VehicleCatalog.IDS.size()-1 and popup.get_item_index(1)==-1,"active car stays excluded")
	await shot("equipped-dropdown")
	popup.hide()
	app._select_header_vehicle(0)
	await create_timer(0.3).timeout
	for screen: String in ["settings","tracks","profile","tracks"]:
		app._show_screen(screen)
		await frames()
	await ready_cache()
	check(cache.captures==captures and picture()==first_texture,"navigation retains the equipped cache")
	# Rebind after clearing memory: the persisted PNG must avoid any model build.
	Icons.customized.clear()
	cache.bind_records(null)
	cache.bind_records(app.records)
	await ready_cache()
	check(cache.disk_hits>0 and cache.captures==captures,"a fresh memory cache loads the saved PNG without rendering")
	check(picture()==Icons.texture("compact",app.records),"disk hit updates the retained header")
	# A corrupt private cache file is a miss, not a permanent wrong picture.
	Icons.customized.clear()
	var broken := FileAccess.open(cache.directory.path_join(key+".png"),FileAccess.WRITE)
	broken.store_string("invalid cache")
	broken.close()
	cache.bind_records(null)
	cache.bind_records(app.records)
	await ready_cache()
	check(cache.captures==captures+1 and Icons.customized.has(key),"invalid cache regenerates one correct picture")
	captures = cache.captures
	for color: String in ["224466","225577","226688","227799"]:
		paint.colors.body = color
		save_look(paint,parts)
	await ready_cache()
	check(cache.captures==captures+1,"rapid saved edits debounce to one final capture")
	check(picture()==Icons.texture("compact",app.records),"latest saved paint wins")
	await compare_reference(paint,parts)
	var previous_kit_pixels: PackedByteArray = picture().get_image().get_data()
	var before_kit: int = cache.captures
	parts.body = str(VehicleCustomisation.OPTIONS.body[1][0])
	save_look(paint,parts)
	await ready_cache()
	check(cache.captures==before_kit+1 and picture().get_image().get_data()!=previous_kit_pixels,"changing only the equipped kit refreshes the actual picture")
	await compare_reference(paint,parts)
	await shot("changed-kit")
	var allow_menu_work: Callable = cache.allowed
	cache.allowed = func() -> bool: return false
	var before_pause: int = cache.captures
	paint.colors.body = "779922"
	save_look(paint,parts)
	await create_timer(0.5).timeout
	check(cache.canvas==null and cache.captures==before_pause,"blocked background work never creates a model")
	cache.allowed = allow_menu_work
	await ready_cache()
	check(cache.captures==before_pause+1,"returning to allowed menus resolves one pending appearance")
	# Replace the records owner while a different appearance is queued/in flight.
	paint.colors.body = "ac3377"
	save_look(paint,parts)
	cache._scan()
	await frames(2)
	var stale_key: String = Icons.appearance_key("compact",app.records)
	var other := LocalRecords.new(folder.path_join("other/records.json"))
	cache.bind_records(other)
	await ready_cache()
	check(not Icons.customized.has(stale_key) and cache.records==other and cache.canvas==null,"old-owner work cannot publish after account replacement")
	app.records = other
	app._show_screen("settings")
	await ready_cache()
	check(picture()==Icons.texture("compact"),"new account never borrows the previous account's picture")
	check(Icons.customized.size()<=Icons.CUSTOM_LIMIT,"custom texture memory stays bounded")
	var report := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":cache.captures,"disk_hits":cache.disk_hits,"peak_worlds":cache.peak_worlds,"header_3d_nodes":app.account_button.find_children("*","Node3D",true,false).size(),"header_subviewports":app.account_button.find_children("*","SubViewport",true,false).size()},"\t"))
	report.close()
	app.queue_free()
	await frames()
	print("HEADER_EQUIPPED_CACHE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
