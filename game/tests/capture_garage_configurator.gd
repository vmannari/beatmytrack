extends SceneTree
## Actual App review with isolated paint and wallet fixtures; no live account.
const Fixture = preload("res://tests/test_customisation_carousel.gd")
var page: GaragePage
var output: String
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(value: bool, caption: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+caption)

func settle() -> void:
	while page._workbench_focus_pending or page._menu_motion!=null or page.showroom.camera_motion!=null and page.showroom.camera_motion.is_running(): await process_frame
	for tick: int in range(12): await process_frame
	await RenderingServer.frame_post_draw

func capture(name: String) -> void:
	await settle()
	check(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"capture "+name)

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	GameSoundtrack.instance().music_enabled = false
	output = "res://../docs/evidence/garage-live-configurator-2026-10-26/review-native"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	var directory: String = "user://garage_configurator_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.library = TrackLibrary.new(directory)
	app.cloud_root_override = directory.path_join("cloud")
	var paint: Dictionary = VehicleLivery.defaults("compact")
	paint.pattern = "apex_twin"
	paint.colors = {"body":"a44844","accent":"efe5cf","detail":"c78e4c"}
	app.records.settings.vehicle_liveries = {"compact":paint}
	check(app.records.save_records()==OK,"isolated paint fixture saved")
	root.size = Vector2i(1720,900)
	root.content_scale_size = root.size
	root.add_child(app)
	while not app.startup_complete: await process_frame
	VehicleCatalog.selected = "compact"
	app._show_screen("garage")
	page = app.root_ui.find_child("GaragePage",true,false)
	var wallet: Node = Fixture.Shop.new()
	wallet.owned.append("kit/compact/hood/scoop")
	page.add_child(wallet)
	page.economy = wallet
	wallet.changed.connect(page._shop_changed)
	page.open_car(0)
	page._show_section("tuning")
	page._shop_changed()
	check(page.showroom.livery==paint,"actual App retains reference paint")
	var saved: Dictionary = page.records.settings.duplicate(true)
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1720,900)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		page._select_kit_category("hood")
		page._preview_kit("hood","louvres")
		await settle()
		page.kit_scroll.scroll_vertical = 0
		await capture("hood-preview-"+str(dimensions.x))
		check(page.tools_panel.get_global_rect().encloses(page.kit_shelf.equip.get_global_rect()),"purchase action fits")
		check(page.kit_scroll.get_global_rect().encloses(page.kit_cards.get_child(1).get_global_rect()),"selected row fits")
		if dimensions.x==1720:
			page._preview_kit("hood","scoop")
			await capture("hood-owned")
			page._select_kit_category("body")
			page._preview_kit("body","wide")
			await capture("body-kit-preview")
	check(page.records.settings==saved and wallet.purchases==0,"review never saves a preview or purchases")
	app.queue_free()
	await process_frame
	print("GARAGE_CONFIGURATOR_CAPTURE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
