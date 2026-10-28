extends SceneTree
var checks: int=0
var failures: int=0
var output: String="res://../build/garage-first-entry"
var metrics: Dictionary={}

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: ",label)

func frames(count: int=4) -> void:
	for _frame: int in range(count): await process_frame

func wait_ready(loader: Node) -> void:
	var deadline: int=Time.get_ticks_msec()+120000
	while (loader.studio==null or not loader.studio.prepared) and Time.get_ticks_msec()<deadline: await process_frame
	check(loader.studio!=null and loader.studio.prepared,"one original world finishes both live and carousel preparation")

func difference(a: Image,b: Image) -> Dictionary:
	if a.get_size()!=b.get_size(): return {"same_size":false}
	var aa: PackedByteArray=a.get_data()
	var bb: PackedByteArray=b.get_data()
	var total: int=0
	var changed: int=0
	var maximum: int=0
	for i: int in range(aa.size()):
		var delta: int=absi(int(aa[i])-int(bb[i]))
		total+=delta;maximum=maxi(maximum,delta)
		if delta>0: changed+=1
	return {"same_size":true,"mean_byte_error":float(total)/aa.size(),"changed_bytes":changed,"max_byte_error":maximum}

func canonical(page: GaragePage) -> Image:
	var service: Node=page._preview_service
	service.prepared_picture={}
	service.idle_ms=0
	service.directory="" # Force both controls through native rendering, not PNG reuse.
	var view: CarShowroom=page.thumbnails.compact
	var count: int=service.renders
	service.request(view)
	var deadline: int=Time.get_ticks_msec()+30000
	while (service.renders==count or not service.active.is_empty()) and Time.get_ticks_msec()<deadline: await process_frame
	check(service.renders==count+1 and service.active.is_empty(),"unmodified canonical renderer completes its exact saved thumbnail")
	return view._image.texture.get_image()

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	output=ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,720)
	var app: Node=load("res://core/app.tscn").instantiate()
	var folder: String="user://first-entry-"+TrackLibrary.unique_id()
	app.records=LocalRecords.new(folder.path_join("records.json"))
	app.library=TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override=folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._publishing_slots_foreground=true # Offscreen native window represents the foreground app.
	var music: GameSoundtrack=GameSoundtrack.instance()
	music.music_enabled=false;music.menu_player.stop();music.menu_player.stream=null
	var paint: Dictionary=VehicleLivery.defaults("compact")
	paint.colors.body="c72d34";paint.pattern=LiveryCatalog.patterns[0].id
	paint.stickers.hood.id=LiveryCatalog.stickers[0].id
	app.records.settings.vehicle_liveries={"compact":paint}
	var wear: Dictionary=VehicleWeathering.new().snapshot()
	wear.dirt=0.2;wear.slow_dirt=0.1
	check(app.records.save_vehicle_conditions({"compact":wear})==OK,"seed only isolated saved appearance and wear")
	var wear_hash: String=FileAccess.get_sha256(app.records.path+".conditions.json")
	VehicleCatalog.selected="compact"
	app._garage_appearance_changed()
	app._show_screen("tracks")
	var loader: Node=app._garage_preloader
	loader.idle_ms=40;loader.foreground=true
	await wait_ready(loader)
	if loader.studio==null:
		app.queue_free();await frames(20);quit(1);return
	var studio: CarShowroom=loader.studio
	var wall: Node=studio.find_child("EarnedAchievements",true,false)
	check(wall!=null,"actual career wall geometry exists before entry")
	var wall_id: int=wall.get_instance_id() if wall!=null else 0
	check(studio._thumbnail_state.is_empty() and not studio.read_only,"completed preparation restores live interaction and camera state")
	check(studio.camera.fov==40.0 and studio.showroom_viewport.msaa_3d==Viewport.MSAA_4X,"main camera and original 4x sampling restored before readiness")
	check(studio.camera.get_parent().get_node("GarageKey").shadow_enabled,"original main key shadows restored before readiness")
	check(studio.reflections.views.size()==2 and studio.find_children("*","SubViewport",true,false).size()==3,"same world retains both original reflections without extra views")
	if DisplayServer.get_name()!="headless": check(studio.carousel_texture!=null and studio.carousel_texture.get_size()==Vector2(2048,512),"saved selected-car picture is captured before entry")
	app._show_screen("garage")
	var page: GaragePage=app._retained_garage
	check(page.showroom==studio,"visible Garage adopts the prepared world")
	var visible_wall: Node=studio.find_child("EarnedAchievements",true,false)
	check(visible_wall!=null and visible_wall.get_instance_id()==wall_id,"unchanged career data retains the already warmed wall")
	check(studio.car.livery==paint and is_equal_approx(studio.weathering.dirt_amount,0.2),"live geometry preserves saved paint, stickers and dirt")
	check(FileAccess.get_sha256(app.records.path+".conditions.json")==wear_hash,"offscreen rendering leaves owner condition bytes untouched")
	var service: Node=page._preview_service
	var selected: CarShowroom=page.thumbnails.compact
	if DisplayServer.get_name()!="headless":
		check(selected.displayed_key==service.identity(selected),"first carousel publishes an exact saved appearance rather than its stock fallback")
		check(service.renders==0,"opening does not construct a second selected-car studio")
	while app.menu_page_motion!=null and app.menu_page_motion.is_running(): await process_frame
	await frames(8)
	if DisplayServer.get_name()!="headless":
		var prepared: Image=selected._image.texture.get_image()
		var a: Image=await canonical(page)
		var b: Image=await canonical(page)
		metrics.prepared_vs_canonical=difference(prepared,a)
		metrics.canonical_repeat=difference(a,b)
		check(metrics.prepared_vs_canonical.same_size,"preloaded picture has the unchanged canonical dimensions")
		check(metrics.prepared_vs_canonical.mean_byte_error<=metrics.canonical_repeat.mean_byte_error+0.01,"preloaded picture matches the actual canonical renderer within its repeated-render variation")
		prepared.save_png(output.path_join("prepared-thumbnail.png"))
		a.save_png(output.path_join("canonical-thumbnail.png"))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("live.png"))
	# Held input, passive hover, text focus and navigation gate expensive work.
	service.idle_ms=750
	service._last_input=Time.get_ticks_msec()-1000
	var held:=InputEventScreenTouch.new()
	held.index=9;held.pressed=true;service._input(held)
	service._last_input=Time.get_ticks_msec()-1000
	check(not service._render_allowed(),"held touch pauses native work even after the idle deadline")
	held.pressed=false;service._input(held)
	service._last_input=Time.get_ticks_msec()-1000
	var at: int=service._last_input
	service._input(InputEventMouseMotion.new())
	check(service._last_input==at,"passive hover cannot postpone exact thumbnail readiness")
	var edit:=LineEdit.new()
	root.add_child(edit);edit.grab_focus()
	check(not service._render_allowed(),"text focus pauses optional GPU work")
	edit.release_focus();edit.queue_free()
	service.can_render=func() -> bool: return false
	check(not service._render_allowed(),"outer menu transition gate prevents native capture work")
	service.can_render=func() -> bool: return true
	check(service._render_allowed(),"idle native work resumes after focus and navigation settle")
	held.pressed=true;service._input(held)
	service.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(service._touches.is_empty(),"focus loss retires held touches that may never receive a release")
	# Enter while temporary thumbnail rendering is in flight: restore immediately.
	app._show_screen("tracks")
	while app.menu_page_motion!=null and app.menu_page_motion.is_running(): await process_frame
	app._trim_hidden_garage()
	loader.queue_free()
	loader=preload("res://ui/garage_preloader.gd").new()
	loader.app=app;app._garage_preloader=loader;app.add_child(loader)
	loader.idle_ms=0;loader.foreground=true
	var deadline: int=Time.get_ticks_msec()+120000
	while (loader.studio==null or loader.studio._thumbnail_state.is_empty()) and Time.get_ticks_msec()<deadline: await process_frame
	check(loader.studio!=null and not loader.studio._thumbnail_state.is_empty(),"fixture interrupts the actual temporary thumbnail pass")
	if loader.studio!=null:
		studio=loader.studio
		var state: Dictionary=studio._thumbnail_state.duplicate()
		app._show_screen("garage")
		check(app._retained_garage.showroom==studio and studio.adopted,"entry during the thumbnail pass retains the exact live world")
		check(not studio.read_only and studio._thumbnail_state.is_empty(),"partial-pass adoption removes temporary read-only state")
		check(studio.camera.transform==state.camera and studio.camera.fov==state.fov,"partial-pass adoption restores original live camera immediately")
		check(studio.showroom_viewport.msaa_3d==state.msaa and studio.camera.get_parent().get_node("GarageKey").shadow_enabled==state.shadow,"partial-pass adoption restores original sampling and shadows")
		var yaw: float=studio.yaw
		var drag:=InputEventMouseMotion.new()
		drag.button_mask=MOUSE_BUTTON_MASK_LEFT;drag.relative=Vector2(30,0)
		studio.gui_input.emit(drag)
		check(studio.yaw!=yaw,"partial-pass handoff permits live rotation immediately")
		await frames(16)
		check(studio.camera.fov==40.0 and not studio.read_only,"completed asynchronous continuation cannot overwrite adopted live settings")
	metrics.checks=checks;metrics.failures=failures
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(metrics,"  "))
	print("GARAGE_FIRST_ENTRY ",JSON.stringify(metrics))
	deadline=Time.get_ticks_msec()+30000
	while not preload("res://ui/garage_preview_cache.gd").pending_pictures.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	app.queue_free();await frames(24)
	quit(1 if failures else 0)
