extends SceneTree
## Offline decode using the pinned engine; source files remain outside exports.
func _initialize() -> void:
	const BASE: String = "res://../build/grass_nature/sources/moving_leaves"
	var stream: AudioStreamOggVorbis = AudioStreamOggVorbis.load_from_file(BASE + ".ogg")
	if stream == null or stream.get_length() <= 0.0 or stream.get_length() > 12.0:
		push_error("Expected short cleared leaf recording")
		quit(1)
		return
	var playback: AudioStreamPlayback = stream.instantiate_playback()
	playback.start()
	var samples: PackedVector2Array = playback.mix_audio(1.0, ceili(stream.get_length() * AudioServer.get_mix_rate()))
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 4)
	for index: int in range(samples.size()): bytes.encode_float(index * 4, (samples[index].x + samples[index].y) * 0.5)
	var file := FileAccess.open(BASE + ".f32", FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	var meta := FileAccess.open(BASE + ".decode.json", FileAccess.WRITE)
	meta.store_string(JSON.stringify({"rate": AudioServer.get_mix_rate(), "seconds": stream.get_length(), "frames": samples.size(), "sha256": FileAccess.get_sha256(BASE + ".f32")}))
	meta.close()
	print("GRASS_LEAVES_DECODE: %d frames, %.3fs" % [samples.size(), stream.get_length()])
	quit()
