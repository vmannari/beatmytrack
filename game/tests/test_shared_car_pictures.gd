extends SceneTree
## SCP01-SCP04: identical stock/custom textures, one capture, saved look and IO fences.
const Icons = preload("res://ui/header_car_icons.gd")
var checks: int = 0
var failures: int = 0
var app: Node
var page: GaragePage
var output: String
var observations: Dictionary = {}

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
func shot(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"capture "+label)
func header() -> Texture2D:
	return app.account_button.get_node("MenuProfileCar").preview.texture
func same_pictures() -> void:
	for vehicle: String in VehicleCatalog.IDS:
		var view: Node = page.thumbnails[vehicle]
		check(view._image.texture==Icons.texture(vehicle,app.records),vehicle+" carousel shares the exact profile texture object")
		check(view._image.texture!=null and view._image.texture.get_size()==Vector2(Icons.SIZE),vehicle+" has carousel resolution")
		check(view.find_children("*","SubViewport",true,false).is_empty(),vehicle+" thumbnail owns no 3D viewport")
	check(page._preview_service.renderer==null and page._preview_service.renders==0,"Garage creates no separate thumbnail renderer")
	check(app._garage_preloader.picture_service.renderer==null and app._garage_preloader.picture_service.renders==0,"preloader creates no separate thumbnail renderer")

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	VehicleSimulation.new(VehicleCatalog.config("compact")).step(DriveFrame.sample(0,1,0))
	output=ProjectSettings.globalize_path("res://../docs/evidence/shared-car-pictures-2026-11-15/test")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output=argument.trim_prefix("--evidence-root=")
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,720)
	root.content_scale_size=root.size
	var folder: String="user://shared-car-pictures-"+TrackLibrary.unique_id()
	app=load("res://core/app.tscn").instantiate()
	app.records=LocalRecords.new(folder.path_join("records.json"))
	app.records.settings={"music_enabled":false,"selected_car":"compact","tutorial_complete":true}
	app.library=TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override=folder.path_join("cloud")
	Icons.customized.clear()
	root.add_child(app)
	await wait_for(func() -> bool: return app.startup_complete,"App starts with private records")
	app._show_screen("garage")
	page=app._retained_garage
	await wait_for(func() -> bool: return page.showroom.showroom_ready,"live Garage becomes ready")
	await frames(20)
	page._finish_menu_move()
	page._refresh_thumbnails()
	check(page.shared_header_cache==app.header_car_cache,"actual Garage uses the profile cache")
	same_pictures()
	check(header()==page.thumbnails.compact._image.texture,"equipped profile and carousel share one texture")
	check(app.header_car_cache.captures==0,"stock entry performs zero car-picture captures")
	check(preload("res://ui/garage_selection_pictures.gd")._textures.is_empty(),"entry never loads a second stock portrait set")
	check(preload("res://ui/garage_preview_cache.gd").factory_pictures.is_empty(),"entry never imports the old studio pictures")
	await shot("stock-1280")
	var saved: Dictionary=app.records.settings.duplicate(true)
	for index: int in range(VehicleCatalog.IDS.size()):
		page.preview_car(index)
		page.gallery.ensure_control_visible(page.cards.get_child(index))
		page.showroom.finish_car_transition()
		await frames()
		check(page._car_stats.vehicle_id==VehicleCatalog.IDS[index],"browsing retains car stats "+VehicleCatalog.IDS[index])
	check(app.records.settings==saved,"browsing never equips or writes a car")
	root.size=Vector2i(960,540)
	root.content_scale_size=root.size
	await frames(12)
	await shot("stock-960")
	root.size=Vector2i(1280,720)
	root.content_scale_size=root.size
	page.preview_car(0)
	page.showroom.finish_car_transition()
	page.gallery.scroll_horizontal=0
	if DisplayServer.get_name()!="headless":
		var paint: Dictionary=VehicleLivery.defaults("compact")
		paint.colors.body="c82e37"
		paint.pattern="apex_twin"
		var parts: Dictionary=VehicleCustomisation.defaults()
		parts.hood="cowl"
		parts.aero="splitwing"
		app.records.settings.vehicle_liveries={"compact":paint}
		app.records.settings.vehicle_customisation={"compact":parts}
		check(app.records.save_records()==OK,"save a private paint and fitted-parts fixture")
		check(header()==null and page.thumbnails.compact._image.texture==null,"saved edit clears both old pictures immediately")
		await wait_for(func() -> bool: return Icons.ready("compact",app.records),"shared customised picture completes while Garage is open")
		await frames(15)
		check(app.header_car_cache.captures==1,"custom paint and parts require exactly one capture total")
		check(header()!=null and header()==page.thumbnails.compact._image.texture,"custom profile and carousel share one texture")
		same_pictures()
		page.refresh_cosmetics()
		await shot("custom-1280")
		var picture: Texture2D=header()
		var wear: Dictionary=VehicleWeathering.new().snapshot()
		wear.dirt=0.64
		VehicleCondition.save(app.records,"compact",wear)
		page.refresh_cosmetics()
		await frames(15)
		check(page.showroom.weathering.snapshot().dirt==0.64,"live Garage retains the saved dirt")
		check(header()==picture and page.thumbnails.compact._image.texture==picture and app.header_car_cache.captures==1,"dirt changes reuse the clean shared picture without capturing")
		for _repeat: int in range(12): page._refresh_thumbnails(); app._refresh_account_car()
		check(app.header_car_cache.captures==1 and page._preview_service.renders==0,"warm refreshes never render another picture")
		app._show_screen("tracks")
		await frames(20)
		Icons.customized.clear()
		app.header_car_cache.bind_records(null)
		app.header_car_cache.bind_records(app.records)
		await wait_for(func() -> bool: return Icons.ready("compact",app.records),"shared picture reloads from disk")
		check(app.header_car_cache.disk_hits==1 and app.header_car_cache.captures==1,"disk restoration avoids a second capture")
		app._show_screen("garage")
		await frames(15)
		check(header()==page.thumbnails.compact._image.texture,"retained Garage receives the disk-restored shared texture")
		var raw: Image=header().get_image()
		raw.clear_mipmaps()
		check(raw.save_png(output.path_join("shared-custom-picture.png"))==OK,"save native customised texture")
		observations.custom_captures=app.header_car_cache.captures
		observations.disk_hits=app.header_car_cache.disk_hits
	observations.texture_size=str(Icons.SIZE)
	observations.garage_picture_renders=page._preview_service.renders
	observations.stock_texture_loads=Icons.texture_loads
	observations.two_old_stock_sets_unused=preload("res://ui/garage_selection_pictures.gd")._textures.is_empty() and preload("res://ui/garage_preview_cache.gd").factory_pictures.is_empty()
	app.queue_free()
	await frames(15)
	var report: Dictionary={"checks":checks,"failures":failures,"observations":observations}
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SHARED_CAR_PICTURES ",JSON.stringify(report))
	quit(1 if failures else 0)
