extends RefCounted
## Bounded presentation cache. Tickets and verified results remain authoritative.
const IO = preload("res://backend/atomic_json.gd")
const WRITER = preload("res://backend/menu_snapshot_writer.gd")
const SCHEMA: String = "menu-snapshots-v1"
const MAX_BYTES: int = 2097152
var path: String = ""
var scope: String = ""
var entries: Dictionary = {}
var max_entries: int = 32
var max_age_seconds: int = 600
var _last_write_requested: int = 0

func configure(destination: String, identity: String) -> void:
	if destination == path and identity == scope: return
	path = destination
	scope = identity
	# A queued old-scope snapshot owns its previous dictionary until dispatch.
	entries = {}
	_last_write_requested = 0
	if path.is_empty() or scope.is_empty(): return
	var saved: Dictionary = WRITER.peek(path,scope)
	if saved.is_empty(): saved = IO.read(path,MAX_BYTES)
	if saved.get("schema","") == SCHEMA and saved.get("scope","") == scope and saved.get("entries") is Dictionary:
		entries = saved.entries
		while entries.size() > max_entries: entries.erase(entries.keys()[0])

func read(key: String) -> Dictionary:
	var saved: Variant = entries.get(key,{})
	if not saved is Dictionary or not saved.get("data") is Dictionary: return {}
	if not (saved.get("saved_at") is int or saved.get("saved_at") is float): return {}
	var age: int = int(Time.get_unix_time_from_system())-int(saved.get("saved_at",0))
	if age < 0 or age >= max_age_seconds: return {}
	return saved.data.duplicate(true)

func remember(key: String, value: Dictionary) -> void:
	if path.is_empty() or scope.is_empty(): return
	var now: int = int(Time.get_unix_time_from_system())
	var previous: Variant = entries.get(key)
	if previous is Dictionary and previous.get("saved_at",0) == now and previous.get("data") == value: return
	var unchanged: bool = previous is Dictionary and previous.get("data") == value
	entries.erase(key)
	entries[key] = {"saved_at":now,"data":previous.data if unchanged else value.duplicate(true)}
	while entries.size() > max_entries: entries.erase(entries.keys()[0])
	# Preserve immediate RAM freshness. Identical data only needs a bounded
	# timestamp checkpoint on disk; new data/removals still queue immediately.
	if unchanged and now >= _last_write_requested and now-_last_write_requested < mini(60,maxi(1,max_age_seconds/2)): return
	_save()

func forget(key: String) -> void:
	if not entries.has(key): return
	entries.erase(key)
	_save()

func _save() -> void:
	if not path.is_empty():
		_last_write_requested = int(Time.get_unix_time_from_system())
		WRITER.queue(path,{"schema":SCHEMA,"scope":scope,"entries":entries})
