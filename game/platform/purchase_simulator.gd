extends Node
## Debug-only test transport. Durable request identity recovers a lost response.
const AtomicJSON = preload("res://backend/atomic_json.gd")
const PRODUCTS: Array[String] = ["creator_slot_1","creator_slots_5","creator_slots_10","ad_free_month","ad_free_forever"]
var client: Node
var path_override: String = ""
var busy: bool = false

func _path() -> String:
	if not path_override.is_empty(): return path_override
	return "user://purchase_simulation/" + (client.base_url()+":"+str(client.player.get("id",""))).sha256_text()+".json"

static func valid_entitlements(data: Variant) -> bool:
	if not data is Dictionary: return false
	for field: String in ["publishing_slots","ad_free_until","max_rewinds_per_race","server_now"]:
		var value: Variant = data.get(field)
		if not (value is float or value is int) or float(value) != floorf(float(value)) or float(value) < 0: return false
	for field: String in ["ad_free","ad_free_forever","free_rewinds","purchase_simulation","store_available"]:
		if not data.get(field) is bool: return false
	return int(data.max_rewinds_per_race) == 3

static func valid_purchase(data: Variant) -> bool:
	return data is Dictionary and data.get("id") is String and not str(data.id).is_empty() and str(data.id).length() <= 96 and data.get("product_id") is String and data.get("state") in ["approved","pending","declined","cancelled"]

static func valid_result(data: Variant) -> bool:
	return data is Dictionary and valid_purchase(data.get("purchase")) and valid_entitlements(data.get("entitlements"))

func _guard() -> Dictionary:
	if not OS.is_debug_build(): return {"ok":false,"error":"Purchase simulation is available in debug builds only."}
	if not is_instance_valid(client) or not client.signed_in(): return {"ok":false,"error":"Sign in with Development on the purchase-test backend."}
	if busy: return {"ok":false,"error":"Purchase request is in progress."}
	return {"ok":true}

func catalog() -> Dictionary:
	var guard: Dictionary = _guard()
	if not guard.ok: return guard
	var result: Dictionary = await client.request_api("/development/purchases",HTTPClient.METHOD_GET,{},"",true)
	if result.ok and (not result.data.get("products") is Array or not result.data.get("purchases") is Array or not valid_entitlements(result.data.get("entitlements"))):
		return {"ok":false,"error":"Invalid purchase-test response."}
	if result.ok:
		if result.data.products.size() > 5 or result.data.purchases.size() > 40: return {"ok":false,"error":"Purchase-test response exceeds its bounded catalog."}
		for product: Variant in result.data.products:
			if not product is Dictionary or not product.get("id") in PRODUCTS or not product.get("title") is String or not product.get("price_eur") is String:
				return {"ok":false,"error":"Invalid purchase-test catalog."}
		for order: Variant in result.data.purchases:
			if not valid_purchase(order): return {"ok":false,"error":"Invalid purchase-test history."}
	return result

func has_pending_request() -> bool:
	return is_instance_valid(client) and client.signed_in() and FileAccess.file_exists(_path())

func purchase(product_id: String, outcome: String) -> Dictionary:
	var guard: Dictionary = _guard()
	if not guard.ok: return guard
	var path: String = _path()
	var journal: Dictionary = AtomicJSON.read(path,4096)
	if journal.has("_read_error"): return {"ok":false,"error":"Could not read purchase recovery. Preserve the file and check storage."}
	if not journal.is_empty(): return {"ok":false,"error":"Retry the saved purchase before starting another."}
	journal = {"request_id":_uuid(),"product_id":product_id,"outcome":outcome}
	if not AtomicJSON.write(path,journal,4096): return {"ok":false,"error":"Could not save purchase recovery. Free storage and retry."}
	return await _send_saved(path,journal)

func retry() -> Dictionary:
	var guard: Dictionary = _guard()
	if not guard.ok: return guard
	var path: String = _path()
	var journal: Dictionary = AtomicJSON.read(path,4096)
	if journal.is_empty() or journal.has("_read_error"): return {"ok":false,"error":"No readable purchase request to retry."}
	return await _send_saved(path,journal)

func _send_saved(path: String, journal: Dictionary) -> Dictionary:
	busy = true
	var result: Dictionary = await client.request_api("/development/purchases",HTTPClient.METHOD_POST,journal,"",true)
	busy = false
	if result.ok and not valid_result(result.data):
		return {"ok":false,"error":"Invalid purchase response. Retry the saved request."}
	if result.ok or int(result.get("status",0)) in [400,403,409,422]:
		if FileAccess.file_exists(path) and DirAccess.remove_absolute(path) != OK:
			return {"ok":false,"error":"Purchase processed, but recovery could not be cleared. Retry safely."}
	return result

func resolve(purchase_id: String, outcome: String) -> Dictionary:
	var guard: Dictionary = _guard()
	if not guard.ok: return guard
	busy = true
	var result: Dictionary = await client.request_api("/development/purchases/"+purchase_id.uri_encode()+"/resolve",HTTPClient.METHOD_POST,{"outcome":outcome},"",true)
	busy = false
	if result.ok and not valid_result(result.data): return {"ok":false,"error":"Invalid purchase resolution. Refresh to recover."}
	return result

func adjust(action: String) -> Dictionary:
	var guard: Dictionary = _guard()
	if not guard.ok: return guard
	busy = true
	var result: Dictionary = await client.request_api("/development/entitlements/adjust",HTTPClient.METHOD_POST,{"request_id":_uuid(),"action":action},"",true)
	busy = false
	return result

static func _uuid() -> String:
	var bytes: PackedByteArray = Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 15) | 64
	bytes[8] = (bytes[8] & 63) | 128
	var hex: String = bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0,8),hex.substr(8,4),hex.substr(12,4),hex.substr(16,4),hex.substr(20,12)]
