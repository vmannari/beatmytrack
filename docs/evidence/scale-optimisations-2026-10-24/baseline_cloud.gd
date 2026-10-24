extends "res://tests/test_cloud_tracks.gd"

func _initialize() -> void:
	var before: String = OS.get_environment("BMT_SCALE_TASK_BEFORE")
	for name: String in ["backend_client.gd","cloud_tracks.gd"]:
		assert(FileAccess.file_exists(before.path_join(name)))
		var source: GDScript = load("res://backend/"+name)
		source.source_code = FileAccess.get_file_as_string(before.path_join(name))
		assert(source.source_code.begins_with("extends Node"))
		assert(source.reload() == OK)
	print("TASK_START_CLIENT_AND_CLOUD_RELOADED_IN_MEMORY")
	super._initialize()
