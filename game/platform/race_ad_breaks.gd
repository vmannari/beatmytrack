extends Node
## Presentation-only cadence, independent of race simulation and result authority.
signal blocking_changed(value: bool)
const RACES_PER_AD: int = 3
const INTERVAL_MSEC: int = 10 * 60 * 1000
const ACCESS = preload("res://backend/store_access_cache.gd")
const Policy = preload("res://backend/game_config_policy.gd")
const Storage = preload("res://backend/atomic_json.gd")
const SAVE_INTERVAL_MSEC: int = 15000
const MAX_ACTIVE_MSEC: int = 7200000
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
var policy: Dictionary = {}
var permission: Callable
var session_msec: int = 0
var shown_count: int = 0
var rewarded_elapsed_msec: int = -1
var session_races: int = 0
var storage_path: String = ""
var storage_error: bool = false
var _save_thread: Thread
var _writing_progress: Dictionary = {}
var _saved_progress: Dictionary = {}
var _save_requested: bool = false
var _next_save_at: int = 0

func _progress() -> Dictionary:
	return {"schema":1,"races":races,"active_msec":active_msec}

static func _valid_progress(value: Dictionary) -> bool:
	return value.size() == 3 and Policy.whole(value.get("schema"),1,1) and Policy.whole(value.get("races"),0,100) and Policy.whole(value.get("active_msec"),0,MAX_ACTIVE_MSEC)

func _finish_save() -> void:
	if _save_thread == null: return
	storage_error = not bool(_save_thread.wait_to_finish())
	if not storage_error: _saved_progress = _writing_progress
	_save_thread = null
	_writing_progress = {}

func _poll_save() -> void:
	if _save_thread != null:
		if _save_thread.is_alive(): return
		_finish_save()
	if not _save_requested or storage_path.is_empty(): return
	_save_requested = false
	var progress: Dictionary = _progress()
	if progress == _saved_progress: return
	_writing_progress = progress
	_save_thread = Thread.new()
	if _save_thread.start(Storage.write.bind(storage_path,progress,256),Thread.PRIORITY_LOW) != OK:
		_save_thread = null
		_writing_progress = {}
		storage_error = true

func _request_save() -> void:
	_save_requested = true
	_poll_save()

func flush_progress() -> bool:
	# Suspend/shutdown joins the owned writer before saving the newest state.
	# Ordinary play uses the low-priority writer, never per-frame disk IO.
	_finish_save()
	_save_requested = false
	if storage_path.is_empty() or _progress() == _saved_progress: return not storage_error
	storage_error = not Storage.write(storage_path,_progress(),256)
	if not storage_error: _saved_progress = _progress()
	return not storage_error

func _exit_tree() -> void:
	observe_time(false)
	flush_progress()

func set_policy(value: Dictionary) -> void:
	if Policy.valid(value): policy = value.duplicate(true)

func _value(key: String, fallback: Variant) -> Variant:
	return policy.get(key,fallback)

func rewarded_presented() -> void:
	rewarded_elapsed_msec = 0

func can_present() -> bool:
	if session_races == 0: return false
	if not _value("ads.permitted",true) or not _value("ads.interstitial_enabled",true): return false
	if permission.is_valid() and not permission.call("ads.interstitial_enabled"): return false
	if session_msec < int(_value("ads.first_delay_seconds",0))*1000: return false
	if races < int(_value("ads.min_races",0)) or active_msec < int(_value("ads.min_seconds",0))*1000: return false
	var cap: Variant = _value("ads.session_cap",null)
	if cap != null and shown_count >= int(cap): return false
	if rewarded_elapsed_msec >= 0 and rewarded_elapsed_msec < int(_value("ads.rewarded_cooldown_seconds",0))*1000: return false
	return true

func _ready() -> void:
	if not storage_path.is_empty():
		var progress: Dictionary = Storage.read(storage_path,256)
		if _valid_progress(progress):
			races = int(progress.races)
			active_msec = int(progress.active_msec)
			_saved_progress = _progress()
	if adapter == null:
		adapter = preload("res://platform/admob_interstitial.gd").new()
		add_child(adapter)

func observe_time(active: bool) -> void:
	var now: int = clock_msec.call()
	if _sampled_at >= 0 and _was_active:
		var elapsed: int = maxi(0,now-_sampled_at)
		active_msec = mini(MAX_ACTIVE_MSEC,active_msec+elapsed)
		session_msec = mini(86400000,session_msec+elapsed)
		if rewarded_elapsed_msec >= 0: rewarded_elapsed_msec = mini(7200000,rewarded_elapsed_msec+elapsed)
	var stopped: bool = _was_active and (not active or not enabled or blocking)
	_sampled_at = now
	_was_active = active and enabled and not blocking
	_poll_save()
	if stopped or now >= _next_save_at:
		_next_save_at = now+SAVE_INTERVAL_MSEC
		_request_save()

func record_finish() -> void:
	races = mini(100, races + 1)
	session_races = mini(100, session_races + 1)
	_request_save()

func due() -> bool:
	var race_due: bool = races >= int(_value("ads.races",RACES_PER_AD))
	var time_due: bool = active_msec >= int(_value("ads.active_seconds",INTERVAL_MSEC/1000))*1000
	return (race_due and time_due) if _value("ads.trigger","either") == "both" else (race_due or time_due)

func _available() -> bool:
	return enabled and is_instance_valid(adapter) and adapter.supported() and (not permission.is_valid() or permission.call("ads.interstitial_enabled"))

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
	if not _available() or not due() or not can_present() or busy or not at_break.call(): return {"shown":false}
	busy = true
	var scope: String = ACCESS.identity(client)
	var eligible: bool = await _eligible(scope)
	if not _available() or not can_present() or scope != ACCESS.identity(client) or not eligible or not at_break.call():
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
		shown_count = mini(100,shown_count+1)
		_request_save()
	blocking = false
	blocking_changed.emit(false)
	busy = false
	return result
