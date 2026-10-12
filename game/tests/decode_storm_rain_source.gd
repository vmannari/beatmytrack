extends SceneTree
## Offline build tooling; optionally decode only a bounded owner-selected region.
func _initialize() -> void:
	var path: String = "res://../build/storm_rain_sources/rural-rain-200271"
	var start_seconds: float = 0.0
	var duration: float = 0.0
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--source-path="): path = argument.trim_prefix("--source-path=")
		if argument.begins_with("--source-base="): path = "res://../build/storm_rain_sources/"+argument.trim_prefix("--source-base=")
		if argument.begins_with("--start-seconds="): start_seconds = argument.trim_prefix("--start-seconds=").to_float()
		if argument.begins_with("--seconds="): duration = argument.trim_prefix("--seconds=").to_float()
	var stream := AudioStreamMP3.new()
	stream.data = FileAccess.get_file_as_bytes(path+".mp3")
	var playback: AudioStreamPlayback = stream.instantiate_playback()
	if duration<=0.0: duration = stream.get_length()-start_seconds
	if start_seconds<0.0 or duration<=0.0 or start_seconds+duration>stream.get_length():
		push_error("Requested region is outside the recording")
		quit(1)
		return
	playback.start(start_seconds)
	var samples: PackedVector2Array = playback.mix_audio(1.0,ceili(duration*AudioServer.get_mix_rate()))
	var bytes := PackedByteArray()
	bytes.resize(samples.size()*4)
	for i: int in range(samples.size()): bytes.encode_float(i*4,(samples[i].x+samples[i].y)*0.5)
	var file := FileAccess.open(path+".f32",FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	var meta := FileAccess.open(path+".decode.json",FileAccess.WRITE)
	meta.store_string(JSON.stringify({"rate":AudioServer.get_mix_rate(),"frames":samples.size(),"seconds":duration,"source_seconds":stream.get_length(),"start_seconds":start_seconds,"sha256":FileAccess.get_sha256(path+".f32")}))
	meta.close()
	print("RURAL_RAIN_DECODE: %d frames at %d Hz"%[samples.size(),AudioServer.get_mix_rate()])
	quit()
