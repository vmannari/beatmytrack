extends SceneTree
## Production App policy: cheap reads immediately, native captures after idle.
const Icons = preload("res://ui/header_car_icons.gd")
var app: Node
var checks: int = 0
var failures: int = 0
var capture_starts: int = 0
var menu_draws: int = 0
var capture_menu_draws: int = 0
var cancel_next: bool = false
var output: String
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("DEFERRED_HEADER_FAIL ",label)
func frames(count: int = 6) -> void:
	for _i: int in range(count):
		app._publishing_slots_foreground = true
		await process_frame
func wait_reads() -> void:
	var deadline: int = Time.get_ticks_msec()+10000
	while not app.header_car_cache.reads_idle() and Time.get_ticks_msec()<deadline: await frames(1)
	check(app.header_car_cache.reads_idle(),"all queued disk reads finish despite deferred native work")
func picture() -> Control: return app.account_button.get_node("MenuProfileCar")
func shot(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"native view "+label)
func capture_started(_vehicle: String) -> void:
	capture_starts += 1
	check(app.screen!="garage" and not app._retained_garage.is_visible_in_tree(),"production capture waits until Garage has left the screen")
	check(app.header_car_cache.canvas==null,"settled menu draw precedes renderer construction")
	capture_menu_draws = menu_draws
	if cancel_next: app._show_screen.call_deferred("garage")
func after_draw() -> void:
	if not is_instance_valid(app): return
	menu_draws += 1
	if app.header_car_cache.canvas!=null:
		check(menu_draws>capture_menu_draws+1,"settled menu drew before the first native construction")
