extends SceneTree
## Compile every project script in one engine process; never instantiate test entrypoints.
var checked: int = 0
var failed: bool = false

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	scan("res://")
	print("SCRIPT_PARSE: %d scripts, %d failures" % [checked,1 if failed else 0])
	quit(1 if failed or checked == 0 else 0)

func scan(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		failed = true
		return
	# Match Godot's resource import boundary. Android's ignored Gradle template
	# includes vendor instrumented-test assets that are not project scripts.
	if directory.file_exists(".gdignore"): return
	for filename: String in directory.get_files():
		if not filename.ends_with(".gd") or filename == "test_script_parse.gd": continue
		checked += 1
		var script: GDScript = load(path.path_join(filename))
		# Loading compiles the script and its dependencies. Reloading an autoload
		# or another script with live instances is prohibited by the engine.
		if script == null or not script.can_instantiate():
			failed = true
			print("FAIL: "+path.path_join(filename))
	for child: String in directory.get_directories():
		if child.begins_with("."): continue
		scan(path.path_join(child))
