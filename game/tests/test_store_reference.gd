extends SceneTree
## Native Store layout and service-state checks; all service responses are local fixtures.
const Store = preload("res://ui/store_page.gd")
var checks: int = 0
var failures: int = 0
var output: String
var captures: Array[String] = []

class Service extends Node:
	var player: Dictionary = {"id":"store-reference-fixture"}
	var online: bool = true
	var logged_in: bool = true
	var simulation: bool = false
	var forever: bool = false
	var pending: bool = false
	var posts: int = 0
	var reads: int = 0
	var five_price: String = "3.49"
	func signed_in() -> bool: return logged_in
	func base_url() -> String: return "http://store-reference.invalid/"+str(get_instance_id())
	func catalog() -> Array[Dictionary]:
		var result: Array[Dictionary] = []
		for item: Array in [["creator_slot_1","0.99"],["creator_slots_5",five_price],["creator_slots_10","5.99"],["ad_free_month","3.49"],["ad_free_forever","9.99"]]:
			result.append({"id":item[0],"title":item[0],"price_eur":item[1],"enabled":true})
		return result
	func entitlements() -> Dictionary:
		return {"publishing_slots":3,"ad_free_until":0,"max_rewinds_per_race":3,"server_now":1,"ad_free":forever,"ad_free_forever":forever,"free_rewinds":forever,"purchase_simulation":simulation,"store_available":false}
	func request_api(path: String, method: int = HTTPClient.METHOD_GET, payload: Dictionary = {}, _key: String = "", _auth: bool = false) -> Dictionary:
		reads += 1
		await get_tree().process_frame
		if not online: return {"ok":false,"error":"Fixture offline"}
		if path == "/store/products": return {"ok":true,"data":{"products":catalog()}}
		if path == "/me/entitlements": return {"ok":true,"data":entitlements()}
		if path == "/development/purchases" and method == HTTPClient.METHOD_GET:
			var orders: Array = [{"id":"fixture-pending","product_id":"creator_slots_5","state":"pending"}] if pending else []
			return {"ok":true,"data":{"products":catalog(),"purchases":orders,"entitlements":entitlements()}}
		if path == "/development/purchases" and method == HTTPClient.METHOD_POST:
			posts += 1
			return {"ok":true,"data":{"purchase":{"id":"fixture-approved","product_id":payload.product_id,"state":"approved"},"entitlements":entitlements()}}
		return {"ok":false,"error":"Unknown fixture route"}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)
func frames() -> void:
	for _frame: int in range(12): await process_frame
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"native capture "+label)
	captures.append(label+".png")
func ready_page(page: Node) -> void:
	while page.working: await process_frame
	await frames()
func layout(page: Control) -> void:
	check(root.get_visible_rect().encloses(page.get_global_rect()),"page stays inside viewport "+str(root.size))
	var scroll: ScrollContainer = page.get_node("StoreScroll")
	check(scroll.get_h_scroll_bar().max_value <= scroll.size.x+1,"no horizontal overflow "+str(root.size))
	for card: Control in page._cards:
		check(card.position.x >= 0 and card.size.x <= scroll.size.x+1,"offer fits available width "+card.name)
		var id: String = str(card.get_meta("telemetry_product_id"))
		var button: Button = card.find_child("StoreBuy_"+id,true,false)
		check(button.size.y >= 52 and card.get_global_rect().encloses(button.get_global_rect()),"checkout touch target stays inside "+id)

