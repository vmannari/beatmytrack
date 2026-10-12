extends SceneTree
## Offline pinned-engine loop decoder and sample-accurate PCM boundary witness.
const OUTPUT: String = "res://../build/audio_loop_audit"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var reports: Array[Dictionary] = []
	for guarded: bool in [false,true]:
		for pitch: float in [0.73,1.0,1.85]:
			var sample := AudioStreamWAV.new()
			sample.format = AudioStreamWAV.FORMAT_16_BITS
			sample.mix_rate = AudioServer.get_mix_rate()
			var pcm := PackedByteArray()
			pcm.resize(997*2)
			for frame: int in range(997): pcm.encode_s16(frame*2,8192)
			sample.loop_mode = AudioStreamWAV.LOOP_FORWARD
			sample.loop_begin = 0
			sample.loop_end = 997
			if guarded: pcm.append_array(pcm.slice(0,2))
			sample.data = pcm
			var playback: AudioStreamPlayback = sample.instantiate_playback()
			playback.start()
			var mixed: PackedVector2Array = playback.mix_audio(pitch,20000)
			var minimum: float = 1.0
			var glitches: int = 0
			for index: int in range(500,mixed.size()):
				minimum = minf(minimum,mixed[index].x)
				if mixed[index].x<0.249: glitches += 1
			reports.append({"guard":guarded,"pitch":pitch,"minimum":minimum,"glitch_samples":glitches})
			print("PCM_BOUNDARY: ",reports[-1])
	var file := FileAccess.open(OUTPUT.path_join("endpoint-probe.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(reports,"\t"))
	file.close()
	if OS.get_cmdline_user_args().has("--probe-only"):
		quit(0)
		return
	var decoded: Array[Dictionary] = []
	for family: String in ["locked_in_v1","score_v1"]:
		var folder: String = "res://assets/audio/"+family
		for filename: String in DirAccess.get_files_at(folder):
			if not filename.ends_with(".ogg"): continue
			var source: String = folder.path_join(filename)
			var stream: AudioStreamOggVorbis = (load(source) as AudioStreamOggVorbis).duplicate() as AudioStreamOggVorbis
			stream.loop = true
			stream.loop_offset = 0
			var playback: AudioStreamPlayback = stream.instantiate_playback()
			playback.start()
			var samples: PackedVector2Array = playback.mix_audio(1.0,ceili((stream.get_length()+0.25)*AudioServer.get_mix_rate()))
			var bytes: PackedByteArray = samples.to_byte_array()
			if bytes.size()!=samples.size()*8:
				push_error("Packed vector size differs from float32 stereo")
				quit(1)
				return
			var label: String = family+"_"+filename.trim_suffix(".ogg")
			file = FileAccess.open(OUTPUT.path_join(label+".f32"),FileAccess.WRITE)
			file.store_buffer(bytes)
			file.close()
			decoded.append({"file":source.trim_prefix("res://"),"decoded":label+".f32","rate":AudioServer.get_mix_rate(),"length":stream.get_length(),"frames":samples.size(),"sha256":FileAccess.get_sha256(source),"shipping":family=="locked_in_v1","enabled":false})
			print("LOOP_DECODE: ",label)
	file = FileAccess.open(OUTPUT.path_join("decoded.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(decoded,"\t"))
	file.close()
	print("LOOP_AUDIT_DECODE: ",decoded.size()," Ogg loops")
	quit(0)
