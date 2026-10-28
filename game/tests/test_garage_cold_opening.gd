extends SceneTree
var checks: int=0
var failures: int=0
var output: String="res://../build/garage-cold-opening"
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: ",label)
func frames(count: int=4) -> void:
	for _i: int in range(count): await process_frame
func run() -> void:
	OS.set_environment("BMT_API_URL","")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	output=ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,720)
	var app: Node=load("res://core/app.tscn").instantiate()
	var folder: String="user://garage-cold-"+TrackLibrary.unique_id()
	app.library=TrackLibrary.new(folder.path_join("tracks"))
	app.records=LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override=folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var music: GameSoundtrack=GameSoundtrack.instance()
	music.music_enabled=false;music.menu_player.stop();music.menu_player.stream=null
	app._show_screen("tracks")
	await frames(10)
	var began: int=Time.get_ticks_usec()
	app._show_screen("garage")
	var dispatch: float=(Time.get_ticks_usec()-began)/1000.0
	var page: GaragePage=app._retained_garage
	check(dispatch<250,"Garage navigation returns in less than 250ms")
	check(app.screen=="garage" and page.visible,"normal Garage page opens immediately")
	check(page.showroom.preparing and page.showroom.car==null,"page does not construct a car in its navigation callback")
	check(page.showroom.find_child("GarageOpeningPicture",true,false)!=null,"first frame already has the car picture")
	check(page.thumbnails.size()==7,"all seven car cards exist on entry")
	for id: String in page.thumbnails: check(page.thumbnails[id]._image.texture!=null,"immediate card "+id)
	page._show_section("tuning")
	check(page._opening_section=="tuning","tools requested before the world exists retain their destination")
	page._show_section("cars")
	while app.menu_page_motion!=null and app.menu_page_motion.is_running(): await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		check(page.showroom.car==null,"incoming Garage picture draws before native construction begins")
		check(root.get_texture().get_image().save_png(output.path_join("first-frame.png"))==OK,"capture first frame")
	var first_ms: float=(Time.get_ticks_usec()-began)/1000.0
	print("GARAGE_IMMEDIATE dispatch_ms=",dispatch," first_frame_ms=",first_ms)
	# A loading cover closes optional work before the main menu is hidden.
	app.cloud_starting=true
	await frames(8)
	check(page.showroom.car==null,"race loading prevents optional studio construction")
	check(page.showroom.find_child("GarageOpeningPicture",true,false)!=null,"race loading retains the ready picture")
	app.cloud_starting=false
	# Navigation can leave before a single native shader is compiled.
	app._show_screen("settings")
	await frames(4)
	check(app.screen=="settings","leave Garage while native preparation is pending")
	app._show_screen("garage")
	# Rapid previews during original-material preparation coalesce to the latest.
	var equipped: String=VehicleCatalog.selected
	page.preview_car(VehicleCatalog.IDS.find("pickup"))
	page.preview_car(VehicleCatalog.IDS.find("electric"))
	check(VehicleCatalog.selected==equipped,"preview during preparation does not equip or save the car")
	var frame_times: Array[float]=[]
	var deadline: int=Time.get_ticks_msec()+120000
	while not page.showroom.interaction_ready and page.showroom.preparing and Time.get_ticks_msec()<deadline: await process_frame
	check(page.showroom.interaction_ready and not page.showroom.preparing,"first interactive live view has original finishes and reflections ready")
	check(page.section=="cars" and page._opening_section.is_empty(),"later Cars navigation cancels an earlier deferred tools request")
	var held_position: float=page.showroom.yaw
	var active_max_ms: float=0.0
	var active_frames: Array[float]=[]
	for _i: int in range(24):
		var tick: int=Time.get_ticks_usec()
		var motion:=InputEventMouseMotion.new()
		motion.position=Vector2(640,300)
		page.showroom._input(motion)
		page.showroom.rotate_view(Vector2(1,0))
		await process_frame
		var frame_ms: float=(Time.get_ticks_usec()-tick)/1000.0
		active_frames.append(frame_ms)
		active_max_ms=maxf(active_max_ms,frame_ms)
	check(page.showroom.yaw!=held_position,"orbit responds while full finishes are still preparing")
	check(active_max_ms<150,"active orbit frames stay below 150ms while shader preparation waits for idle")
	print("GARAGE_ACTIVE_FRAMES ",active_frames)
	page._show_section("tuning")
	check(page.section=="tuning","Parts opens before full shader preparation finishes")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join("early-live-studio.png"))==OK,"capture early live geometry")
	page._show_section("cars")
	while page.showroom.preparing and Time.get_ticks_msec()<deadline:
		var tick: int=Time.get_ticks_usec()
		await process_frame
		frame_times.append((Time.get_ticks_usec()-tick)/1000.0)
	check(not page.showroom.preparing,"real 3D studio completes its staged first draws")
	check(page.showroom.vehicle_id=="electric" and page.showroom.car.vehicle_id=="electric","latest requested car replaces the earlier preparation target")
	check(page.showroom.car.model_ready and page.showroom.camera!=null and page.showroom.reflections.views.size()==2,"full live car, camera and both reflections remain")
	check(page.showroom.find_child("GarageOpeningPicture",true,false)==null,"temporary picture releases after live preparation")
	page.showroom.rotate_view(Vector2(20,0))
	check(page.showroom.yaw!=CarShowroom.DEFAULT_YAW,"live orbit remains available")
	var studio: CarShowroom=page.showroom
	app._show_screen("settings")
	app._show_screen("garage")
	check(page.showroom==studio and not studio.preparing,"subsequent Garage entry reuses the ready studio")
	await frames(4)
	check(studio.find_children("OpeningLiveGeometry","MeshInstance3D",true,false).is_empty(),"temporary live geometry is released after full preparation")
	check(studio.find_children("*","SubViewport",true,false).size()==3,"steady Garage returns to its main view and two reflections")
	for mesh: Node in studio.find_children("*","MeshInstance3D",true,false): check(mesh.layers!=8,"original geometry leaves the preparation-only layer")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join("live-studio.png"))==OK,"capture settled live studio")
	var elapsed: float=(Time.get_ticks_usec()-began)/1000.0
	frame_times.sort()
	var report: Dictionary={"dispatch_ms":dispatch,"first_frame_ms":first_ms,"live_ready_ms":studio.live_ready_ms,"active_orbit_max_ms":active_max_ms,"studio_ms":elapsed,"frame_max_ms":frame_times[-1] if not frame_times.is_empty() else 0,"checks":checks,"failures":failures}
	var old: WeakRef=weakref(page)
	app.records=LocalRecords.new(folder.path_join("another-records.json"))
	app._show_screen("garage")
	check(app._retained_garage!=page and app._retained_garage.records==app.records,"records owner replacement creates a separately owned opening job")
	app.queue_free()
	await frames(12)
	check(old.get_ref()==null,"prior owner preparation and world are released")
	report.checks=checks
	report.failures=failures
	var file:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("GARAGE_COLD_OPENING ",JSON.stringify(report))
	quit(1 if failures else 0)
