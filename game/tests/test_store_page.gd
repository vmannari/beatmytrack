extends SceneTree
const AppScene = preload("res://core/app.tscn")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(value: bool, description: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(description)

func run() -> void:
	create_timer(100).timeout.connect(func() -> void: push_error("Store acceptance deadline"); quit(1))
	var folder: String = ProjectSettings.globalize_path("res://../build/store-test-"+str(Time.get_ticks_usec()))
	var app: Node = AppScene.instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var suffix: String = Crypto.new().generate_random_bytes(8).hex_encode()
	var login: Dictionary = await app.online.client.development_login("store-ui-"+suffix,"Store UI test "+suffix,OS.get_environment("BMT_DEV_AUTH_KEY"))
	check(login.ok,"isolated simulated buyer signs in")
	app._show_screen("tracks")
	check(app.root_ui.find_child("Tab_store",true,false) != null,"Store tab appears alongside Race/Create/Garage")
	app.root_ui.find_child("Tab_store",true,false).pressed.emit()
	var page: Node = app.root_ui.find_child("StorePage",true,false)
	check(page != null and app.screen == "store","Store tab opens actual store page")
	while page.working: await process_frame
	check(page.products.size() == 5 and page.eligible,"five products and explicitly eligible simulation")
	check("NO PAYMENT" in page.controls.get_child(1).text,"checkout is labelled as simulation")
	var before: int = int(page.entitlements.publishing_slots)
	var buy: Button = page.find_child("StoreBuy_creator_slot_1",true,false)
	check(buy != null and not buy.disabled,"publishing slot is purchasable for test buyer")
	buy.pressed.emit()
	buy.pressed.emit()
	while page.working: await process_frame
	check(int(page.entitlements.publishing_slots) == before+1,"double press delivers one purchase")
	page.outcome.selected = 1
	page.find_child("StoreBuy_creator_slots_5",true,false).pressed.emit()
	while page.working: await process_frame
	check(int(page.entitlements.publishing_slots) == before+1,"pending checkout grants nothing")
	check(page.pending_rows.get_child_count() == 1,"pending checkout can be recovered from Store")
	var order: Dictionary = (await page.adapter.catalog()).data.purchases.filter(func(p: Dictionary) -> bool: return p.state == "pending")[0]
	await page._resolve(str(order.id),"approved")
	check(int(page.entitlements.publishing_slots) == before+6,"pending approval updates Store balance")
	page.outcome.selected = 0
	await page._purchase("ad_free_month")
	check(page.entitlements.free_rewinds and page.entitlements.max_rewinds_per_race == 3,"monthly access supplies free limited rewinds")
	for size: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = size
		for _frame: int in range(10): await process_frame
		check(root.get_visible_rect().encloses(page.get_global_rect()),"Store fits logical viewport "+str(size))
		if size == Vector2i(1280,720):
			var scroll: Control = page.find_child("StoreScroll",true,false)
			check(scroll.get_global_rect().encloses(page.find_child("StoreBuy_ad_free_forever",true,false).get_global_rect()),"all five checkout actions fit desktop viewport")
		if DisplayServer.get_name() != "headless":
			var output: String = ProjectSettings.globalize_path("res://../docs/evidence/store-admin-2026-10-07")
			DirAccess.make_dir_recursive_absolute(output)
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(output.path_join("store-%dx%d.png" % [size.x,size.y])) == OK,"Store screenshot saved")
	app._show_screen("tracks")
	check(app.screen == "tracks" and app.root_ui.find_child("Tab_store",true,false) != null,"normal Race navigation retained")
	print("STORE_PAGE_TESTS: %d checks, %d failures" % [checks,failures])
	app.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures == 0 else 1)
