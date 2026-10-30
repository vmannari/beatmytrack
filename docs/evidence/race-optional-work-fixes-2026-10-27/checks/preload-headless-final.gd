extends SceneTree
var checks: int=0
var failures: int=0
var output: String="res://../build/race-optional-work-fixes-2026-10-27/outputs/preload-headless-final/"
var timings: Dictionary={}
func _initialize() -> void:
	if "--task-start-app" in OS.get_cmdline_user_args():
		var script: Script=load("res://core/app.gd")
		script.source_code=FileAccess.get_file_as_string("res://../docs/evidence/garage-preload-2026-10-27/before/game/core/app.gd")
		assert(script.reload(true)==OK)
	run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: ",label)
func frames(count: int=4) -> void:
	for _frame: int in range(count): await process_frame
func viewport_drag(view: CarShowroom) -> void:
	var point: Vector2=view.get_global_rect().get_center()
	var touch:=InputEventScreenTouch.new()
	touch.index=6;touch.position=point;touch.pressed=true
	Input.parse_input_event(touch)
	await process_frame
	var motion:=InputEventScreenDrag.new()
	motion.index=6;motion.position=point+Vector2(50,0);motion.relative=Vector2(50,0)
	Input.parse_input_event(motion)
	await process_frame
	touch.pressed=false;touch.position=motion.position
	Input.parse_input_event(touch)
	await process_frame
func wait_ready(loader: Node) -> void:
	var deadline: int=Time.get_ticks_msec()+120000
	while (loader.studio==null or not loader.studio.prepared) and Time.get_ticks_msec()<deadline: await process_frame
	check(loader.studio!=null and loader.studio.prepared,"original studio finishes preloading before entry")
func replace_loader(app: Node) -> Node:
	app._show_screen("tracks")
	while app.menu_page_motion!=null and app.menu_page_motion.is_running(): await process_frame
	app._trim_hidden_garage()
	app._garage_preloader.queue_free()
	var loader: Node=preload("res://ui/garage_preloader.gd").new()
	loader.app=app
	app._garage_preloader=loader
	app.add_child(loader)
	loader.idle_ms=40
	loader.foreground=true
	return loader
func finish(app: Node) -> void:
	var deadline: int=Time.get_ticks_msec()+30000
	while not preload("res://ui/garage_preview_cache.gd").pending_pictures.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	app.queue_free()
	await frames(20)
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"timings":timings},"  "))
	print("GARAGE_PRELOAD ",checks," checks, ",failures," failures ",JSON.stringify(timings))
	quit(1 if failures else 0)
