class_name LaunchStart
extends RefCounted
## Launch timing uses only canonical 120 Hz inputs. Marker only enables a race start.
static func initialize(state: VehicleState, marker: int) -> void:
	if state.tick == 0 and marker > 0:
		state.launch_pending = marker == 1
		if marker == 2:
			state.launch_result = "Jumped start"
			state.launch_delay_until = 72 # 0.6 s, measured from lights-out.

static func advance(state: VehicleState, frame: DriveFrame) -> void:
	initialize(state, frame.launch_start)
	if not state.launch_pending: return
	if state.tick > 54:
		state.launch_pending = false
		return
	if frame.throttle == 0: return
	state.launch_pending = false
	if state.tick < 10: # First sample at >=80 ms is tick 10 (83.3 ms).
		state.launch_result = "Jumped start"
		state.launch_delay_until = state.tick + 6 # Tiny 50 ms delay; no bonus.
	elif state.tick < 22:
		state.launch_result = "Perfect start"
		state.launch_gain = 0.12
		state.launch_end_tick = state.tick + 84
	elif state.tick < 36:
		state.launch_result = "Great start"
		state.launch_gain = 0.08
		state.launch_end_tick = state.tick + 72
	elif state.tick < 54:
		state.launch_result = "Good start"
		state.launch_gain = 0.04
		state.launch_end_tick = state.tick + 48
