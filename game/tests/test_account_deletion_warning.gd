extends SceneTree
const Client = preload("res://backend/backend_client.gd")
const Dialog = preload("res://ui/account_deletion_dialog.gd")
const Benefits = preload("res://ui/account_deletion_benefits.gd")
var checks: int = 0
var failures: int = 0

class MockClient extends Client:
	var answer: Dictionary = {}
	var waiting: bool = true
	var requests: int = 0
	func request_api(path: String, method: HTTPClient.Method = HTTPClient.METHOD_GET, _payload: Dictionary = {}, _key: String = "", authenticated: bool = false) -> Dictionary:
		assert(path == "/privacy/deletion-preview" and method == HTTPClient.METHOD_GET and authenticated)
		requests += 1
		while waiting: await get_tree().process_frame
		return answer

class MockAccount extends Node:
	var client := MockClient.new()
	var deletions: Array = []
	func delete_account(actor: String, origin: String) -> void: deletions.append([actor,origin])

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; print("FAIL: "+label)

func fixture() -> Dictionary:
	return {"schema_version":1,"player_id":"fixture-owner","server_now":1800000000,"publishing_slots":7,"coins":12345,"banked_resumes":4,"cosmetic_unlocks":9,"pending_purchases":1,"ad_free":true,"ad_free_until":1800000000+365*86400,"ad_free_forever":false}

func open_dialog(account: MockAccount) -> ConfirmationDialog:
	var dialog := Dialog.new()
	root.add_child(dialog)
	dialog.open_for(account)
	return dialog

func frames() -> void:
	for _i: int in range(5): await process_frame

func run() -> void:
	root.size = Vector2i(1280,720)
	var account := MockAccount.new()
	root.add_child(account)
	account.add_child(account.client)
	account.client.configure("http://127.0.0.1:1")
	account.client.player = {"id":"fixture-owner"}
	account.client._access_token = "fictional-access"
	var data: Dictionary = fixture()
	check(Benefits.valid(data) and Client.valid_response("/privacy/deletion-preview",HTTPClient.METHOD_GET,data),"strict native API contract accepts the complete snapshot")
	for field: String in data:
		var incomplete: Dictionary = data.duplicate(true); incomplete.erase(field)
		check(not Benefits.valid(incomplete),"missing disclosure field rejected: "+field)
	for bad: Variant in [-1,0.5,"7",true,INF]:
		var corrupt: Dictionary = data.duplicate(true); corrupt.coins = bad
		check(not Benefits.valid(corrupt),"invalid balance rejected: "+str(bad))
	var dialog: ConfirmationDialog = open_dialog(account)
	check(dialog.get_ok_button().disabled,"loading cannot confirm deletion")
	check(account.deletions.is_empty(),"preview is read only")
	account.client.answer = {"ok":true,"data":data}; account.client.waiting = false
	await frames()
	check(not dialog.get_ok_button().disabled,"valid account snapshot permits the explicit action")
	var text: String = dialog.benefits.text
	check(text.contains("Publishing slots: 7") and text.contains("Coins: 12345") and text.contains("Banked resumes: 4") and text.contains("Online cosmetic unlocks: 9"),"all remaining balances are visible")
	check(text.contains("365 days, 0 hours") and text.contains("UTC") and text.contains("Pending purchases: 1"),"remaining duration, exact expiry and pending purchases are disclosed")
	check(dialog.find_child("DeleteAccountCopy",true,false).text.contains("permanently") and dialog.find_child("DeleteAccountCopy",true,false).text.contains("paid benefits"),"permanent paid-benefit loss is explicit")
	var capture: String = OS.get_environment("BMT_DELETION_CAPTURE")
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		dialog.queue_free(); await process_frame
		root.size = dimensions
		dialog = open_dialog(account); await frames()
		check(dialog.size.x <= dimensions.x and dialog.size.y <= dimensions.y,"dialog fits "+str(dimensions)+" actual="+str(dialog.size))
		check(dialog.get_ok_button().get_global_rect().end.y <= dialog.size.y and dialog.get_cancel_button().get_global_rect().end.y <= dialog.size.y,"actions remain reachable "+str(dimensions))
		check(dialog.scroll.get_global_rect().end.y <= dialog.get_ok_button().get_global_rect().position.y,"scroll content stays above actions "+str(dimensions))
		if not capture.is_empty() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(capture.path_join("deletion-%dx%d.png" % [dimensions.x,dimensions.y])) == OK,"native UI capture")
	# Switching identities after loading cannot delete the replacement account.
	account.client.player.id = "different-owner"
	await frames()
	check(dialog.get_ok_button().disabled,"identity switch disables confirmation")
	dialog.confirmed.emit(); await process_frame
	check(account.deletions.is_empty(),"even a stale confirmed signal cannot delete another account")
	account.client.player.id = "fixture-owner"
	account.client.answer = {"ok":false,"error":"NETWORK_ERROR"}
	dialog = open_dialog(account); await frames()
	check(dialog.get_ok_button().disabled and dialog.retry.visible,"load failure offers retry without inventing zero balances")
	account.client.answer = {"ok":true,"data":data}
	dialog._load_benefits(); await frames()
	check(not dialog.get_ok_button().disabled,"retry recovers the balance disclosure")
	dialog.canceled.emit(); await process_frame
	check(account.deletions.is_empty(),"keeping the account submits no deletion")
	var other: Dictionary = data.duplicate(true); other.player_id = "wrong-owner"
	account.client.answer = {"ok":true,"data":other}
	dialog = open_dialog(account); await frames()
	check(dialog.get_ok_button().disabled,"a response for another account cannot authorize confirmation")
	dialog.queue_free(); await process_frame
	account.client.waiting = true
	dialog = open_dialog(account)
	account.client._session_generation += 1
	account.client.answer = {"ok":true,"data":data}; account.client.waiting = false
	await frames()
	check(dialog.get_ok_button().disabled,"a delayed response from a previous login stays disabled")
	dialog.queue_free(); await process_frame
	account.client.waiting = true
	dialog = open_dialog(account); dialog.canceled.emit(); await process_frame
	account.client.waiting = false; await frames()
	check(account.deletions.is_empty(),"closing during loading has no deletion side effect")
	var expired: Dictionary = data.duplicate(true); expired.ad_free = false; expired.ad_free_until = 1799999999
	check(Benefits.describe(expired).contains("none active"),"expired ad-free access has no false remaining time")
	expired.ad_free = true; expired.ad_free_forever = true
	check(Benefits.describe(expired).contains("no scheduled expiry"),"legacy forever access is described truthfully")
	account.client.answer = {"ok":true,"data":data}
	dialog = open_dialog(account); await frames(); dialog.confirmed.emit(); await process_frame
	check(account.deletions == [["fixture-owner","http://127.0.0.1:1"]],"explicit confirmation binds the reviewed account and origin")
	account.queue_free(); await process_frame
	print("Account deletion warning: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
