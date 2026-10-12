extends SceneTree
## Matched fixed-RPM native recordings include the neighboring-layer/load blend.
const OUTPUT: String = "res://../docs/evidence/compact-period-2026-10-10"
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func sample(clip: String, variant: String) -> AudioStreamWAV:
	if variant=="after":
		return (load(VehicleAudio.BANK+clip+".wav") as AudioStreamWAV).duplicate() as AudioStreamWAV
	# Saved masters outside the export root are canonical 44-byte mono PCM WAVs.
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(OUTPUT.path_join("before/game/assets/audio/vehicles/"+clip+".wav"))
	if bytes.size()<44 or bytes.decode_u16(20)!=1 or bytes.decode_u16(22)!=1 or bytes.decode_u32(24)!=44100 or bytes.decode_u16(34)!=16:
		push_error("Unexpected diagnostic WAV format")
		failures += 1
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	stream.stereo = false
	stream.data = bytes.slice(44)
	return stream

func run() -> void:
	if DisplayServer.get_name()=="headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var bus: int = AudioServer.get_bus_index("Engine")
	var recorder := AudioEffectRecord.new()
	recorder.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(bus,recorder)
	var reports: Array[Dictionary] = []
	for variant: String in ["before","after"]:
		for fixture: String in ["high","overlap"]:
			var players: Array[AudioStreamPlayer] = []
			var weights: Vector3 = Vector3(0,0,1)
			if fixture=="overlap":
				var model := VehicleAudioModel.new()
				model.configure("compact",46)
				model.rpm = 4500
				weights = model.weights()
			for index: int in [1,2]:
				for mode: String in ["load","coast"]:
					var stream: AudioStreamWAV = sample("compact_%d_%s"%[index,mode],variant)
					stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
					stream.loop_begin = 0
					stream.loop_end = stream.data.size()/2
					var player := AudioStreamPlayer.new()
					player.stream = stream
					player.bus = "Engine"
					player.pitch_scale = (6000.0 if fixture=="high" else 4500.0)/([3000.0,6000.0][index-1])
					player.volume_linear = weights[index]*sqrt(0.65 if mode=="load" else 0.35)*0.6*(1.0 if mode=="load" else 0.84)
					root.add_child(player)
					players.append(player)
			for player: AudioStreamPlayer in players: player.play()
			var elapsed: float = 0.0
			var clock_us: int = Time.get_ticks_usec()
			var wraps: Array[int] = [0,0,0,0]
			var positions: Array[float] = [0,0,0,0]
			recorder.set_recording_active(true)
			while elapsed<26.0:
				await process_frame
				var now: int = Time.get_ticks_usec()
				elapsed += float(now-clock_us)/1000000.0
				clock_us = now
				for index: int in range(players.size()):
					var position: float = players[index].get_playback_position()
					if position+0.1<positions[index]: wraps[index] += 1
					positions[index] = position
					if elapsed>=25.0: players[index].stream_paused = true
			recorder.set_recording_active(false)
			var recording: AudioStreamWAV = recorder.get_recording()
			if recording==null or recording.get_length()<25.5: failures += 1
			elif recording.save_to_wav(OUTPUT.path_join(variant+"-"+fixture+".wav"))!=OK: failures += 1
			for count: int in wraps:
				if count<2: failures += 1
			reports.append({"variant":variant,"fixture":fixture,"wraps":wraps})
			for player: AudioStreamPlayer in players: player.free()
			print("COMPACT_SUSTAIN: ",variant," ",fixture," wraps=",wraps)
	AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
	var file := FileAccess.open(OUTPUT.path_join("native-capture.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"reports":reports,"failures":failures},"\t"))
	file.close()
	print("COMPACT_SUSTAIN_CAPTURE: failures=",failures)
	quit(1 if failures>0 else 0)
