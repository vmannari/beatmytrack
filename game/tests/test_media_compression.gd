extends SceneTree
## Native decoder loops/seeks/pitch, unchanged masters and real runtime selection.
const OUT: String = "res://../docs/evidence/media-compression-2026-10-12"
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", message)

func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/compressed/manifest.json"))
	check(manifest.outputs.size() == 19, "complete compressed loop inventory")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.path_join("native-loops")))
	var reports: Array[Dictionary] = []
	var mix_rate: int = int(AudioServer.get_mix_rate())
	for row: Dictionary in manifest.outputs:
		var master_path: String = "res://" + str(row.master).trim_prefix("game/")
		var encoded_path: String = "res://" + str(row.encoded).trim_prefix("game/")
		check(FileAccess.get_sha256(master_path) == row.master_sha256, "unchanged master: " + master_path)
		check(FileAccess.get_sha256(encoded_path) == row.encoded_sha256, "traceable compression: " + encoded_path)
		check(float(row.snr_db) >= 30.0 and absf(float(row.rms_change_db)) < .15 and float(row.peak) < 1.0, "independent decoded quality: " + encoded_path)
		var source: AudioStreamWAV = load(master_path) as AudioStreamWAV
		var original: AudioStreamWAV = PcmAudioLoop.prepare(source)
		var encoded: AudioStreamOggVorbis = load(encoded_path) as AudioStreamOggVorbis
		var loop: AudioStreamOggVorbis = AudioLoop.prepare(encoded) as AudioStreamOggVorbis
		check(loop != encoded and not encoded.loop and loop.loop and loop.loop_offset == 0, "shared source resource is untouched: " + encoded_path)
		check(absf(loop.get_length() - float(row.duration_seconds)) < 1.0 / 44100.0 and loop.packet_sequence.sampling_rate == 44100, "original duration/sample rate: " + encoded_path)
		for pitch: float in [.85, 1.0, 1.3]:
			var playback: AudioStreamPlayback = loop.instantiate_playback()
			var reference: AudioStreamPlayback = original.instantiate_playback()
			var start: float = loop.get_length() - .75 * pitch
			playback.start(start)
			reference.start(start)
			var began: int = Time.get_ticks_usec()
			var frames: PackedVector2Array = playback.mix_audio(pitch, mix_rate * 2)
			var decode_us: int = Time.get_ticks_usec() - began
			var baseline: PackedVector2Array = reference.mix_audio(pitch, mix_rate * 2)
			check(frames.size() == mix_rate * 2 and playback.get_loop_count() >= 1 and playback.is_playing(), "full native seek/wrap/pitch: " + encoded_path + " @" + str(pitch))
			var peak: float = 0.0
			var largest_step: float = 0.0
			var reference_step: float = 0.0
			var new_dropouts: int = 0
			var window: int = maxi(1, mix_rate / 100)
			var energy: float = 0.0
			var original_energy: float = 0.0
			for i: int in range(frames.size()):
				var frame: Vector2 = frames[i]
				peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
				if i > 0:
					largest_step = maxf(largest_step, maxf(absf(frame.x-frames[i-1].x),absf(frame.y-frames[i-1].y)))
					reference_step = maxf(reference_step, maxf(absf(baseline[i].x-baseline[i-1].x),absf(baseline[i].y-baseline[i-1].y)))
				energy += frame.length_squared()
				original_energy += baseline[i].length_squared()
				if (i+1) % window == 0:
					if original_energy > .0001 and energy < original_energy*.0016: new_dropouts += 1
					energy = 0.0
					original_energy = 0.0
			check(is_finite(peak) and peak > 0 and peak < 1.0 and new_dropouts == 0, "native output has no clipping or new gaps: " + encoded_path + " @" + str(pitch))
			check(largest_step <= maxf(.02, reference_step * 2.0), "native wrap has no excessive discontinuity: " + encoded_path + " @" + str(pitch))
			reports.append({"asset":encoded_path,"pitch":pitch,"peak":peak,"new_dropout_windows":new_dropouts,
				"maximum_step":largest_step,"reference_maximum_step":reference_step,"two_seconds_decode_us":decode_us})
			if pitch == 1.0:
				var capture := AudioStreamWAV.new()
				capture.format = AudioStreamWAV.FORMAT_16_BITS
				capture.stereo = true
				capture.mix_rate = mix_rate
				var pcm := PackedByteArray()
				pcm.resize(frames.size() * 4)
				for i: int in range(frames.size()):
					pcm.encode_s16(i*4, int(roundf(clampf(frames[i].x,-1,1)*32767)))
					pcm.encode_s16(i*4+2, int(roundf(clampf(frames[i].y,-1,1)*32767)))
				capture.data = pcm
				check(capture.save_to_wav(OUT.path_join("native-loops/" + encoded_path.get_file().get_basename() + ".wav")) == OK, "native playable wrap preview saved")
			playback.stop()
			reference.stop()
	var vehicle := VehicleAudio.new()
	vehicle.use_windows_impacts = false
	root.add_child(vehicle)
	for clip: String in VehicleAudio.COMPRESSED_LOOPS:
		check(vehicle._stream(clip,true) is AudioStreamOggVorbis, "vehicle uses compressed bed: " + clip)
	for clip: String in VehicleAudio.BODY_CLIPS:
		check(vehicle._stream(clip,false) is AudioStreamWAV, "responsive impact remains PCM: " + clip)
	vehicle.configure("compact",VehicleCatalog.config("compact"))
	if DisplayServer.get_name() == "headless":
		check(not vehicle.engine_load[0].playing and not (vehicle.layers.road as AudioStreamPlayer).playing,
			"headless diagnostics allocate no output decoder voices")
	check(GameSoundtrack.instance().menu_player.stream is AudioStreamOggVorbis, "actual menu uses compressed recording")
	vehicle.free()
	var output: FileAccess = FileAccess.open(OUT.path_join("native-audio-quality.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"mix_rate":mix_rate,"outputs":reports},"\t")+"\n")
	print("MEDIA_COMPRESSION_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
