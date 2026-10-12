extends SceneTree
## Read-only pinned-engine latency snapshot for the sound timing investigation.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	await create_timer(.25).timeout
	var settings: Dictionary = {}
	for key: String in ["audio/driver/output_latency","audio/driver/output_latency.android","audio/driver/mix_rate"]:
		settings[key] = ProjectSettings.get_setting(key)
	print("EFFECT_TIMING_BASELINE: ",JSON.stringify({"settings":settings,"driver":AudioServer.get_driver_name(),"mix_rate":AudioServer.get_mix_rate(),"output_latency_ms":AudioServer.get_output_latency()*1000.0,"next_mix_ms":AudioServer.get_time_to_next_mix()*1000.0,"effects":AudioServer.get_bus_effect_count(AudioServer.get_bus_index("Vehicle"))}))
	quit()