func run() -> void:
	var optional_work_test_config:=ConfigFile.new()
	optional_work_test_config.set_value("backend","url","")
	assert(optional_work_test_config.save("user://backend.cfg")==OK)
	OS.unset_environment("BMT_API_URL")

	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	output=ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,720)
	var app: Node=load("res://core/app.tscn").instantiate()
	var folder: String="user://preload-"+TrackLibrary.unique_id()
	app.records=LocalRecords.new(folder.path_join("records.json"))
	app.library=TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override=folder.path_join("cloud")
	var began: int=Time.get_ticks_usec()
	root.add_child(app)
	while not app.startup_complete: await process_frame
	timings.startup_ms=(Time.get_ticks_usec()-began)/1000.0
	check(not is_instance_valid(app._retained_garage),"startup does not construct a Garage page")
	var loader: Node=app.get("_garage_preloader")
	check(is_instance_valid(loader),"startup schedules the optional preloader")
	if loader==null:
		await finish(app)
		return
	check(loader.studio==null,"startup does not await native construction or first draws")
	loader.foreground=true # Offscreen native test window represents an active app.
	if DisplayServer.get_name()=="headless": loader.idle_ms=40
	var music: GameSoundtrack=GameSoundtrack.instance()
	music.music_enabled=false;music.menu_player.stop();music.menu_player.stream=null
	var paint: Dictionary=VehicleLivery.defaults("compact")
	paint.colors.body="c72d34"
	paint.pattern=LiveryCatalog.patterns[0].id
	paint.stickers.hood.id=LiveryCatalog.stickers[0].id
	app.records.settings.vehicle_liveries={"compact":paint.duplicate(true)}
	var wear: Dictionary=VehicleWeathering.new().snapshot()
	wear.dirt=0.2;wear.slow_dirt=0.1
	check(app.records.save_vehicle_conditions({"compact":wear})==OK,"seed isolated saved wear")
	var wear_hash: String=FileAccess.get_sha256(app.records.path+".conditions.json")
	VehicleCatalog.selected="compact"
	app._garage_appearance_changed()
	app._show_screen("tracks")
	var deadline: int=Time.get_ticks_msec()+120000
	while (loader.studio==null or not loader.studio.showroom_ready) and Time.get_ticks_msec()<deadline: await process_frame
	check(loader.studio!=null and loader.studio.showroom_ready,"selected native car is built offscreen after menu idle")
	if loader.studio==null:
		await finish(app)
		return
	var held:=InputEventScreenTouch.new()
	held.index=7;held.pressed=true
	loader._input(held)
	await frames(2)
	var draws: int=loader.studio.warm_draws
	await frames(6)
	check(loader.studio.warm_draws==draws,"held input pauses native preparation between batches")
	check(not loader._allowed(),"a held touch cannot become idle")
	held.pressed=false;loader._input(held)
	var last_input: int=loader.last_input
	loader._input(InputEventMouseMotion.new())
	check(loader.last_input==last_input,"passive hover does not postpone preparation")
	began=Time.get_ticks_usec()
	await wait_ready(loader)
	timings.remaining_preload_ms=(Time.get_ticks_usec()-began)/1000.0
	check(not is_instance_valid(app._retained_garage),"preparation remains separate from visible page creation")
	var studio: CarShowroom=loader.studio
	timings.max_native_warm_draw_ms=studio.max_draw_ms
	timings.warm_draws=studio.warm_draws
	timings.preload_residency=loader.residency()
	check(studio.car.livery==paint and studio.reflections.views.size()==2,"preloaded studio uses saved livery and original reflections")
	check(is_equal_approx(studio.weathering.dirt_amount,0.2) and is_equal_approx(studio.weathering.slow_dirt_amount,0.1),"preloaded live geometry retains saved wear")
	check(FileAccess.get_sha256(app.records.path+".conditions.json")==wear_hash,"preloading leaves saved condition bytes unchanged")
	check(studio.find_children("*","SubViewport",true,false).size()==3,"preload owns one original studio with three viewports")
	var original_geometry: Array=studio._held.duplicate()
	began=Time.get_ticks_usec()
	app._show_screen("garage")
	timings.entry_dispatch_ms=(Time.get_ticks_usec()-began)/1000.0
	var entry_began: int=began
	var page: GaragePage=app._retained_garage
	check(page.showroom==studio and studio.adopted,"Garage adopts the exact preloaded world")
	check(loader.studio==null,"preloader relinquishes the adopted world")
	check(studio._pending.is_empty() and studio._held.is_empty(),"handoff releases every held original")
	for entry: Dictionary in original_geometry:
		var node: Object=entry.node.get_ref()
		if is_instance_valid(node):
			check(node.visible and node.extra_cull_margin==entry.margin,"handoff restores original visibility and culling")
	check(studio.find_child("GarageOpeningPicture",true,false)==null,"main Garage remains live without a stock-photo cover")
	var yaw: float=studio.yaw
	var motion:=InputEventMouseMotion.new()
	motion.button_mask=MOUSE_BUTTON_MASK_LEFT;motion.relative=Vector2(30,0)
	studio.gui_input.emit(motion)
	check(studio.yaw!=yaw,"adopted live input works immediately")
	check(app.records.settings.vehicle_liveries.compact==paint,"preloading does not rewrite saved appearance")
	while app.menu_page_motion!=null and app.menu_page_motion.is_running(): await process_frame
	await frames(4)
	timings.first_live_page_ms=(Time.get_ticks_usec()-entry_began)/1000.0
	yaw=studio.yaw
	await viewport_drag(studio)
	check(studio.yaw!=yaw,"viewport touch input rotates the adopted studio")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join("preloaded-live.png"))==OK,"capture the adopted original live studio")
	# A saved appearance arriving after a ready preload cannot publish stale paint.
	loader=await replace_loader(app)
	await wait_ready(loader)
	var stale: WeakRef=weakref(loader.studio)
	paint.colors.body="326da8"
	app.records.settings.vehicle_liveries.compact=paint.duplicate(true)
	app._show_screen("garage")
	check(app._retained_garage.showroom.car.livery==paint,"a late saved-paint change uses the current live appearance")
	check(not app._retained_garage.showroom.is_queued_for_deletion(),"stale preload rejection leaves a live normal showroom")
	await frames(4)
	check(stale.get_ref()==null,"stale private studio is released")
	loader=await replace_loader(app)
	await wait_ready(loader)
	stale=weakref(loader.studio)
	app.records=LocalRecords.new(folder.path_join("another-owner.json"))
	app._show_screen("garage")
	check(app._retained_garage.showroom.car.livery==VehicleLivery.defaults("compact"),"another records owner cannot adopt the prior appearance")
	await frames(4)
	check(stale.get_ref()==null,"owner replacement releases the old private world")
	loader=await replace_loader(app)
	await wait_ready(loader)
	app.cloud_starting=true
	await frames(4)
	check(loader.studio==null and not loader._allowed(),"race preparation retires optional native work")
	app.cloud_starting=false
	await wait_ready(loader)
	loader.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not loader._allowed(),"background application cannot warm native materials")
	loader.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	app.notification(NOTIFICATION_OS_MEMORY_WARNING)
	await frames(12)
	check(loader.evicted and loader.studio==null and not loader.has_work(),"memory pressure releases and suppresses optional preload")
	# Resource-only entry retains threaded reads through the normal constructor.
	loader=await replace_loader(app)
	loader.foreground=false
	deadline=Time.get_ticks_msec()+30000
	var asset: String="res://assets/garage/cars_v1/compact.scn"
	while not loader._resources.has(asset) and Time.get_ticks_msec()<deadline: await process_frame
	check(loader.studio==null and loader._resources.has(asset),"asset decoding runs before native work is allowed")
	var decoded: WeakRef=weakref(loader._resources[asset])
	app._show_screen("garage")
	check(app._retained_garage.showroom.showroom_ready and decoded.get_ref()!=null,"resource-only entry builds live 3D using the retained asset")
	check(app._retained_garage.showroom.find_child("GarageOpeningPicture",true,false)==null,"resource-only fallback uses the normal live view")
	# Entering while the first draw batch is outstanding restores every original.
	loader=await replace_loader(app)
	deadline=Time.get_ticks_msec()+30000
	while (loader.studio==null or not loader.studio.showroom_ready) and Time.get_ticks_msec()<deadline: await process_frame
	var partial: CarShowroom=loader.studio
	var margins: Array=partial._held.duplicate()
	app._show_screen("garage")
	check(app._retained_garage.showroom==partial and partial.adopted,"partially warmed studio transfers without waiting")
	for entry: Dictionary in margins:
		var node: Object=entry.node.get_ref()
		if is_instance_valid(node): check(node.visible and node.extra_cull_margin==entry.margin,"partial handoff restores visibility and original culling")
	loader=await replace_loader(app)
	var parts: Dictionary=VehicleCustomisation.defaults()
	parts.aero="wing"
	app.records.settings.vehicle_customisation={"compact":parts}
	loader.invalidate()
	deadline=Time.get_ticks_msec()+30000
	while loader.studio==null and Time.get_ticks_msec()<deadline: await process_frame
	var building: CarShowroom=loader.studio
	timings.constructor_interrupted=not building.showroom_ready
	app._show_screen("garage")
	check(app._retained_garage.showroom.showroom_ready and app._retained_garage.showroom.car.customisation==parts,"entry during cooperative construction opens the current complete car")
	if timings.constructor_interrupted: check(app._retained_garage.showroom!=building,"unfinished constructor is retired before normal entry")
	await finish(app)
