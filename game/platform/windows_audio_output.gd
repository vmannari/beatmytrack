class_name WindowsAudioOutput
extends RefCounted
## One app-owned post-effect output transfer. Other platforms keep Godot output.
var backend: RefCounted
var effect: AudioEffect
var _last_state: Array = []

func configure() -> void:
	if backend!=null or OS.get_name()!="Windows" or AudioServer.get_driver_name()!="WASAPI" or AudioServer.output_device!="Default": return
	if AudioServer.get_speaker_mode()!=AudioServer.SPEAKER_MODE_STEREO: return
	if not ClassDB.class_exists("BmtWindowsMixSink"): return # Older loaded DLL.
	var candidate: RefCounted = ClassDB.instantiate("BmtWindowsMixSink") as RefCounted
	if not bool(candidate.call("open",AudioServer.get_mix_rate())):
		candidate.call("close")
		return
	backend = candidate
	effect = backend.call("make_effect") as AudioEffect
	if effect==null:
		close()
		return
	AudioServer.add_bus_effect(0,effect)
	sync_output()
	print("WINDOWS_MIX_OUTPUT: ",backend.call("stats"))

func sync_output() -> void:
	if backend==null: return
	# Effects run before the Master fader. Apply it once at the final sink.
	var state: Array = [db_to_linear(AudioServer.get_bus_volume_db(0)),AudioServer.is_bus_mute(0),AudioServer.output_device=="Default"]
	if state!=_last_state:
		backend.call("set_output",state[0],state[1],state[2])
		_last_state = state
	# Keep diagnostic recorders and any later bus effects upstream of transfer.
	var last: int = AudioServer.get_bus_effect_count(0)-1
	if last<0: return
	if AudioServer.get_bus_effect(0,last)==effect: return
	for index: int in range(last):
		if AudioServer.get_bus_effect(0,index)==effect:
			for cursor: int in range(index,last):
				AudioServer.swap_bus_effects(0,cursor,cursor+1)
			return

func stats() -> Dictionary:
	return backend.call("stats") as Dictionary if backend!=null else {"ready":false}

func close() -> void:
	if effect!=null:
		for index: int in range(AudioServer.get_bus_effect_count(0)):
			if AudioServer.get_bus_effect(0,index)==effect:
				AudioServer.remove_bus_effect(0,index)
				break
	if backend!=null: backend.call("close")
	effect = null
	backend = null
	_last_state = []
