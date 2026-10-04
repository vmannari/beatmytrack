extends RefCounted
## Serialize session rotation across clients sharing a private application folder.
## Only this small adapter touches the filesystem/process state; never simulation.
var path: String = ""
var nonce: String = ""
var owned: bool = false

func _init(session_path: String) -> void:
	path = session_path+".rotation" if not session_path.is_empty() else ""
	nonce = Crypto.new().generate_random_bytes(24).hex_encode()

func acquire(tree: SceneTree) -> Error:
	if path.is_empty(): return OK
	var began: int = Time.get_ticks_msec()
	while Time.get_ticks_msec()-began < 35000:
		var result: Error = DirAccess.make_dir_absolute(path)
		if result == OK:
			var file := FileAccess.open(path.path_join("owner.json"),FileAccess.WRITE)
			if file == null:
				DirAccess.remove_absolute(path)
				return ERR_CANT_CREATE
			file.store_string(JSON.stringify({"pid":OS.get_process_id(),"nonce":nonce}))
			file.flush()
			var saved: bool = file.get_error() == OK
			file.close()
			if not saved:
				DirAccess.remove_absolute(path.path_join("owner.json"))
				DirAccess.remove_absolute(path)
				return ERR_CANT_CREATE
			owned = true
			return OK
		if not DirAccess.dir_exists_absolute(path): return result
		var owner: Dictionary = _owner()
		var old_nonce: String = str(owner.get("nonce",""))
		if old_nonce.length() == 48 and old_nonce.is_valid_hex_number() and int(owner.get("pid",0)) > 0 and not OS.is_process_running(int(owner.pid)):
			# A permanent, nonempty tombstone prevents a second stale observer
			# from moving a newly acquired lock into the same destination.
			var abandoned: String = path+".abandoned."+old_nonce
			if abandoned.get_base_dir() == path.get_base_dir(): DirAccess.rename_absolute(path,abandoned)
		elif owner.is_empty() and Time.get_ticks_msec()-began > 10000:
			# A crash between mkdir and writing its owner can leave an empty lock.
			# rmdir refuses a directory another client has since populated.
			DirAccess.remove_absolute(path)
		await tree.create_timer(0.025).timeout
	return ERR_BUSY

func _owner() -> Dictionary:
	var file := FileAccess.open(path.path_join("owner.json"),FileAccess.READ)
	if file == null or file.get_length() > 1024: return {}
	var value: Variant = JSON.parse_string(file.get_as_text())
	return value if value is Dictionary else {}

func release() -> void:
	if not owned: return
	if str(_owner().get("nonce","")) == nonce:
		DirAccess.remove_absolute(path.path_join("owner.json"))
		DirAccess.remove_absolute(path)
	owned = false
