extends SceneTree
## CPR02: two independent App processes share disk pictures, never process memory.
const Icons = preload("res://ui/header_car_icons.gd")
var checks: int = 0
var failures: int = 0
var app: Node
var output: String
var folder: String
var phase: String

class ObservedApp extends "res://core/app.gd":
	var block_picture_captures: bool = false
	func _header_car_capture_allowed(vehicle: String) -> bool:
		return not block_picture_captures and super._header_car_capture_allowed(vehicle)

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: ",label)
func frames(count: int = 8) -> void:
	for _frame: int in range(count): await process_frame
func wait_for(predicate: Callable, label: String) -> void:
	var deadline: int = Time.get_ticks_msec()+45000
	while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
	check(predicate.call(),label)
func pixels_hash(texture: Texture2D) -> String:
	var pixels: Image = texture.get_image()
	pixels.clear_mipmaps()
	return pixels.get_data().hex_encode().sha256_text()
func header() -> Texture2D:
	return app.account_button.get_node("MenuProfileCar").preview.texture

func run() -> void:
	if DisplayServer.get_name()=="headless": quit(1); return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output=argument.trim_prefix("--evidence-root=")
		if argument.begins_with("--records-root="): folder=argument.trim_prefix("--records-root=")
		if argument.begins_with("--phase="): phase=argument.trim_prefix("--phase=")
	if folder.is_empty() or phase not in ["seed","restore"]: quit(1); return
	DirAccess.make_dir_recursive_absolute(folder)
	DirAccess.make_dir_recursive_absolute(output)
	OS.set_environment("BMT_API_URL","")
	check(Icons.customized.is_empty(),"fresh process starts without customised textures in memory")
	var records := LocalRecords.new(folder.path_join("records.json"))
	if phase=="seed":
		check(not FileAccess.file_exists(records.path),"new private restart fixture")
		var rally: Dictionary=VehicleLivery.defaults("compact")
		rally.colors.body="c82e37"
		rally.pattern="apex_twin"
		var kart: Dictionary=VehicleLivery.defaults("kart")
		kart.colors.body="22879d"
		var parts: Dictionary=VehicleCustomisation.defaults()
		parts.hood="cowl"
		records.settings={"music_enabled":false,"selected_car":"kart","vehicle_liveries":{"compact":rally,"kart":kart},"vehicle_customisation":{"compact":parts}}
		var saved: Error=records.save_records()
		check(saved==OK,"save isolated paint and kit choices: "+str(saved))
		if saved!=OK: quit(1); return
	VehicleSimulation.new(VehicleCatalog.config("compact")).step(DriveFrame.sample(0,1,0))
	root.size=Vector2i(1280,720)
	root.content_scale_size=root.size
	app=ObservedApp.new()
	app.block_picture_captures=phase=="restore"
	app.records=records
	app.library=TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override=folder.path_join("cloud")
	root.add_child(app)
	await wait_for(func() -> bool: return app.startup_complete,"private App starts")
	app._show_screen("tracks")
	var cache: Node=app.header_car_cache
	var previous: Dictionary={}
	if phase=="restore":
		previous=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("seed.json")))
		check(int(previous.pid)!=OS.get_process_id(),"restore runs in a different OS process")
		for id: String in ["compact","kart"]:
			check(Icons.appearance_key(id,records)==previous.cars[id].key,"unchanged build/account/appearance key survives restart "+id)
		if failures>0:
			app.queue_free(); await frames(); quit(1); return
	await wait_for(func() -> bool: return Icons.ready("compact",records) and Icons.ready("kart",records) and cache.idle(),"both saved pictures become ready")
	var summary: Dictionary={"phase":phase,"pid":OS.get_process_id(),"cars":{},"saved_keys":Array(cache._saved_picture_keys()),"captures":cache.captures,"disk_hits":cache.disk_hits,"peak_picture_worlds":cache.peak_worlds}
	for id: String in ["compact","kart"]:
		var key: String=Icons.appearance_key(id,records)
		var path: String=cache.directory.path_join(key+".png")
		var texture: Texture2D=Icons.texture(id,records)
		check(texture!=null and FileAccess.file_exists(path),"current picture exists on disk "+id)
		summary.cars[id]={"key":key,"path":path,"png_sha256":FileAccess.get_sha256(path),"pixels_sha256":pixels_hash(texture)}
		if phase=="restore":
			check(summary.cars[id].png_sha256==previous.cars[id].png_sha256,"persisted PNG unchanged "+id)
			check(summary.cars[id].pixels_sha256==previous.cars[id].pixels_sha256,"restored pixels exactly match the former process "+id)
	if phase=="seed":
		check(cache.captures==2 and cache.disk_hits==0,"first process captures exactly two customised looks")
		FileAccess.open(folder.path_join("seed.json"),FileAccess.WRITE).store_string(JSON.stringify(summary,"\t"))
	else:
		check(cache.captures==0 and cache.disk_hits==2,"restarted App reads both PNGs with zero picture captures")
		check(cache.peak_worlds==0 and cache.canvas==null and cache.studio==null,"disk restoration creates no picture studio")
	await frames(12)
	check(header()==Icons.texture("kart",records),"profile button receives the saved selected-car picture")
	app._show_screen("garage")
	var page: GaragePage=app._retained_garage
	await wait_for(func() -> bool: return page.showroom.showroom_ready,"live Garage opens")
	await frames(15)
	page._finish_menu_move()
	for id: String in ["compact","kart"]:
		check(page.thumbnails[id]._image.texture==Icons.texture(id,records),"carousel reuses the same restored texture "+id)
	check(page._preview_service.renders==0,"Garage never makes separate picture captures")
	if phase=="restore": check(cache.captures==0,"opening Garage after restart still needs zero picture captures")
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join("pictures-"+phase+".png"))==OK,"capture "+phase)
	summary.checks=checks
	summary.failures=failures
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(summary,"\t"))
	app.queue_free()
	await frames(15)
	print("CAR_PICTURE_RESTART ",JSON.stringify(summary))
	quit(1 if failures else 0)
