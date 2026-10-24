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

func _ready() -> void:
	_debounce = Timer.new()
	_debounce.one_shot = true
	_debounce.wait_time = 0.75
	_debounce.timeout.connect(refresh)
	add_child(_debounce)
	_poll = Timer.new()
	_poll.wait_time = 30.0
	_poll.timeout.connect(refresh)
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
	if records != null: records.appearance_committed.connect(_committed)
	if is_instance_valid(_debounce): _debounce.stop()

func _committed() -> void:
	if not _applying and not scope().is_empty() and _scope == scope(): _debounce.start()

func _current(epoch: int, owner: LocalRecords) -> bool:
	return epoch == _epoch and records == owner and not _scope.is_empty() and _scope == scope()

func _save(base: Dictionary, value: Dictionary = {}, pending: Dictionary = {}) -> bool:
	# A colour/part edit made while HTTP was in flight remains pending.
	_applying = true
	if not value.is_empty(): State.apply(records.settings,value)
	records.settings[State.KEY] = {"version":1,"baseline":base.duplicate(true),"pending":pending.duplicate(true)}
	var error: Error = records.save_records()
	_applying = false
	if error != OK: status = "Garage changes could not be saved. Check storage."
	return error == OK

func refresh() -> void:
	if records == null or busy or _scope.is_empty() or scope() != _scope: return
	var epoch: int = _epoch
	var owner: LocalRecords = records
	busy = true
	var response: Dictionary = await client.request_api("/me/appearances",HTTPClient.METHOD_GET,{},"",true)
	if not _current(epoch,owner): return
	if not response.get("ok",false) or not State.valid_collection(response.get("data",{}).get("appearances")):
		status = "Garage sync needs a server update." if response.get("status",0) == 404 else "Garage changes saved on this device. Sync will retry."
		busy = false
		changed.emit()
		return
	status = ""
	var remote: Dictionary = State.normalized_collection(response.data.appearances)
	var initialized: bool = records.settings.has(State.KEY)
	var base: Dictionary = State.baseline(records.settings)
	var pending: Dictionary = State.pending(records.settings)
	for id: String in VehicleCatalog.IDS:
		var local: Dictionary = State.car(records.settings,id)
		var previous: Variant = base.get(id)
		var server: Variant = remote.get(id)
		# A lost reply can precede a second local edit. A durable attempted value
		# identifies our own accepted write without discarding that newer edit.
		if pending.has(id) and server == pending[id]:
			base[id] = server.duplicate(true)
			previous = base[id]
			pending.erase(id)
			if not _save(base,{},pending): break
		var dirty: bool = State.authored(records.settings,id) and (previous == null or local != previous)
		# On first adoption an existing online car is authoritative. On later
		# conflicts the accepted online edit wins; untouched cars never upload.
		if server != null and (not initialized or not dirty or server != previous):
			if previous != server or local != server:
				base[id] = server.duplicate(true)
				pending.erase(id)
				if not _save(base,server,pending): break
			continue
		if not dirty:
			if pending.has(id):
				pending.erase(id)
				if not _save(base,{},pending): break
			continue
		var operation: Dictionary = {"appearance":local.duplicate(true),"previous":previous}
		pending[id] = local.duplicate(true)
		if not _save(base,{},pending): break
		response = await client.request_api("/me/appearances",HTTPClient.METHOD_PUT,operation,"",true)
		if not _current(epoch,owner): return
		if response.get("ok",false) and State.valid_car(response.get("data")) and State.normalized_car(response.data) == local:
			base[id] = local.duplicate(true)
			pending.erase(id)
			if not _save(base,{},pending): break
		elif int(response.get("status",0)) == 409:
			# Re-read before any further attempt; never rebase an old write blindly.
			status = "Garage changed on another device. Refreshing."
			_debounce.start()
			break
		else:
			status = "Garage changes saved on this device. Sync will retry."
			break
	if status.is_empty() and not records.settings.has(State.KEY): _save(base,{},pending)
	busy = false
	if status.is_empty():
		for id: String in VehicleCatalog.IDS:
			if State.authored(records.settings,id) and State.car(records.settings,id) != base.get(id):
				_debounce.start()
				break
	changed.emit()
