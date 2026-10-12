extends SceneTree
## Offline build tooling: decode the cleared public rural-rain preview.
func _initialize() -> void:
	var path: String = "res://../build/storm_rain_sources/rural-rain-200271"
	var stream := AudioStreamMP3.new()
	stream.data = FileAccess.get_file_as_bytes(path+".mp3")
	var playback: AudioStreamPlayback = stream.instantiate_playback()
	playback.start()
	var samples: PackedVector2Array = playback.mix_audio(1.0,ceili(stream.get_length()*AudioServer.get_mix_rate()))
	var bytes := PackedByteArray()
	bytes.resize(samples.size()*4)
	for i: int in range(samples.size()): bytes.encode_float(i*4,(samples[i].x+samples[i].y)*0.5)
	var file := FileAccess.open(path+".f32",FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	var meta := FileAccess.open(path+".decode.json",FileAccess.WRITE)
	meta.store_string(JSON.stringify({"rate":AudioServer.get_mix_rate(),"frames":samples.size(),"seconds":stream.get_length(),"sha256":FileAccess.get_sha256(path+".f32")}))
	meta.close()
	print("RURAL_RAIN_DECODE: %d frames at %d Hz"%[samples.size(),AudioServer.get_mix_rate()])
	quit()
