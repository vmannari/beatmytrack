extends SceneTree
## Offline asset tooling: decode the public CC0 previews using the pinned engine.

func _initialize() -> void:
	for clip: String in ["collision_cc0", "gravel_drive_cc0", "stone_metal_cc0"]:
		var path: String = "res://../build/vehicle_audio_sources/" + clip
		var stream := AudioStreamMP3.new()
		stream.data = FileAccess.get_file_as_bytes(path + ".mp3")
		var playback: AudioStreamPlayback = stream.instantiate_playback()
		playback.start()
		var samples: PackedVector2Array = playback.mix_audio(1.0, ceili(stream.get_length() * AudioServer.get_mix_rate()))
		var bytes := PackedByteArray()
		bytes.resize(samples.size() * 4)
		for i: int in range(samples.size()):
			bytes.encode_float(i * 4, (samples[i].x + samples[i].y) * 0.5)
		var file: FileAccess = FileAccess.open(path + ".f32", FileAccess.WRITE)
		file.store_buffer(bytes)
		file.close()
		var meta: FileAccess = FileAccess.open(path + ".decode.json", FileAccess.WRITE)
		meta.store_string(JSON.stringify({"rate": AudioServer.get_mix_rate(), "frames": samples.size(), "seconds": stream.get_length()}))
		meta.close()
		print("DECODED: ", clip, " ", samples.size(), " frames at ", AudioServer.get_mix_rate())
	quit()