func run() -> void:
	create_timer(180,true,false,true).timeout.connect(func() -> void: printerr("DEFERRED_HEADER_TIMEOUT"); quit(1))
	output = OS.get_environment("BMT_GRAPHICS_EVIDENCE")
	root.size = Vector2i(1280,720)
	Icons.customized.clear()
	app = load("res://core/app.gd").new()
	var records := LocalRecords.new("user://deferred-header/records.json")
	DirAccess.make_dir_recursive_absolute(records.path.get_base_dir())
	var paint: Dictionary = VehicleLivery.defaults("compact")
	paint.colors.body = "32b5d7"
	var kart_paint: Dictionary = VehicleLivery.defaults("kart")
	kart_paint.colors.body = "c82e37"
	records.settings = {"music_enabled":false,"selected_car":"compact","vehicle_liveries":{"compact":paint,"kart":kart_paint}}
	check(records.save_records()==OK,"isolated saved custom appearances")
	app.records = records
	app.library = TrackLibrary.new("user://deferred-header/tracks")
	app.cloud_root_override = "user://deferred-header/cloud"
	root.add_child(app)
	while not app.startup_complete: await frames(1)
	app._garage_preloader.idle_ms = 1000000
	var cache: Node = app.header_car_cache
	check(not app.online.configured and app.screen=="account","actual offline startup completes")
	check(cache.captures==0 and cache.peak_worlds==0,"custom startup never constructs a header world")
	await wait_reads()
	app.race_area_mode = "free"
	app._show_screen("tracks")
	await frames(20)
	check(picture().preview.texture==null and picture()._placeholder.visible,"missing saved design shows a neutral silhouette")
	check(picture()._placeholder.texture.region==Rect2(0,0,384,256),"silhouette uses the selected actual model")
	check(cache.captures==0 and cache.canvas==null,"visible menu never starts a cold header capture")
	check(app.account_button.find_children("*","Node3D",true,false).is_empty() and app.account_button.find_children("*","SubViewport",true,false).is_empty(),"header and picker stay 2D")
	await shot("menu-silhouette")
	# A later car's disk hit must pass an earlier deferred capture in the queue.
	var pixels := Image.create(176,112,false,Image.FORMAT_RGBA8)
	pixels.fill(Color("c82e37"))
	DirAccess.make_dir_recursive_absolute(cache.directory)
	var kart_key: String = Icons.appearance_key("kart",records)
	check(pixels.save_png(cache.directory.path_join(kart_key+".png"))==OK,"seed bounded exact-key disk read")
	cache.bind_records(null)
	cache.bind_records(records)
	await wait_reads()
	check(cache.disk_hits==1 and Icons.customized.has(kart_key),"deferred first-car capture does not starve another car's disk hit")
	check(cache.captures==0 and cache.peak_worlds==0,"disk hits need no renderer")
	for screen: String in ["settings","profile","tracks"]:
		app._show_screen(screen)
		await frames(8)
		check(not app._header_car_capture_allowed("compact"),"no native header capture on "+screen)
	check(cache.captures==0,"ordinary navigation keeps native work deferred")
	if "--garage" in OS.get_cmdline_user_args():
		app._garage_preloader.idle_ms = 750
		app._garage_preloader.last_input = Time.get_ticks_msec()-1000
		cache.capture_started.connect(capture_started)
		RenderingServer.frame_post_draw.connect(after_draw)
		app._show_screen("garage")
		var deadline: int = Time.get_ticks_msec()+100000
		while (not app._retained_garage.showroom.showroom_ready or app._retained_garage.showroom.get("preparing")==true) and Time.get_ticks_msec()<deadline:
			await frames(1)
		await create_timer(1.1).timeout
		check(cache.captures==0 and cache.canvas==null and capture_starts==0,"ready Garage keeps optional native header work deferred")
		await shot("garage-live")
		app._show_screen("tracks")
		deadline = Time.get_ticks_msec()+60000
		while cache.captures==0 and Time.get_ticks_msec()<deadline: await frames(1)
		await wait_reads()
		await frames(10)
		check(cache.captures==1 and Icons.ready("compact",records),"settled menu produces one exact saved picture after leaving Garage")
		check(capture_starts==1 and menu_draws>0 and cache.peak_worlds==1,"one bounded native world after a settled menu draw")
		check(cache.canvas==null,"completed capture releases its world")
		check(picture().preview.texture==Icons.texture("compact",records) and not picture()._placeholder.visible,"finished picture replaces the silhouette")
		await shot("menu-header-ready")
		var first: PackedByteArray = Icons.texture("compact",records).get_image().get_data()
		Icons.customized.clear()
		cache.bind_records(null)
		cache.bind_records(records)
		await wait_reads()
		check(cache.captures==1 and Icons.texture("compact",records).get_image().get_data()==first,"persisted PNG reloads exact final pixels without a capture")
		# A freshly committed appearance removes the previous paint immediately.
		paint.colors.body = "779922"
		records.settings.vehicle_liveries.compact = paint.duplicate(true)
		cancel_next = true
		check(records.save_records()==OK,"save next isolated appearance")
		check(picture().preview.texture==null and picture()._placeholder.visible,"commit immediately clears obsolete saved paint")
		deadline = Time.get_ticks_msec()+10000
		while app.screen=="tracks" and Time.get_ticks_msec()<deadline: await frames(1)
		await frames(12)
		check(app.screen=="garage" and cache.captures==1 and cache.canvas==null,"returning to Garage cancels optional capture before renderer construction")
		check(not Icons.ready("compact",records),"cancelled appearance cannot publish stale pixels")
		RenderingServer.frame_post_draw.disconnect(after_draw)
	# Rebinding drops queued work from the old account.
	var old_key: String = Icons.appearance_key("compact",records)
	var other := LocalRecords.new("user://deferred-header/other.json")
	other.settings.music_enabled = false
	app.records = other
	cache.bind_records(other)
	app._show_screen("settings")
	await frames(12)
	check(cache.idle() and cache.canvas==null and cache.records==other,"account replacement drops deferred old-owner work")
	check(not Icons.customized.has(old_key),"old owner never publishes after replacement")
	check(picture().preview.texture==Icons.texture("compact"),"new stock account displays its own bundled picture")
	var result: Dictionary = {"checks":checks,"failures":failures,"captures":cache.captures,"disk_hits":cache.disk_hits,"peak_worlds":cache.peak_worlds,"capture_starts":capture_starts,"menu_draws":menu_draws}
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	app.queue_free()
	app = null
	for _i: int in range(12): await process_frame
	print("DEFERRED_HEADER ",JSON.stringify(result))
	quit(1 if failures else 0)
