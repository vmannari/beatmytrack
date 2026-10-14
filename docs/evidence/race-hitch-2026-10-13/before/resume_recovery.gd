extends Node
## Durable small operations; never replay a charge while recovering an abandoned race.
var client: Node
var root_override: String = ""
var active: Dictionary = {}
var busy: bool = false
var _next_msec: int = 0
var _serial: int = 0
var _deadlines: Dictionary = {}
var _cursor: Dictionary = {}
var _resolved: Dictionary = {}
const Files = preload("res://backend/atomic_json.gd")
const REQUEST_INTERVAL_SECONDS: int = 5
const MAX_INSPECTED: int = 64

func _directory(owner: String, origin: String) -> String:
	var base: String = root_override if not root_override.is_empty() else client.session_path.get_base_dir().path_join("resume_recovery") if not client.session_path.is_empty() else "user://resume_recovery"
	return base.path_join(origin.sha256_text()).path_join(owner.sha256_text())

func register_race(key: String) -> void:
	active[key] = true

func leave_race(key: String) -> void:
	active.erase(key)
	_next_msec = 0

func save(entry: Dictionary) -> bool:
	if str(entry.get("owner","")).is_empty() or str(entry.get("origin","")).is_empty() or _request_body(entry).is_empty(): return false
	var path: String = _directory(str(entry.owner),str(entry.origin)).path_join(str(entry.consume_key).sha256_text()+".json")
	return Files.write(path,entry,32768)

func discard(entry: Dictionary) -> void:
	if not entry.has_all(["owner","origin","consume_key"]): return
	DirAccess.remove_absolute(_directory(str(entry.owner),str(entry.origin)).path_join(str(entry.consume_key).sha256_text()+".json"))

func _process(_delta: float) -> void:
	if not busy and Time.get_ticks_msec() >= _next_msec:
		_next_msec = Time.get_ticks_msec()+5000+int(Crypto.new().generate_random_bytes(1)[0])*10
		reconcile()

func reconcile() -> void:
	if busy or not client.signed_in() or not bool(client._capabilities.get("resume_recovery",false)): return
	busy = true
	var owner: String = str(client.player.get("id",""))
	var origin: String = str(client.base_url())
	var directory: String = _directory(owner,origin)
	if not _ready_scope(directory):
		busy = false
		return
	var filenames: PackedStringArray = DirAccess.get_files_at(directory) if DirAccess.dir_exists_absolute(directory) else PackedStringArray()
	var start: int = int(_cursor.get(directory,0)) % maxi(1,filenames.size())
	for offset: int in range(mini(MAX_INSPECTED,filenames.size())):
		var index: int = (start+offset) % filenames.size()
		_cursor[directory] = index+1
		var filename: String = filenames[index]
		if not filename.ends_with(".json") or filename.begins_with("."): continue
		var path: String = directory.path_join(filename)
		var entry: Dictionary = Files.read(path,32768)
		if entry.has("_read_error") or str(entry.get("owner","")) != owner or str(entry.get("origin","")) != origin or not entry.get("selection") is Dictionary: continue
		if entry.get("recovery_resolved",false) or _resolved.has(path):
			DirAccess.remove_absolute(path)
			continue
		if entry.has("recovery_failure"): continue
		var key: String = str(entry.get("begin_key",""))
		if filename != str(entry.get("consume_key","")).sha256_text()+".json": continue
		var confirming: bool = entry.get("stage","pending") == "confirm"
		if active.has(key) and not confirming: continue
		var body: Dictionary = _request_body(entry)
		if body.is_empty():
			_block(path,entry,"INVALID_RECOVERY_JOURNAL")
			continue
		# One background write per interval, including explicit reconcile calls.
		# Persist the wait before delivery so restarts/shared profiles respect it.
		_delay_scope(directory,REQUEST_INTERVAL_SECONDS,false,true)
		var response: Dictionary = await client.request_api("/resume-recovery",HTTPClient.METHOD_POST,body,"",true)
		if str(client.player.get("id","")) != owner or client.base_url() != origin: break
		if (response.get("ok",false) and response.get("data",{}).get("state") in ["consumed","abandoned","absent"]) or str(response.get("error","")) == "RACE_ALREADY_SUBMITTED":
			# Accepted replay binds all its receipts; refund is prohibited.
			_resolved[path] = true
			entry.recovery_resolved = true
			Files.write(path,entry,32768)
			DirAccess.remove_absolute(path)
			_delay_scope(directory,REQUEST_INTERVAL_SECONDS,false)
		elif int(response.get("status",0)) in [400,403,404,409,410,422]:
			# Preserve the original operation for repair; never repeat a definitive
			# rejection or invent a replacement charge/key.
			_block(path,entry,str(response.get("error","RECOVERY_REJECTED")))
		else:
			_delay_scope(directory,maxi(30,int(response.get("retry_after",0))),true)
		break
	busy = false

