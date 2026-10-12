extends Node
## Durable small operations; never replay a charge while recovering an abandoned race.
var client: Node
var root_override: String = ""
var active: Dictionary = {}
var busy: bool = false
var _next_msec: int = 0
var _serial: int = 0
const Files = preload("res://backend/atomic_json.gd")

func _directory(owner: String, origin: String) -> String:
	var base: String = root_override if not root_override.is_empty() else client.session_path.get_base_dir().path_join("resume_recovery") if not client.session_path.is_empty() else "user://resume_recovery"
	return base.path_join(origin.sha256_text()).path_join(owner.sha256_text())

func register_race(key: String) -> void:
	active[key] = true

func leave_race(key: String) -> void:
	active.erase(key)
	_next_msec = 0

func save(entry: Dictionary) -> bool:
	if str(entry.get("owner","")).is_empty() or str(entry.get("origin","")).is_empty() or str(entry.get("begin_key","")).is_empty(): return false
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
	var filenames: PackedStringArray = DirAccess.get_files_at(directory) if DirAccess.dir_exists_absolute(directory) else PackedStringArray()
	var inspected: int = 0
	for filename: String in filenames:
		if not filename.ends_with(".json"): continue
		inspected += 1
		if inspected > 16: break
		var entry: Dictionary = Files.read(directory.path_join(filename),32768)
		if entry.has("_read_error") or str(entry.get("owner","")) != owner or str(entry.get("origin","")) != origin or not entry.get("selection") is Dictionary: continue
		var key: String = str(entry.get("begin_key",""))
		if filename != str(entry.get("consume_key","")).sha256_text()+".json": continue
		var confirming: bool = entry.get("stage","pending") == "confirm"
		if active.has(key) and not confirming: continue
		var body: Dictionary = {"begin_key":key,"consume_key":entry.consume_key,
			"selection":entry.selection,"action":"confirm" if confirming else "abandon"}
		if not str(entry.get("race_id","")).is_empty(): body.race_id = entry.race_id
		if not str(entry.get("ticket_id","")).is_empty(): body.ticket_id = entry.ticket_id
		var response: Dictionary = await client.request_api("/resume-recovery",HTTPClient.METHOD_POST,body,"",true)
		if str(client.player.get("id","")) != owner or client.base_url() != origin: break
		if response.ok:
			if response.data.state in ["consumed","abandoned","absent"]:
				DirAccess.remove_absolute(directory.path_join(filename))
		elif str(response.error) == "RACE_ALREADY_SUBMITTED":
			# Accepted replay binds all its receipts; refund is prohibited.
			DirAccess.remove_absolute(directory.path_join(filename))
	busy = false
