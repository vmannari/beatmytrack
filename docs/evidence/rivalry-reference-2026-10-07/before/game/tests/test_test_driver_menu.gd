extends SceneTree
## Captures the real canonically verified test field produced by the HTTP test.
var checks: int = 0
var failures: int = 0
var app: Node
var evidence: String

func _initialize() -> void: call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures += 1; print("FAIL: "+message)

func settle() -> void:
	for _frame: int in range(6): await process_frame

func inspect(node: Node) -> void:
	if node is Button and node.is_visible_in_tree():
		check(root.get_visible_rect().grow(1).encloses(node.get_global_rect()),str(node.name)+" fits")
		check(node.size.y >= 48,str(node.name)+" has a touch target")
	for child: Node in node.get_children(): inspect(child)

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	evidence = ProjectSettings.globalize_path("res://../docs/evidence/test-drivers-2026-10-04")
	var snapshot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(evidence.path_join("verified-field.json")))
	evidence = ProjectSettings.globalize_path("res://../docs/evidence/rivalry-hub-2026-10-07/verified-fixture")
	DirAccess.make_dir_recursive_absolute(evidence)
	check(snapshot.get("driver_count") == 14,"actual HTTP field contains fourteen drivers")
	check(snapshot.get("test_population",false),"server identifies the test population")
	var adapter: Node = load("res://backend/weekly_rivalry_client.gd").new()
	adapter.client = load("res://backend/backend_client.gd").new()
	adapter.add_child(adapter.client)
	var real_scope: String = adapter.scope()
	adapter.set_test_population(true)
	check(adapter.scope() != real_scope and adapter.model.tracks.is_empty(),"switching population fences old views")
	adapter.free()
	app = load("res://core/app.tscn").instantiate()
	var folder: String = "user://test_driver_menu_"+TrackLibrary.unique_id()
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app.online.client._access_token = "isolated-menu-fixture"
	app.online.client.player = {"id":snapshot.self_id}
	app.online.capabilities = {"test_drivers":true}
	app.online.client._capabilities = app.online.capabilities
	app.rivalry.test_population = true
	app.rivalry.model.apply_snapshot(snapshot)
	check(app.rivalry.model.test_population and app.rivalry.model.standing().size() == 14,"projection preserves server test markers")
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,720)]:
		root.size = dimensions
		app._show_screen("rivalry")
		for section: String in ["overview","tracks","detail","standings"]:
			app.rivalry_section = section
			app._rivalry()
			await settle()
			check(app.root_ui.find_child("RivalryTestPopulation",true,false) == null,"development rivals need no separate enable selector")
			var notice: Label = app.root_ui.find_child("RivalryDataNotice",true,false)
			check(notice.text.begins_with("TEST RIVALRY"),"test championship is clearly marked")
			inspect(app.root_ui)
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().save_png(evidence.path_join(section+"-%dx%d.png" % [dimensions.x,dimensions.y])) == OK,"save screenshot")
	app.online.capabilities = {}
	app._rivalry()
	await settle()
	check(app.root_ui.find_child("RivalryTestPopulation",true,false) == null,"ordinary services show no test population selector")
	app.queue_free()
	await settle()
	print("TEST_DRIVER_MENU: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
