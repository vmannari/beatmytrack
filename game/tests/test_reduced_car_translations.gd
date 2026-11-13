extends SceneTree
## SMO02: removed model controls leave no obsolete localized selector text.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var checks: int=0
	var failures: int=0
	for file: String in DirAccess.get_files_at("res://localization"):
		if not file.ends_with(".po") and not file.ends_with(".pot"): continue
		var source: String=FileAccess.get_file_as_string("res://localization/"+file)
		for message: String in ["Simpler car models","Use much lighter cars in races and Garage. Small details and curves are less accurate."]:
			checks+=1
			if source.contains('msgid "'+message+'"'):
				failures+=1;printerr("RETIRED_TRANSLATION_FAIL ",file)
	print("REDUCED_CAR_TRANSLATIONS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
