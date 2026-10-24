extends Node
## Durable small operations; never replay a charge while recovering an abandoned race.
var client: Node
var root_override: String = ""
var active: Dictionary = {}
var busy: bool = false
var _next_msec: int = 0
var _serial: int = 0
var _deadlines: Dictionary = {}
var _retry_versions: Dictionary = {}
var _cursor: Dictionary = {}
var _resolved: Dictionary = {}
var _scope_lock: RefCounted
var _instance_nonce: String = Crypto.new().generate_random_bytes(24).hex_encode()
static var _process_nonce: String = Crypto.new().generate_random_bytes(24).hex_encode()
var profile_callback_us: int = 0
const Files = preload("res://backend/atomic_json.gd")
const REQUEST_INTERVAL_SECONDS: int = 5
const MAX_INSPECTED: int = 64

func _directory(owner: String, origin: String) -> String:
	var base: String = root_override if not root_override.is_empty() else client.session_path.get_base_dir().path_join("resume_recovery") if not client.session_path.is_empty() else "user://resume_recovery"
	return base.path_join(origin.sha256_text()).path_join(owner.sha256_text())

func register_race(key: String) -> void:
	var owner: String = str(client.player.get("id",""))
	var origin: String = str(client.base_url())
	var directory: String = _directory(owner,origin)
	var lease_directory: String = _active_directory(directory,key)
	var path: String = lease_directory.path_join("owner.json")
	var saved: bool = owner.is_empty()
	if Files.read(path,1024).get("instance_nonce") == _instance_nonce:
		saved = true
	elif not owner.is_empty() and _ensure_directory(lease_directory.get_base_dir()):
		# mkdir is the cross-process claim. A duplicate key cannot overwrite a
		# live owner's marker, even if two instances register simultaneously.
		if not DirAccess.dir_exists_absolute(lease_directory) or not _race_is_active(directory,key):
			if DirAccess.make_dir_absolute(lease_directory) == OK:
				saved = Files.write(path,{"pid":OS.get_process_id(),"process_nonce":_process_nonce,"instance_nonce":_instance_nonce},1024)
				if not saved:
					DirAccess.remove_absolute(path+".tmp")
					DirAccess.remove_absolute(path)
					DirAccess.remove_absolute(lease_directory)
	active[key] = {"path":path,"saved":saved}

func leave_race(key: String) -> void:
	if active.has(key):
		var path: String = str(active[key].path)
		if Files.read(path,1024).get("instance_nonce") == _instance_nonce:
			DirAccess.remove_absolute(path)
			DirAccess.remove_absolute(path.get_base_dir())
	active.erase(key)
	_next_msec = 0

func _exit_tree() -> void:
	for key: String in active.keys(): leave_race(key)
	if _scope_lock != null: _scope_lock.release()

func save(entry: Dictionary) -> bool:
	if str(entry.get("owner","")).is_empty() or str(entry.get("origin","")).is_empty() or _request_body(entry).is_empty(): return false
	# A failed ownership journal must stop consumption before any charge.
	if active.has(str(entry.begin_key)) and not bool(active[str(entry.begin_key)].saved): return false
	var path: String = _directory(str(entry.owner),str(entry.origin)).path_join(str(entry.consume_key).sha256_text()+".json")
	return Files.write(path,entry,32768)

func discard(entry: Dictionary) -> void:
	if not entry.has_all(["owner","origin","consume_key"]): return
	DirAccess.remove_absolute(_directory(str(entry.owner),str(entry.origin)).path_join(str(entry.consume_key).sha256_text()+".json"))

func _process(_delta: float) -> void:
	if not busy and Time.get_ticks_msec() >= _next_msec:
		var started: int = Time.get_ticks_usec()
		_next_msec = Time.get_ticks_msec()+5000+int(Crypto.new().generate_random_bytes(1)[0])*10
		reconcile()
		# Initial synchronous journal work only, excluding network wait.
		profile_callback_us += Time.get_ticks_usec() - started

func reconcile() -> void:
	if busy or not client.signed_in() or not bool(client._capabilities.get("resume_recovery",false)): return
	busy = true
	var owner: String = str(client.player.get("id",""))
	var origin: String = str(client.base_url())
	var directory: String = _directory(owner,origin)
	if not _ready_scope(directory):
		busy = false
		return
	if not _ensure_directory(directory):
		busy = false
		return
	_scope_lock = preload("res://backend/session_rotation_lock.gd").new(directory.path_join(".recovery"))
	if await _scope_lock.acquire(get_tree()) != OK:
		_scope_lock = null
		busy = false
		return
	# Re-read after acquiring the shared lock. The preceding instance may have
	# changed both the retry deadline and a journal while this one waited.
	if str(client.player.get("id","")) == owner and client.base_url() == origin and _ready_scope(directory):
		await _reconcile_locked(directory,owner,origin)
	_scope_lock.release()
	_scope_lock = null
	busy = false

