extends RefCounted
## Offline bakers only. Validate candidates before replacing accepted artifacts.
## A directory lock serialises cooperating writers; an interrupted run leaves it
## for inspection rather than guessing that another writer is dead.
var folder: String
var staging: String
var names: Array[String] = []
var previous: Dictionary = {}
var locked: bool = false
var recovery_required: bool = false

func digest(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"

func begin(target: String, files: Array[String]) -> Error:
	for name: String in files:
		if name != name.get_file() or name in ["", ".", ".."] or names.has(name): return ERR_INVALID_PARAMETER
		names.append(name)
	folder = ProjectSettings.globalize_path(target)
	var error: Error = DirAccess.make_dir_recursive_absolute(folder)
	if error != OK: return error
	staging = folder.path_join(".asset-bake-lock")
	error = DirAccess.make_dir_absolute(staging)
	if error != OK: return error
	locked = true
	var ignore := FileAccess.open(staging.path_join(".gdignore"), FileAccess.WRITE)
	if ignore == null:
		close()
		return ERR_CANT_CREATE
	ignore.close()
	for name: String in names: previous[name] = digest(folder.path_join(name))
	# Leave a small recovery receipt if the process stops between file moves.
	var receipt := FileAccess.open(staging.path_join("previous.json"), FileAccess.WRITE)
	if receipt == null:
		close()
		return ERR_CANT_CREATE
	receipt.store_string(JSON.stringify({"folder": folder, "previous": previous}, "\t") + "\n")
	receipt.flush()
	error = receipt.get_error()
	receipt.close()
	if error != OK: close()
	return error

func candidate(name: String) -> String:
	assert(locked and names.has(name))
	return staging.path_join("candidate_" + name)

func unchanged() -> bool:
	for name: String in names:
		if previous[name] != digest(folder.path_join(name)): return false
	return true

func _move(source: String, target: String) -> Error:
	return DirAccess.rename_absolute(source, target)

func publish(files: Array[String]) -> Error:
	if not locked or not unchanged(): return ERR_BUSY
	# The caller lists the manifest last. Protected/excluded files are fenced by
	# unchanged(), but are never replaced.
	var seen: Array[String] = []
	for name: String in files:
		if not names.has(name) or name in seen or not FileAccess.file_exists(candidate(name)): return ERR_INVALID_DATA
		seen.append(name)
	var touched: Array[String] = []
	var installed: Array[String] = []
	var error: Error = OK
	for name: String in files:
		var path: String = folder.path_join(name)
		if previous[name] != "missing":
			error = _move(path, staging.path_join("backup_" + name))
			if error != OK: break
		touched.append(name)
		error = _move(candidate(name), path)
		if error != OK: break
		installed.append(name)
	if error != OK:
		touched.reverse()
		for name: String in touched:
			var path: String = folder.path_join(name)
			if name in installed and DirAccess.remove_absolute(path) != OK: recovery_required = true
			if previous[name] != "missing" and _move(staging.path_join("backup_" + name), path) != OK: recovery_required = true
		if recovery_required:
			push_error("Asset publication rollback needs inspection: " + staging)
	return error

func close() -> void:
	if not locked or recovery_required: return
	for name: String in names:
		for prefix: String in ["candidate_", "backup_"]:
			var path: String = staging.path_join(prefix + name)
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(staging.path_join(".gdignore"))
	DirAccess.remove_absolute(staging.path_join("previous.json"))
	DirAccess.remove_absolute(staging)
	locked = false
