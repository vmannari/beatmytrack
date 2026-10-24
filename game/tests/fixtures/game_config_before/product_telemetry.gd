extends Node
## Bounded first-party observations; never invoked by canonical simulation.
## Authentication scopes stay local and are never accepted as event identity.
signal observations_due
const Storage = preload("res://backend/atomic_json.gd")
const SCHEMA: String = "bmt-product-events-v1"
const MAX_EVENTS: int = 1000
const MAX_QUEUE_BYTES: int = 2097152
const MAX_BATCH_EVENTS: int = 50
const MAX_BATCH_BYTES: int = 65536
const MAX_AGE_SECONDS: int = 86400
const FLUSH_INTERVAL_MSEC: int = 60000
const IDLE_FLUSH_MSEC: int = 300000
const SESSION_GAP_MSEC: int = 1800000
const EVENT_NAMES: Array[String] = ["app_first_open","session_started","session_foregrounded","session_backgrounded","session_heartbeat","collection_summary","menu_ready","track_exposed","track_selected","car_exposed","car_selected","race_attempt","race_started","race_finished","race_abandoned","race_retried","publish_requested","challenge_opened","challenge_joined","challenge_created","share_clicked","store_opened","offer_exposed","purchase_requested"]
const STORE_PRODUCTS: Array[String] = ["creator_slot_1","creator_slots_5","creator_slots_10","ad_free_month","ad_free_forever"]
const NUMBER_PROPERTIES: Array[String] = ["foreground_ms","position","dropped_events","rejected_events","persistence_failures"]
var client: Node
var storage_path: String = ""
var enabled: bool = true
var queue: Array[Dictionary] = []
var _queue_budget_bytes: int = 0
var dropped_events: int = 0
var rejected_events: int = 0
var persistence_failures: int = 0
var last_batch_bytes: int = 0
var last_save_usec: int = 0
var _loaded: bool = false
var _dirty: bool = false
var _generation: int = 0
var _saved_generation: int = -1
var _save_generation: int = -1
var _persisted_ids: Dictionary = {}
var _thread: Thread
var _thread_kind: String = ""
var _session_id: String = uuid()
var _sequence: int = 0
var _session_start_msec: int = Time.get_ticks_msec()
var _session_clock_unix: int = int(Time.get_unix_time_from_system())
var _clock_quality: String = "client_clock"
var _foreground_start_msec: int = Time.get_ticks_msec()
var _background_msec: int = 0
var _foreground: bool = true
var _allowed: bool = true
var _scope: String = "guest"
var _first_open_scopes: Dictionary = {}
var _heartbeat_msec: int = Time.get_ticks_msec()
var _uploading: bool = false
var _next_upload_msec: int = 0
var _retry_delay_msec: int = FLUSH_INTERVAL_MSEC
var _deduplicated: Dictionary = {}
var _timer: Timer
var _uuid_pattern: RegEx = RegEx.create_from_string("^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$")
var _next_prune_msec: int = 0
var _pending_since_msec: int = -1
var _journey_pending_msec: int = -1
var _next_save_msec: int = 0
var _save_retry_msec: int = 5000
var _install_id: String = uuid()
var _build_id: String = preload("res://core/build_identity.gd").ID
var _platform: String = OS.get_name().to_lower()
var _build_pattern: RegEx = RegEx.create_from_string("^[A-Za-z0-9._:-]{1,80}$")
var _scope_pattern: RegEx = RegEx.create_from_string("^[a-f0-9]{64}$")
var _next_summary_msec: int = 0
var _reported_counters: String = "0/0/0"
var _event_ids: Array[String] = uuid_pool(128)
var _provisional_first_opens: Dictionary = {}
var _collection_started_scope: String = ""
var _process_exit_cursor: int = 0
const QUALITY_NAMES: Array[String] = ["quality_summary","process_exit","race_statistics"]
const NETWORK_NAMES: Array[String] = ["network_summary","network_failure"]
const PASSIVE_NAMES: Array[String] = ["session_heartbeat","quality_summary","process_exit","network_summary","network_failure"]
const QUALITY_NUMBERS: Array[String] = ["samples","slow","segment","cell_x","cell_y","exit_reason","b0","b1","b2","b3","b4","b5","b6","b7"]

static func uuid() -> String:
	var bytes: PackedByteArray = Crypto.new().generate_random_bytes(16)
	return _uuid_from_bytes(bytes)

