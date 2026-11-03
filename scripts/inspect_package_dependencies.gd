extends SceneTree
## Run in an isolated empty project; reads dependency headers without loading scenes.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3:
		push_error("Expected game root, JSON input list, JSON output path")
		quit(2)
		return
	var root: String = args[0]
	var paths: Array = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	var result: Dictionary = {}
	for relative: String in paths:
		result[relative] = Array(ResourceLoader.get_dependencies(root.path_join(relative)))
	var output := FileAccess.open(args[2], FileAccess.WRITE)
	if output == null:
		push_error("Cannot write dependency report")
		quit(3)
		return
	output.store_string(JSON.stringify(result))
	output.close()
	print("Inspected %d binary resources without instantiation" % paths.size())
	quit()
