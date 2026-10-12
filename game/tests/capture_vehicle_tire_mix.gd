extends SceneTree
## Local A/B of the owner-requested tire presence change; actual master-bus audio.
const OUTPUT: String = "res://../docs/evidence/vehicle-audio-continuity-2026-10-06"

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	if DisplayServer.get_name()=="headless":
		print("TIRE_MIX_CAPTURE requires -Graphical")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var record := AudioEffectRecord.new()
	record.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0,record)
	for variant: String in ["before","after"]:
		var audio := VehicleAudio.new()
		root.add_child(audio)
		audio.configure("compact",VehicleCatalog.config("compact"))
		var state := VehicleState.new()
		var frame: DriveFrame = DriveFrame.sample(0.0,0.45,0.0)
		var elapsed: float = 0.0
		var clock_usec: int = Time.get_ticks_usec()
		record.set_recording_active(true)
		while elapsed<6.0:
			await process_frame
			var now_usec: int = Time.get_ticks_usec()
			var delta: float = float(now_usec-clock_usec)/1000000.0
			clock_usec = now_usec
			elapsed += delta
			state.tick += 1
			# Same held slide in both variants; quiet straight/paused portions give context.
			state.velocity = Vector2(7.0 if elapsed>1.0 and elapsed<4.8 else 0.0,25.0)
			audio.present(state,frame,null,delta,elapsed>5.3)
			if variant=="before":
				(audio.layers.tire as AudioStreamPlayer).volume_db += linear_to_db(0.38/0.62)
		record.set_recording_active(false)
		var sample: AudioStreamWAV = record.get_recording()
		if sample==null or sample.save_to_wav(OUTPUT.path_join("tires-"+variant+".wav"))!=OK:
			audio.free()
			quit(1)
			return
		audio.free()
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	print("TIRE_MIX_CAPTURE: before/after saved; dry-slip gain +%.2f dB"%linear_to_db(0.62/0.38))
	quit(0)
