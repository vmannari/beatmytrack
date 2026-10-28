extends "res://tests/test_store_reference.gd"
## Reload the exact task-start Store only in this disposable process's memory.
func _initialize() -> void:
	var script: GDScript = load("res://ui/store_page.gd")
	script.source_code = FileAccess.get_file_as_string("res://../docs/evidence/translation-gaps-2026-10-25/before/game__ui__store_page.gd")
	if script.reload(true) != OK:
		quit(2)
		return
	super._initialize()
