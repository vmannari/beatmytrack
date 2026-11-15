extends SceneTree
## Separate the new information panel from the actual App's studio preparation.
class EmptyStats extends PanelContainer:
	func set_vehicle(_id: String) -> void: pass
	func fit_in_preview(_dimensions: Vector2) -> void: pass

func _initialize() -> void: run.call_deferred()

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	var script: GDScript = load("res://ui/garage_page.gd")
	script.source_code = script.source_code.replace('preload("res://ui/garage_car_stats.gd").new()','load("res://tests/probe_garage_stats_entry.gd").EmptyStats.new()')
	if script.reload() != OK:
		quit(1)
		return
	var folder: String = ProjectSettings.globalize_path("res://../build/garage-car-stats-2026-11-14/control-"+TrackLibrary.unique_id())
	DirAccess.make_dir_recursive_absolute(folder)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.records.settings = {"music_enabled":false,"selected_car":"compact","tutorial_complete":true}
	app.library = TrackLibrary.new(folder)
	app.cloud_root_override = folder.path_join("cloud")
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	root.add_child(app)
	while not app.startup_complete: await process_frame
	print("GARAGE_STATS_CONTROL_SHOW_BEGIN")
	app._show_screen("garage")
	print("GARAGE_STATS_CONTROL_SHOW_END")
	var page: GaragePage = app.root_ui.find_child("GaragePage",true,false)
	while page == null or not page.showroom.showroom_ready:
		await process_frame
		page = app.root_ui.find_child("GaragePage",true,false)
	while page.showroom.preparing: await process_frame
	print("GARAGE_STATS_CONTROL_READY")
	app.queue_free()
	await process_frame
	quit()