static func _uuid_from_bytes(bytes: PackedByteArray) -> String:
	bytes[6] = (bytes[6] & 15) | 64
	bytes[8] = (bytes[8] & 63) | 128
	var value: String = bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [value.substr(0,8),value.substr(8,4),value.substr(12,4),value.substr(16,4),value.substr(20,12)]

static func uuid_pool(count: int) -> Array[String]:
	var result: Array[String] = []
	if count <= 0: return result
	var bytes: PackedByteArray = Crypto.new().generate_random_bytes(16*count)
	for index: int in range(count): result.append(_uuid_from_bytes(bytes.slice(index*16,(index+1)*16)))
	return result

func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = 1.0
	_timer.timeout.connect(pump)
	add_child(_timer)
	_timer.start()
	if _platform not in ["android","windows","linux","ios"]: _platform = "linux"
	if _build_pattern.search(_build_id) == null: _build_id = "unknown"
	if not enabled:
		_loaded = true
		_erase_saved_queue()
	elif storage_path.is_empty():
		_loaded = true
	else:
		_start_thread("read",_read_with_ids.bind(storage_path))
	update_identity()

func _erase_saved_queue() -> void:
	if storage_path.is_empty(): return
	for suffix: String in ["", ".tmp"]:
		if FileAccess.file_exists(storage_path+suffix) and DirAccess.remove_absolute(storage_path+suffix) != OK: persistence_failures += 1

func set_enabled(value: bool) -> void:
	if enabled == value: return
	enabled = value
	if client != null:
		if "analytics_opt_in" in client: client.analytics_opt_in = value
		if client.has_method("cancel_telemetry"): client.cancel_telemetry()
	if not value:
		# Settings is a menu action. Join the already bounded disk task so it cannot
		# recreate a removed outbox after withdrawal.
		if _thread != null:
			if _thread.is_alive(): _thread.wait_to_finish()
			_thread = null
		_loaded = true
		queue.clear()
		_persisted_ids.clear()
		_first_open_scopes.clear()
		_provisional_first_opens.clear()
		_collection_started_scope = ""
		_queue_budget_bytes = 0
		_dirty = false
		_erase_saved_queue()
		if client != null and "network_health" in client: client.network_health._scopes.clear()
	else: update_identity()

func erase_account(origin: String, player_id: String) -> void:
	var removed_scope: String = (origin+"/"+player_id).sha256_text()
	if _thread != null:
		var completed: Variant = _thread.wait_to_finish()
		_finish_thread(completed)
	var kept: Array[Dictionary] = []
	for entry: Dictionary in queue:
		if entry.scope == removed_scope: _persisted_ids.erase(str(entry.event.id))
		else: kept.append(entry)
	queue = kept
	_first_open_scopes.erase(removed_scope)
	_recount_budget()
	if client != null and "network_health" in client: client.network_health._scopes.erase(removed_scope)
	_mark_dirty()
	if enabled: _save_if_needed()
	else:
		_dirty = false
		_erase_saved_queue()

func update_identity() -> void:
	var next_scope: String = "guest"
	if client != null and client.signed_in():
		next_scope = (client.base_url()+"/"+str(client.player.get("id",""))).sha256_text()
	var supported: bool = client != null and client.telemetry_supported() and next_scope != "guest"
	if next_scope == _scope:
		if not supported:
			_collection_started_scope = ""
			return
		if _collection_started_scope == _scope:
			_record_first_open()
			return
	_scope = next_scope
	_collection_started_scope = _scope if supported else ""
	# No implicit guest/account merging and no transfer between signed-in players.
	_session_id = uuid()
	_sequence = 0
	_session_start_msec = Time.get_ticks_msec()
	_anchor_clock()
	_foreground_start_msec = _session_start_msec
	_deduplicated.clear()
	_next_upload_msec = 0
	_pending_since_msec = -1
	_journey_pending_msec = -1
	observe("session_started",{"reason":"launch"})
	_record_first_open()

func _record_first_open() -> void:
	if _first_open_scopes.has(_scope) or _provisional_first_opens.has(_scope): return
	# Reserve the first-open observation now, before menu/race observations.
	# The async queue read may reveal a prior first-open; discard this provisional
	# event before persistence/upload in that case. Sequence/monotonic order stays
	# truthful and a fast restored sign-in cannot move the funnel anchor later.
	if not observe("app_first_open"): return
	if _loaded:
		_first_open_scopes[_scope] = true
		while _first_open_scopes.size() > 32: _first_open_scopes.erase(_first_open_scopes.keys()[0])
	else:
		_provisional_first_opens[_scope] = str(queue[-1].event.id)