func _reconcile_locked(directory: String, owner: String, origin: String) -> void:
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
		if not confirming and (active.has(key) or _race_is_active(directory,key)): continue
		var body: Dictionary = _request_body(entry)
		if body.is_empty():
			_block(path,entry,"INVALID_RECOVERY_JOURNAL")
			continue
		# One background write per interval, including explicit reconcile calls.
		# Persist the wait before delivery so restarts/shared profiles respect it.
		if not _delay_scope(directory,REQUEST_INTERVAL_SECONDS,false,true): return
		var response: Dictionary = await client.request_api("/resume-recovery",HTTPClient.METHOD_POST,body,"",true)
		var callback_started: int = Time.get_ticks_usec()
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
		profile_callback_us += Time.get_ticks_usec() - callback_started
		break

func _race_is_active(directory: String, key: String) -> bool:
	var lease_directory: String = _active_directory(directory,key)
	var path: String = lease_directory.path_join("owner.json")
	if not DirAccess.dir_exists_absolute(lease_directory): return false
	var lease: Dictionary = Files.read(path,1024)
	# An unreadable lease is uncertain ownership, never permission to abandon.
	var raw_pid: Variant = lease.get("pid")
	if not (raw_pid is int or raw_pid is float) or not is_finite(float(raw_pid)) or float(raw_pid) != float(int(raw_pid)) or int(raw_pid) <= 0: return true
	for field: String in ["process_nonce","instance_nonce"]:
		if not lease.get(field) is String or lease[field].length() != 48 or not lease[field].is_valid_hex_number(): return true
	var pid: int = int(lease.pid)
	var previous_process: bool = pid == OS.get_process_id() and lease.get("process_nonce") != _process_nonce
	if not previous_process and OS.is_process_running(pid): return true
	# Preserve a nonempty tombstone: stale observers cannot rename a newly
	# acquired lease to the same destination after this owner was retired.
	var abandoned: String = lease_directory+".abandoned."+str(lease.instance_nonce)
	if DirAccess.rename_absolute(lease_directory,abandoned) == OK: return false
	return DirAccess.dir_exists_absolute(lease_directory)

static func _active_directory(directory: String, key: String) -> String:
	return directory.path_join(".active").path_join(key.sha256_text()+".lease")

static func _ensure_directory(path: String) -> bool:
	var ancestor: String = path
	while not ancestor.is_empty():
		if FileAccess.file_exists(ancestor): return false
		if DirAccess.dir_exists_absolute(ancestor): break
		var parent: String = ancestor.get_base_dir()
		if parent == ancestor: break
		ancestor = parent
	return DirAccess.make_dir_recursive_absolute(path) == OK

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
	var saved: Dictionary = Files.read(directory.path_join(".retry.json"),1024)
	if saved.has("_read_error"): return false
	var revision: String = str(saved.get("retry_id",JSON.stringify(saved)))
	if not _deadlines.has(directory) or _retry_versions.get(directory) != revision:
		var seconds: int = clampi(int(saved.get("retry_delay",0)),0,3600)
		if client.server_now() > 0 and int(saved.get("retry_server_at",0)) > 0:
			seconds = clampi(int(saved.retry_server_at)-client.server_now(),0,seconds)
		_deadlines[directory] = Time.get_ticks_msec()+seconds*1000
		_retry_versions[directory] = revision
	return Time.get_ticks_msec() >= int(_deadlines[directory])

func _delay_scope(directory: String, seconds: int, failed: bool, reserve: bool = false) -> bool:
	var saved: Dictionary = Files.read(directory.path_join(".retry.json"),1024)
	if saved.has("_read_error"): return false
	var streak: int = mini(6,int(saved.get("retry_streak",0))+1) if failed else 0
	# Keep the previous failure streak while reserving the next delivery.
	if reserve: streak = int(saved.get("retry_streak",0))
	var wait_seconds: int = maxi(seconds,mini(600,30*int(pow(2,streak-1)))) if failed else seconds
	saved = {"retry_id":Crypto.new().generate_random_bytes(24).hex_encode(),"retry_streak":streak,"retry_delay":wait_seconds,"retry_server_at":client.server_now()+wait_seconds if client.server_now() > 0 else 0}
	if not Files.write(directory.path_join(".retry.json"),saved,1024): return false
	_retry_versions[directory] = saved.retry_id
	_deadlines[directory] = Time.get_ticks_msec()+wait_seconds*1000
	return true
