extends SceneTree
## A real interpolation regression, complete runtime PCM inventory and decode bounds.
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func verify(source: AudioStreamWAV, prepared: AudioStreamWAV, label: String) -> void:
	var frame_bytes: int = 4 if source.stereo else 2
	var original: PackedByteArray = source.data
	check(prepared.loop_mode==AudioStreamWAV.LOOP_FORWARD and prepared.loop_begin==0,"full cyclic mode: "+label)
	check(prepared.loop_end==original.size()/frame_bytes,"exact source frame count: "+label)
	check(prepared.data.size()==original.size()+frame_bytes,"one interpolation frame: "+label)
	check(prepared.data.slice(0,original.size())==original and prepared.data.slice(original.size())==original.slice(0,frame_bytes),"unchanged waveform plus exact cyclic endpoint: "+label)

func run() -> void:
	for stereo: bool in [false,true]:
		var source := AudioStreamWAV.new()
		source.format = AudioStreamWAV.FORMAT_16_BITS
		source.mix_rate = AudioServer.get_mix_rate()
		source.stereo = stereo
		var frame_bytes: int = 4 if stereo else 2
		var pcm := PackedByteArray()
		pcm.resize(997*frame_bytes)
		for frame: int in range(997):
			pcm.encode_s16(frame*frame_bytes,8192)
			if stereo: pcm.encode_s16(frame*frame_bytes+2,-8192)
		source.data = pcm
		var prepared: AudioStreamWAV = PcmAudioLoop.prepare(source)
		verify(source,prepared,"constant stereo="+str(stereo))
		check(source.data==pcm and source.loop_mode==AudioStreamWAV.LOOP_DISABLED,"preparation leaves original resource intact")
		for pitch: float in [0.16,0.35,0.73,1.0,1.85,2.85,6.2]:
			var playback: AudioStreamPlayback = prepared.instantiate_playback()
			playback.start()
			var mixed: PackedVector2Array = playback.mix_audio(pitch,20000)
			var maximum_error: float = 0.0
			for frame: int in range(500,mixed.size()):
				maximum_error = maxf(maximum_error,absf(mixed[frame].x-0.25))
				maximum_error = maxf(maximum_error,absf(mixed[frame].y-(-0.25 if stereo else 0.25)))
			check(maximum_error<0.00005,"no sample-level wrap dip at pitch %.2f/stereo=%s"%[pitch,stereo])
	var audio := VehicleAudio.new()
	root.add_child(audio)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(VehicleAudio.BANK+"manifest.json"))
	var loops: int = 0
	for clip: Dictionary in manifest.outputs:
		var source: AudioStreamWAV = load(VehicleAudio.BANK+str(clip.file))
		if bool(clip.loop):
			loops += 1
			verify(source,audio._stream(str(clip.file).trim_suffix(".wav"),true),str(clip.file))
		else:
			check(source.loop_mode==AudioStreamWAV.LOOP_DISABLED,"incident is still a one-shot: "+str(clip.file))
	check(loops==40,"all forty vehicle looping masters covered, including deferred wet asset")
	verify(load("res://assets/audio/vehicles/tire.wav"),TireAudio.make_scrub(),"legacy tire diagnostic")
	var legacy_rain: AudioStreamWAV = load("res://assets/audio/storm_rain.wav")
	verify(legacy_rain,PcmAudioLoop.prepare(legacy_rain),"retained inactive rain")
	var world: GameSoundtrack = root.get_node("AudioWorld")
	verify(load(world.BANK+"menu_theme.wav"),world._menu_loop(),"menu stereo")
	var night := NightAmbience.new()
	root.add_child(night)
	night.configure("night_city")
	verify(load("res://assets/audio/ambience/night_cicadas.wav"),night.player.stream,"night ambience")
	var storm := StormWeather.new()
	root.add_child(storm)
	verify(load("res://assets/audio/ambience/storm_rain_recorded.wav"),storm.rain_audio.stream,"storm rain")
	audio.free()
	night.free()
	storm.free()
	print("AUDIO_LOOP_REGRESSION: %d checks, %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
