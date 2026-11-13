extends SceneTree
## Actual isolated App, header selection, Garage and a local five-lap race.
var checks: int = 0
var failures: int = 0
var output: String

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func settle(count: int = 12) -> void:
	for frame: int in range(count):
		await process_frame
		if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func capture(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	output = "res://../docs/evidence/super-rally-2026-11-08/"+RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(1280,720)
	var directory: String = ProjectSettings.globalize_path("user://super-rally-ui/"+TrackLibrary.unique_id())
	DirAccess.make_dir_recursive_absolute(directory)
	var records := LocalRecords.new(directory.path_join("records.json"))
	records.load_records()
	records.settings.selected_car = "compact"
	check(records.save_records() == OK,"private initial Rally selection")
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records = records
	app.library = TrackLibrary.new(directory)
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._show_screen("garage")
	await settle()
	var page: GaragePage = app.root_ui.find_child("GaragePage",true,false)
	check(page != null,"actual App opens Garage")
	while not page.showroom.showroom_ready or (page.progressive_entry and page.showroom.get("preparing")): await process_frame
	page.open_car(VehicleCatalog.IDS.find("super_rally"))
	await settle(40)
	while not page.showroom.showroom_ready or (page.progressive_entry and page.showroom.get("preparing")): await process_frame
	check(VehicleCatalog.selected == "super_rally" and page.showroom.car.vehicle_id == "super_rally","Garage selects actual new car")
	check(page.showroom.car.model_id == "compact" and page.showroom.car.simple_model,"Garage uses approved reduced Rally chassis")
	var reopened := LocalRecords.new(records.path)
	reopened.load_records()
	check(reopened.settings.selected_car == "super_rally","selection survives reload")
	check(VehicleCatalog.artwork("super_rally") != null and preload("res://ui/header_car_icons.gd").texture("super_rally") != null,"new catalogue and header pictures load")
	page._show_section("cars")
	await settle(20)
	capture("catalogue")
	page._show_section("customise")
	await settle(20)
	capture("garage")
	var track := NativeTrack.read("res://resources/tracks/ellipse.json")
	await app._start_race(track,true,true)
	while not app.game.preparation_complete: await process_frame
	var game: Node = app.game
	game.set_physics_process(false)
	if game.paused: game.toggle_pause(false)
	check(game.handling.vehicle_id == "super_rally" and game.handling.version == "super-rally-1","actual race loads new performance profile")
	check(game.car.vehicle_id == "super_rally" and game.car.model_id == "compact" and game.car.simple_model,"actual race retains separate car identity and reduced chassis")
	check(game.handling.handbrake_enabled and not game.handling.rear_wheel_drive,"Rally handbrake and drive layout retained")
	check(game.track_session.target_laps == 5,"ordinary race retains five laps")
	game.countdown_ticks = 0
	game.countdown_label.hide()
	await settle(20)
	capture("race")
	var file := FileAccess.open(output.path_join("acceptance.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	file.close()
	app.queue_free()
	await settle(2)
	print("SUPER_RALLY_UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
