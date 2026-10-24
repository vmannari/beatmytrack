extends Node
## Presentation-only cadence, independent of race simulation and result authority.
signal blocking_changed(value: bool)
const RACES_PER_AD: int = 3
const INTERVAL_MSEC: int = 10 * 60 * 1000
const ACCESS = preload("res://backend/store_access_cache.gd")
var client: Node
var adapter: Node
var enabled: bool = false
var races: int = 0
var active_msec: int = 0
var busy: bool = false
var blocking: bool = false
var clock_msec: Callable = Time.get_ticks_msec
var _sampled_at: int = -1
var _was_active: bool = false
var _preparing: bool = false

func _ready() -> void:
	if adapter == null:
		adapter = preload("res://platform/admob_interstitial.gd").new()
		add_child(adapter)

func observe_time(active: bool) -> void:
	var now: int = clock_msec.call()
	if _sampled_at >= 0 and _was_active:
		active_msec = mini(INTERVAL_MSEC, active_msec + maxi(0, now - _sampled_at))
	_sampled_at = now
	_was_active = active and enabled and not blocking

func record_finish() -> void:
	races = mini(RACES_PER_AD, races + 1)

func due() -> bool:
	return races >= RACES_PER_AD or active_msec >= INTERVAL_MSEC

func _available() -> bool:
	return enabled and is_instance_valid(adapter) and adapter.supported()

func _eligible(scope: String) -> bool:
	if not is_instance_valid(client): return false
	if not client.signed_in(): return true
	# Read ownership at the break as well as during warming. Unknown ownership
	# skips the ad; an account change cannot reuse another player's entitlement.
	var result: Dictionary = await client.request_api("/me/entitlements", HTTPClient.METHOD_GET, {}, "", true)
	if scope != ACCESS.identity(client) or not result.get("ok", false): return false
	var owned: Variant = result.get("data")
	if not preload("res://platform/purchase_simulator.gd").valid_entitlements(owned): return false
	return not owned.ad_free and not owned.ad_free_forever

func prepare() -> void:
	if not _available() or _preparing or busy: return
	_preparing = true
	var scope: String = ACCESS.identity(client)
	var eligible: bool = await _eligible(scope)
	_preparing = false
	if not _available() or scope != ACCESS.identity(client): return
	if eligible: adapter.prepare()
	else: adapter.discard()

func show_if_due(at_break: Callable) -> Dictionary:
	if not _available() or not due() or busy or not at_break.call(): return {"shown":false}
	busy = true
	var scope: String = ACCESS.identity(client)
	var eligible: bool = await _eligible(scope)
	if not _available() or scope != ACCESS.identity(client) or not eligible or not at_break.call():
		busy = false
		return {"shown":false}
	# Only this short SDK handoff owns navigation. Entitlement reads leave the
	# result usable; leaving it invalidates at_break and prevents a late popup.
	blocking = true
	blocking_changed.emit(true)
	observe_time(false)
	var result: Dictionary = await adapter.show_interstitial()
	if bool(result.get("shown", false)):
		races = 0
		active_msec = 0
	blocking = false
	blocking_changed.emit(false)
	busy = false
	return result
