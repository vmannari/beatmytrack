extends SceneTree
## Read actual settings, write only a disposable copy; no player data in output.
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var source := LocalRecords.new()
	var explicit_path: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--records="):
			source.path = argument.trim_prefix("--records=")
			explicit_path = true
	source.load_records()
	var sources: Array[LocalRecords] = [source]
	if not explicit_path:
		var largest_path: String = ""
		var largest_size: int = 0
		for profile: String in DirAccess.get_directories_at("user://players"):
			var path: String = "user://players".path_join(profile).path_join("records.json")
			var file := FileAccess.open(path, FileAccess.READ)
			if file == null: continue
			if file.get_length() > largest_size:
				largest_size = file.get_length()
				largest_path = path
			file.close()
		if not largest_path.is_empty():
			var largest := LocalRecords.new(largest_path)
			largest.load_records()
			sources.append(largest)
	var directory: String = ProjectSettings.globalize_path("res://../build/race-hitch-save-profile")
	DirAccess.make_dir_recursive_absolute(directory)
	for index: int in range(sources.size()):
		if not measure(sources[index], directory.path_join("records-%d.json" % index), index):
			quit(1)
			return
	quit()

func measure(source: LocalRecords, path: String, index: int) -> bool:
	var disposable := LocalRecords.new(path)
	disposable.records = source.records.duplicate(true)
	disposable.settings = source.settings.duplicate(true)
	var durations: Array[float] = []
	for sample_index: int in range(30):
		var start: int = Time.get_ticks_usec()
		var error: Error = disposable.save_records()
		durations.append((Time.get_ticks_usec() - start) / 1000.0)
		if error != OK:
			push_error("Disposable save failed: " + error_string(error))
			return false
	durations.sort()
	print("CONDITION_SAVE_PROFILE store=", index, " bytes=", FileAccess.get_file_as_bytes(disposable.path).size(), "median_ms=", durations[15], "max_ms=", durations[-1], "samples=", durations.size())
	return true
