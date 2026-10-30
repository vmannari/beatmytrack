extends SceneTree
## Actual App regression: the first Garage is the saved, interactive native car.
var checks: int=0
var failures: int=0
var output: String="res://../build/re-audit-2026-10-27/outputs/test_garage_live_entry"
var timings: Dictionary={}
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: ",label)
func frames(count: int=4) -> void:
	for _frame: int in range(count): await process_frame
func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"capture "+label)
func drag(view: CarShowroom,relative: Vector2) -> void:
	var motion:=InputEventMouseMotion.new()
	motion.button_mask=MOUSE_BUTTON_MASK_LEFT
	motion.relative=relative
	view.gui_input.emit(motion)
func viewport_drag(view: CarShowroom) -> void:
	var point: Vector2=view.get_global_rect().get_center()
	var down:=InputEventScreenTouch.new()
	down.index=4;down.position=point;down.pressed=true
	Input.parse_input_event(down)
	await process_frame
	var motion:=InputEventScreenDrag.new()
	motion.index=4;motion.position=point+Vector2(50,0);motion.relative=Vector2(50,0)
	Input.parse_input_event(motion)
	await process_frame
	var up:=InputEventScreenTouch.new()
	up.index=4;up.position=motion.position
	Input.parse_input_event(up)
	await process_frame
func changed(a: Image,b: Image) -> int:
	var count: int=0
	for y: int in range(a.get_height()):
		for x: int in range(a.get_width()):
			var p: Color=a.get_pixel(x,y);var q: Color=b.get_pixel(x,y)
			if absf(p.r-q.r)+absf(p.g-q.g)+absf(p.b-q.b)>0.025: count+=1
	return count
func finish(app: Node) -> void:
	app.queue_free()
	await frames(16)
	var result: Dictionary={"checks":checks,"failures":failures,"timings":timings}
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("GARAGE_LIVE_ENTRY ",JSON.stringify(result))
	quit(1 if failures else 0)
func run() -> void:
	print("AUDIT_PID ",OS.get_process_id())
	var audit_config := ConfigFile.new()
	audit_config.set_value("backend","url","")
	assert(audit_config.save("user://backend.cfg")==OK)
	OS.unset_environment("BMT_API_URL")

	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	output=ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,720)
	var app: Node=load("res://core/app.tscn").instantiate()
	var folder: String="user://garage-live-"+TrackLibrary.unique_id()
	app.records=LocalRecords.new(folder.path_join("records.json"))
	app.library=TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override=folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var music: GameSoundtrack=GameSoundtrack.instance()
	music.music_enabled=false;music.menu_player.stop();music.menu_player.stream=null
	check(not is_instance_valid(app._retained_garage),"guest startup stays independent of Garage")
	var paints: Dictionary={}
	for id: String in VehicleCatalog.IDS:
		var paint: Dictionary=VehicleLivery.defaults(id)
		paint.colors.body="c72d34"
		paint.pattern=LiveryCatalog.patterns[0].id
		paint.stickers.hood.id=LiveryCatalog.stickers[0].id
		paints[id]=paint
	app.records.settings.vehicle_liveries=paints.duplicate(true)
	app.records.settings.selected_car="compact"
	VehicleCatalog.selected="compact"
	app._show_screen("tracks")
	await frames(10)
	var start: int=Time.get_ticks_usec()
	app._show_screen("garage")
	timings.entry_dispatch_ms=(Time.get_ticks_usec()-start)/1000.0
	var page: GaragePage=app._retained_garage
	var view: CarShowroom=page.showroom
	check(not page.progressive_entry,"production Garage uses the original live showroom")
	check(view.find_child("GarageOpeningPicture",true,false)==null,"first Garage has no stock picture cover")
	check(is_instance_valid(view.car) and view.showroom_ready,"native saved car exists when Garage entry returns")
	var yaw: float=view.yaw
	drag(view,Vector2(20,0))
	check(view.yaw!=yaw,"first drag moves the car through its connected input handler")
	if not is_instance_valid(view.car):
		await finish(app)
		return
	check(view.car.livery==paints.compact,"first native car has saved colours, pattern and sticker")
	while app.menu_page_motion!=null and app.menu_page_motion.is_running(): await process_frame
	await frames(4)
	timings.first_live_page_ms=(Time.get_ticks_usec()-start)/1000.0
	await capture("first-saved-live")
	yaw=view.yaw
	await viewport_drag(view)
	check(view.yaw!=yaw,"viewport-dispatched touch drag reaches the native Garage")
	if DisplayServer.get_name()!="headless":
		var saved_image: Image=view.showroom_viewport.get_texture().get_image()
		view.apply_livery(VehicleLivery.defaults("compact"))
		await frames(4)
		await RenderingServer.frame_post_draw
		check(changed(saved_image,view.showroom_viewport.get_texture().get_image())>100,"saved finish visibly differs from the factory picture colours")
		view.apply_livery(paints.compact)
		await frames(4)
		await RenderingServer.frame_post_draw
		var before_drag: Image=view.showroom_viewport.get_texture().get_image()
		drag(view,Vector2(40,0))
		await frames(4)
		await RenderingServer.frame_post_draw
		check(changed(before_drag,view.showroom_viewport.get_texture().get_image())>100,"drag changes actual live pixels")
		await capture("saved-live-rotated")
	for id: String in VehicleCatalog.IDS:
		page.preview_car(VehicleCatalog.IDS.find(id))
		check(view.car.vehicle_id==id and view.car.model_ready,"preview uses the actual native "+id)
		check(view.car.livery==paints[id],"saved livery on native "+id)
		check(view.car.paint_materials.body.albedo_color==Color(paints[id].colors.body),"saved paint material on "+id)
		view.finish_car_transition()
		check(view.reflections.enabled and view.reflections.views.size()==2,"both original reflections on "+id)
		check(view.find_child("GarageOpeningPicture",true,false)==null,"no photo replaces native "+id)
		await frames(3)
	check(VehicleCatalog.selected=="compact" and app.records.settings.vehicle_liveries==paints,"browsing does not equip a car or overwrite its saved paint")
	app._show_screen("settings")
	app._show_screen("garage")
	check(app._retained_garage==page and page.showroom==view,"return retains the same live world")
	yaw=view.yaw;drag(view,Vector2(12,0))
	check(view.yaw!=yaw,"retained world remains movable")
	app.records=LocalRecords.new(folder.path_join("other-records.json"))
	app._show_screen("garage")
	check(app._retained_garage!=page and app._retained_garage.showroom.car.livery==VehicleLivery.defaults("compact"),"owner replacement uses its own saved/default appearance")
	await finish(app)
