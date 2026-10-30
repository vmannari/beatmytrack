extends SceneTree
## Coin-free guests, account recovery/fences and real Garage purchase controls.
const Economy = preload("res://backend/cosmetic_economy.gd")
const Shop = preload("res://persistence/cosmetic_catalog.gd")
const Client = preload("res://backend/backend_client.gd")
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/guest-no-coins-2026-10-16/headless"
var page: GaragePage

class FakeClient extends Node:
	signal identity_changed
	var player: Dictionary = {"id":"fixture-alice"}
	var enabled: bool = true
	var state: Dictionary = {"schema":1,"revision":0,"balance":2000,"owned":[],"prices":{}}
	var receipts: Dictionary = {}
	var charge_count: int = 0
	var keys: Array[String] = []
	var lose_response: bool = false
	var delayed: bool = false
	var requests: int = 0
	func signed_in() -> bool: return enabled
	func base_url() -> String: return "http://fixture.invalid"
	func new_operation_key() -> String: return "fixture-operation-"+str(requests)
	func request_api(path: String, _method: int = 0, body: Dictionary = {}, key: String = "", _auth: bool = false) -> Dictionary:
		requests += 1
		state.prices = preload("res://persistence/cosmetic_catalog.gd").items()
		var response: Dictionary = {"ok":true,"status":200,"data":state.duplicate(true),"error":""}
		if path == "/economy/purchases":
			keys.append(key)
			if receipts.has(key): response.data = receipts[key].duplicate(true)
			else:
				var price: int = state.prices[body.item_id]
				if state.balance < price: return {"ok":false,"status":409,"error":"INSUFFICIENT_COINS","data":{}}
				state.balance -= price
				state.revision += 1
				state.owned.append(body.item_id)
				charge_count += 1
				response.data = {"item_id":body.item_id,"charged":price,"wallet":state.duplicate(true)}
				receipts[key] = response.data.duplicate(true)
				if lose_response:
					lose_response = false
					response = {"ok":false,"status":0,"error":"NETWORK_ERROR","data":{}}
		while delayed: await get_tree().process_frame
		return response

func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func settle() -> void:
	if is_instance_valid(page):
		while page._menu_motion != null: await process_frame
	for frame: int in range(8): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)

