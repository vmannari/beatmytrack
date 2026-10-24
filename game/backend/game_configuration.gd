extends Node
## Optional scoped configuration; asynchronous IO and transport run in safe states.
signal changed
signal rewarded_presented
const Policy = preload("res://backend/game_config_policy.gd")
const Storage = preload("res://backend/atomic_json.gd")
const Identity = preload("res://backend/store_access_cache.gd")
var client: Node
var telemetry: Node
var storage_path: String = ""
var negotiated: bool = false
var settings: Dictionary = Policy.DEFAULTS.duplicate(true)
var snapshot: Dictionary = {}
var menu_snapshot: Dictionary = {}
var pending: Dictionary = {}
var emergency: Dictionary = {}
var last_error: String = ""
var clock_msec: Callable = Time.get_ticks_msec
var _scope: String = ""
var _allowed: bool = true
var _foreground: bool = true
var _busy: bool = false
var _generation: int = 0
var _next_fetch: int = 0
var _next_emergency: int = 0
var _permission_until: int = 0
var _emergency_revision: int = -1
var _thread: Thread
var _thread_kind: String = ""
var _disk_cache: Dictionary = {}
var _save_pending: Dictionary = {}
var _exposed: Dictionary = {}
var _applied_resolution: String = ""
var _applied_menu_resolution: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(pump)
	add_child(timer)
	timer.start()
	if not storage_path.is_empty(): _start_io("read",Storage.read.bind(storage_path,70000))
	pump.call_deferred()

func _exit_tree() -> void:
	if _thread != null and _thread.is_started(): _thread.wait_to_finish()
	if client != null and client.has_method("cancel_configuration"): client.cancel_configuration()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
		_foreground = false
		_permission_until = 0
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN,NOTIFICATION_APPLICATION_RESUMED]:
		_foreground = true
		_next_emergency = 0

func set_transport_allowed(value: bool) -> void:
	if _allowed == value: return
	_allowed = value
	if not value and client != null and client.has_method("cancel_configuration"): client.cancel_configuration()

func _identity() -> String:
	return Identity.identity(client)+"/analytics="+str(client.telemetry_supported()) if client != null else ""

func _player_scope() -> String:
	return str(client.player.get("id","")) if client != null and client.signed_in() else "guest"

func _reset_scope() -> void:
	_scope = _identity()
	_generation += 1
	settings = Policy.DEFAULTS.duplicate(true)
	snapshot = {}
	menu_snapshot = {}
	pending = {}
	emergency = {}
	_permission_until = 0
	_emergency_revision = -1
	_next_fetch = 0
	_next_emergency = 0
	_applied_resolution = ""
	_applied_menu_resolution.clear()
	_exposed.clear()
	negotiated = false
	changed.emit()

func _start_io(kind: String, work: Callable) -> void:
	if _thread != null: return
	_thread = Thread.new()
	_thread_kind = kind
	if _thread.start(work,Thread.PRIORITY_LOW) != OK:
		_thread = null
		last_error = "CONFIG_STORAGE_UNAVAILABLE"

func _poll_io() -> void:
	if _thread == null or _thread.is_alive(): return
	var value: Variant = _thread.wait_to_finish()
	_thread = null
	if _thread_kind == "read" and value is Dictionary: _disk_cache = value
	elif value is bool and not value: last_error = "CONFIG_STORAGE_UNAVAILABLE"
	_thread_kind = ""

func pump() -> void:
	if not _allowed or not _foreground: return
	_poll_io()
	if _scope != _identity(): _reset_scope()
	if client == null: return
	var online_protocol: bool = client.has_method("game_configuration_supported") and client.game_configuration_supported()
	var policy_now: int = client.server_now() if client.server_now() > 0 else int(Time.get_unix_time_from_system())
	if not snapshot.is_empty() and policy_now > int(snapshot.expires_at):
		settings = Policy.DEFAULTS.duplicate(true)
		snapshot = {}
		menu_snapshot = {}
		pending = {}
		_permission_until = 0
		_next_fetch = 0
		changed.emit()
	if snapshot.is_empty() and pending.is_empty() and _disk_cache.get("scope","") == _scope.sha256_text():
		var cached: Variant = _disk_cache.get("snapshot",{})
		var cache_now: int = client.server_now() if client.server_now() > 0 else int(Time.get_unix_time_from_system())
		if Policy.snapshot_valid(cached,_player_scope()) and cache_now >= int(cached.server_now) and cache_now <= int(cached.expires_at) and (cached.assignments.is_empty() or (online_protocol and client.telemetry_supported())):
			pending = cached.duplicate(true)
			negotiated = true
		_disk_cache = {}
	if not online_protocol: return
	negotiated = true
	if not _save_pending.is_empty() and _thread == null and not storage_path.is_empty():
		var writing: Dictionary = _save_pending
		_save_pending = {}
		_start_io("write",Storage.write.bind(storage_path,writing,70000))
	if _busy: return
	var now: int = clock_msec.call()
	if now >= _next_emergency:
		_refresh_emergency()
	elif now >= _next_fetch:
		_refresh()