func _anchor_clock() -> void:
	var estimated: int = int(client.server_now()) if client != null and client.has_method("server_now") else 0
	_session_clock_unix = estimated if estimated > 0 else int(Time.get_unix_time_from_system())
	_clock_quality = "server_estimate" if estimated > 0 else "client_clock"

func observe(name: String, properties: Dictionary = {}, once_key: String = "") -> bool:
	if name == "race_statistics": return false # Only a negotiated lifecycle capture may enqueue this.
	if name in NETWORK_NAMES and (not _allowed or not _network_supported()): return false
	if name in ["track_exposed","track_selected"]:
		var published_version: Variant = properties.get("track_version_id","")
		if not published_version is String or _uuid_pattern.search(published_version) == null: return false
	if name in QUALITY_NAMES and (client == null or not client.has_method("quality_supported") or not client.quality_supported()): return false
	if name in QUALITY_NAMES and not _allowed and _event_ids.size() <= 32: return false # Reserve identifiers for product/race observations.
	if not enabled or not _foreground or (name not in EVENT_NAMES and name not in QUALITY_NAMES and name not in NETWORK_NAMES) or client == null or not client.telemetry_supported() or _scope == "guest": return false
	if name in ["offer_exposed","purchase_requested"] and properties.get("product_id","") not in STORE_PRODUCTS: return false
	# Never call the operating-system random provider during a live race.
	# An unusually long attempt can exhaust the bounded preallocated pool; report
	# that loss at the next menu instead of making the simulation wait for IDs.
	if not _allowed and _event_ids.is_empty():
		dropped_events += 1
		_mark_dirty()
		return false
	if not once_key.is_empty():
		var key: String = name+"/"+once_key
		if _deduplicated.has(key): return false
		# Discovery cannot exhaust session memory by scrolling an unlimited catalog.
		if _deduplicated.size() >= 1000: return false
		_deduplicated[key] = true
	var safe: Dictionary = _safe_properties(name,properties)
	if name in NETWORK_NAMES and safe.is_empty(): return false
	return _enqueue(name,safe)

func reserve_capture_id() -> String:
	# Reserve product/race journey identifiers ahead of optional diagnostics.
	if _scope == "guest": return ""
	if _event_ids.size() <= 32:
		dropped_events += 1
		_mark_dirty()
		return ""
	return _event_ids.pop_back()

func observe_race_statistics(properties: Dictionary, captured_scope: String) -> bool:
	# Capture was negotiated at attempt start. Temporary bootstrap loss or a
	# focus-out at finish must not discard it or move it to another account.
	if not enabled or client == null or not client.signed_in() or captured_scope == "guest" or captured_scope != _scope: return false
	var actual_scope: String = (client.base_url()+"/"+str(client.player.get("id",""))).sha256_text()
	if actual_scope != captured_scope: return false
	var safe: Dictionary = _safe_race_statistics(properties)
	if safe.is_empty(): return false
	return _enqueue("race_statistics",safe,str(safe.race_id))

static func _entry_budget(entry: Dictionary) -> int:
	# Conservative UTF-8/envelope bounds avoid per-event JSON work during driving.
	return 8192 if entry.event.name == "race_statistics" else 4096 if entry.event.name == "network_summary" else 1536

func _enqueue(name: String, safe: Dictionary, identifier: String = "") -> bool:
	_sequence += 1
	var elapsed: int = maxi(0,Time.get_ticks_msec()-_session_start_msec)
	var event: Dictionary = {"id":identifier if not identifier.is_empty() else _event_ids.pop_back() if not _event_ids.is_empty() else uuid(),"name":name,"occurred_at":_session_clock_unix+elapsed/1000,"session_id":_session_id,"seq":_sequence,"monotonic_ms":elapsed,"properties":safe}
	var entry: Dictionary = {"scope":_scope,"build_id":_build_id,"platform":_platform,"clock_quality":_clock_quality,"event":event}
	queue.append(entry)
	_queue_budget_bytes += _entry_budget(entry)
	if _pending_since_msec < 0: _pending_since_msec = Time.get_ticks_msec()
	if name not in PASSIVE_NAMES and _journey_pending_msec < 0: _journey_pending_msec = Time.get_ticks_msec()
	while queue.size() > MAX_EVENTS or _queue_budget_bytes > MAX_QUEUE_BYTES-8192:
		_persisted_ids.erase(str(queue[0].event.id))
		_queue_budget_bytes -= _entry_budget(queue[0])
		queue.pop_front()
		dropped_events += 1
	_mark_dirty()
	return true

