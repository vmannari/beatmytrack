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
const EVENT_NAMES: Array[String] = ["app_first_open","session_started","session_foregrounded","session_backgrounded","session_heartbeat","collection_summary","menu_ready","track_exposed","track_selected","car_exposed","car_selected","race_attempt","race_started","race_finished","race_abandoned","race_retried","editor_opened","draft_saved","publish_requested","challenge_opened","challenge_joined","challenge_created","share_clicked","store_opened","offer_exposed","purchase_requested"]
const STORE_PRODUCTS: Array[String] = ["creator_slot_1","creator_slots_5","creator_slots_10","ad_free_month","ad_free_forever"]
const NUMBER_PROPERTIES: Array[String] = ["foreground_ms","position","dropped_events","rejected_events","persistence_failures"]
var client: Node
var storage_path: String = ""
var enabled: bool = true
var queue: Array[Dictionary] = []
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
var _build_id: String = str(ProjectSettings.get_setting("application/config/version","local"))
var _platform: String = OS.get_name().to_lower()
var _build_pattern: RegEx = RegEx.create_from_string("^[A-Za-z0-9._:-]{1,80}$")
var _scope_pattern: RegEx = RegEx.create_from_string("^[a-f0-9]{64}$")
var _next_summary_msec: int = 0
var _reported_counters: String = "0/0/0"
var _event_ids: Array[String] = uuid_pool(128)
var _provisional_first_opens: Dictionary = {}
var _collection_started_scope: String = ""
var _process_exit_cursor: int = 0
const QUALITY_NAMES: Array[String] = ["quality_summary","segment_summary","process_exit"]
const PASSIVE_NAMES: Array[String] = ["session_heartbeat","quality_summary","segment_summary","process_exit"]
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
	if storage_path.is_empty():
		_loaded = true
	else:
		_start_thread("read",_read_with_ids.bind(storage_path))
	update_identity()

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
	if name in QUALITY_NAMES and (client == null or not client.has_method("quality_supported") or not client.quality_supported()): return false
	if name in QUALITY_NAMES and not _allowed and _event_ids.size() <= 32: return false # Reserve identifiers for product/race observations.
	if not enabled or not _foreground or (name not in EVENT_NAMES and name not in QUALITY_NAMES) or client == null or not client.telemetry_supported() or _scope == "guest": return false
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
	# Fixed 7 ASCII identifiers + 2 integers plus envelope stays below 1.5 KiB/event.
	# The count cap therefore bounds the 2 MiB queue without serializing each event.
	_sequence += 1
	var elapsed: int = maxi(0,Time.get_ticks_msec()-_session_start_msec)
	var event: Dictionary = {"id":_event_ids.pop_back() if not _event_ids.is_empty() else uuid(),"name":name,"occurred_at":_session_clock_unix+elapsed/1000,"session_id":_session_id,"seq":_sequence,"monotonic_ms":elapsed,"properties":safe}
	queue.append({"scope":_scope,"build_id":_build_id,"platform":_platform,"clock_quality":_clock_quality,"event":event})
	if _pending_since_msec < 0: _pending_since_msec = Time.get_ticks_msec()
	if name not in PASSIVE_NAMES and _journey_pending_msec < 0: _journey_pending_msec = Time.get_ticks_msec()
	while queue.size() > MAX_EVENTS:
		_persisted_ids.erase(str(queue[0].event.id))
		queue.pop_front()
		dropped_events += 1
	_mark_dirty()
	return true

func _safe_properties(name: String, properties: Dictionary) -> Dictionary:
	var allowed: Array[String] = []
	if name == "quality_summary": allowed = ["device_class","scene","samples","slow","b0","b1","b2","b3","b4","b5","b6","b7"]
	elif name == "segment_summary": allowed = ["track_version_id","segment","cell_x","cell_y","samples","slow"]
	elif name == "process_exit": allowed = ["exit_reason","device_class"]
	elif name in ["track_exposed","track_selected","car_exposed","car_selected","race_attempt","race_started","race_finished","race_abandoned","race_retried"]:
		allowed = ["track_version_id","ticket_id","car_id","biome","mode","position"]
		if name in ["race_finished","race_abandoned","race_retried"]: allowed.append("reason")
	elif name in ["editor_opened","draft_saved","publish_requested"]: allowed = ["biome","reason"]
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
			if key in QUALITY_NUMBERS and value is int and value >= (-5000 if key in ["cell_x","cell_y"] else 0) and value <= (5000 if key in ["cell_x","cell_y"] else 1000000): safe[key] = value
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

func background(application_paused: bool = false) -> void:
	if _foreground:
		observe("session_backgrounded",{"foreground_ms":maxi(0,Time.get_ticks_msec()-_foreground_start_msec)})
		_foreground_start_msec = Time.get_ticks_msec()
		_foreground = false
		_background_msec = Time.get_ticks_msec()
	if client != null and client.has_method("cancel_telemetry"): client.cancel_telemetry()
	# Losing window focus does not suspend Windows race processing. Start a disk
	# worker only from a menu or an explicit application-pause notification.
	if _allowed or application_paused:
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

func _flush_due(now_msec: int = -1) -> bool:
	var count: int = 0
	for entry: Dictionary in queue:
		if entry.scope == _scope and _persisted_ids.has(str(entry.event.id)):
			count += 1
			if count >= MAX_BATCH_EVENTS: return true
	if count == 0: return false
	var now: int = Time.get_ticks_msec() if now_msec < 0 else now_msec
	return (_journey_pending_msec >= 0 and now-_journey_pending_msec >= FLUSH_INTERVAL_MSEC) or (_pending_since_msec >= 0 and now-_pending_since_msec >= IDLE_FLUSH_MSEC)

func batch_payload() -> Dictionary:
	var events: Array[Dictionary] = []
	var bytes: int = 128
	var build: String = ""
	var platform: String = ""
	var quality: String = ""
	for entry: Dictionary in queue:
		if str(entry.scope) != _scope or not _persisted_ids.has(str(entry.event.id)): continue
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
		_mark_dirty()

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

func _finish_thread() -> void:
	if _thread == null or _thread.is_alive(): return
	var result: Variant = _thread.wait_to_finish()
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
				if entry is Dictionary and _scope_pattern.search(str(entry.get("scope",""))) != null and _build_pattern.search(str(entry.get("build_id",""))) != null and entry.get("platform","") in ["android","windows","linux","ios"] and entry.get("clock_quality","") in ["server_estimate","client_clock"] and entry.get("event") is Dictionary and (entry.event.get("name","") in EVENT_NAMES or entry.event.get("name","") in QUALITY_NAMES) and _uuid_pattern.search(str(entry.event.get("id",""))) != null and _uuid_pattern.search(str(entry.event.get("session_id",""))) != null and entry.event.get("properties") is Dictionary:
					var original: Dictionary = entry.event
					entry.event = {"id":str(original.id),"name":str(original.name),"occurred_at":_saved_integer(original.get("occurred_at",0)),"session_id":str(original.session_id),"seq":_saved_integer(original.get("seq",0)),"monotonic_ms":_saved_integer(original.get("monotonic_ms",0)),"properties":_safe_properties(str(original.name),original.properties)}
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
		_provisional_first_opens.clear()
		_record_first_open()
		while queue.size() > MAX_EVENTS:
			_persisted_ids.erase(str(queue[0].event.id))
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
