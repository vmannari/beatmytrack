extends SceneTree
## Actual-App first-frame images, separate-process restart, cancellation and scope.
var output: String
var profile: String
var phase: String="seed"
var checks: int=0
var failures: int=0
var app: Node
var metrics: Dictionary={}

func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: ",label)
func frames(count: int=4) -> void:
	for _frame: int in range(count): await process_frame
func settle() -> void:
	await create_timer(0.4).timeout
	await frames()
func checksum(texture: Texture2D) -> String:
	var hash:=HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(texture.get_image().get_data())
	return hash.finish().hex_encode()
func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"capture "+label)
func first_frame(label: String,prior_io: int=0) -> void:
	var page: GaragePage=app._retained_garage
	check(app.screen=="garage" and page!=null,"ready pictures allow immediate Garage navigation "+label)
	if page==null: return
	for id: String in VehicleCatalog.IDS:
		var view: CarShowroom=page.thumbnails[id]
		check(view._image.texture!=null,"picture exists before the first draw "+id+" "+label)
		check(not view._placeholder.visible,"no visible loading state "+id+" "+label)
		check(view.displayed_key==view.preview_key,"picture has the current exact identity "+id+" "+label)
		check(view.car==null and view.showroom_viewport==null,"picture owns no native world "+id)
	check(page._preview_service.renders==0,"entry creates no picture renderer "+label)
	check(page._preview_service.worker==null and page._preview_service.file_io_us==prior_io,"entry starts no PNG reads "+label)
