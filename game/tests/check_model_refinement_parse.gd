extends SceneTree
var checked: int = 0
var failures: int = 0
func _initialize() -> void:
	scan("res://")
	print("PRODUCTION_PARSE ",checked," scripts, ",failures," failures")
	quit(1 if failures else 0)
func scan(path: String) -> void:
	if path=="res://tests": return
	var folder := DirAccess.open(path)
	if folder==null or folder.file_exists(".gdignore"): return
	for name: String in folder.get_files():
		if name.ends_with(".gd"):
			checked += 1
			var script: GDScript = load(path.path_join(name))
			if script==null or not script.can_instantiate(): failures += 1
	for child: String in folder.get_directories():
		if not child.begins_with("."): scan(path.path_join(child))
