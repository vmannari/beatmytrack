extends SceneTree
const Simulator = preload("res://platform/purchase_simulator.gd")
const Client = preload("res://backend/backend_client.gd")
const Credits = preload("res://platform/resume_credits.gd")
const AppScene = preload("res://core/app.tscn")
var checks: int = 0
var failures: int = 0

class MockClient extends Node:
	var player: Dictionary = {"id":"purchase-test"}
	var lost_response: bool = true
	var grants: int = 0
	var orders: Dictionary = {}
	var last_id: String = ""
	var allow_publish: bool = false
	var data: Dictionary = {"publishing_slots":1,"ad_free":false,"ad_free_until":0,"ad_free_forever":false,"free_rewinds":false,"max_rewinds_per_race":3,"purchase_simulation":true,"store_available":false,"server_now":1700000000}
	func signed_in() -> bool: return not player.is_empty()
	func base_url() -> String: return "http://127.0.0.1:18182"
	func request_api(path: String, _method: int, body: Dictionary, _key: String, _auth: bool) -> Dictionary:
		await get_tree().process_frame
		if path == "/resumes": return {"ok":true,"data":{"balance":7,"free":1,"free_rewinds":true,"ad_preview_available":false}}
		if path == "/resume-races": return {"ok":true,"data":{"race_id":"race-test"}}
		if path.ends_with("/resumes"): return {"ok":true,"data":{"receipt_id":"receipt-test","wallet":{"balance":7,"free":1,"free_rewinds":true}}}
		if path.begins_with("/me/track-versions/"): return {"ok":true,"data":{"state":"tested"}}
		if path.ends_with("/publish"):
			return {"ok":true,"data":{"state":"published","version_id":"test-version"}} if allow_publish else {"ok":false,"status":409,"error":"NO_PUBLISHING_SLOTS"}
		if path == "/development/purchases" and _method == HTTPClient.METHOD_GET:
			return {"ok":true,"data":{"products":[{"id":"creator_slot_1","title":"1 publishing slot","price_eur":"0.99"},{"id":"ad_free_month","title":"One month ad-free","price_eur":"3.49"},{"id":"ad_free_forever","title":"Forever ad-free","price_eur":"9.99"}],"purchases":orders.values(),"entitlements":data}}
		last_id = str(body.request_id)
		if not orders.has(last_id):
			orders[last_id] = {"id":last_id,"state":body.outcome,"product_id":body.product_id}
			if body.outcome == "approved": grants += 1; data.publishing_slots += 1
		if lost_response:
			lost_response = false
			return {"ok":false,"status":0,"error":"Response lost after grant"}
		return {"ok":true,"data":{"purchase":orders[last_id],"entitlements":data}}

class NoAds extends Node:
	var calls: int = 0
	func show_rewarded() -> Dictionary:
		calls += 1
		return {"ok":false,"error":"Ad-free should bypass ads"}

class MemoryFlow extends TrackLifecycle:
	var saved: Dictionary = {}
	var finished: bool = false
	func scope() -> String: return "purchase-workflow-test"
	func _path(_document: Dictionary) -> String: return "memory"
	func _archived(_id: String, _directory: String = "") -> bool: return false
	func _read(_path: String) -> Dictionary: return saved.duplicate(true)
	func _save(_path: String, value: Dictionary, _proof: bool = false) -> bool:
		saved = value.duplicate(true)
		return true
	func process_jobs() -> void: await _advance("memory",saved.duplicate(true),scope())
	func _finalize(_path: String, _job: Dictionary, _owner_scope: String) -> void: finished = true

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; print("FAIL: "+label)