func wait_for_writes() -> void:
	var deadline: int=Time.get_ticks_msec()+10000
	var service: Node=app._garage_preloader.picture_service
	while (service.worker!=null or not service.pending_writes.is_empty()) and Time.get_ticks_msec()<deadline: await process_frame
	check(service.worker==null and service.pending_writes.is_empty(),"prewarmed PNG writes complete")
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg.begins_with("--profile="): profile=arg.trim_prefix("--profile=")
		if arg.begins_with("--phase="): phase=arg.trim_prefix("--phase=")
	create_timer(160).timeout.connect(func() -> void: print("FAIL: ready-picture deadline");quit(1))
	root.size=Vector2i(1280,720)
	check(DirAccess.make_dir_recursive_absolute(profile)==OK,"create the isolated profile folder")
	var records:=LocalRecords.new(profile.path_join("records.json"))
	if phase=="seed":
		var paints: Dictionary={}
		var conditions: Dictionary={}
		for id: String in VehicleCatalog.IDS:
			var paint: Dictionary=VehicleLivery.for_car({},id)
			paint.colors.body="c72d34"
			paints[id]=paint
			var condition: Dictionary=VehicleWeathering.new().snapshot()
			condition.dirt=0.2
			conditions[id]=condition
		records.settings.vehicle_liveries=paints
		records.settings.music_enabled=false
		check(records.save_records()==OK,"seed isolated saved liveries")
		check(records.save_vehicle_conditions(conditions)==OK,"seed isolated saved wear")
	app=load("res://core/app.tscn").instantiate()
	app.records=records
	app.library=TrackLibrary.new(profile.path_join("tracks"))
	app.cloud_root_override=profile.path_join("cloud")
	var began: int=Time.get_ticks_usec()
	root.add_child(app)
	while not app.startup_complete:
		app._publishing_slots_foreground=true # Represent a foreground app in the native test window.
		await process_frame
	metrics.startup_ms=(Time.get_ticks_usec()-began)/1000.0
	metrics.preview_revision=preload("res://core/build_identity.gd").GARAGE_PREVIEW_SHA256
	var loader: Node=app._garage_preloader
	loader.idle_ms=100000 # Isolate picture preparation from the optional live-studio warmup.
	loader.foreground=true
	GameSoundtrack.instance().music_enabled=false
	GameSoundtrack.instance().menu_player.stop()
	check(loader.pictures_ready(),"all exact pictures are prepared before the startup menu")
	if not loader.pictures_ready():
		metrics.ready_vehicles=loader.picture_pool().keys()
		metrics.active_vehicle=loader.picture_service.active.get("vehicle","")
		metrics.picture_captures=loader.picture_service.renders
		metrics.checks=checks;metrics.failures=failures;metrics.phase=phase
		FileAccess.open(output.path_join(phase+".json"),FileAccess.WRITE).store_string(JSON.stringify(metrics,"  "))
		print("READY_PICTURES: ",JSON.stringify(metrics))
		quit(1)
		return
	check(app._retained_garage==null,"picture preparation constructs no Garage page")
	check(loader.picture_service.renderer==null,"startup releases the temporary picture world")
	metrics.picture_captures=loader.picture_service.renders
	var expected: Dictionary={}
	if phase!="seed": expected=JSON.parse_string(FileAccess.get_file_as_string(profile.path_join("picture-pixels.json")))
	metrics.same_visual_revision=phase!="seed" and expected.get("revision")==metrics.preview_revision
	if phase=="seed" or metrics.same_visual_revision:
		check(loader.picture_service.renders==(VehicleCatalog.IDS.size() if phase=="seed" else 0),"only an uncached visual revision generates pictures")
	app._show_screen("tracks")
	await settle()
	began=Time.get_ticks_usec()
	app._navigate_menu_page("garage")
	metrics.entry_dispatch_ms=(Time.get_ticks_usec()-began)/1000.0
	first_frame("entry")
	var hashes: Dictionary={}
	for id: String in VehicleCatalog.IDS: hashes[id]=checksum(app._retained_garage.thumbnails[id]._image.texture)
	if phase=="seed":
		var file:=FileAccess.open(profile.path_join("picture-pixels.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"revision":metrics.preview_revision,"pixels":hashes}));file.close()
	else:
		if metrics.same_visual_revision: check(hashes==expected.pixels,"the new process displays the exact saved PNG pixels")
	metrics.pixel_hashes=hashes
	await capture("first-draw")
	await settle()
	await capture("ready-carousel")
	var memory: Dictionary=app._garage_residency()
	metrics.memory=memory
	check(int(memory.get("preload_picture_gpu_bytes",0))<=VehicleCatalog.IDS.size()*2048*512*4,"ready-picture memory stays bounded to the catalogue")
	check(memory.image_gpu_bytes==0,"shared pictures are not counted twice in Garage residency")
	await wait_for_writes()
	app._show_screen("biome")
	await settle()
	await frames(8)
	check(app.menu_neighbors.has(1) and app.menu_neighbors[1].screen=="garage","retained Garage is a real swipe neighbor")
	app._drag_menu_edge(-120.0)
	check(app.menu_neighbors[1].body.visible,"ready Garage can be revealed under the swipe")
	app._swipe_menu_page(1)
	first_frame("swipe")
	await settle()
	if phase=="reuse": await changes_and_scope()
	app.queue_free()
	await frames(8)
	metrics.checks=checks;metrics.failures=failures;metrics.phase=phase
	FileAccess.open(output.path_join(phase+".json"),FileAccess.WRITE).store_string(JSON.stringify(metrics,"  "))
	print("READY_PICTURES: ",JSON.stringify(metrics))
	quit(1 if failures else 0)

func changes_and_scope() -> void:
	app._show_screen("settings")
	await settle()
	var paint: Dictionary=VehicleLivery.for_car(app.records.settings,"compact")
	paint.colors.body="3d7acf"
	app.records.settings.vehicle_liveries.compact=paint
	check(app.records.save_records()==OK,"save a changed appearance only in the fixture")
	app._garage_appearance_changed()
	app._navigate_menu_page("garage")
	check(app.screen=="settings","an uncaptured new appearance does not reveal a loading carousel")
	app._show_screen("tracks")
	var loader: Node=app._garage_preloader
	var deadline: int=Time.get_ticks_msec()+45000
	while not loader.pictures_ready() and Time.get_ticks_msec()<deadline: await process_frame
	check(loader.pictures_ready() and app.screen=="tracks","another tab cancels the pending Garage navigation")
	await settle()
	var prior_io: int=app._retained_garage._preview_service.file_io_us
	app._navigate_menu_page("garage")
	first_frame("changed",prior_io)
	check(app._retained_garage.thumbnails.compact.livery.colors.body=="3d7acf","first changed picture matches the saved blue finish")
	await settle()
	await wait_for_writes()
	app._show_screen("settings")
	await settle()
	var old_pool: Dictionary=loader.picture_pool()
	var before_pressure: String=JSON.stringify(VehicleCondition.read(app.records,"compact")).sha256_text()
	app._trim_hidden_garage()
	check(loader.picture_service==null and old_pool.is_empty(),"memory pressure releases optional decoded pictures")
	await frames()
	app._navigate_menu_page("garage")
	if app.screen!="garage":
		var missing: Dictionary={}
		for id: String in loader.picture_service.warm_views:
			var view: CarShowroom=loader.picture_service.warm_views[id]
			missing[id]={"key":view.preview_key,"displayed":view.displayed_key,"exists":FileAccess.file_exists(loader.picture_service.directory.path_join(view.preview_key+".png")),"condition_hash":JSON.stringify(view.condition).sha256_text()}
		missing.before_pressure=before_pressure
		print("PRESSURE_PICTURES: ",JSON.stringify(missing))
	first_frame("disk-after-pressure")
	app._show_screen("settings")
	await settle()
	var other:=LocalRecords.new(profile.path_join("other/records.json"))
	app.records=other
	app._navigate_menu_page("garage")
	first_frame("other-owner")
	check(app._retained_garage.records==other and loader.picture_records==other,"ready pictures are fenced by the current storage owner")
	check(app._retained_garage.thumbnails.compact.livery==VehicleLivery.for_car(other.settings,"compact"),"new owner's first picture does not reuse the old blue finish")
	await settle()
	await capture("other-owner")
