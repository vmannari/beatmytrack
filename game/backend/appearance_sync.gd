extends Node
## Account-owned garage sync. Acknowledgements and pending edits survive restart.
signal changed
const State = preload("res://persistence/appearance_state.gd")
var records: LocalRecords
var client: Node
var busy: bool = false
var status: String = ""
var _scope: String = ""
var _epoch: int = 0
var _applying: bool = false
var _debounce: Timer
var _poll: Timer
var refresh_allowed: Callable
var _last_success_msec: int = -1
var _rejected: Dictionary = {}
var _retry_failures: int = 0

func _fingerprint(local: Dictionary, previous: Variant) -> String:
	var contract: String = str(client.appearance_contract()) if client.has_method("appearance_contract") else ""
	return JSON.stringify({"appearance":local,"previous":previous,"contract":contract}).sha256_text()

func _blocked(id: String, local: Dictionary, previous: Variant) -> bool:
	return _rejected.get(id,"") == _fingerprint(local,previous)

func _reset_backoff() -> void:
	_retry_failures = 0
	if is_instance_valid(_poll): _poll.wait_time = 30.0

func _retry_later() -> void:
	_retry_failures = mini(_retry_failures+1,4)
	_poll.start(minf(300.0,30.0*pow(2.0,_retry_failures)))

func _ready() -> void:
	_debounce = Timer.new()
	_debounce.one_shot = true
	_debounce.wait_time = 0.75
	_debounce.timeout.connect(refresh)
	add_child(_debounce)
	_poll = Timer.new()
	_poll.wait_time = 30.0
	_poll.timeout.connect(_poll_refresh)
	add_child(_poll)
	_poll.start()

func scope() -> String:
	return client.base_url()+"/"+str(client.player.get("id","")) if client != null and client.signed_in() else ""

func bind_records(value: LocalRecords) -> void:
	var next: String = scope()
	if records == value and _scope == next: return
	if records != null and records.appearance_committed.is_connected(_committed): records.appearance_committed.disconnect(_committed)
	records = value
	_scope = next
	_epoch += 1
	busy = false
	status = ""
	_last_success_msec = -1
	_rejected = records.settings.get(State.KEY,{}).get("rejected",{}).duplicate() if records != null else {}
	_reset_backoff()
	if records != null: records.appearance_committed.connect(_committed)
	if is_instance_valid(_debounce): _debounce.stop()
	if is_instance_valid(_poll):
		if not _scope.is_empty() and _needs_recovery(): _poll.start()
		else: _poll.stop()

func _committed() -> void:
	if not _applying and not scope().is_empty() and _scope == scope():
		_reset_backoff()
		_debounce.start()
		_poll.start()

func _needs_recovery() -> bool:
	if records == null: return false
	if not records.settings.has(State.KEY): return true
	var base: Dictionary = State.baseline(records.settings)
	var pending: Dictionary = State.pending(records.settings)
	for id: String in VehicleCatalog.IDS:
		var local: Dictionary = State.car(records.settings,id)
		if (pending.has(id) or (State.authored(records.settings,id) and local != base.get(id))) and not _blocked(id,local,base.get(id)): return true
	return false

func _poll_refresh() -> void:
	# An unchanged local baseline gives no reason to fetch every 30 seconds.
	# A visible consumer/foreground return can explicitly request freshness.
	if not _needs_recovery():
		_poll.stop()
		return
	refresh()

func refresh_if_stale() -> void:
	if _last_success_msec < 0 or Time.get_ticks_msec()-_last_success_msec >= 30000 or _needs_recovery(): refresh()

func _current(epoch: int, owner: LocalRecords) -> bool:
	return epoch == _epoch and records == owner and not _scope.is_empty() and _scope == scope()

func _save(base: Dictionary, value: Dictionary = {}, pending: Dictionary = {}) -> bool:
	# A colour/part edit made while HTTP was in flight remains pending.
	_applying = true
	if not value.is_empty(): State.apply(records.settings,value)
	records.settings[State.KEY] = {"version":1,"baseline":base.duplicate(true),"pending":pending.duplicate(true)}
	if not _rejected.is_empty(): records.settings[State.KEY].rejected = _rejected.duplicate()
	var error: Error = records.save_records()
	_applying = false
	if error != OK: status = "Garage changes could not be saved. Check storage."
	return error == OK

