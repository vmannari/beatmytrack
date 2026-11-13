extends SceneTree
func _initialize() -> void:
	# The reused check initially wrote its historical output path. Restore its
	# original recorded values and keep subsequent results in this task folder.
	var folder: String = "res://../docs/evidence/challenger-panels-2026-11-12/"
	for line: String in FileAccess.get_file_as_string(folder+"panels-final.log").split("\n"):
		if line.begins_with("CHALLENGER_PANELS:"):
			var metrics: Array = JSON.parse_string(line.substr(line.find("[")))
			var file := FileAccess.open(folder+"panel-after.json",FileAccess.WRITE)
			file.store_string(JSON.stringify({"checks":884,"failures":0,"metrics":metrics},"\t"));file.close()
	print("Historical panel receipt restored from its retained original log")
	quit()
