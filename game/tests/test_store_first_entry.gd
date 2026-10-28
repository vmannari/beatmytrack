extends SceneTree
## Hold each local response independently to exercise the actual first Store frames.
const Store = preload("res://ui/store_page.gd")
const Access = preload("res://backend/store_access_cache.gd")
var checks: int = 0
var failures: int = 0
var output: String

class Service extends Node:
	signal release_catalog
	signal release_access
	var player: Dictionary = {"id":"first-entry"}
	var paths: Array[String] = []
	var hold_catalog: bool = true
	var hold_access: bool = true
	var online: bool = true
	var authenticated: bool = true
	var ids: Array[String] = ["creator_slot_1","creator_slots_5","creator_slots_10","ad_free_month","ad_free_forever"]
	func base_url() -> String: return "http://store-first-entry.invalid/"+str(get_instance_id())
	func signed_in() -> bool: return authenticated
	func request_api(path: String, _method: int = HTTPClient.METHOD_GET, _payload: Dictionary = {}, _key: String = "", _auth: bool = false) -> Dictionary:
		paths.append(path)
		if path == "/store/products" and hold_catalog: await release_catalog
		if path == "/me/entitlements" and hold_access: await release_access
		await get_tree().process_frame
		if not online: return {"ok":false,"error":"Fixture offline"}
		if path == "/store/products":
			var offers: Array[Dictionary] = []
			for id: String in ids: offers.append({"id":id,"title":id,"price_eur":"2.49","enabled":true})
			return {"ok":true,"data":{"products":offers}}
		if path == "/me/entitlements":
			return {"ok":true,"data":{"publishing_slots":3,"ad_free_until":0,"max_rewinds_per_race":3,"server_now":1,"ad_free":false,"ad_free_forever":false,"free_rewinds":false,"purchase_simulation":true,"store_available":false}}
		if path == "/development/purchases": return {"ok":true,"data":{"products":[],"purchases":[],"entitlements":{}}}
		return {"ok":false,"error":"Unexpected fixture route"}

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; print("FAIL: "+label)
func frames() -> void:
	for _frame: int in range(8): await process_frame
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)
func disabled(page: Node) -> bool:
	for button: Node in page.find_children("StoreBuy_*","Button",true,false)+page.find_children("StoreGift_*","Button",true,false):
		if not button.disabled: return false
	return not page.eligible
func make_page(service: Service, preview: bool = false) -> Control:
	var page: Control = Store.new()
	page.client = service
	page.page_preview = preview
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(page)
	page.adapter.path_override = output.path_join("unused-checkout.json")
	return page
func settle(page: Node) -> void:
	while page.working: await process_frame
	await frames()

func app_entry() -> void:
	OS.set_environment("BMT_API_URL","")
	var app: Node = load("res://core/app.tscn").instantiate()
	var folder: String = ProjectSettings.globalize_path("res://../build/store-first-entry-"+TrackLibrary.unique_id())
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.records.settings["music_enabled"] = false
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._show_screen("tracks")
	await frames()
	var page: Node = app.root_ui.find_child("StorePage",true,false)
	check(page != null and page.page_preview,"actual App prepares a passive Store neighbor")
	if page != null:
		var service := Service.new()
		root.add_child(service)
		page.client = service
		page.adapter.client = service
		page.adapter.path_override = folder.path_join("unused-checkout.json")
		app.root_ui.find_child("Tab_store",true,false).pressed.emit()
		await create_timer(0.4).timeout
		check(app.screen == "store" and page._cards.size() == 5,"actual first Store tab shows all five offers before a response")
		check(page.products.is_empty() and disabled(page),"actual App first entry has no invented prices or checkout access")
		await capture("app-first-entry-loading")
		service.hold_catalog = false
		service.release_catalog.emit()
		await frames()
		check(page.products.size() == 5 and page.working and disabled(page),"actual App presents catalog while account response is held")
		await capture("app-catalog-before-access")
		service.hold_access = false
		service.release_access.emit()
		await settle(page)
		check(page.eligible,"actual App receives confirmed debug access")
		service.queue_free()
	app.queue_free()
	await frames()

