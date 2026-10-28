extends SceneTree
const Store = preload("res://ui/store_page.gd")
const Reference = preload("res://tests/test_store_reference.gd")
const Simulator = preload("res://platform/purchase_simulator.gd")
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/track-slot-gifts-2026-10-25/native"

class Service extends Reference.Service:
	var sent: Dictionary = {}
	var lost: bool = false
	var gift_grants: int = 0
	var orders: Dictionary = {}
	func request_api(path: String, method: int = HTTPClient.METHOD_GET, payload: Dictionary = {}, key: String = "", auth: bool = false) -> Dictionary:
		if path.begins_with("/store/gift-recipient?"):
			await get_tree().process_frame
			if "Alice" in path: return {"ok":true,"data":{"id":"11111111-1111-4111-8111-111111111111","display_name":"Alice"}}
			return {"ok":false,"status":404,"error":"GIFT_RECIPIENT_UNAVAILABLE"}
		if path == "/development/purchases" and method == HTTPClient.METHOD_POST:
			await get_tree().process_frame
			sent = payload.duplicate()
			if not orders.has(payload.request_id):
				posts += 1
				gift_grants += 5
				orders[payload.request_id] = {"id":payload.request_id,"product_id":payload.product_id,"state":payload.outcome,"recipient_player_id":payload.get("recipient_player_id")}
			if lost:
				lost = false
				return {"ok":false,"status":0,"error":"Lost response"}
			return {"ok":true,"data":{"purchase":orders[payload.request_id],"entitlements":entitlements()}}
		return await super.request_api(path,method,payload,key,auth)

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+label)
func frames() -> void:
	for _index: int in range(10): await process_frame
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="): output = argument.trim_prefix("--evidence-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.gui_embed_subwindows = true
	var service := Service.new()
	service.simulation = true
	root.add_child(service)
	var page := Store.new()
	page.client = service
	root.add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	while page.working: await process_frame
	await frames()
	page.adapter.path_override = "user://gift-test-"+Simulator._uuid()+".json"
	for id: String in ["creator_slot_1","creator_slots_5","creator_slots_10"]:
		check(page.find_child("StoreGift_"+id,true,false) != null,"gift action for "+id)
	check(page.find_child("StoreGift_ad_free_month",true,false) == null,"no ad-free gifts")
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = dimensions
		await frames()
		var scroll: ScrollContainer = page.get_node("StoreScroll")
		scroll.scroll_vertical = 9999
		await frames()
		check(scroll.get_h_scroll_bar().max_value <= scroll.size.x+1,"store fits width "+str(dimensions))
		for card: Control in page._cards:
			var gift_button: Button = card.find_child("StoreGift_"+str(card.get_meta("telemetry_product_id")),true,false)
			if gift_button != null: check(card.get_global_rect().encloses(gift_button.get_global_rect()),"gift stays inside card "+card.name)
		await capture("store-%dx%d" % [dimensions.x,dimensions.y])
		page._open_gift("creator_slots_5")
		page._gift_username.text = "Missing"
		await page._confirm_gift()
		check(page._gift_recipient.is_empty() and service.posts == 0,"unknown player cannot purchase")
		page._gift_username.text = "Alice"
		await page._confirm_gift()
		check(page._gift_recipient.get("display_name") == "Alice" and service.posts == 0,"lookup confirms identity before checkout")
		await frames()
		check(page._gift_dialog.size.x <= dimensions.x and page._gift_dialog.size.y <= dimensions.y,"gift dialog fits screen")
		await capture("confirm-%dx%d" % [dimensions.x,dimensions.y])
		page._gift_dialog.hide()
	page._open_gift("creator_slots_5")
	page._gift_username.text = "Alice"
	await page._confirm_gift()
	service.lost = true
	await page._confirm_gift()
	check(service.posts == 1 and service.gift_grants == 5,"confirmed gift grants once")
	check(page.adapter.has_pending_request(),"lost response preserves gift recovery")
	var saved: Dictionary = service.sent.duplicate()
	await page._retry()
	check(service.sent == saved and service.gift_grants == 5,"retry preserves recipient and request identity")
	check(not page.adapter.has_pending_request(),"successful recovery clears journal")
	for locale: String in ["fr","es","de","pt_BR","ja","ko","nl","it","fi","sv","nb"]:
		TranslationServer.set_locale(locale)
		await frames()
		var translated_scroll: ScrollContainer = page.get_node("StoreScroll")
		check(translated_scroll.get_h_scroll_bar().max_value <= translated_scroll.size.x+1,"translated store fits width "+locale)
		page._open_gift("creator_slots_5")
		page._gift_username.text = "Alice"
		await page._confirm_gift()
		check(page._gift_dialog.title != "Gift track slots","localized gift title "+locale)
		check("Alice" in page._gift_message.text and "{player}" not in page._gift_message.text and "3.49" in page._gift_message.text,"localized confirmation preserves recipient and price "+locale)
		if locale in ["fi","de","ja"]:
			await frames()
			await capture("confirm-"+locale)
		page._gift_dialog.hide()
	TranslationServer.set_locale("en")
	page._open_gift("creator_slots_5")
	service.player = {"id":"different-account"}
	await page._confirm_gift()
	check(not page._gift_dialog.visible and service.posts == 1,"account switch closes stale checkout")
	service.simulation = false
	await page.refresh()
	check(page.find_child("StoreGift_creator_slot_1",true,false).disabled,"unavailable billing disables gifting")
	page.queue_free()
	service.queue_free()
	await process_frame
	print("SLOT_GIFT_TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