func run() -> void:
	create_timer(100).timeout.connect(func() -> void: print("FAIL: Store reference deadline"); quit(1))
	OS.set_environment("BMT_API_URL","")
	output = ProjectSettings.globalize_path("res://../docs/evidence/store-reference-2026-10-24/"+RenderingServer.get_current_rendering_method())
	if DisplayServer.get_name() == "headless": output = output.path_join("headless")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var service := Service.new()
	root.add_child(service)
	var app: Node = load("res://core/app.tscn").instantiate()
	var folder: String = ProjectSettings.globalize_path("res://../build/store-reference-2026-10-24/fixture-"+TrackLibrary.unique_id())
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.records.settings["music_enabled"] = false
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._show_screen("store")
	var page: Control = app.root_ui.find_child("StorePage",true,false)
	page.client = service
	page.adapter.client = service
	page.adapter.path_override = folder.path_join("checkout.json")
	await page.refresh()
	await ready_page(page)
	check(page.products.size() == 5 and not page.eligible and not page.controls.visible,"shipping billing state stays unavailable")
	check(page.summary.text == "3 publishing slots · Ads enabled","account summary uses fixture entitlements")
	for size: Vector2i in [Vector2i(1600,1000),Vector2i(1280,720),Vector2i(960,540)]:
		root.size = size
		await frames()
		layout(page)
		check(page.telemetry_exposures().size() == 5,"both offer groups report visible desktop cards "+str(size))
		for card: Control in page._cards:
			var id: String = str(card.get_meta("telemetry_product_id"))
			check(page.get_node("StoreScroll").get_global_rect().encloses(card.find_child("StoreBuy_"+id,true,false).get_global_rect()),"all five actions fit desktop without scrolling "+id+str(size))
		await capture("store-%dx%d" % [size.x,size.y])
	var forever_card: Control = page.find_child("StoreCard_ad_free_forever",true,false)
	var slot_card: Control = page.find_child("StoreCard_creator_slot_1",true,false)
	check(forever_card.get_global_rect().end.y <= slot_card.get_global_rect().position.y,"ad-free offers precede publishing packs")
	check(page.find_child("StorePrice_creator_slots_5",true,false).text == "€3.49","displayed price comes from catalogue")
	check(page.find_child("StoreBuy_ad_free_forever",true,false).disabled,"design never enables unconnected real billing")
	await page._purchase("ad_free_forever")
	check(service.posts == 0,"unavailable checkout makes no purchase request")
	# Narrow logical sizes exercise Store itself independently of the shared menu header.
	page.reparent(root)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.queue_free()
	await frames()
	for size: Vector2i in [Vector2i(600,360),Vector2i(390,844)]:
		root.size = size
		root.content_scale_size = size
		await frames()
		layout(page)
		var scroll: ScrollContainer = page.get_node("StoreScroll")
		scroll.scroll_vertical = 0
		await frames()
		check(page.telemetry_exposures().size() < 5,"compact impressions exclude clipped offers")
		await capture("narrow-%dx%d-top" % [size.x,size.y])
		scroll.scroll_vertical = 100000
		await frames()
		check("creator_slots_10" in page.telemetry_exposures(),"scroll reaches final publishing offer")
		await capture("narrow-%dx%d-bottom" % [size.x,size.y])
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	service.forever = true
	await page.refresh()
	await frames()
	for id: String in ["ad_free_forever","ad_free_month"]:
		var button: Button = page.find_child("StoreBuy_"+id,true,false)
		check(button.disabled and button.text == "Already ad-free forever","owned access disables "+id)
	await capture("owned-access")
	service.forever = false
	service.simulation = true
	service.pending = true
	await page.refresh()
	await frames()
	var recovery_row: Node = page.pending_rows.get_child(0)
	root.size = Vector2i(600,360)
	root.content_scale_size = root.size
	await frames()
	check(page.pending_rows.get_child(0) == recovery_row,"resizing retains pending recovery controls")
	check(page.controls.visible and "NO PAYMENT" in page.controls.get_child(1).text,"simulation remains explicitly labelled")
	service.pending = false
	await page.refresh()
	page._purchase("creator_slot_1")
	page._purchase("creator_slot_1")
	await ready_page(page)
	check(service.posts == 1,"double press still sends one simulated checkout")
	service.five_price = "1.00"
	await page.refresh()
	await frames()
	check(page.find_child("StorePrice_creator_slots_5",true,false).text == "€1.00","updated catalogue price replaces old price")
	check(page._best_slot_value(service.catalog()[1]) and not page._best_slot_value(service.catalog()[2]),"best-value emphasis follows current per-slot prices")
	service.online = false
	await page.refresh()
	await frames()
	check(not page.eligible and "unavailable" in page.status.text.to_lower(),"offline refresh exposes actionable unavailable state")
	for card: Control in page._cards:
		var id: String = str(card.get_meta("telemetry_product_id"))
		check(card.find_child("StoreBuy_"+id,true,false).disabled,"offline disables stale offer "+id)
	await capture("offline")
	service.online = true
	service.simulation = false
	service.logged_in = false
	page._restore.pressed.emit()
	await ready_page(page)
	check(page.entitlements.is_empty() and "Sign in" in page.summary.text,"guest account state avoids fabricated capacity")
	check(page.pending_rows.get_child_count() == 1 and page.pending_rows.get_child(0).text == "Sign in","guest has a sign-in action")
	page.hide()
	check(page.telemetry_exposures().is_empty(),"hidden Store reports no impressions")
	page.queue_free()
	service.queue_free()
	await frames()
	var report := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"fixture":"Local fake service; no real account or purchase","renderer":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name()},"\t"))
	report.close()
	print("STORE_REFERENCE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
