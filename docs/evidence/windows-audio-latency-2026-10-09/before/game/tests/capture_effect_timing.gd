extends SceneTree
## PCM reference and SFX share an audio clock: measure event dispatch and bus delay.
const OUT: String = "res://../docs/evidence/effect-timing-2026-10-08"
var results: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name()=="headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(VehicleAudio.BANK+"manifest.json"))
	var variant: String = "before" if manifest.revision=="surface-impact-2" else "after"
	var reference_bus: int = AudioServer.get_bus_count()
	AudioServer.add_bus()
	AudioServer.set_bus_name(reference_bus,"TimingReference")
	AudioServer.set_bus_send(reference_bus,"Master")
	var reference_record := AudioEffectRecord.new()
	var vehicle_record := AudioEffectRecord.new()
	var output_record := AudioEffectRecord.new()
	for record: AudioEffectRecord in [reference_record,vehicle_record,output_record]: record.format = AudioStreamWAV.FORMAT_16_BITS
	var vehicle_bus: int = AudioServer.get_bus_index("Vehicle")
	AudioServer.add_bus_effect(reference_bus,reference_record)
	AudioServer.add_bus_effect(vehicle_bus,vehicle_record,0)
	AudioServer.add_bus_effect(0,output_record)
	var marker := AudioStreamPlayer.new()
	marker.bus = "TimingReference"
	marker.volume_linear = .01
	var pulse := AudioStreamWAV.new()
	pulse.mix_rate = 44100
	pulse.format = AudioStreamWAV.FORMAT_16_BITS
	var marker_pcm := PackedByteArray()
	marker_pcm.resize(882)
	for i: int in range(441): marker_pcm.encode_s16(i*2,16000 if i%2==0 else -16000)
	pulse.data = marker_pcm
	marker.stream = pulse
	root.add_child(marker)
	var audio := VehicleAudio.new()
	root.add_child(audio)
	audio.configure("compact",VehicleCatalog.config("compact"))
	var state := VehicleState.new()
	state.velocity = Vector2.ZERO
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Engine"),true)
	# Warm the audio device/recorders, without a queue of synchronous audio tests.
	audio.present(state,DriveFrame.new(),null,.016,false)
	await create_timer(.35).timeout
	for trial: int in range(5):
		audio.reset()
		audio.present(state,DriveFrame.new(),null,.016,false)
		await create_timer(.12).timeout
		for record: AudioEffectRecord in [reference_record,vehicle_record,output_record]: record.set_recording_active(true)
		await create_timer(.12).timeout
		marker.play()
		var start_us: int = Time.get_ticks_usec()
		audio.collision(Vector2(20,0))
		var direct: bool = audio.impact_count>0
		# A 30ms presentation workload models a slow render-frame callback.
		# It is deliberately confined to this diagnostic, never shipping code.
		OS.delay_msec(30)
		audio.present(state,DriveFrame.new(),null,.05,false)
		var dispatch_us: int = Time.get_ticks_usec()-start_us
		await create_timer(.35).timeout
		for record: AudioEffectRecord in [reference_record,vehicle_record,output_record]: record.set_recording_active(false)
		var row: Dictionary = {"trial":trial,"variant":variant,"direct_dispatch":direct,"presentation_gap_ms":float(dispatch_us)/1000.0,"driver_output_ms":AudioServer.get_output_latency()*1000.0}
		for label: String in ["marker","vehicle","output"]:
			var record: AudioEffectRecord = reference_record if label=="marker" else vehicle_record if label=="vehicle" else output_record
			var sample: AudioStreamWAV = record.get_recording()
			sample.save_to_wav(OUT.path_join("%s-%d-%s.wav"%[variant,trial,label]))
			var pcm: PackedByteArray = sample.data
			var onset: int = -1
			for offset: int in range(0,pcm.size(),4):
				if absi(pcm.decode_s16(offset))>(500 if label=="output" else 40):
					onset = offset/4
					break
			row[label+"_onset_ms"] = float(onset)/sample.mix_rate*1000.0
		row.raw_delay_ms = row.vehicle_onset_ms-row.marker_onset_ms
		results.append(row)
		await create_timer(.05).timeout
	var report: FileAccess = FileAccess.open(OUT.path_join(variant+"-dispatch.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify(results,"\t"))
	report.close()
	print("EFFECT_TIMING_CAPTURE: ",JSON.stringify(results))
	audio.free()
	marker.free()
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Engine"),false)
	AudioServer.remove_bus_effect(vehicle_bus,0)
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	AudioServer.remove_bus(reference_bus)
	quit()
