extends "res://tests/test_cars.gd"
## The established five-lap / exact-replay checks for electric-3.
func _run() -> void:
	for track_id: String in ["arto4","hiekka","ovaali3"]:
		await _laps("electric",track_id)
	print("ELECTRIC_POWER_LAPS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