func create_economy(records: LocalRecords, client: Node = null) -> Node:
	var value: Node = Economy.new()
	value.records = records
	value.client = client
	root.add_child(value)
	return value

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-root="): output = arg.trim_prefix("--evidence-root=")
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	var directory: String = "user://earned_coins_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var records := LocalRecords.new(directory.path_join("records.json"))
	var paint: Dictionary = VehicleLivery.defaults("compact")
	paint.pattern = "offset_gt"
	records.settings.vehicle_liveries = {"compact":paint}
	var fitted: Dictionary = VehicleCustomisation.defaults()
	fitted.aero = "wing"
	records.settings.vehicle_customisation = {"compact":fitted}
	check(records.save_records() == OK,"initial existing cosmetics save")
	var economy: Node = create_economy(records)
	check(economy.balance() == 0 and economy.owns("livery/plain"),"fresh guest balance and free plain paint")
	check(economy.owns("livery/offset_gt") and economy.owns("kit/compact/aero/wing"),"migration retains fitted livery and kit")
	check(not economy.owns("livery/apex_twin") and not economy.owns("kit/compact/hood/scoop"),"migration does not unlock the catalog")
	check(Shop.items().size() == 87,"48 liveries plus 39 kit parts")
	check(not (await economy.purchase("livery/apex_twin")) and economy.balance() == 0,"insufficient funds spend nothing")
	check(not records.settings.has("guest_coins"),"new guests never create a wallet")
	records.settings.guest_coins = {"version":1,"balance":6000,"owned":["kit/compact/hood/scoop"],"sequence":132}
	check(records.save_records() == OK,"save historical guest fixture")
	check(economy.balance() == 0 and economy.owns("kit/compact/hood/scoop"),"old guest balance is unavailable and old cosmetics are retained")
	check(not (await economy.purchase("livery/endurance")) and records.settings.guest_coins.balance == 6000,"guest cannot spend a historical balance")
	check(not economy.has_method("award_guest") and not economy.has_method("next_guest_sequence"),"guest grant paths are removed")
	var reloaded := LocalRecords.new(records.path)
	reloaded.load_records()
	check(reloaded.settings.guest_coins == records.settings.guest_coins,"historical data survives without new grants or debits")
	check(VehicleLivery.for_car(reloaded.settings,"compact") == VehicleLivery.for_car(records.settings,"compact") and VehicleCustomisation.for_car(reloaded.settings,"compact") == VehicleCustomisation.for_car(records.settings,"compact"),"wallet writes retain saved cosmetics")
	economy.free()
	economy = create_economy(reloaded)
	check(economy.balance() == 0 and economy.owns("kit/compact/hood/scoop"),"recreated guest retains cosmetics with zero available coins")
	for invalid: Variant in [{"version":1,"balance":-1,"owned":[],"sequence":0},{"version":1,"balance":true,"owned":[],"sequence":0},{"version":1,"balance":0,"owned":["fake"],"sequence":0},{"version":1,"balance":0,"owned":[],"sequence":1.5}]:
		check(not Shop.valid_guest(invalid),"invalid guest wallet rejected")
	incident_checks()
	var fake := FakeClient.new()
	root.add_child(fake)
	var account: Node = create_economy(reloaded,fake)
	await account.refresh()
	check(account.balance() == 2000 and not account.owns("livery/apex_twin"),"account coins/ownership never import guest values")
	fake.lose_response = true
	check(not (await account.purchase("livery/apex_twin")) and not account.pending.is_empty(),"lost purchase response keeps durable pending operation")
	check(fake.charge_count == 1,"lost response charged once at authoritative boundary")
	var operation: String = account.pending.key
	account.free()
	account = create_economy(reloaded,fake)
	check(account.pending.key == operation,"restart reloads original purchase operation key")
	await account.refresh()
	check(account.pending.is_empty() and account.balance() == 1500 and account.owns("livery/apex_twin"),"restart resolves original receipt and ownership")
	check(fake.charge_count == 1 and fake.keys == [operation,operation],"recovery retries same identity without another charge")
	check(await account.purchase("livery/apex_twin") and fake.charge_count == 1,"owned account cosmetic avoids another request")
	var old_owned: Dictionary = account.wallet.duplicate(true)
	var stale: Dictionary = old_owned.duplicate(true)
	stale.revision = 0
	stale.balance = 9999
	check(account._accept(stale) and account.wallet == old_owned,"older receipt cannot roll balance/ownership back")
	await garage_checks(account,reloaded,fake)
	fake.delayed = true
	account.refresh()
	await process_frame
	fake.player = {"id":"fixture-bob"}
	fake.identity_changed.emit()
	fake.delayed = false
	await process_frame
	check(account.wallet.is_empty() and account.pending.is_empty(),"late previous-account response is fenced")
	fake.enabled = false
	fake.identity_changed.emit()
	check(account.balance() == 0 and account.owns("kit/compact/hood/scoop"),"sign-out exposes no coins and retains historical cosmetics")
	check(not Client.valid_response("/economy",HTTPClient.METHOD_GET,{"schema":1,"balance":-1,"revision":0,"owned":[],"prices":{}}),"wire validator rejects invalid balance")
	check(not Client.valid_response("/economy/rewards/a",HTTPClient.METHOD_GET,{"status":"credited","amount":500,"rows":[]}),"wire validator rejects mismatched reward total")
	account.free()
	fake.free()
	await guest_checks(economy,reloaded)
	var report: Dictionary = {"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"guest_balance":economy.balance(),"owned":reloaded.settings.guest_coins.owned,"phone_test":false}
	preload("res://backend/atomic_json.gd").write(output.path_join("report.json"),report)
	economy.free()
	print("EARNED_COINS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func garage_checks(economy: Node, records: LocalRecords, fake: FakeClient) -> void:
	economy.status = ""
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var host := Control.new()
	host.theme = MenuStyle.theme()
	root.add_child(host)
	MenuStyle.fill(host)
	page = GaragePage.new()
	page.records = records
	page.economy = economy
	page.vehicle_id = "compact"
	host.add_child(page)
	MenuStyle.fill(page)
	page.open_car(0)
	await settle()
	check(page._coin_balance.text.contains(str(economy.balance())),"Garage displays persisted balance")
	var locked: LiveryTile = page.livery_menu.pattern_tiles[3]
	check(locked.get_node("CoinPrice").text == "500 coins","locked livery price is visible")
	var original: String = page.draft.pattern
	page._select_livery(3)
	await settle()
	check(is_instance_valid(page._purchase_dialog) and page.draft.pattern == original,"locked livery opens confirmation before equipping")
	await capture("livery-purchase-confirmation")
	page._purchase_dialog.hide()
	await process_frame
	var before: int = economy.balance()
	check(await economy.purchase("livery/endurance"),"confirmed shop livery purchase")
	page._select_livery(3)
	check(page.draft.pattern == "endurance" and economy.balance() == before-500,"owned livery applies and charges only once")
	await settle()
	await capture("livery-owned")
	page._show_section("tuning")
	await settle()
	var selected: String = page.kit_draft.hood
	page._select_kit("hood","dome")
	await settle()
	check(is_instance_valid(page._purchase_dialog) and page.kit_draft.hood == selected,"locked kit opens confirmation without changing fitted parts")
	page._purchase_dialog.confirmed.emit()
	page._purchase_dialog.hide()
	await settle()
	check(economy.owns("kit/compact/hood/dome") and page.kit_draft.hood == "dome","actual confirmation buys and equips kit")
	await capture("kit-owned")
	page._reset_kits()
	check(economy.owns("kit/compact/hood/dome") and page.kit_draft.hood == "stock","reset keeps purchased kit ownership")
	var owned_balance: int = economy.balance()
	fake.state.balance = 1
	fake.state.revision += 1
	await economy.refresh()
	page._select_kit("hood","louvres")
	await settle()
	check(is_instance_valid(page._purchase_dialog) and page._purchase_dialog.get_ok_button().disabled,"insufficient balance disables confirmation")
	await capture("insufficient-coins")
	page._purchase_dialog.hide()
	fake.state.balance = owned_balance
	fake.state.revision += 1
	await economy.refresh()
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await settle()
		check(page._coin_balance.get_global_rect().end.x <= root.size.x,"coin balance fits viewport "+str(dimensions.x))
		await capture("tuning-"+str(dimensions.x))
	host.remove_child(page)
	page.free()
	page = null
	var summary := RaceResults.new()
	summary.circuit = "Fixture loop"
	summary.vehicle_name = "Compact"
	summary.total = 100.0
	summary.laps = [20.0,20.0,20.0,20.0,20.0]
	var complete := RaceComplete.new()
	complete.results = summary
	complete.economy = economy
	complete.coin_receipt = {"status":"credited","amount":200,"rows":[{"title":"Clean race","amount":200,"icon":"trophy","eligible":true,"status":"Credited"}]}
	host.add_child(complete)
	MenuStyle.fill(complete)
	await settle()
	if complete.reward_reveal != null:
		complete.reward_reveal.pause()
		complete.reward_reveal.custom_step(10.0)
	await settle()
	check(complete.reward_total.text == "+ 200" and complete._reward_status.text.begins_with("Coins saved"),"registered results show the credited clean-race bonus and balance")
	await capture("saved-race-rewards")
	host.free()
	summary.free()

func guest_checks(economy: Node, records: LocalRecords) -> void:
	var host := Control.new()
	host.theme = MenuStyle.theme()
	root.add_child(host)
	MenuStyle.fill(host)
	page = GaragePage.new()
	page.records = records
	page.economy = economy
	host.add_child(page)
	MenuStyle.fill(page)
	page.open_car(0)
	await settle()
	check(page._coin_balance.text == "Sign in to earn coins","guest Garage offers sign-in instead of a spendable balance")
	page._select_livery(3)
	await settle()
	check(page._purchase_dialog.ok_button_text == "Sign in" and not page._purchase_dialog.get_ok_button().disabled,"guest purchase offers an enabled sign-in action")
	var requested: Array = []
	page.account_requested.connect(func() -> void: requested.append(true))
	page._purchase_dialog.confirmed.emit()
	check(requested.size() == 1 and economy.balance() == 0,"guest purchase opens account without spending")
	await capture("guest-sign-in")
	host.remove_child(page)
	page.free()
	page = null
	var summary := RaceResults.new()
	summary.circuit = "Guest loop"
	summary.total = 100.0
	summary.laps = [20.0,20.0,20.0,20.0,20.0]
	var complete := RaceComplete.new()
	complete.results = summary
	complete.economy = economy
	complete.coin_receipt = {"status":"credited","amount":200,"rows":[{"title":"Clean race","amount":200,"icon":"trophy","eligible":true,"status":"Credited"}]}
	host.add_child(complete)
	MenuStyle.fill(complete)
	await settle()
	check(complete.reward_total.text == "+ 0" and complete._reward_status.text == "Sign in to earn coins.","guest results ignore historical positive receipts")
	await capture("guest-no-rewards")
	host.free()
	summary.free()

func incident_checks() -> void:
	var session := TrackSession.new()
	session.finished = true
	session.completed_laps = RaceRules.LAPS
	session.elapsed_ticks = 6000
	var telemetry := LapTelemetry.new()
	for index: int in range(RaceRules.LAPS): telemetry.completed.append({"valid":true,"samples":[{}],"events":[]})
	var state := VehicleState.new()
	var incidents: Dictionary = preload("res://race/race_incidents.gd").build(session,telemetry,state)
	check(incidents == {"schema":"bmt-race-incidents-v1","ticks":6000,"collision_count":0,"off_track":false},"complete clean telemetry records bonus eligibility")
	state.collision_count = 1
	check(preload("res://race/race_incidents.gd").build(session,telemetry,state).collision_count == 1,"collision counter disqualifies clean race")
	state.collision_count = 0
	telemetry.completed[0].events = [{"kind":"collision"}]
	check(preload("res://race/race_incidents.gd").build(session,telemetry,state).collision_count == 1,"recorded collision disqualifies clean race")
	telemetry.completed[0].events = [{"kind":"off_track"}]
	check(preload("res://race/race_incidents.gd").build(session,telemetry,state).off_track,"off-track event disqualifies clean race")
	telemetry.completed[0].valid = false
	check(preload("res://race/race_incidents.gd").build(session,telemetry,state).is_empty(),"invalid lap cannot claim clean bonus")
	telemetry.completed[0].valid = true
	telemetry.completed[0].samples = []
	check(preload("res://race/race_incidents.gd").build(session,telemetry,state).is_empty(),"missing telemetry cannot claim clean bonus")
	session.finished = false
	check(preload("res://race/race_incidents.gd").build(session,telemetry,state).is_empty(),"incomplete race cannot claim clean bonus")
	var proof: Dictionary = {"schema":"bmt-race-proof-v1","samples":[[0,0.0,0.0,0.0,0.0,0.0,0,0],[6,1.0,0.0,0.0,0.0,0.0,0,0]],"incidents":incidents}
	var modern: Dictionary = Client._pack_trajectory(6000,proof,[],{},true)
	var legacy: Dictionary = Client._pack_trajectory(6000,proof,[])
	check(modern.race_proof.incidents == incidents,"capable server receives incidents alongside trajectory")
	check(not legacy.race_proof.has("incidents") and legacy.race_proof.samples == modern.race_proof.samples,"older server receives original unchanged trajectory")
	check(preload("res://tests/fixtures/replay_wire_reference.gd").pack([[0,0,0]],[],false,proof,true).race_proof.incidents == incidents,"legacy replay envelope can carry normalized incidents")
