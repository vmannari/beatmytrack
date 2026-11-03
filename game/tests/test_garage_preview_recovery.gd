extends SceneTree
## Reproduce header-car changes and stale carousel pictures in an isolated App.
var app: Node
var checks: int=0
var failures: int=0
var output: String="res://../tmp/garage-recovery/output"

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	if "--task-start" in OS.get_cmdline_user_args():
		for name: String in ["garage_preview_cache","garage_preloader"]:
			var script: Script=load("res://ui/"+name+".gd")
			script.source_code=FileAccess.get_file_as_string("res://../docs/evidence/garage-preview-recovery-2026-11-02/before/"+name+".gd")
			assert(script.reload(true)==OK)
	run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; print("FAIL: ",label)
func frames(count: int=4) -> void:
	for _frame: int in range(count): await process_frame
func settle() -> void:
	await create_timer(0.5).timeout
	await frames()
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.get_texture().get_image().save_png(output.path_join(label+".png"))
func diagnostic(label: String) -> void:
	var loader: Node=app._garage_preloader
	var service: Node=loader.picture_service
	var info: Dictionary={"label":label,"screen":app.screen,"generation":app._navigation_generation,"request":app._garage_picture_navigation,"waiters":loader._picture_waiters,"foreground":app._publishing_slots_foreground,"loader_processing":loader.is_processing(),"evicted":loader.evicted,"allowed":loader._pictures_allowed()}
	if is_instance_valid(service):
		info.merge({"service_processing":service.is_processing(),"render_allowed":service._render_allowed(),"queued":service.queued.size(),"active":service.active.get("vehicle",""),"renders":service.renders,"renderer_ready":is_instance_valid(service.renderer) and service.renderer.showroom_ready})
	print("RECOVERY_STATE: ",JSON.stringify(info))
func wait_pictures(label: String) -> bool:
	var deadline: int=Time.get_ticks_msec()+12000
	while not app._garage_preloader.pictures_ready() and Time.get_ticks_msec()<deadline: await process_frame
	diagnostic(label)
	return app._garage_preloader.pictures_ready()
func run() -> void:
	create_timer(100).timeout.connect(func() -> void: print("FAIL: recovery deadline");quit(1))
	root.size=Vector2i(1280,720)
	root.gui_embed_subwindows=true
	var folder: String="user://recovery-"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	app=load("res://core/app.tscn").instantiate()
	app.records=LocalRecords.new(folder.path_join("records.json"))
	app.library=TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override=folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete:
		app._publishing_slots_foreground=true
		await process_frame
	app._garage_preloader.idle_ms=100000
	app._show_screen("garage")
	await settle()
	check(app.screen=="garage","initial Garage entry")
	var picker: MenuButton=app.account_button.get_node("MenuCarPicker")
	var popup: PopupMenu=picker.get_popup()
	var touch:=InputEventScreenTouch.new()
	touch.index=7; touch.position=picker.get_global_rect().get_center(); touch.pressed=true
	root.push_input(touch,true)
	picker.show_popup()
	await frames(2)
	touch.pressed=false; touch.position=Vector2(30,30)
	popup.push_input(touch,true)
	popup.hide()
	await frames(2)
	print("POPUP_TOUCH: preloader=",app._garage_preloader._touches," pictures=",app._garage_preloader.picture_service._touches," carousel=",app._retained_garage._preview_service._touches)
	check(app._garage_preloader.picture_service._touches.is_empty(),"popup release clears picture worker touch")
	check(app._retained_garage._preview_service._touches.is_empty(),"popup release clears carousel worker touch")
	check(app._garage_preloader._touches.is_empty(),"popup release clears optional studio touch")
	app._select_header_vehicle(1)
	await settle()
	# New saved appearance invalidates one exact picture, as care/customisation do.
	var paints: Dictionary={}
	for id: String in VehicleCatalog.IDS: paints[id]=VehicleLivery.for_car(app.records.settings,id)
	paints.compact.colors.body="ac5732"
	app.records.settings.vehicle_liveries=paints
	check(app.records.save_records()==OK,"save fixture appearance")
	app._garage_appearance_changed()
	check(not app._garage_preloader.pictures_ready(),"fixture has a missing exact picture")
	app._navigate_menu_page("garage")
	diagnostic("immediate-request")
	await frames(4)
	diagnostic("four-frames")
	check(await wait_pictures("visible-Garage"),"explicit request finishes while Garage is visible")
	await frames(2)
	await capture("carousel")
	app._show_screen("profile")
	await settle()
	app._select_header_vehicle(2)
	app._navigate_menu_page("garage")
	await wait_pictures("profile-return")
	await settle()
	check(app.screen=="garage","Garage button returns from profile after car selection")
	for id: String in VehicleCatalog.IDS:
		var view: CarShowroom=app._retained_garage.thumbnails[id]
		check(view.displayed_key==view.preview_key and view._image.texture!=null and not view._placeholder.visible,"exact carousel picture recovered "+id)
	if app.screen=="garage": await popup_cancellation()
	await capture("recovered")
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"task_start":"--task-start" in OS.get_cmdline_user_args()},"  "))
	app.queue_free()
	await frames(8)
	print("GARAGE_RECOVERY: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

func popup_cancellation() -> void:
	var service: Node=app._retained_garage._preview_service
	# A popup created after startup must forward only the released finger.
	var popup:=PopupPanel.new()
	app.add_child(popup)
	await frames(2)
	for index: int in [4,5]:
		var press:=InputEventScreenTouch.new()
		press.index=index; press.pressed=true; press.position=Vector2(10,10)
		root.push_input(press,true)
	check(service._touches.has(4) and service._touches.has(5),"both active fingers pause preview rendering")
	check(not service._render_allowed(),"held touch still blocks preview rendering")
	popup.popup_centered(Vector2i(200,100))
	await frames(2)
	var release:=InputEventScreenTouch.new()
	release.index=4; release.position=Vector2(20,20)
	popup.push_input(release,true)
	check(not service._touches.has(4) and service._touches.has(5),"popup release preserves the other held finger")
	release.index=5; release.pressed=true; release.canceled=true
	popup.push_input(release,true)
	check(service._touches.is_empty(),"popup cancellation releases the remaining finger")
	popup.hide()
	popup.queue_free()
	await frames(2)
