class_name WindowsImpactAudio
extends RefCounted
## Optional desktop output adapter; never runs in simulation or Android.
var backend: RefCounted
var paused: bool = false

func configure(samples: Array[AudioStreamWAV]) -> void:
	if OS.get_name()!="Windows" or AudioServer.get_driver_name()!="WASAPI" or AudioServer.output_device!="Default": return
	if not ClassDB.class_exists("BmtWindowsImpact"): return
	backend = ClassDB.instantiate("BmtWindowsImpact") as RefCounted
	for i: int in range(samples.size()):
		if not bool(backend.call("load_pcm",i,samples[i].data,samples[i].mix_rate)):
			close()
			return
	if not bool(backend.call("open")):
		print("WINDOWS_IMPACT_AUDIO: normal Godot fallback ",backend.call("stats"))
		close()
	else:
		print("WINDOWS_IMPACT_AUDIO: ",backend.call("stats"))
		sync_output(false)

func sync_output(silent: bool) -> void:
	paused = silent
	if backend==null: return
	var impact: int = AudioServer.get_bus_index("Impacts")
	var master: int = AudioServer.get_bus_index("Master")
	var vehicle: int = AudioServer.get_bus_index("Vehicle")
	var mute: bool = AudioServer.is_bus_mute(impact) or AudioServer.is_bus_mute(master) or AudioServer.output_device!="Default"
	var chassis_mute: bool = AudioServer.is_bus_mute(vehicle) or AudioServer.is_bus_mute(master) or AudioServer.output_device!="Default"
	var solo_mode: bool = false
	var impact_soloed: bool = false
	var vehicle_soloed: bool = false
	for bus: int in range(AudioServer.bus_count):
		if not AudioServer.is_bus_solo(bus): continue
		solo_mode = true
		var send: int = bus
		for depth: int in range(AudioServer.bus_count):
			if send==impact: impact_soloed = true
			if send==vehicle: vehicle_soloed = true
			if send<=0: break
			send = AudioServer.get_bus_index(AudioServer.get_bus_send(send))
	if solo_mode and not impact_soloed: mute = true
	if solo_mode and not vehicle_soloed: chassis_mute = true
	backend.call("set_output",db_to_linear(AudioServer.get_bus_volume_db(impact)),db_to_linear(AudioServer.get_bus_volume_db(master)),mute,silent)
	# An already running development game may still hold the previous DLL until
	# restart; keep that live instance functional during a script reload.
	if backend.has_method("set_chassis_output"):
		backend.call("set_chassis_output",db_to_linear(AudioServer.get_bus_volume_db(vehicle)),chassis_mute)

func play(index: int, amplitude: float, pitch: float, slot: int = -1) -> bool:
	if backend==null or AudioServer.output_device!="Default": return false
	sync_output(false)
	return bool(backend.call("play",index,amplitude,pitch,slot))

func stop_voice(slot: int) -> void:
	if backend!=null: backend.call("stop_voice",slot)

func reset() -> void:
	if backend!=null: backend.call("clear")
	paused = false

func stats() -> Dictionary:
	return backend.call("stats") as Dictionary if backend!=null else {"ready":false}

func close() -> void:
	if backend!=null: backend.call("close")
	backend = null
