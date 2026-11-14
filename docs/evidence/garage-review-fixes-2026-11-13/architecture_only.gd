extends "res://tests/test_menu_responsiveness.gd"
func run() -> void:
	architecture()
	print("WORKSHOP_EQUIVALENCE ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
