extends SceneTree
## Native impact/raw/master comparison. Full-transient onset and peak protection.
const OUT: String = "res://../docs/evidence/collision-attack-2026-10-08"
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func run() -> void:
	if DisplayServer.get_name()=="headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var impact_bus: int = AudioServer.get_bus_index("Impacts")
	var raw := AudioEffectRecord.new()
	var output := AudioEffectRecord.new()
	raw.format = AudioStreamWAV.FORMAT_16_BITS
	output.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(impact_bus,raw,0)
	AudioServer.add_bus_effect(0,output)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Engine"),true)
	var rows: Array[Dictionary] = []
	var audio := VehicleAudio.new()
	root.add_child(audio)
	audio.configure("compact",VehicleCatalog.config("compact"))
	for trial: int in range(6):
		audio.reset()
		await create_timer(.15).timeout
		raw.set_recording_active(true)
		output.set_recording_active(true)
		await create_timer(.12).timeout
		audio.begin_physics_feedback()
		var strength: float = [2.5,9.0,20.0][trial%3]
		audio.collision(Vector2(strength,0))
		check(audio.impact_count==1,"contact starts before the first presentation callback")
		await create_timer(.8).timeout
		raw.set_recording_active(false)
		output.set_recording_active(false)
		var row: Dictionary = {"trial":trial,"strength":strength,"driver_latency_ms":AudioServer.get_output_latency()*1000.0}
		for label: String in ["raw","output"]:
			var sample: AudioStreamWAV = (raw if label=="raw" else output).get_recording()
			check(sample.save_to_wav(OUT.path_join("impact-%d-%s.wav"%[trial,label]))==OK,"saved "+label+" PCM")
			var pcm: PackedByteArray = sample.data
			var peak: int = 0
			for offset: int in range(0,pcm.size(),4): peak = maxi(peak,absi(pcm.decode_s16(offset)))
			var first: int = -1
			var strong: int = -1
			for offset: int in range(0,pcm.size(),4):
				var value: int = absi(pcm.decode_s16(offset))
				if first<0 and value>40: first = offset/4
				if strong<0 and value>int(float(peak)*.5): strong = offset/4
			row[label+"_onset_ms"] = float(first)/sample.mix_rate*1000.0
			row[label+"_strong_ms"] = float(strong)/sample.mix_rate*1000.0
			row[label+"_peak"] = peak
			check(first>=0 and float(strong-first)/sample.mix_rate<.0005,"no audible fade-in before the strong contact: "+label)
			if label=="output": check(peak<29000,"final output stays inside retained ceiling")
		row.route_delay_ms = row.output_onset_ms-row.raw_onset_ms
		check(absf(float(row.route_delay_ms))<3.0,"direct contact route has only the retained master lookahead")
		rows.append(row)
	var report: FileAccess = FileAccess.open(OUT.path_join("capture-timing.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify(rows,"\t"))
	report.close()
	print("COLLISION_ATTACK_CAPTURE: ",JSON.stringify(rows))
	audio.free()
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Engine"),false)
	AudioServer.remove_bus_effect(impact_bus,0)
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	await create_timer(.15).timeout
	print("COLLISION_ATTACK_CAPTURE_CHECKS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