static func _request_body(entry: Dictionary) -> Dictionary:
	for key: String in ["begin_key","consume_key"]:
		if not entry.get(key) is String or entry[key].length() < 8 or entry[key].length() > 128: return {}
	if not entry.get("selection") is Dictionary or entry.get("stage","pending") not in ["pending","confirm"]: return {}
	var selection: Dictionary = entry.selection.duplicate(true)
	for field: String in selection:
		if field not in ["ordinal","input_offset","from_tick","to_tick","recovery"]: return {}
	for field: String in ["ordinal","input_offset","from_tick","to_tick"]:
		var value: Variant = selection.get(field)
		var minimum: int = 0 if field == "to_tick" else 1
		var maximum: int = 3 if field == "ordinal" else 215999 if field == "to_tick" else 216000
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) < minimum or float(value) > maximum or float(value) != float(int(value)): return {}
		# Godot JSON reloads integers as floats. Cast only validated whole fields;
		# changing the server's strict contract would hide corrupt evidence.
		selection[field] = int(value)
	if selection.get("recovery") != null and selection.recovery != "v1": return {}
	if selection.from_tick-selection.to_tick < 1 or selection.from_tick-selection.to_tick > 1200: return {}
	var body: Dictionary = {"begin_key":entry.begin_key,"consume_key":entry.consume_key,"selection":selection,"action":"confirm" if entry.get("stage","pending") == "confirm" else "abandon"}
	for field: String in ["race_id","ticket_id"]:
		if entry.get(field,"") == "": continue
		if not entry.get(field) is String or entry[field].length() != 36: return {}
		body[field] = entry[field]
	return body

func _block(path: String, entry: Dictionary, error: String) -> void:
	entry.recovery_failure = error
	Files.write(path,entry,32768)

func _ready_scope(directory: String) -> bool:
	if not _deadlines.has(directory):
		var saved: Dictionary = Files.read(directory.path_join(".retry.json"),1024)
		var seconds: int = clampi(int(saved.get("retry_delay",0)),0,3600)
		if client.server_now() > 0 and int(saved.get("retry_server_at",0)) > 0:
			seconds = clampi(int(saved.retry_server_at)-client.server_now(),0,seconds)
		_deadlines[directory] = Time.get_ticks_msec()+seconds*1000
	return Time.get_ticks_msec() >= int(_deadlines[directory])

func _delay_scope(directory: String, seconds: int, failed: bool, reserve: bool = false) -> void:
	var saved: Dictionary = Files.read(directory.path_join(".retry.json"),1024)
	var streak: int = mini(6,int(saved.get("retry_streak",0))+1) if failed else 0
	# Keep the previous failure streak while reserving the next delivery.
	if reserve: streak = int(saved.get("retry_streak",0))
	var wait_seconds: int = maxi(seconds,mini(600,30*int(pow(2,streak-1)))) if failed else seconds
	saved = {"retry_streak":streak,"retry_delay":wait_seconds,"retry_server_at":client.server_now()+wait_seconds if client.server_now() > 0 else 0}
	Files.write(directory.path_join(".retry.json"),saved,1024)
	_deadlines[directory] = Time.get_ticks_msec()+wait_seconds*1000
