extends Node
## Scoped achievement reads and commit-driven notifications; no polling timer.
signal changed
signal unlocked(item: Dictionary)
const IO = preload("res://backend/atomic_json.gd")
var client: Node
var records: LocalRecords:
	set(value):
		if records == value: return
		if records != null and records.achievement_progress_committed.is_connected(_local_committed):
			records.achievement_progress_committed.disconnect(_local_committed)
		records = value
		if records != null: records.achievement_progress_committed.connect(_local_committed)
		_seed_known()
var directory: String = "user://achievement_cache"
var snapshot: Dictionary = {}
var scope: String = ""
var status: String = ""
var busy: bool = false
var _epoch: int = 0
var _read_at: int = -60000
var _attempt_at: int = -60000
var _known: Dictionary = {}
var _remote_seeded: bool = false
var _activity_pending: bool = false
var _activity_timer: SceneTreeTimer

func authenticated() -> bool:
	return client != null and client.signed_in()

func _scope() -> String:
	return str(client.base_url())+"/"+str(client.player.get("id","")) if authenticated() else "guest"

func sync_identity() -> void:
	var next: String = _scope()
	if next == scope: return
	scope = next
	_epoch += 1
	busy = false
	snapshot = {}
	_read_at = -60000
	_attempt_at = -60000
	status = ""
	_activity_pending = false
	if authenticated():
		var cached: Dictionary = IO.read(directory.path_join(scope.sha256_text()+".json"),131072)
		if valid(cached): snapshot = cached
	_remote_seeded = not snapshot.is_empty()
	_seed_known()
	changed.emit()

func _seed_known() -> void:
	_known.clear()
	for family: Dictionary in AchievementProgress.catalog().families:
		for key: String in source(family).get("unlocked",{}):
			if key.begins_with(str(family.id)+"/"): _known[key] = true

func _observe_unlocks() -> void:
	for family: Dictionary in AchievementProgress.catalog().families:
		var highest: int = 0
		var state: Dictionary = source(family)
		for i: int in range(family.tiers.size()):
			var key: String = str(family.id)+"/"+str(i+1)
			if state.get("unlocked",{}).has(key) and not _known.has(key):
				_known[key] = true
				highest = i+1
		if highest > 0:
			unlocked.emit({"scope":scope,"family":str(family.id),"tier":highest})

func _local_committed() -> void:
	if scope != _scope():
		sync_identity()
		return
	_observe_unlocks()
	changed.emit()

func refresh_after_activity() -> void:
	sync_identity()
	if not authenticated(): return
	_activity_pending = true
	if busy or _activity_timer != null: return
	# Coalesce receipts from one flush, without periodic collection reads.
	_activity_timer = get_tree().create_timer(maxf(0.35,1.0-(Time.get_ticks_msec()-_attempt_at)/1000.0))
	_activity_timer.timeout.connect(_refresh_activity)

func _refresh_activity() -> void:
	_activity_timer = null
	if not _activity_pending: return
	if busy: return # The in-flight operation schedules the retained activity.
	_activity_pending = false
	refresh(true)

func valid(data: Variant) -> bool:
	if not data is Dictionary or data.get("schema") != 1 or not data.get("states") is Dictionary: return false
	if data.states.size() > 2 or not data.get("rarity") is Dictionary: return false
	for key: Variant in data.states:
		if key not in ["race","creator"] or not AchievementProgress.valid(data.states[key]): return false
	var rarity: Dictionary = data.rarity
	if not AchievementProgress.whole(rarity.get("eligible")) or rarity.get("minimum") != 100 or not rarity.get("unlocks") is Dictionary or rarity.unlocks.size() > 122: return false
	for key: Variant in rarity.unlocks:
		if not key is String or key.length() > 64 or not AchievementProgress.whole(rarity.unlocks[key]) or rarity.unlocks[key] > rarity.eligible: return false
	return true

func refresh(activity: bool = false) -> void:
	sync_identity()
	if not authenticated() or busy or (not activity and Time.get_ticks_msec()-_attempt_at < 60000): return
	var expected: String = scope
	var epoch: int = _epoch
	_attempt_at = Time.get_ticks_msec()
	busy = true
	changed.emit()
	var response: Dictionary = await client.request_api("/achievements",HTTPClient.METHOD_GET,{},"",true)
	if expected != _scope() or epoch != _epoch: return
	busy = false
	if response.ok and valid(response.data):
		snapshot = response.data.duplicate(true)
		if _remote_seeded:
			_observe_unlocks()
		else:
			# A first collection is history, not a burst of newly earned awards.
			_remote_seeded = true
			_seed_known()
		_read_at = Time.get_ticks_msec()
		status = ""
		if not IO.write(directory.path_join(scope.sha256_text()+".json"),snapshot,131072): status = "Progress is online; the offline copy could not be saved."
	else:
		status = "The achievement service needs an update." if response.get("status",0) == 404 else "Offline · showing saved achievements."
	changed.emit()
	if _activity_pending: refresh_after_activity()

func source(family: Dictionary) -> Dictionary:
	if family.scope == "local": return AchievementProgress.read(records)
	if not authenticated():
		return AchievementProgress.read(records) if family.scope == "race" and family.category not in ["Rivalry","Social"] else AchievementProgress.empty()
	return snapshot.get("states",{}).get(family.scope,AchievementProgress.empty())

func featured() -> Array:
	var selected: Array = []
	if authenticated(): selected = snapshot.get("states",{}).get("race",{}).get("featured",[]).duplicate()
	for id: String in AchievementProgress.read(records).featured:
		if id not in selected and (not authenticated() or _local(id)): selected.append(id)
	return selected.slice(0,5)

func _local(id: String) -> bool:
	for f: Dictionary in AchievementProgress.catalog().families:
		if f.id == id: return f.scope == "local"
	return false

func toggle_feature(id: String) -> void:
	if busy: return
	var selected: Array = featured()
	if id in selected: selected.erase(id)
	elif selected.size() < 5: selected.append(id)
	else:
		status = "Choose up to five featured achievements."
		changed.emit()
		return
	if authenticated():
		var remote: Array = []
		for item: String in selected:
			if not _local(item): remote.append(item)
		var expected: String = _scope()
		var epoch: int = _epoch
		busy = true
		var response: Dictionary = await client.request_api("/achievements/featured",HTTPClient.METHOD_PUT,{"families":remote},"",true)
		if expected != _scope() or epoch != _epoch: return
		busy = false
		if not response.ok:
			status = "Could not save featured achievements. Reconnect and try again."
			changed.emit()
			if _activity_pending: refresh_after_activity()
			return
		if not snapshot.has("states"): snapshot.states = {}
		if not snapshot.states.has("race"): snapshot.states.race = AchievementProgress.empty()
		snapshot.states.race.featured = remote
		IO.write(directory.path_join(scope.sha256_text()+".json"),snapshot,131072)
	var local: Dictionary = AchievementProgress.read(records)
	local.featured = selected
	records.settings.achievements = local
	status = "" if records.save_records() == OK else "Could not save profile display. Check storage."
	changed.emit()
	if _activity_pending: refresh_after_activity()

func erase_account(origin: String, player_id: String) -> bool:
	var path: String = directory.path_join((origin+"/"+player_id).sha256_text()+".json")
	var ok: bool = true
	for suffix: String in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix) and DirAccess.remove_absolute(path+suffix) != OK: ok = false
	return ok
