extends "res://tests/test_race_loading_first_lap.gd"
## Retain every existing car/theme/emission/cancellation assertion; isolate
## races from the unrelated optional Garage job between rapid test entries.
func observe() -> void:
	super.observe()
	if is_instance_valid(app) and is_instance_valid(app._garage_preloader):
		app._garage_preloader.idle_ms = 100000000
		app._garage_preloader.foreground = false