func _safe_properties(name: String, properties: Dictionary) -> Dictionary:
	if name in NETWORK_NAMES: return preload("res://backend/network_health.gd").normalize(name,properties)
	if name == "race_statistics": return _safe_race_statistics(properties)
	var allowed: Array[String] = []
	if name == "quality_summary": allowed = ["device_class","scene","samples","slow","b0","b1","b2","b3","b4","b5","b6","b7"]
	elif name == "process_exit": allowed = ["exit_reason","device_class"]
	elif name in ["track_exposed","track_selected","car_exposed","car_selected","race_attempt","race_started","race_finished","race_abandoned","race_retried"]:
		allowed = ["track_version_id","ticket_id","car_id","biome","mode","position"]
		if name in ["race_finished","race_abandoned","race_retried"]: allowed.append("reason")
	elif name == "publish_requested": allowed = ["biome","reason"]
	elif name in ["challenge_opened","challenge_joined","challenge_created","share_clicked"]: allowed = ["challenge_id","reason"]
	elif name in ["session_started","session_foregrounded"]: allowed = ["reason"]
	elif name in ["session_backgrounded","session_heartbeat"]: allowed = ["foreground_ms"]
	elif name == "collection_summary": allowed = ["dropped_events","rejected_events","persistence_failures"]
	elif name in ["offer_exposed","purchase_requested"]: allowed = ["product_id"]
	var safe: Dictionary = {}
	for key: String in properties:
		if key not in allowed: continue
		var value: Variant = properties[key]
		if name in QUALITY_NAMES:
			if key in QUALITY_NUMBERS and _bounded_integer(value,-5000 if key in ["cell_x","cell_y"] else 0,5000 if key in ["cell_x","cell_y"] else 1000000): safe[key] = int(value)
			elif key == "device_class" and value in ["android_arm64","android_other","desktop","other"]: safe[key] = value
			elif key == "scene" and value in ["menu","race","editor"]: safe[key] = value
			elif key == "track_version_id" and value is String and _uuid_pattern.search(value) != null: safe[key] = value
			continue
		if key in ["track_version_id","ticket_id","challenge_id"] and value is String and _uuid_pattern.search(value) != null: safe[key] = value
		elif key == "car_id" and value in ["compact","pickup","classic","formula","kart"]: safe[key] = value
		elif key == "mode" and value in ["free","rivalry","challenge","creator"]: safe[key] = value
		elif key == "biome" and value in ["pine","desert","night_city","winter","storm"]: safe[key] = value
		elif key == "reason" and value in ["launch","resume","inactivity","finished","restart","exit","background","unknown","save","publish","edit","test","open","join","create","share"]: safe[key] = value
		elif key == "product_id" and value in STORE_PRODUCTS: safe[key] = value
		elif key in NUMBER_PROPERTIES and (value is int or value is float) and is_finite(float(value)) and float(value) >= 0 and float(value) <= (1000 if key == "position" else 86400000 if key == "foreground_ms" else 1000000):
			safe[key] = int(value)
	return safe

static func _bounded_integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == int(value) and value >= minimum and value <= maximum

