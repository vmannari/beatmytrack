extends SceneTree
## Offline decode of the owner's two rustle clips; never used by gameplay.
func _initialize() -> void:
	for id: String in ["511299","511301"]:
		var path: String = "res://../build/vehicle_audio_sources/owner_grass_"+id
		var stream := AudioStreamMP3.new()
		stream.data = FileAccess.get_file_as_bytes(path+".mp3")
		assert(not stream.data.is_empty())
		var playback: AudioStreamPlayback = stream.instantiate_playback()
		playback.start()
		var rate: int = AudioServer.get_mix_rate()
		var samples: PackedVector2Array = playback.mix_audio(1.0,ceili(stream.get_length()*rate))
		var bytes := PackedByteArray()
		bytes.resize(samples.size()*4)
		for index: int in range(samples.size()): bytes.encode_float(index*4,(samples[index].x+samples[index].y)*.5)
		var file := FileAccess.open(path+".f32",FileAccess.WRITE)
		file.store_buffer(bytes)
		file.close()
		var meta := FileAccess.open(path+".decode.json",FileAccess.WRITE)
		meta.store_string(JSON.stringify({"rate":rate,"frames":samples.size(),"seconds":stream.get_length(),"decoder":Engine.get_version_info().string}))
		meta.close()
		print("OWNER_GRASS_DECODE: ",id," ",samples.size()," frames / ",stream.get_length()," s")
	quit()