func refresh() -> void:
	if records == null or busy or _scope.is_empty() or scope() != _scope: return
	if refresh_allowed.is_valid() and not bool(refresh_allowed.call()): return
	if _poll.is_stopped(): _poll.start()
	var epoch: int = _epoch
	var owner: LocalRecords = records
	busy = true
	var response: Dictionary = await client.request_api("/me/appearances",HTTPClient.METHOD_GET,{},"",true)
	if not _current(epoch,owner): return
	if refresh_allowed.is_valid() and not bool(refresh_allowed.call()):
		busy = false
		return
	if not response.get("ok",false) or not State.valid_collection(response.get("data",{}).get("appearances")):
		status = "Garage sync needs a server update." if response.get("status",0) == 404 else "Garage changes saved on this device. Sync will retry."
		busy = false
		if _needs_recovery(): _retry_later()
		else: _poll.stop()
		changed.emit()
		return
	status = ""
	var remote: Dictionary = State.normalized_collection(response.data.appearances)
	var initialized: bool = records.settings.has(State.KEY)
	var base: Dictionary = State.baseline(records.settings)
	var pending: Dictionary = State.pending(records.settings)
	for id: String in VehicleCatalog.IDS:
		if refresh_allowed.is_valid() and not bool(refresh_allowed.call()): break
		var local: Dictionary = State.car(records.settings,id)
		var previous: Variant = base.get(id)
		var server: Variant = remote.get(id)
		# A lost reply can precede a second local edit. A durable attempted value
		# identifies our own accepted write without discarding that newer edit.
		if pending.has(id) and server == pending[id]:
			_rejected.erase(id)
			base[id] = server.duplicate(true)
			previous = base[id]
			pending.erase(id)
			if not _save(base,{},pending): break
		var dirty: bool = State.authored(records.settings,id) and (previous == null or local != previous)
		# On first adoption an existing online car is authoritative. On later
		# conflicts the accepted online edit wins; untouched cars never upload.
		if server != null and (not initialized or not dirty or server != previous):
			if previous != server or local != server:
				_rejected.erase(id)
				base[id] = server.duplicate(true)
				pending.erase(id)
				if not _save(base,server,pending): break
			continue
		if not dirty:
			if pending.has(id):
				_rejected.erase(id)
				pending.erase(id)
				if not _save(base,{},pending): break
			continue
		if _blocked(id,local,previous):
			status = "Garage changes saved on this device. This design could not be synced."
			continue
		var operation: Dictionary = {"appearance":local.duplicate(true),"previous":previous}
		pending[id] = local.duplicate(true)
		if not _save(base,{},pending): break
		response = await client.request_api("/me/appearances",HTTPClient.METHOD_PUT,operation,"",true)
		if not _current(epoch,owner): return
		if response.get("ok",false) and State.valid_car(response.get("data")) and State.normalized_car(response.data) == local:
			_rejected.erase(id)
			base[id] = local.duplicate(true)
			pending.erase(id)
			if not _save(base,{},pending): break
		elif int(response.get("status",0)) == 409:
			# Re-read before any further attempt; never rebase an old write blindly.
			status = "Garage changed on another device. Refreshing."
			_debounce.start()
			break
		elif int(response.get("status",0)) == 422:
			_rejected[id] = _fingerprint(local,previous)
			status = "Garage changes saved on this device. This design could not be synced."
			if not _save(base,{},pending): break
			continue
		elif response.get("error","") == "COSMETIC_NOT_OWNED":
			status = "This design includes items not owned by this account."
			_retry_later()
			continue
		else:
			status = "Garage changes saved on this device. Sync will retry."
			_retry_later()
			break
	if status.is_empty() and not records.settings.has(State.KEY): _save(base,{},pending)
	busy = false
	if status.is_empty():
		_reset_backoff()
		_last_success_msec = Time.get_ticks_msec()
		for id: String in VehicleCatalog.IDS:
			if State.authored(records.settings,id) and State.car(records.settings,id) != base.get(id):
				_debounce.start()
				break
	if not _needs_recovery(): _poll.stop()
	changed.emit()