func run() -> void:
	create_timer(60).timeout.connect(func() -> void: print("FAIL: Store first-entry deadline"); quit(1))
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	output = ProjectSettings.globalize_path("res://../docs/evidence/store-first-entry-2026-10-28/"+RenderingServer.get_current_rendering_method())
	if DisplayServer.get_name() == "headless": output = output.path_join("headless")
	DirAccess.make_dir_recursive_absolute(output)
	Access.scopes.clear()
	var service := Service.new()
	root.add_child(service)
	var page: Control = make_page(service,true)
	check(service.paths.is_empty(),"passive neighbor makes no network request")
	check(page._cards.size() == 5,"all five offer cards exist in the first ready frame")
	check(page.products.is_empty() and disabled(page),"initial offer presentation invents no service products or checkout access")
	page.activate()
	check(page._cards.size() == 5 and page.working,"first entry retains five cards while catalog is held")
	check(service.paths == ["/store/products"],"first entry starts only one catalog request")
	await frames()
	check(page.telemetry_exposures().is_empty(),"unconfirmed offer shells do not count as product impressions")
	await capture("first-entry-loading")
	service.hold_catalog = false
	service.release_catalog.emit()
	await frames()
	check(page.working and service.paths == ["/store/products","/me/entitlements"],"account response is held independently")
	check(page.products.size() == 5,"verified catalog displays before account access completes")
	var price: Label = page.find_child("StorePrice_creator_slot_1",true,false)
	check(price != null and price.text == "€2.49","service price appears while account response is pending")
	check(disabled(page) and page.entitlements.is_empty(),"catalog arrival cannot authorize checkout")
	await page._purchase("creator_slot_1")
	check(service.paths.size() == 2,"loading checkout cannot send a purchase")
	await capture("catalog-before-access")
	# A second view joins the in-flight account read after the catalog arrived.
	page.hide()
	var joined: Control = make_page(service)
	check(joined.products.size() == 5 and disabled(joined),"joining refresh immediately receives the already-verified catalog")
	check(service.paths.size() == 2,"joining refresh coalesces service reads")
	service.hold_access = false
	service.release_access.emit()
	await settle(page)
	await settle(joined)
	check(page.eligible and joined.eligible,"only confirmed debug entitlements enable existing simulation")
	var card: Node = joined._cards[0]
	joined.activate()
	check(joined._cards[0] == card,"fresh re-entry retains the prepared cards")
	await capture("access-ready")
	# Explicit refresh disables old buttons before yielding to the network.
	service.online = false
	service.hold_catalog = true
	joined.refresh()
	check(disabled(joined),"refresh immediately disables previously enabled checkout and gifts")
	service.hold_catalog = false
	service.release_catalog.emit()
	await settle(joined)
	check(joined._cards.size() == 5 and disabled(joined),"offline refresh preserves visible offers with checkout disabled")
	await capture("offline")
	# Service exclusions and a successful empty catalog replace all local shells.
	service.online = true
	service.ids = ["creator_slot_1"]
	await joined.refresh()
	check(joined._cards.size() == 1 and joined.products.size() == 1,"service subset replaces initial offer presentation")
	service.ids.clear()
	await joined.refresh()
	check(joined._cards.is_empty() and joined.products.is_empty(),"successful empty service catalog never resurrects local offers")
	# A reply for an old identity cannot present prices or grant access.
	service.hold_catalog = true
	joined.refresh()
	service.player.id = "changed-account"
	service.ids = ["creator_slot_1"]
	service.hold_catalog = false
	service.release_catalog.emit()
	await settle(joined)
	check(joined.products.is_empty() and joined.entitlements.is_empty() and disabled(joined),"old-account catalog reply cannot reach the new account")
	page.queue_free()
	joined.queue_free()
	service.queue_free()
	await frames()
	# Fresh offline entry still draws useful offers, without invented prices.
	var offline := Service.new()
	offline.online = false
	offline.hold_catalog = false
	root.add_child(offline)
	var cold_offline: Control = make_page(offline)
	await settle(cold_offline)
	check(cold_offline._cards.size() == 5 and disabled(cold_offline),"first-ever offline entry shows five unavailable offers")
	price = cold_offline.find_child("StorePrice_creator_slot_1",true,false)
	check(price != null and not "€" in price.text,"offline offer shells never display an invented price")
	await capture("first-entry-offline")
	cold_offline.queue_free()
	offline.queue_free()
	await frames()
	await app_entry()
	print("STORE_FIRST_ENTRY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
