extends SceneTree
var checks: int = 0
var failures: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var rows: Array[Dictionary] = []
	for name: String in ["impact_0","impact_1","impact_2"]:
		var path: String = "res://assets/audio/vehicles/"+name+".wav"
		var sample: AudioStreamWAV = load(path)
		check(sample!=null,"imported clip exists: "+name)
		if sample==null: continue
		check(sample.format==AudioStreamWAV.FORMAT_16_BITS and not sample.stereo and sample.mix_rate==44100,"lossless authored mono PCM format: "+name)
		var wav: PackedByteArray = FileAccess.get_file_as_bytes(path)
		var original := PackedByteArray()
		var offset: int = 12
		while offset+8<=wav.size():
			var count: int = wav.decode_u32(offset+4)
			if wav.slice(offset,offset+4).get_string_from_ascii()=="data":
				original = wav.slice(offset+8,offset+8+count)
				break
			offset += 8+count+(count%2)
		var pcm: PackedByteArray = sample.data
		check(not original.is_empty() and pcm==original,"Godot loads exactly the inspected WAV samples: "+name)
		var frames: int = pcm.size()/2
		var window: int = int(round(sample.mix_rate*.01))
		var energy := PackedFloat64Array()
		energy.resize(frames)
		var peak: int = 0
		for frame: int in range(frames):
			var value: int = pcm.decode_s16(frame*2)
			peak = maxi(peak,absi(value))
			energy[frame] = pow(float(value)/32768.0,2)
		check(absi(pcm.decode_s16(0))>=int(peak*.99),"full impact starts on the first sample: "+name)
		var first: float = 0.0
		for frame: int in range(window): first += energy[frame]
		var loudest: float = first
		var current: float = first
		var strongest_start: int = 0
		for frame: int in range(window,frames):
			current += energy[frame]-energy[frame-window]
			if current>loudest:
				loudest = current
				strongest_start = frame-window+1
		check(first>=loudest*.99,"first 10ms are the strongest sustained impact, not a precursor click: "+name)
		var first_ms: float = 0.0
		for frame: int in range(int(round(sample.mix_rate*.001))): first_ms += energy[frame]
		first_ms = sqrt(first_ms/round(sample.mix_rate*.001))
		check(first_ms>=.2,"first millisecond contains substantial body energy: "+name)
		rows.append({"clip":name,"first_sample":pcm.decode_s16(0),"first_1ms_rms":first_ms,"first_10ms_rms":sqrt(first/window),"loudest_10ms_start_ms":float(strongest_start)/sample.mix_rate*1000.0,"source_pcm_exact":pcm==original})
	print("COLLISION_SOURCE_ONSETS: ",JSON.stringify(rows))
	print("COLLISION_SOURCE_TESTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
