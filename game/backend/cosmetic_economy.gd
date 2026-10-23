extends Node
## Only signed-in accounts earn or spend Coins. Old local cosmetics remain available.
signal changed
const Shop = preload("res://persistence/cosmetic_catalog.gd")
const IO = preload("res://backend/atomic_json.gd")
var records: LocalRecords
var client: Node
var wallet: Dictionary = {}
var pending: Dictionary = {}
var status: String = ""
var busy: bool = false
var refreshing: bool = false
var scope: String = ""
var _path: String = ""
var _storage_ok: bool = true
var _epoch: int = 0
var _timer: Timer

func _ready() -> void:
	if not records.settings.has("cosmetic_legacy"):
		records.settings.cosmetic_legacy = Shop.legacy(records.settings)
		if records.save_records() != OK: status = "Could not save cosmetic ownership."
	if client != null: client.identity_changed.connect(sync_identity)
	sync_identity()
	_timer = Timer.new()
	_timer.wait_time = 15.0
	_timer.timeout.connect(func() -> void:
		if not pending.is_empty() and not busy: refresh())
	add_child(_timer)
	_timer.start()

func authenticated() -> bool:
	return client != null and client.signed_in()

func _current_scope() -> String:
	return str(client.base_url())+"/"+str(client.player.get("id","")) if authenticated() else "guest"

func sync_identity() -> void:
	var next: String = _current_scope()
	if next == scope: return
	scope = next
	_epoch += 1
	wallet = {}
	pending = {}
	busy = false
	refreshing = false
	_storage_ok = true
	status = ""
	_path = records.path.get_base_dir().path_join("economy/"+scope.sha256_text()+".json")
	if authenticated():
		var cached: Dictionary = IO.read(_path,65536)
		if cached.has("_read_error"):
			_storage_ok = false
			status = "Coin purchase recovery could not be read. Check storage."
		elif not cached.is_empty():
			if Shop.valid_wallet(cached.get("wallet")): wallet = cached.wallet
			var saved: Variant = cached.get("pending",{})
			if saved is Dictionary and (saved.is_empty() or (saved.size() == 3 and saved.get("item_id") is String and Shop.items().has(saved.item_id) and saved.get("key") is String and saved.key.length() >= 8 and saved.key.length() <= 128 and Shop.whole(saved.get("expected_price"),1000000) and saved.expected_price > 0)):
				pending = saved
			else:
				_storage_ok = false
				status = "Coin purchase recovery could not be read. Check storage."
	changed.emit()

func balance() -> int:
	return int(wallet.get("balance",0)) if authenticated() else 0

func _guest() -> Dictionary:
	return records.settings.get("guest_coins",{"version":1,"balance":0,"owned":[],"sequence":0}).duplicate(true)

func owns(id: String) -> bool:
	if Shop.free_item(id) or id in records.settings.get("cosmetic_legacy",[]): return true
	return id in (wallet.get("owned",[]) if authenticated() else _guest().owned)

func price(id: String) -> int:
	return int(wallet.get("prices",{}).get(id,Shop.items().get(id,0))) if authenticated() else int(Shop.items().get(id,0))

func caption(id: String) -> String:
	return "Free" if Shop.free_item(id) else "Owned" if owns(id) else "%d coins" % price(id)

func erase_account(origin: String, player_id: String) -> bool:
	var path: String = records.path.get_base_dir().path_join("economy/"+(origin+"/"+player_id).sha256_text()+".json")
	var ok: bool = true
	for suffix: String in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix) and DirAccess.remove_absolute(path+suffix) != OK: ok = false
	return ok

func _persist() -> bool:
	return _storage_ok and IO.write(_path,{"wallet":wallet,"pending":pending},65536)

func _accept(value: Variant) -> bool:
	if not Shop.valid_wallet(value): return false
	if wallet.is_empty() or int(value.revision) >= int(wallet.revision): wallet = value.duplicate(true)
	return true

func refresh() -> void:
	sync_identity()
	if not authenticated() or refreshing or busy: return
	var expected: String = scope
	var epoch: int = _epoch
	refreshing = true
	var response: Dictionary = await client.request_api("/economy",HTTPClient.METHOD_GET,{},"",true)
	if _current_scope() != expected or epoch != _epoch: return
	refreshing = false
	if response.ok and _accept(response.data):
		status = ""
		if not _persist(): status = "Coin balance is online. Local recovery could not be saved."
	elif response.get("status",0) == 404:
		status = "Coin shop needs a server update."
	else: status = "Could not refresh coins. Reconnect to buy."
	changed.emit()
	if not pending.is_empty() and _storage_ok: await _send_purchase()

func purchase(id: String) -> bool:
	sync_identity()
	if busy or not Shop.items().has(id): return false
	if owns(id): return true
	if not authenticated():
		status = "Sign in to earn and spend coins."
		changed.emit()
		return false
	if not pending.is_empty():
		status = "Finishing your previous purchase."
		changed.emit()
		return false
	pending = {"item_id":id,"key":client.new_operation_key(),"expected_price":price(id)}
	if not _persist():
		pending = {}
		status = "Purchase could not be saved. No coins spent."
		changed.emit()
		return false
	return await _send_purchase()

func _send_purchase() -> bool:
	if busy or pending.is_empty() or not authenticated(): return false
	var expected: String = scope
	var epoch: int = _epoch
	var operation: Dictionary = pending.duplicate(true)
	busy = true
	status = "Completing purchase…"
	changed.emit()
	var response: Dictionary = await client.request_api("/economy/purchases",HTTPClient.METHOD_POST,{"item_id":operation.item_id,"expected_price":operation.expected_price},operation.key,true)
	if _current_scope() != expected or epoch != _epoch: return false
	busy = false
	var success: bool = response.ok and response.data.get("item_id") == operation.item_id and _accept(response.data.get("wallet"))
	if success:
		pending = {}
		status = "Purchased."
	elif int(response.get("status",0)) in [400,401,403,404,410,422] or str(response.get("error","")) in ["INSUFFICIENT_COINS","COSMETIC_PRICE_CHANGED"]:
		pending = {}
		status = "Not enough coins. Complete more races." if str(response.get("error","")) == "INSUFFICIENT_COINS" else "Purchase unavailable. Refresh and try again."
		if str(response.get("error","")) == "COSMETIC_PRICE_CHANGED": status = "Price changed. Refresh coins before buying."
	else: status = "Purchase pending. We’ll retry automatically."
	if not _persist(): status = "Purchase recovery could not be saved. Reconnect to check ownership."
	changed.emit()
	if str(response.get("error","")) in ["INSUFFICIENT_COINS","COSMETIC_PRICE_CHANGED"]: refresh.call_deferred()
	return success

func reward_for(ticket: String) -> Dictionary:
	if not authenticated() or ticket.is_empty(): return {"status":"unavailable","amount":0,"rows":[]}
	var expected: String = _current_scope()
	var epoch: int = _epoch
	var response: Dictionary = await client.request_api("/economy/rewards/"+ticket,HTTPClient.METHOD_GET,{},"",true)
	if _current_scope() != expected or epoch != _epoch: return {"status":"unavailable","amount":0,"rows":[]}
	if response.ok:
		if response.data.get("status") == "credited": refresh()
		return response.data
	if int(response.get("status",0)) in [401,403,404,410]: return {"status":"unavailable","amount":0,"rows":[]}
	return {"status":"pending","amount":0,"rows":[]}
