class_name HandlingRecorder
extends RefCounted
## Diagnostic experiment only, not verified competitive replay or telemetry upload.

const LIMIT: int = 120 * 120
var active: bool = false
var frames: Array = []
var checkpoints: Array = []
var header: Dictionary = {}


func start(sim: VehicleSimulation, yard: PlaygroundData) -> void:
	frames.clear()
	checkpoints.clear()
	header = {"schema_version": 6, "physics_version": VehicleSimulation.PHYSICS_VERSION,
		"tick_rate": VehicleSimulation.TICK_RATE, "engine": Engine.get_version_info().string,
		"handling": sim.config.snapshot(), "yard": yard.identity, "initial_state": sim.state.snapshot()}
	if yard is NativeTrack:
		header["track_sha256"] = (yard as NativeTrack).content_hash
	active = true


func append(frame: DriveFrame, state: VehicleState) -> void:
	if not active or frames.size() >= LIMIT:
		return
	frames.append(frame.packed())
	if frames.size() % 120 == 0:
		checkpoints.append({"after_input": frames.size(), "state": state.snapshot()})


func save(state: VehicleState, path: String = "user://handling_capture.json") -> Error:
	active = false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"manifest": header, "inputs": frames,
		"checkpoints": checkpoints, "final_state": state.snapshot()}))
	file.flush()
	return file.get_error()
