extends "res://tests/test_garage_reflections.gd"
## Restore only the original plant builder in this test process, never on disk.
func _initialize() -> void:
	var workshop: GDScript = preload("res://ui/garage_workshop.gd")
	var old: String = FileAccess.get_file_as_string("res://../docs/evidence/garage-plant-2026-10-15/baseline/garage_workshop.gd")
	var marker: String = "static func _plant(root: Node3D) -> void:"
	if not old.contains(marker):
		push_error("Missing audited baseline plant source")
		quit(2)
		return
	workshop.source_code = workshop.source_code.get_slice(marker,0)+marker+old.get_slice(marker,1)
	if workshop.reload(true) != OK:
		quit(2)
		return
	print("ORIGINAL_PLANT_BASELINE: process-only source restoration")
	super._initialize()
