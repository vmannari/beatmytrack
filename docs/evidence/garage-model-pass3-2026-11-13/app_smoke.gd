extends SceneTree
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)
func run() -> void:
	OS.set_environment("BMT_API_URL","")
	root.size = Vector2i(1280,720)
	var app: Node = load("res://core/app.tscn").instantiate()
	var folder: String = "user://garage_model_smoke"
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.records.settings = {"music_enabled":false,"selected_car":"compact"}
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	GameSoundtrack.instance().music_enabled = false
	app._show_screen("garage")
	var page: GaragePage = app._retained_garage
	while not page.showroom.showroom_ready or (page.progressive_entry and page.showroom.preparing): await process_frame
	var view: CarShowroom = page.showroom
	view.finish_car_transition()
	check(view.car.model_ready and view.car.simple_model,"actual App displays the reduced car")
	check(view.reflections.views.size() == 2 and view.reflections.enabled,"actual App retains both reflections")
	var stage_id: int = view.turntable.get_instance_id()
	for section: String in ["customise","care","trophies","records","cars"]:
		page._show_section(section)
		for tick: int in range(10): await process_frame
		check(page.section == section,"open actual Garage "+section)
		check(view.turntable.get_instance_id() == stage_id,"section retains pedestal "+section)
	var paint: Dictionary = view.livery.duplicate(true)
	paint.colors.body = "a1473b"
	view.apply_livery(paint,true)
	view.finish_paint_transition()
	check(view.car.paint_materials.body.albedo_color == Color("a1473b"),"actual App repaint remains live")
	view.set_wash_mode(true)
	check(view.wash_mode and is_instance_valid(view.wash_effect),"actual App washing remains available")
	view.set_wash_mode(false)
	view.invalidate_render()
	for tick: int in range(12): await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://../build/garage-model-pass3-2026-11-13/app-smoke-mobile.png") == OK,"capture actual App")
	app.queue_free()
	for tick: int in range(8): await process_frame
	print("GARAGE_MODEL_APP_SMOKE ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
