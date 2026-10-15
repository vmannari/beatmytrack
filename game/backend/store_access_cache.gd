extends RefCounted
## Scoped, short-lived read data only. Checkout still requires server validation.
const MAX_SCOPES: int = 4
const TTL_MS: int = 60000
static var scopes: Dictionary = {}
signal completed
var value: Dictionary = {}
var refreshed: int = -1
var busy: bool = false

static func identity(service: Node) -> String:
	if not is_instance_valid(service): return ""
	var development: bool = service.test_drivers_available() if service.has_method("test_drivers_available") else false
	return JSON.stringify([service.base_url(),service.player.get("id",""),development])

static func for_service(service: Node) -> RefCounted:
	var key: String = identity(service)
	var cache: RefCounted = scopes.get(key)
	if cache == null: cache = load("res://backend/store_access_cache.gd").new()
	scopes.erase(key)
	scopes[key] = cache
	while scopes.size() > MAX_SCOPES: scopes.erase(scopes.keys()[0])
	return cache

static func valid_catalog(data: Variant) -> bool:
	if not data is Dictionary or not data.get("products") is Array or data.products.size() > 5: return false
	for product: Variant in data.products:
		if not product is Dictionary or not product.get("id") in preload("res://platform/purchase_simulator.gd").PRODUCTS or not product.get("title") is String or not product.get("price_eur") is String or not product.get("enabled") is bool: return false
	return true

func fetch(service: Node, force: bool = false) -> Dictionary:
	if busy:
		await completed
		return value.duplicate(true)
	if not force and refreshed >= 0 and Time.get_ticks_msec()-refreshed < TTL_MS: return value.duplicate(true)
	busy = true
	var scope: String = identity(service)
	var result: Dictionary = await service.request_api("/store/products")
	var owned: Dictionary = {}
	if scope == identity(service) and result.get("ok",false) and valid_catalog(result.get("data")) and service.signed_in():
		var response: Dictionary = await service.request_api("/me/entitlements",HTTPClient.METHOD_GET,{},"",true)
		if response.get("ok",false) and preload("res://platform/purchase_simulator.gd").valid_entitlements(response.get("data")): owned = response.data
	if scope != identity(service):
		value = {"ok":false,"error":"Account changed"}
		refreshed = -1
	elif result.get("ok",false) and valid_catalog(result.get("data")):
		refreshed = Time.get_ticks_msec()
		value = {"ok":true,"data":result.data,"entitlements":owned,"revision":refreshed}
	else:
		refreshed = -1
		value = {"ok":false,"error":result.get("error","Store unavailable")}
	busy = false
	completed.emit()
	return value.duplicate(true)
