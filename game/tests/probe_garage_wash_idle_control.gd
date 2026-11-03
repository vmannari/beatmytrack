extends "res://tests/test_garage_wash_animation.gd"
## Attribute existing washing-fixture failures to the archived task-start runtime.
func _initialize() -> void:
	for relative: String in ["ui/car_showroom.gd","ui/garage_wash_effect.gd"]:
		var script: Script = load("res://"+relative)
		script.source_code = FileAccess.get_file_as_string("res://../docs/evidence/garage-idle-audit-2026-11-01/before/game/"+relative)
		assert(script.reload(true) == OK)
	super._initialize()
