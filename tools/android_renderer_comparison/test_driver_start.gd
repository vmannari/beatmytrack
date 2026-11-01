extends SceneTree
const Start = preload("driver_start.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	if Start.ready(1, 20): failures.append("driver admitted during countdown")
	if Start.ready(0, 9): failures.append("driver admitted during early-throttle window")
	if not Start.ready(0, 10): failures.append("driver blocked at safe tick")
	var state := VehicleState.new()
	var first := -1
	for tick in range(12):
		state.tick = tick
		var frame := DriveFrame.new()
		if tick == 0: frame.launch_start = 1
		if Start.ready(0, tick):
			if first < 0: first = tick
			frame.throttle = 255
		LaunchStart.advance(state, frame)
	if first != 10: failures.append("unexpected first driver tick")
	if state.launch_result != "Perfect start": failures.append("normal launch logic did not see safe input")
	var control := VehicleState.new()
	var premature := DriveFrame.new()
	premature.launch_start = 1
	premature.throttle = 255
	LaunchStart.advance(control, premature)
	if control.launch_result != "False start": failures.append("early-throttle control failed")
	for failure in failures: push_error(failure)
	print("DRIVER_START_TEST: ", "pass" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
