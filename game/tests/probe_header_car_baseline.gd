extends "res://tests/test_app.gd"
## Compare the existing App regression with exact task-start runtime sources.
func _initialize() -> void:
	for entry: Array in [["res://core/app.gd","app.gd.txt"],["res://ui/track_of_day_page.gd","track_of_day_page.gd.txt"]]:
		var source: GDScript = load(entry[0])
		source.source_code = FileAccess.get_file_as_string("res://../docs/evidence/header-car-dropdown-2026-10-26/before/"+entry[1])
		if source.reload() != OK:
			quit(1)
			return
	super._initialize()