func _safe_race_statistics(properties: Dictionary) -> Dictionary:
	var required: Array[String] = ["schema_version","race_id","outcome","elapsed_ms","device_class","device_model","os_version","frame_buckets","cells","segments","position_samples","dropped_samples"]
	for key: String in required:
		if not properties.has(key): return {}
	if not _bounded_integer(properties.schema_version,2,3) or properties.outcome not in ["finished","abandoned","restarted"]: return {}
	if not properties.race_id is String or _uuid_pattern.search(properties.race_id) == null or properties.race_id.substr(14,1) != "4" or properties.race_id.substr(19,1).to_lower() not in ["8","9","a","b"]: return {}
	if properties.device_class not in ["android_arm64","android_other","desktop","other"]: return {}
	if not _bounded_integer(properties.elapsed_ms,0,3600000) or not _bounded_integer(properties.position_samples,0,3600) or not _bounded_integer(properties.dropped_samples,0,3600): return {}
	var safe: Dictionary = {"schema_version":int(properties.schema_version),"race_id":properties.race_id,"outcome":properties.outcome,"device_class":properties.device_class,"elapsed_ms":int(properties.elapsed_ms),"position_samples":int(properties.position_samples),"dropped_samples":int(properties.dropped_samples)}
	if properties.schema_version == 3:
		var context: Dictionary = preload("res://backend/race_render_context.gd").normalize(properties.get("render_context"))
		if context.is_empty() or not properties.get("render_context_changed") is bool: return {}
		safe.render_context = context
		safe.render_context_changed = properties.render_context_changed
	elif properties.has("render_context") or properties.has("render_context_changed"): return {}
	for key: String in ["device_model","os_version"]:
		if not properties[key] is String or properties[key].is_empty() or properties[key].length() > 80: return {}
		for index: int in range(properties[key].length()):
			if properties[key].unicode_at(index) < 32 or properties[key].unicode_at(index) == 127: return {}
		safe[key] = properties[key]
	for key: String in ["track_version_id","ticket_id"]:
		if properties.has(key):
			if not properties[key] is String or _uuid_pattern.search(properties[key]) == null: return {}
			safe[key] = properties[key]
	if not properties.frame_buckets is Array or properties.frame_buckets.size() != 8: return {}
	var buckets: Array = []; var frame_count: int = 0
	for count: Variant in properties.frame_buckets:
		if not _bounded_integer(count,0,1000000): return {}
		frame_count += int(count); buckets.append(int(count))
	if frame_count > 1000000: return {}
	safe.frame_buckets = buckets
	var sample_totals: Dictionary = {"cells":0,"segments":0}
	for key: String in ["cells","segments"]:
		var rows: Variant = properties[key]
		if not rows is Array or rows.size() > (128 if key == "cells" else 32): return {}
		var packed: Array = []; var seen: Dictionary = {}
		for row: Variant in rows:
			if not row is Array or row.size() != (4 if key == "cells" else 3): return {}
			if not _bounded_integer(row[0],-5000 if key == "cells" else 0,5000 if key == "cells" else 31): return {}
			if key == "cells" and not _bounded_integer(row[1],-5000,5000): return {}
			var count_index: int = 2 if key == "cells" else 1
			if not _bounded_integer(row[count_index],1,3600) or not _bounded_integer(row[count_index+1],0,int(row[count_index])): return {}
			var identity: String = str(int(row[0]))+"/"+str(int(row[1])) if key == "cells" else str(int(row[0]))
			if seen.has(identity): return {}
			seen[identity] = true
			var normalized: Array = []
			for value: Variant in row: normalized.append(int(value))
			packed.append(normalized); sample_totals[key] += int(row[count_index])
		safe[key] = packed
	if sample_totals.cells+safe.dropped_samples != safe.position_samples or sample_totals.segments != safe.position_samples: return {}
	if safe.position_samples > 0 and not safe.has("track_version_id"): return {}
	return safe

