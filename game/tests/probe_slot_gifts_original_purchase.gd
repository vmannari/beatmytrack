extends "res://tests/test_purchase_simulation.gd"
## Isolated process-memory baseline; no production file is replaced.
func _initialize() -> void:
	var original: GDScript = load("res://platform/purchase_simulator.gd")
	original.source_code = FileAccess.get_file_as_string("res://../docs/evidence/track-slot-gifts-2026-10-25/before/game/platform/purchase_simulator.gd")
	if original.reload() != OK: quit(2); return
	print("TASK_START_PURCHASE_ADAPTER_RELOADED_IN_PROCESS_MEMORY")
	super._initialize()
