extends SceneTree
## SCP05: real workshop commits refresh without navigation, cover or active input.
const Icons = preload("res://ui/header_car_icons.gd")
var app: Node
var page: GaragePage
var checks: int = 0
var failures: int = 0
var cover_frames: int = 0
var output: String
var timings: Dictionary = {}
var stages: Array[Dictionary] = []
var phase: String = ""
var phase_started: int = 0
var last_stage: String = ""

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
func settle() -> void:
	await wait_for(func() -> bool: return page.showroom.showroom_ready and not page.showroom.preparing and page._menu_motion==null and not page._workbench_focus_pending,"workshop settles")
	await frames()
func observe() -> void:
	var cover: Node=app.find_child("HeaderPicturePreparation",true,false)
	if is_instance_valid(cover) and cover.is_visible_in_tree(): cover_frames += 1
	var stage: String=phase+":"+app.header_car_cache._stage+":"+app.header_car_cache._io_kind
	if not phase.is_empty() and stage!=last_stage:
		stages.append({"stage":stage,"ms":(Time.get_ticks_usec()-phase_started)/1000.0})
		last_stage=stage
func picture() -> Texture2D:
	return app.account_button.get_node("MenuProfileCar").preview.texture
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"capture "+label)
func ready_picture() -> bool:
	return Icons.ready("compact",app.records) and picture()!=null and page.thumbnails.compact._image.texture==picture()

func run() -> void:
	if DisplayServer.get_name()=="headless": quit(1); return
	OS.set_environment("BMT_API_URL","")
	VehicleSimulation.new(VehicleCatalog.config("compact")).step(DriveFrame.sample(0,1,0))
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output=argument.trim_prefix("--evidence-root=")
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,720)
	root.content_scale_size=root.size
	Icons.customized.clear()
	var folder: String="user://shared-picture-refresh-"+TrackLibrary.unique_id()
	app=load("res://core/app.tscn").instantiate()
	app.records=LocalRecords.new(folder.path_join("records.json"))
	app.records.settings={"music_enabled":false,"selected_car":"compact","tutorial_complete":true}
	app.library=TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override=folder.path_join("cloud")
	root.add_child(app)
	await wait_for(func() -> bool: return app.startup_complete,"private App starts")
	app._show_screen("garage")
	page=app._retained_garage
	await settle()
	page.open_car(0)
	page._set_customise_tab("colours")
	await settle()
	var live_car: CarVisual=page.showroom.car
	var live_viewport: SubViewport=page.showroom.showroom_viewport
	RenderingServer.frame_pre_draw.connect(observe)
	# Deliberately hold a touch through two actual palette commits.
	app._garage_preloader._touches[44]=true
	page.livery_menu._palette_colour(Color("c52d43"))
	var superseded: String=Icons.appearance_key("compact",app.records)
	page.livery_menu._palette_colour(Color("245fd2"))
	await create_timer(0.4).timeout
	check(app.header_car_cache.captures==0 and app.header_car_cache.canvas==null,"held gesture prevents native picture work")
	check(not ready_picture(),"saved paint never keeps the previous picture")
	var began: int=Time.get_ticks_usec()
	phase="paint"
	phase_started=began
	app._garage_preloader._release_preview_touch(44)
	await wait_for(ready_picture,"paint picture updates inside Appearance")
	timings.paint_ms=(Time.get_ticks_usec()-began)/1000.0
	check(timings.paint_ms<2000,"desktop saved paint updates within two seconds of touch release")
	check(page.section=="customise" and app.screen=="garage","paint requires no navigation")
	check(app.header_car_cache.captures==1 and not Icons.customized.has(superseded),"rapid palette commits produce only the newest picture")
	check(page.showroom.car==live_car and page.showroom.showroom_viewport==live_viewport,"picture refresh preserves the painted live world")
	check(picture()==Icons.texture("compact",app.records) and page.showroom.car.livery==VehicleLivery.for_car(app.records.settings,"compact"),"header, carousel and live paint match the saved look")
	await shot("paint-refreshed-in-appearance")
	page._show_section("tuning")
	await settle()
	var parts: Dictionary=page.kit_draft.duplicate(true)
	parts.hood="cowl"
	app._garage_preloader.last_input=Time.get_ticks_msec()
	began=Time.get_ticks_usec()
	phase="kit"
	phase_started=began
	page._save_kits(parts)
	timings.kit_commit_ms=(Time.get_ticks_usec()-began)/1000.0
	await wait_for(ready_picture,"kit picture updates inside Parts")
	timings.kit_ms=(Time.get_ticks_usec()-began)/1000.0
	check(timings.kit_ms<2000,"desktop saved parts update within two seconds")
	check(page.section=="tuning" and app.screen=="garage","kit requires no navigation")
	check(app.header_car_cache.captures==2 and page._preview_service.renders==0,"each saved look has exactly one shared capture")
	check(page.showroom.car.customisation==parts and VehicleCustomisation.for_car(app.records.settings,"compact")==parts,"live and saved fitted parts remain exact")
	check(page.showroom.car==live_car and page.showroom.showroom_viewport==live_viewport and cover_frames==0,"paint and parts refresh never replace or cover the live Garage")
	await shot("kit-refreshed-in-parts")
	var yaw: float=page.showroom.yaw
	page.showroom.rotate_view(Vector2(32,0))
	check(page.showroom.yaw!=yaw,"live car remains turnable")
	RenderingServer.frame_pre_draw.disconnect(observe)
	var report: Dictionary={"checks":checks,"failures":failures,"timings":timings,"stages":stages,"cover_frames":cover_frames,"captures":app.header_car_cache.captures}
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	app.queue_free()
	await frames(15)
	print("SHARED_PICTURE_REFRESH ",JSON.stringify(report))
	quit(1 if failures else 0)
