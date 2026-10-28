extends "res://tests/test_app.gd"
## Isolated comparison of App shutdown diagnostics without the new cache service.
func _initialize() -> void:
	var source: GDScript = load("res://core/app.gd")
	source.source_code = FileAccess.get_file_as_string("res://../docs/evidence/header-car-appearance-cache-2026-10-26/before/app.gd.txt")
	if OS.get_environment("BMT_HEADER_CACHE_CONTROL") == "1":
		# Keep concurrent App changes; disable only this task's cache service.
		source.source_code = FileAccess.get_file_as_string("res://core/app.gd")
		var start: int = source.source_code.find("\theader_car_cache = preload(")
		var end: int = source.source_code.find("\tachievements = preload(",start)
		assert(start >= 0 and end > start)
		source.source_code = source.source_code.substr(0,start)+source.source_code.substr(end)
	# The concurrent sync implementation retired this assignment; adapt only its API.
	source.source_code = source.source_code.replace("\tappearance_sync.clean_poll_allowed = func() -> bool: return not is_instance_valid(game)\n","")
	if source.reload()!=OK: quit(1); return
	super._initialize()
