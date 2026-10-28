extends "res://tests/test_store_reference.gd"
## Isolated process-memory baseline; no production file is replaced.
func _initialize() -> void:
	var original: GDScript = load("res://ui/store_page.gd")
	original.source_code = FileAccess.get_file_as_string("res://../docs/evidence/track-slot-gifts-2026-10-25/before/game/ui/store_page.gd")
	if original.reload() != OK: quit(2); return
	print("TASK_START_STORE_RELOADED_IN_PROCESS_MEMORY")
	super._initialize()
