extends SceneTree
const Store = preload("res://ui/store_page.gd")
const Telemetry = preload("res://backend/product_telemetry.gd")
var checks: int = 0
var failures: int = 0

class StoreClient extends Node:
	var player: Dictionary = {"id":"isolated-store-observer"}
	var simulation: bool = true
	var posts: int = 0
	func signed_in() -> bool: return true
	func telemetry_supported() -> bool: return true
	func base_url() -> String: return "http://127.0.0.1:18181"
	func catalog() -> Array[Dictionary]:
		var products: Array[Dictionary] = []
		for id: String in Telemetry.STORE_PRODUCTS: products.append({"id":id,"title":id,"price_eur":"1.00","enabled":true})
		return products
	func entitlements() -> Dictionary:
		return {"publishing_slots":1,"ad_free_until":0,"max_rewinds_per_race":3,"server_now":int(Time.get_unix_time_from_system()),"ad_free":false,"ad_free_forever":false,"free_rewinds":false,"purchase_simulation":simulation,"store_available":false}
	func request_api(path: String, method: HTTPClient.Method = HTTPClient.METHOD_GET, payload: Dictionary = {}, _key: String = "", _authenticated: bool = false) -> Dictionary:
		await get_tree().process_frame
		if path == "/store/products": return {"ok":true,"data":{"products":catalog()}}
		if path == "/me/entitlements": return {"ok":true,"data":entitlements()}
		if path == "/development/purchases" and method == HTTPClient.METHOD_GET: return {"ok":true,"data":{"products":catalog(),"purchases":[],"entitlements":entitlements()}}
		if path == "/development/purchases" and method == HTTPClient.METHOD_POST:
			posts += 1
			return {"ok":true,"status":200,"data":{"purchase":{"id":Telemetry.uuid(),"product_id":payload.product_id,"state":"approved"},"entitlements":entitlements()}}
		return {"ok":false,"status":404,"error":"FAKE_ROUTE_ABSENT"}

func _initialize() -> void: run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures += 1; print("FAIL: "+label)

func settled() -> void:
	for index: int in range(12): await process_frame

func ready_store(store: Node) -> void:
	var deadline: int = Time.get_ticks_msec()+10000
	while store.working and Time.get_ticks_msec() < deadline: await process_frame
	check(not store.working,"fake store completes its bounded refresh")
	await settled()

func run() -> void:
	root.size = Vector2i(1280,720)
	var client := StoreClient.new()
	root.add_child(client)
	var collector := Telemetry.new()
	collector.client = client
	root.add_child(collector)
	collector._timer.stop()
	var store := Store.new()
	store.client = client
	store.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	store.purchase_requested.connect(func(product: String) -> void: collector.observe("purchase_requested",{"product_id":product}))
	root.add_child(store)
	var journal: String = ProjectSettings.globalize_path("res://../build/telemetry-analysis-2026-10-11/client-test/store-"+Telemetry.uuid()+".json")
	store.adapter.path_override = journal
	await ready_store(store)
	var exposed: Array[String] = store.telemetry_exposures()
	check(exposed.size() == 5,"all five actual visible desktop offer cards are observed")
	for product: String in exposed: check(product in Telemetry.STORE_PRODUCTS,"offer observation uses fixed catalog SKU")
	store.hide()
	check(store.telemetry_exposures().is_empty(),"hidden prepared store page generates no impressions")
	store.show()
	var scroll: ScrollContainer = store.get_node("StoreScroll")
	root.size = Vector2i(600,360)
	root.content_scale_size = Vector2i(600,360)
	await settled()
	scroll.scroll_vertical = 0
	await settled()
	var compact_exposed: Array[String] = store.telemetry_exposures()
	check(compact_exposed.size() < 5,"offscreen compact-store cards are excluded from offers")
	scroll.scroll_vertical = 100000
	await settled()
	check("ad_free_forever" in store.telemetry_exposures(),"scrolling establishes an actually visible last offer")
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	await settled()
	var before: int = collector.queue.size()
	store._purchase("creator_slot_1")
	store._purchase("creator_slot_1")
	await ready_store(store)
	check(client.posts == 1,"existing double-click checkout guard remains effective")
	check(collector.queue.size() == before+1 and collector.queue[-1].event.name == "purchase_requested" and collector.queue[-1].event.properties == {"product_id":"creator_slot_1"},"one user checkout action records SKU intent without fulfillment values")
	client.simulation = false
	await store.refresh()
	await settled()
	before = collector.queue.size()
	await store._purchase("ad_free_month")
	check(client.posts == 1 and collector.queue.size() == before,"unavailable checkout emits neither request nor purchase intent")
	check(not store.eligible,"shipping-style unavailable billing remains unavailable")
	store.queue_free()
	collector.queue_free()
	client.queue_free()
	await process_frame
	if FileAccess.file_exists(journal): DirAccess.remove_absolute(journal)
	print("PRODUCT_STORE_TELEMETRY: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
