extends RefCounted
## Only a hashed, account-specific recovery directory; authored files are outside it.
static func erase_roots(paths: Array[String]) -> bool:
	var ok: bool = true
	for path: String in paths:
		if not erase_account_tree(path): ok = false
	return ok

static func erase_account_tree(path: String) -> bool:
	var root: String = ProjectSettings.globalize_path(path).simplify_path().replace("\\","/")
	var leaf: String = root.get_file()
	if leaf.length() != 64 or not leaf.is_valid_hex_number(): return false
	var parent := DirAccess.open(root.get_base_dir())
	if parent == null or parent.is_link(leaf): return false
	if not DirAccess.dir_exists_absolute(root): return true
	return _erase(root,root,0)

static func _erase(path: String, root: String, depth: int) -> bool:
	path = path.simplify_path()
	if depth > 8 or (path != root and not path.begins_with(root+"/")): return false
	var directory := DirAccess.open(path)
	if directory == null: return false
	var ok: bool = true
	for file: String in directory.get_files():
		if directory.is_link(file) or DirAccess.remove_absolute(path.path_join(file)) != OK: ok = false
	for folder: String in directory.get_directories():
		if directory.is_link(folder) or not _erase(path.path_join(folder),root,depth+1): ok = false
	return ok and DirAccess.remove_absolute(path) == OK