func run() -> void:
	var mock := MockClient.new()
	root.add_child(mock)
	var path: String = "user://purchase-test-"+Simulator._uuid()+".json"
	var adapter := Simulator.new()
	adapter.client = mock
	adapter.path_override = path
	root.add_child(adapter)
	check(Simulator.valid_entitlements(mock.data),"typed entitlement contract")
	check(not Simulator.valid_entitlements({"publishing_slots":-1}),"reject invalid entitlement response")
	check(not Client.valid_wallet({"balance":0,"free":1,"reset_at":1700000000,"free_rewinds":"true"}),"reject nonboolean free-rewind authorization")
	var result: Dictionary = await adapter.purchase("creator_slot_1","approved")
	check(not result.ok and mock.grants == 1 and adapter.has_pending_request(),"lost response preserves request after server grant")
	var original_id: String = mock.last_id
	check(not (await adapter.purchase("creator_slots_5","approved")).ok,"pending recovery blocks another purchase")
	adapter.queue_free()
	await process_frame
	adapter = Simulator.new()
	adapter.client = mock
	adapter.path_override = path
	root.add_child(adapter)
	result = await adapter.retry()
	check(result.ok and mock.last_id == original_id and mock.grants == 1,"restart retry keeps original purchase identity and single grant")
	check(not adapter.has_pending_request(),"resolved journal cleared")
	for state: String in ["pending","declined","cancelled"]:
		result = await adapter.purchase("creator_slot_1",state)
		check(result.ok and result.data.purchase.state == state and mock.grants == 1,"simulate "+state+" without a grant")
	var credits := Credits.new()
	credits.client = mock
	credits.show_ads = true
	root.add_child(credits)
	credits.ad_adapter.queue_free()
	var ads := NoAds.new()
	credits.add_child(ads)
	credits.ad_adapter = ads
	credits.begin()
	for _n: int in range(3):
		result = await credits.consume(120,0,120*(_n+1))
		check(result.ok and result.data.wallet.balance == 7,"ad-free resume preserves banked balance")
	check(ads.calls == 0,"ad-free client never invokes rewarded ads")
	check(not (await credits.consume(120,0,480)).ok,"ad-free cannot exceed three per race")
	var hud := RewindHUDButton.new()
	hud.show_resource({"balance":7,"free_rewinds":true},1)
	check(not hud.use_ad and hud.race_remaining == 2 and "Ad-free" in hud.tooltip_text,"HUD shows free remaining uses")
	hud.free()
	var flow := MemoryFlow.new()
	var cloud := Node.new()
	cloud.set_script(preload("res://backend/cloud_tracks.gd"))
	cloud.client = mock
	root.add_child(cloud)
	flow.cloud = cloud
	root.add_child(flow)
	var document: Dictionary = {"id":"purchase-workflow","name":"Saved proof"}
	flow.saved = {"scope":flow.scope(),"state":"ready","document":document,"version_id":"test-version","publish_requested":true,"publish_key":"saved-publish-key"}
	await flow.process_jobs()
	check(flow.saved.get("publication_error") == "NO_PUBLISHING_SLOTS" and flow.saved.state == "ready","slot rejection preserves verified draft")
	check(flow.can_retry(document) and "publishing slots" in flow.caption(document),"quota failure offers a clear retry")
	mock.allow_publish = true
	await flow.retry(document)
	check(flow.finished and not flow.saved.has("failure"),"adding a slot allows publication retry with the saved proof")
	flow.queue_free()
	cloud.queue_free()
	credits.queue_free()
	adapter.queue_free()
	mock.queue_free()
	await process_frame
	if OS.has_environment("BMT_PURCHASE_TEST_URL"): await live_test()
	print("PURCHASE_SIMULATION_TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func live_test() -> void:
	var client := Client.new()
	root.add_child(client)
	check(client.configure(OS.get_environment("BMT_PURCHASE_TEST_URL")) == OK,"loopback configured")
	var result: Dictionary = await client.developer_login(OS.get_environment("BMT_DEV_AUTH_KEY"))
	check(result.ok,"real development sign-in")
	if not result.ok: client.queue_free(); return
	var adapter := Simulator.new()
	adapter.client = client
	root.add_child(adapter)
	result = await adapter.catalog()
	check(result.ok and result.data.products.size() == 5,"live five-product catalog")
	if not result.ok: adapter.queue_free(); client.queue_free(); return
	var before: int = int(result.data.entitlements.publishing_slots)
	result = await adapter.purchase("creator_slots_5","pending")
	check(result.ok and int(result.data.entitlements.publishing_slots) == before,"live pending spends nothing")
	var pending_id: String = result.data.purchase.id
	result = await adapter.resolve(pending_id,"approved")
	check(result.ok and int(result.data.entitlements.publishing_slots) == before+5,"live pending approval grants five slots")
	result = await adapter.resolve(pending_id,"approved")
	check(result.ok and int(result.data.entitlements.publishing_slots) == before+5,"live duplicate callback grants once")
	# Fresh lab for this test: monthly entitlement remains stackable.
	result = await adapter.purchase("ad_free_month","approved")
	check(result.ok and result.data.entitlements.free_rewinds,"live monthly access authorizes free rewinds")
	var page := SettingsPage.new()
	page.records = LocalRecords.new("user://purchase-settings-"+Simulator._uuid()+".json")
	page.purchase_client = client
	page.signed_in = true
	page.player_name = "developer"
	page.section = "development"
	root.add_child(page)
	root.size = Vector2i(1280,720)
	await process_frame
	page.position = Vector2(24,24)
	page.size = root.get_visible_rect().size-Vector2(48,48)
	for _frame: int in range(40): await process_frame
	var panel: Node = page.find_child("PurchaseSimulator",true,false)
	while panel.working: await process_frame
	check(page.find_child("Simulate_creator_slots_10",true,false) != null,"live simulator mounted in Settings")
	var purchase_button: Button = page.find_child("Simulate_creator_slot_1",true,false)
	purchase_button.pressed.emit()
	purchase_button.pressed.emit()
	while panel.working: await process_frame
	result = await adapter.catalog()
	check(int(result.data.entitlements.publishing_slots) == before+6,"double UI click grants one purchase")
	var scroll: ScrollContainer = page.find_child("SettingsScroll",true,false)
	scroll.scroll_vertical = 380
	for _frame: int in range(5): await process_frame
	check(root.get_visible_rect().encloses(page.get_global_rect()),"Settings panel fits the logical viewport")
	if DisplayServer.get_name() != "headless":
		var folder: String = ProjectSettings.globalize_path("res://../docs/evidence/purchases-2026-10-06")
		DirAccess.make_dir_recursive_absolute(folder)
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(folder.path_join("purchase-simulator.png")) == OK,"real simulator screenshot saved")
	page.queue_free()
	adapter.queue_free()
	client.queue_free()
	await process_frame
