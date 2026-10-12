extends "res://tests/test_surface_impact_audio.gd"
## Capture in a fresh process, without flooding the audio command queue with
## thousands of synchronous behavioral-test play/stop commands first.

func run() -> void:
	if DisplayServer.get_name()=="headless":
		print("SURFACE_IMPACT_CAPTURE requires -Graphical")
		quit(1)
		return
	var track: NativeTrack = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	await process_frame
	await capture(track,VehicleCatalog.config("compact"))
	print("SURFACE_IMPACT_CAPTURE: %d checks, %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
