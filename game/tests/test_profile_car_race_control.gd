extends "res://tests/test_race_optional_work.gd"
## Retain every assertion, reverting only this task in the process's script cache.
func _initialize() -> void:
	for name: String in ["header_car_icons","header_car_appearance_cache"]:
		var script: GDScript = load("res://ui/"+name+".gd")
		script.source_code = FileAccess.get_file_as_string("res://../docs/evidence/profile-car-startup-2026-10-29/before/game/ui/"+name+".gd")
		assert(script.reload(true) == OK)
	var app_script: GDScript = load("res://core/app.gd")
	app_script.source_code = app_script.source_code.replace("\tawait header_car_cache.prepare_selected()\n","").replace('return (startup_complete or header_car_cache.preparing_selected) and not is_instance_valid(game) and _background_work_allowed() and (screen != "restoring" or header_car_cache.preparing_selected)','return startup_complete and not is_instance_valid(game) and _background_work_allowed() and screen not in ["account","restoring"]')
	assert(app_script.reload(true) == OK)
	super._initialize()
