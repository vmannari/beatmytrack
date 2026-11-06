extends SceneTree
const PRUNE = preload("res://tests/shader_branch_probe.gd")
func _initialize() -> void:
	var folder: String = OS.get_environment("BMT_PRUNE_BASELINE")
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("profile.json")))
	var sources: Dictionary = {}
	for draw: Dictionary in profile.draws:
		for node: Dictionary in draw.sources:
			for material: Dictionary in node.materials:
				if str(material.get("origin","")).begins_with("res://track/"):
					var path: String = folder.path_join(material.hash+".gdshader")
					if not FileAccess.file_exists(path): push_error("Missing source "+path); quit(1); return
					sources[material.hash] = FileAccess.get_file_as_string(path)
	var times: Array = []
	var removed: int = 0
	for trial: int in range(5):
		var began: int = Time.get_ticks_usec()
		for source: String in sources.values():
			var candidate: String = PRUNE.reduce(source)
			if trial == 0: removed += source.length()-candidate.length()
		times.append((Time.get_ticks_usec()-began)/1000.0)
	print("PRUNING_CPU ",JSON.stringify({"sources":sources.size(),"removed_characters":removed,"batch_ms":times}))
	quit()