func set_transport_allowed(allowed: bool) -> void:
	if _allowed and not allowed and client != null and client.has_method("cancel_telemetry"): client.cancel_telemetry()
	_allowed = allowed

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		background(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		background()
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		foreground()

func background(_application_paused: bool = false) -> void:
	if _foreground:
		observe("session_backgrounded",{"foreground_ms":maxi(0,Time.get_ticks_msec()-_foreground_start_msec)})
		_foreground_start_msec = Time.get_ticks_msec()
		_foreground = false
		_background_msec = Time.get_ticks_msec()
	if client != null and client.has_method("cancel_telemetry"): client.cancel_telemetry()
	# Losing window focus does not suspend Windows race processing. Start a disk
	# worker only from a menu. Even application-pause keeps active capture in RAM.
	if _allowed:
		_finish_thread()
		_save_if_needed()

func foreground() -> void:
	if _foreground: return
	var now: int = Time.get_ticks_msec()
	_foreground = true
	if now-_background_msec >= SESSION_GAP_MSEC:
		_session_id = uuid()
		_sequence = 0
		_session_start_msec = now
		_anchor_clock()
		_deduplicated.clear()
		observe("session_started",{"reason":"inactivity"})
	_foreground_start_msec = now
	observe("session_foregrounded",{"reason":"resume"})

func pump() -> void:
	if not enabled or not _foreground: return
	observations_due.emit()
	if _foreground and Time.get_ticks_msec()-_heartbeat_msec >= FLUSH_INTERVAL_MSEC:
		_heartbeat_msec = Time.get_ticks_msec()
		if observe("session_heartbeat",{"foreground_ms":maxi(0,_heartbeat_msec-_foreground_start_msec)}): _foreground_start_msec = _heartbeat_msec
	if not enabled or not _allowed or not _foreground: return
	_finish_thread()
	if not _loaded: return
	if Time.get_ticks_msec() >= _next_prune_msec:
		_prune()
		_next_prune_msec = Time.get_ticks_msec()+FLUSH_INTERVAL_MSEC
	_report_losses()
	_collect_network()
	_save_if_needed()
	if _thread != null or _dirty or _uploading or Time.get_ticks_msec() < _next_upload_msec: return
	if client == null or not client.telemetry_supported() or client.auth_busy(): return
	if not _flush_due(): return
	var batch: Dictionary = batch_payload()
	if batch.events.is_empty(): return
	_upload.call_deferred(batch,_scope)

func _report_losses() -> void:
	var now: int = Time.get_ticks_msec()
	if now < _next_summary_msec: return
	var counters: String = str(dropped_events)+"/"+str(rejected_events)+"/"+str(persistence_failures)
	if counters == _reported_counters: return
	if observe("collection_summary",{"dropped_events":mini(1000000,dropped_events),"rejected_events":mini(1000000,rejected_events),"persistence_failures":mini(1000000,persistence_failures)}):
		_reported_counters = counters
		_next_summary_msec = now+IDLE_FLUSH_MSEC

func _network_supported() -> bool:
	return client != null and client.has_method("network_supported") and client.network_supported()

func _collect_network() -> void:
	if not _allowed or not _foreground or _scope == "guest" or not _network_supported(): return
	var monitor: RefCounted = client.get("network_health")
	if monitor == null: return
	for observation: Dictionary in monitor.pending(_scope):
		if _event_ids.is_empty(): return # Optional diagnostics never allocate live random IDs.
		if observe(str(observation.name),observation.properties): monitor.acknowledge(_scope,str(observation.name),observation.properties)

func _flush_due(now_msec: int = -1) -> bool:
	var count: int = 0
	for entry: Dictionary in queue:
		if entry.scope == _scope and _persisted_ids.has(str(entry.event.id)):
			if entry.event.name in NETWORK_NAMES and not _network_supported(): continue
			if entry.event.name == "race_statistics":
				if _package_supported(entry.event.properties): return true
				continue
			count += 1
			if count >= MAX_BATCH_EVENTS: return true
	if count == 0: return false
	var now: int = Time.get_ticks_msec() if now_msec < 0 else now_msec
	return (_journey_pending_msec >= 0 and now-_journey_pending_msec >= FLUSH_INTERVAL_MSEC) or (_pending_since_msec >= 0 and now-_pending_since_msec >= IDLE_FLUSH_MSEC)

func batch_payload() -> Dictionary:
	var events: Array[Dictionary] = []
	# The bounded ASCII envelope (including build ID) fits below 512 bytes.
	var bytes: int = 512
	var build: String = ""
	var platform: String = ""
	var quality: String = ""
	for entry: Dictionary in queue:
		if str(entry.scope) != _scope or not _persisted_ids.has(str(entry.event.id)): continue
		if entry.event.name in NETWORK_NAMES and not _network_supported(): continue
		if entry.event.name == "race_statistics" and not _package_supported(entry.event.properties): continue
		if build.is_empty():
			build = str(entry.build_id)
			platform = str(entry.platform)
			quality = str(entry.clock_quality)
		if entry.build_id != build or entry.platform != platform or entry.clock_quality != quality: continue
		var event_bytes: int = JSON.stringify(entry.event).to_utf8_buffer().size()+1
		if events.size() >= MAX_BATCH_EVENTS or bytes+event_bytes > MAX_BATCH_BYTES: break
		events.append(entry.event.duplicate(true))
		bytes += event_bytes
	var value: Dictionary = {"schema":SCHEMA,"purpose_policy":"bmt-product-telemetry-v1","build_id":build,"platform":platform,"clock_quality":quality,"batch_id":uuid(),"install_id":_install_id,"events":events}
	last_batch_bytes = JSON.stringify(value).to_utf8_buffer().size()
	return value

func _package_supported(properties: Dictionary) -> bool:
	if client == null or not client.quality_supported(): return false
	var version: int = client.quality_schema_version() if client.has_method("quality_schema_version") else 2
	return int(properties.get("schema_version",0)) in [2,3] and int(properties.schema_version) <= version

func _upload(batch: Dictionary, scope: String) -> void:
	if _uploading or not _allowed or not _foreground or scope != _scope: return
	_uploading = true
	var response: Dictionary = await client.request_telemetry(batch)
	_uploading = false
	_next_upload_msec = Time.get_ticks_msec()+_retry_delay_msec
	if not response.get("ok",false):
		_retry_delay_msec = mini(900000,_retry_delay_msec*2)
		return
	if response.get("data",{}).get("schema","") != "bmt-product-acks-v1": return
	_retry_delay_msec = FLUSH_INTERVAL_MSEC
	var sent: Dictionary = {}
	for event: Dictionary in batch.events: sent[str(event.id)] = true
	var acknowledged: Dictionary = {}
	for item: Variant in response.get("data",{}).get("events",[]):
		if not item is Dictionary or not sent.has(str(item.get("id",""))): continue
		if item.get("status","") in ["accepted","duplicate","rejected"]:
			acknowledged[str(item.id)] = true
			if item.status == "rejected": rejected_events += 1
	if acknowledged.is_empty(): return
	var kept: Array[Dictionary] = []
	for entry: Dictionary in queue:
		if str(entry.scope) == scope and acknowledged.has(str(entry.event.id)):
			_persisted_ids.erase(str(entry.event.id))
		else: kept.append(entry)
	queue = kept
	_recount_budget()
	_pending_since_msec = -1
	_journey_pending_msec = -1
	for entry: Dictionary in queue:
		if entry.scope != _scope: continue
		if _pending_since_msec < 0: _pending_since_msec = Time.get_ticks_msec()
		if entry.event.name not in PASSIVE_NAMES: _journey_pending_msec = Time.get_ticks_msec()
	_mark_dirty()

func _prune() -> void:
	var oldest: int = _session_clock_unix+maxi(0,Time.get_ticks_msec()-_session_start_msec)/1000-MAX_AGE_SECONDS
	var kept: Array[Dictionary] = []
	for entry: Dictionary in queue:
		if int(entry.event.get("occurred_at",0)) < oldest:
			_persisted_ids.erase(str(entry.event.id))
			dropped_events += 1
		else: kept.append(entry)
	if kept.size() != queue.size():
		queue = kept
		_recount_budget()
		_mark_dirty()

func _recount_budget() -> void:
	_queue_budget_bytes = 0
	for entry: Dictionary in queue: _queue_budget_bytes += _entry_budget(entry)

func _mark_dirty() -> void:
	_dirty = true
	_generation += 1

func _start_thread(kind: String, task: Callable) -> void:
	if _thread != null: return
	_thread = Thread.new()
	_thread_kind = kind
	if _thread.start(task) != OK:
		_thread = null
		persistence_failures += 1
		_next_save_msec = Time.get_ticks_msec()+_save_retry_msec
		if kind == "read": _loaded = true

func _save_if_needed() -> void:
	if _thread != null or not _loaded or not _dirty: return
	if Time.get_ticks_msec() < _next_save_msec: return
	if storage_path.is_empty(): return # Tests may explicitly exercise enqueue only.
	_save_generation = _generation
	# Event dictionaries are immutable after enqueue; copy only the outer list.
	var value: Dictionary = {"schema":SCHEMA,"install_id":_install_id,"process_exit_cursor":_process_exit_cursor,"first_open_scopes":_first_open_scopes.duplicate(),"queue":queue.duplicate(),"dropped_events":dropped_events,"rejected_events":rejected_events,"persistence_failures":persistence_failures}
	_start_thread("write",_write_measured.bind(storage_path,value,256 if _event_ids.size() < 128 else 0))

static func _write_measured(path: String, value: Dictionary, refill_count: int = 0) -> Dictionary:
	var start: int = Time.get_ticks_usec()
	return {"ok":Storage.write(path,value,MAX_QUEUE_BYTES),"usec":Time.get_ticks_usec()-start,"event_ids":uuid_pool(refill_count),"ids":value.queue.map(func(entry: Dictionary) -> String: return str(entry.event.id))}

static func _read_with_ids(path: String) -> Dictionary:
	return {"data":Storage.read(path,MAX_QUEUE_BYTES),"event_ids":uuid_pool(256)}

static func _saved_integer(value: Variant) -> int:
	return int(value) if (value is int or value is float) and is_finite(float(value)) and float(value) >= 0 and float(value) <= 4102444800 else 0

func _finish_thread(completed: Variant = null) -> void:
	if _thread == null or _thread.is_alive(): return
	var result: Variant = completed if completed != null else _thread.wait_to_finish()
	_thread = null
	if result is Dictionary and result.get("event_ids") is Array:
		for id: String in result.event_ids:
			if _event_ids.size() < 512: _event_ids.append(id)
	if _thread_kind == "read":
		result = result.get("data",{}) if result is Dictionary else {}
		_loaded = true
		if result is Dictionary and result.get("schema","") == SCHEMA:
			var exit_cursor: Variant = result.get("process_exit_cursor",0)
			if (exit_cursor is int or exit_cursor is float) and is_finite(float(exit_cursor)) and exit_cursor >= 0 and exit_cursor <= 4102444800000: _process_exit_cursor = int(exit_cursor)
			if _uuid_pattern.search(str(result.get("install_id",""))) != null: _install_id = str(result.install_id)
			var restored: Array[Dictionary] = []
			var saved_queue: Array = result.queue if result.get("queue") is Array else []
			for entry: Variant in saved_queue:
				if entry is Dictionary and _scope_pattern.search(str(entry.get("scope",""))) != null and _build_pattern.search(str(entry.get("build_id",""))) != null and entry.get("platform","") in ["android","windows","linux","ios"] and entry.get("clock_quality","") in ["server_estimate","client_clock"] and entry.get("event") is Dictionary and (entry.event.get("name","") in EVENT_NAMES or entry.event.get("name","") in QUALITY_NAMES or entry.event.get("name","") in NETWORK_NAMES) and _uuid_pattern.search(str(entry.event.get("id",""))) != null and _uuid_pattern.search(str(entry.event.get("session_id",""))) != null and entry.event.get("properties") is Dictionary:
					var original: Dictionary = entry.event
					entry.event = {"id":str(original.id),"name":str(original.name),"occurred_at":_saved_integer(original.get("occurred_at",0)),"session_id":str(original.session_id),"seq":_saved_integer(original.get("seq",0)),"monotonic_ms":_saved_integer(original.get("monotonic_ms",0)),"properties":_safe_properties(str(original.name),original.properties)}
					if (original.name == "race_statistics" or original.name in NETWORK_NAMES) and entry.event.properties.is_empty(): continue
					restored.append(entry)
					_persisted_ids[str(entry.event.id)] = true
					if restored.size() >= MAX_EVENTS: break
			restored.append_array(queue)
			queue = restored
			dropped_events += _saved_integer(result.get("dropped_events",0))
			rejected_events += _saved_integer(result.get("rejected_events",0))
			persistence_failures += _saved_integer(result.get("persistence_failures",0))
			var scopes: Dictionary = result.first_open_scopes if result.get("first_open_scopes") is Dictionary else {}
			for scope: String in scopes:
				if _scope_pattern.search(scope) != null and scopes[scope] == true: _first_open_scopes[scope] = true
				if _first_open_scopes.size() >= 32: break
		elif result is Dictionary and result.get("_read_error",false): persistence_failures += 1
		var kept: Array[Dictionary] = []
		for entry: Dictionary in queue:
			if str(entry.event.id) == str(_provisional_first_opens.get(str(entry.scope),"")):
				if _first_open_scopes.has(str(entry.scope)): continue
				_first_open_scopes[str(entry.scope)] = true
			kept.append(entry)
		queue = kept
		_recount_budget()
		_provisional_first_opens.clear()
		_record_first_open()
		while queue.size() > MAX_EVENTS or _queue_budget_bytes > MAX_QUEUE_BYTES-8192:
			_persisted_ids.erase(str(queue[0].event.id))
			_queue_budget_bytes -= _entry_budget(queue[0])
			queue.pop_front()
			dropped_events += 1
		_mark_dirty()
	elif _thread_kind == "write":
		if result is Dictionary and result.get("ok",false):
			_saved_generation = _save_generation
			last_save_usec = int(result.usec)
			for id: String in result.ids: _persisted_ids[id] = true
			_dirty = _generation != _saved_generation
			_save_retry_msec = 5000
			_next_save_msec = 0
		else:
			persistence_failures += 1
			_next_save_msec = Time.get_ticks_msec()+_save_retry_msec
			_save_retry_msec = mini(300000,_save_retry_msec*2)

func _exit_tree() -> void:
	# Join only an existing bounded worker; do not perform synchronous queue IO.
	if _thread != null and _thread.is_started(): _thread.wait_to_finish()