func _query() -> String:
	var platform: String = OS.get_name().to_lower()
	if platform not in ["android","windows","linux","ios"]: platform = "linux"
	return "?platform="+platform+"&build_id="+preload("res://core/build_identity.gd").ID.uri_encode()+"&capabilities=ad_policy_v1,menu_policy_v1&experiments_enabled="+("true" if client.telemetry_supported() else "false")

func _refresh_emergency() -> void:
	_busy = true
	var scope: String = _scope
	var epoch: int = _generation
	_next_emergency = clock_msec.call()+30000
	var response: Dictionary = await client.request_configuration("/game-config/emergency")
	_busy = false
	if scope != _identity() or epoch != _generation or not _foreground: return
	var data: Variant = response.get("data",{})
	if response.get("ok",false) and data is Dictionary and data.get("restrictions") is Dictionary and Policy.whole(data.get("revision",-1),0,2147483647):
		if not Policy.whole(data.get("valid_seconds",0),1,120): return
		if int(data.revision) < _emergency_revision: return
		var valid: bool = true
		for key: String in data.restrictions:
			if key not in ["ads.permitted","ads.interstitial_enabled","ads.rewarded_resume_enabled"] or data.restrictions[key] != false: valid = false
		if not valid: return
		emergency = data.restrictions.duplicate(true)
		_emergency_revision = int(data.revision)
		_permission_until = clock_msec.call()+120000
		_next_emergency = clock_msec.call()+110000
		if int(data.revision) != int(snapshot.get("control_revision",-1)): _next_fetch = 0
		changed.emit()

func _refresh() -> void:
	_busy = true
	var scope: String = _scope
	var epoch: int = _generation
	_next_fetch = clock_msec.call()+60000
	var response: Dictionary = await client.request_configuration("/game-config"+_query())
	if scope != _identity() or epoch != _generation:
		_busy = false
		return
	if response.get("ok",false) and response.get("data") is Dictionary and response.data.get("assignment_refresh_required",false) and client.telemetry_supported() and _allowed:
		await client.request_configuration("/experiments/assignments"+_query(),true)
		if scope == _identity() and epoch == _generation and _allowed: response = await client.request_configuration("/game-config"+_query())
	_busy = false
	if scope != _identity() or epoch != _generation: return
	if not response.get("ok",false):
		last_error = str(response.get("error","CONFIG_UNAVAILABLE"))
		return
	var candidate: Variant = response.get("data",{})
	if not Policy.snapshot_valid(candidate,_player_scope()):
		last_error = "INVALID_CONFIG_SNAPSHOT"
		if candidate is Dictionary and Policy.whole(candidate.get("generation",-1),0,2147483647) and candidate.get("resolution_id") is String and RegEx.create_from_string("^[a-f0-9]{64}$").search(candidate.resolution_id) != null:
			_observe("config_rejected",{"config_generation":int(candidate.generation),"config_resolution":candidate.resolution_id})
		return
	if int(candidate.generation) < maxi(int(snapshot.get("generation",0)),int(pending.get("generation",0))) or int(candidate.control_revision) < _emergency_revision:
		last_error = "STALE_CONFIG_REPLY"
		return
	pending = candidate.duplicate(true)
	_save_pending = {"scope":_scope.sha256_text(),"snapshot":pending.duplicate(true)}
	_next_fetch = clock_msec.call()+1800000+int(_scope.sha256_text().left(4).hex_to_int()%180000)
	last_error = ""

func enter_menu() -> void:
	if _scope != _identity(): _reset_scope()
	if not _allowed or not _foreground or pending.is_empty(): return
	# Menu settings apply on entry; ad settings wait for their result boundary.
	for key: String in pending.settings:
		if not key.begins_with("ads."): settings[key] = pending.settings[key]
	menu_snapshot = pending.duplicate(true)
	changed.emit()

func menu_applied(screen: String, store_visible: bool = false) -> void:
	if menu_snapshot.is_empty(): return
	var group: String = "store" if screen == "store" and store_visible else "menu"
	if _applied_menu_resolution.get(group,"") != str(menu_snapshot.resolution_id):
		var properties: Dictionary = _properties({},menu_snapshot)
		properties.config_group = group
		if _observe("config_applied",properties,group+"/"+str(menu_snapshot.resolution_id)):
			_applied_menu_resolution[group] = str(menu_snapshot.resolution_id)
	expose("presentation","menu_entry")
	if screen == "store" and store_visible: expose("presentation","store_entry")

