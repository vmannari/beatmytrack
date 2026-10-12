extends SceneTree
## Native diagnostic: does tyre energy modulate an otherwise steady engine?
const OUT: String = "res://../docs/evidence/engine-grass-repair-2026-10-11"
func _initialize() -> void: call_deferred("run")

func run() -> void:
	assert(DisplayServer.get_name()!="headless")
	var label: String = "after" if OS.get_cmdline_user_args().has("--after") else "before"
	if label=="after":
		var compressor: AudioEffectCompressor = AudioServer.get_bus_effect(AudioServer.get_bus_index("Vehicle"),0) as AudioEffectCompressor
		assert(compressor.sidechain==&"Engine")
	var rate: int = AudioServer.get_mix_rate()
	var players: Array[AudioStreamPlayer] = []
	for ground: bool in [false,true]:
		var bytes := PackedByteArray()
		bytes.resize(rate*2*2)
		for index: int in range(rate*2):
			var seconds: float = float(index)/rate
			var value: float = .55*(.12+.88*(.5+.5*sin(TAU*3*seconds)))*sin(TAU*850*seconds) if ground else .15*sin(TAU*40*seconds)
			bytes.encode_s16(index*2,roundi(value*32767))
		var source := AudioStreamWAV.new()
		source.format = AudioStreamWAV.FORMAT_16_BITS
		source.mix_rate = rate
		source.data = bytes
		var player := AudioStreamPlayer.new()
		player.stream = PcmAudioLoop.prepare(source)
		player.bus = "Tires" if ground else "Engine"
		player.volume_linear = 0.0 if ground else 1.0
		root.add_child(player)
		player.play()
		players.append(player)
	await create_timer(.25).timeout
	var recorder := AudioEffectRecord.new()
	recorder.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0,recorder)
	recorder.set_recording_active(true)
	await create_timer(.6).timeout
	players[1].volume_linear = 1.0
	await create_timer(3.0).timeout
	for player: AudioStreamPlayer in players: player.volume_linear = 0.0
	await create_timer(.4).timeout
	recorder.set_recording_active(false)
	assert(recorder.get_recording().save_to_wav(OUT.path_join(label+"-engine-surface-probe.wav"))==OK)
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	for player: AudioStreamPlayer in players: player.free()
	players.clear()
	await create_timer(.15).timeout
	print("ENGINE_SURFACE_PROBE: ",label)
	quit()
