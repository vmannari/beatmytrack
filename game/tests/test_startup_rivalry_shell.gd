extends SceneTree
## Offline real podium/menu entry without a service or artificial membership wait.
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("RIVALRY_SHELL_FAIL ",label)
func run() -> void:
	create_timer(90,true,false,true).timeout.connect(func() -> void: printerr("RIVALRY_SHELL_TIMEOUT"); quit(1))
	root.size = Vector2i(1280,720)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records = load("res://persistence/local_records.gd").new("user://rivalry-shell/records.json")
	DirAccess.make_dir_recursive_absolute(app.records.path.get_base_dir())
	app.records.settings.music_enabled = false
	check(app.records.save_records() == OK,"private records")
	app.library = load("res://persistence/track_library.gd").new("user://rivalry-shell/tracks")
	app.cloud_root_override = "user://rivalry-shell/cloud"
	root.add_child(app)
	while not app.startup_complete: await process_frame
	check(not app.online.configured,"no real service")
	app.rivalry.model = load("res://race/weekly_rivalry.gd").new(true)
	app._show_screen("rivalry")
	app._stop_menu_page_motion()
	var page: Control = app.content.find_child("WeeklyRivalryPage",true,false)
	check(is_instance_valid(page),"existing Rivalry page")
	var cars: Array[Node] = []
	var ready: bool = false
	while not ready:
		app._publishing_slots_foreground = true
		cars = page.find_children("RivalryPodiumCar_*","",true,false)
		ready = page.standings_ready and page.track_rows.size() == 5 and cars.size() == 3
		for car: Node in cars: ready = ready and car.presentation_ready
		if not ready: await process_frame
	check(cars.size() == 3,"all real podium cars")
	check(page.track_rows.size() == 5,"five tracks retain their real layout")
	check(app.game == null and app.canvas == null and app._retained_garage == null,"menu does not construct Race, Editor or Garage")
	check(not ResourceLoader.has_cached("res://core/game.tscn"),"race scene remains deferred")
	check(not ResourceLoader.has_cached("res://editor/editor_canvas.gd"),"native editor remains deferred")
	check(not ResourceLoader.has_cached("res://ui/garage_page.gd"),"Garage page remains deferred")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(OS.get_environment("BMT_LOADING_OUTPUT").get_basename()+".png") == OK,"native podium capture")
	print("RIVALRY_SHELL ",checks," checks, ",failures," failures")
	app.queue_free()
	app = null
	for _i: int in range(12): await process_frame
	quit(1 if failures else 0)
