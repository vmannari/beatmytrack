extends "res://tests/test_app.gd"
## Same current App suite with only the two exact task-start runtime scripts in memory.
func _initialize() -> void:
	for name: String in ["garage_first_draw.gd","garage_opening_showroom.gd"]:
		var script: GDScript=load("res://ui/"+name)
		var source: String=FileAccess.get_file_as_string("res://../docs/evidence/garage-reflections-restored-2026-10-27/before/game/ui/"+name)
		assert(not source.is_empty())
		script.source_code=source
		assert(script.reload()==OK)
	super._initialize()