func at_result(expose_ads: bool = true) -> void:
	if _scope != _identity(): _reset_scope()
	if not pending.is_empty():
		snapshot = pending.duplicate(true)
		for key: String in snapshot.settings:
			if key.begins_with("ads."): settings[key] = snapshot.settings[key]
		if _applied_resolution != str(snapshot.resolution_id):
			_applied_resolution = str(snapshot.resolution_id)
			var properties: Dictionary = _properties({})
			properties.config_group = "ads"
			_observe("config_applied",properties,"apply/"+_applied_resolution)
	if expose_ads and needs_ad_exposure(): expose("ads","race_result")

func needs_ad_exposure() -> bool:
	if snapshot.is_empty() or not bool(settings.get("ads.permitted",false)) or clock_msec.call() >= _permission_until or emergency.has("ads.permitted") or emergency.has("ads.interstitial_enabled") or "ad_free_entitlement" in snapshot.get("restrictions",[]): return false
	for item: Dictionary in snapshot.assignments:
		if item.layer == "ads" and not _exposed.has(str(item.experiment_id)+"/"+str(item.revision)): return true
	return false

func renew_result_permission() -> void:
	# A long race can outlive the short permission lease. Renew only at its
	# result, leaving navigation usable and the applied policy unchanged.
	if not negotiated or not _allowed or not _foreground or _busy: return
	if clock_msec.call() < _permission_until or clock_msec.call() < _next_emergency: return
	await _refresh_emergency()

func rewarded_permission() -> bool:
	if permission("ads.rewarded_resume_enabled"): return true
	# An explicitly requested rewarded offer is a paused, safe transition. It
	# may renew only the small emergency lease, without applying race policy.
	if not negotiated or not _foreground or _busy or clock_msec.call() < _next_emergency: return false
	await _refresh_emergency()
	return permission("ads.rewarded_resume_enabled")

func permission(key: String) -> bool:
	if not negotiated: return client == null or not client.has_method("game_configuration_supported") or not client.game_configuration_supported()
	if _scope != _identity() or not _foreground or clock_msec.call() >= _permission_until: return false
	return bool(settings.get("ads.permitted",false)) and bool(settings.get(key,false)) and emergency.get("ads.permitted",true) and emergency.get(key,true)

func expose(layer: String, boundary: String = "menu_entry") -> void:
	var source: Dictionary = menu_snapshot if layer == "presentation" else snapshot
	if source.is_empty(): return
	for item: Dictionary in source.assignments:
		if item.layer != layer or item.get("boundary","menu_entry" if layer == "presentation" else "race_result") != boundary: continue
		var once: String = str(item.experiment_id)+"/"+str(item.revision)
		if _exposed.has(once): continue
		if _observe("experiment_exposed",_properties(item,source),once): _exposed[once] = true

func record_ad_decision(outcome: String) -> void:
	if snapshot.is_empty(): return
	var reference: Dictionary = {}
	for item: Dictionary in snapshot.assignments:
		if item.layer == "ads": reference = item
	var props: Dictionary = _properties(reference)
	props.ad_outcome = outcome
	_observe("ad_policy_decision",props)

func event_context(name: String) -> Dictionary:
	if _scope != _identity(): return {}
	var store_event: bool = name in ["store_opened","offer_exposed","purchase_requested"]
	var menu_event: bool = store_event or name in ["menu_ready","track_exposed","track_selected","car_exposed","car_selected","challenge_opened","challenge_joined","challenge_created","share_clicked","publish_requested"]
	var source: Dictionary = menu_snapshot if menu_event else snapshot
	if source.is_empty(): return {}
	var layer: String = "presentation" if menu_event else "ads"
	var boundary: String = "store_entry" if store_event else "menu_entry" if menu_event else "race_result"
	var reference: Dictionary = {}
	for item: Dictionary in source.assignments:
		if item.layer == layer and item.get("boundary",boundary) == boundary and _exposed.has(str(item.experiment_id)+"/"+str(item.revision)): reference = item
	var properties: Dictionary = _properties(reference,source)
	properties.config_group = "store" if store_event else "menu" if menu_event else "ads"
	return properties

func _properties(reference: Dictionary, source: Dictionary = {}) -> Dictionary:
	var active: Dictionary = snapshot if source.is_empty() else source
	var result: Dictionary = {"config_generation":int(active.get("generation",0)),"config_resolution":str(active.get("resolution_id",""))}
	if not reference.is_empty():
		result.experiment_id = reference.experiment_id
		result.variant = reference.variant
		result.experiment_revision = int(reference.revision)
	return result

func _observe(name: String, properties: Dictionary, once: String = "") -> bool:
	return telemetry != null and telemetry.observe(name,properties,once)
