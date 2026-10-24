extends RefCounted
## Small shared IO boundary; no menus, simulation or platform SDK dependencies.
static func read(path: String, limit: int = 8388608) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > limit: return {"_read_error":true}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK: return {"_read_error":true}
	return json.data if json.data is Dictionary else {"_read_error":true}

static func write(path: String, value: Dictionary, limit: int = 8388608) -> bool:
	var encoded: String = JSON.stringify(value)
	if encoded.to_utf8_buffer().size() > limit: return false
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK: return false
	var temporary: String = path+".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null: return false
	file.store_string(encoded)
	file.flush()
	var ok: bool = file.get_error() == OK
	file.close()
	return ok and DirAccess.rename_absolute(temporary,path) == OK
