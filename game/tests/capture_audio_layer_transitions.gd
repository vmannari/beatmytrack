extends SceneTree
## Compare exact pre-change/runtime mixes while sweeping RPM/load; sources unchanged.
const OUTPUT: String = "res://../docs/evidence/audio-layer-transitions-2026-10-10"
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func run() -> void:
	if DisplayServer.get_name()=="headless":
		quit(1)
		return
	var prior := GDScript.new()
	var text: String = FileAccess.get_file_as_string(OUTPUT.path_join("before/game/vehicle/vehicle_audio.gd"))
	prior.source_code = text.substr(text.find("\n")+1) # Test-only Node script, without duplicate global class name.
	if prior.reload()!=OK:
		quit(1)
		return
	var bus: int = AudioServer.get_bus_index("Engine")
	var recorder := AudioEffectRecord.new()
	recorder.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(bus,recorder)
	var reports: Array[Dictionary] = []
	for variant: String in ["before","after"]:
		for fixture: String in ["low_mid","mid_high","full_range","load_coast"]:
			var audio: Node = prior.new() if variant=="before" else VehicleAudio.new()
			root.add_child(audio)
			audio.call("configure","compact",VehicleCatalog.config("compact"))
			var model: VehicleAudioModel = audio.get("model")
			var state := VehicleState.new()
			state.velocity = Vector2(0,20)
			var elapsed: float = 0.0
			var clock_us: int = Time.get_ticks_usec()
			var telemetry: Array[Dictionary] = []
			var starting_streams: int = (audio.get("streams") as Dictionary).size()
			# Settle the first native mixer startup before starting wall-time evidence.
			await create_timer(0.5).timeout
			clock_us = Time.get_ticks_usec()
			recorder.set_recording_active(true)
			while elapsed<15.0:
				await process_frame
				var now: int = Time.get_ticks_usec()
				elapsed += float(now-clock_us)/1000000.0
				clock_us = now
				# Endpoint holds 0-2/6-8/12-14; two slow traversals between.
				var blend: float = clampf((elapsed-2.0)/4.0,0,1) if elapsed<8.0 else clampf((12.0-elapsed)/4.0,0,1)
				var rpm: float = 6000.0 if fixture=="load_coast" else lerpf(1200.0,3000.0,blend) if fixture=="low_mid" else lerpf(1200.0,6000.0,blend) if fixture=="full_range" else lerpf(3000.0,6000.0,blend)
				model.rpm = rpm
				model.load_amount = blend if fixture=="load_coast" else 1.0
				model.shift_cooldown = 1.0
				audio.set("engine_envelope",0.6)
				state.tick += 1
				var canonical: Array = state.snapshot()
				audio.call("present",state,DriveFrame.sample(0,1,0),null,0.0,elapsed>=14.0)
				if state.snapshot()!=canonical: failures += 1
				if telemetry.is_empty() or elapsed-float(telemetry[-1].seconds)>=0.05:
					telemetry.append({"seconds":elapsed,"rpm":rpm,"blend":blend,"load":model.load_amount})
			recorder.set_recording_active(false)
			var recording: AudioStreamWAV = recorder.get_recording()
			if recording==null or recording.get_length()<14.5:
				failures += 1
				print("INVALID_NATIVE_RECORDING: ",variant," ",fixture," seconds=",recording.get_length() if recording!=null else -1)
			if recording!=null and recording.save_to_wav(OUTPUT.path_join(variant+"-"+fixture+".wav"))!=OK: failures += 1
			if model.shifts!=0 or audio.get("event_count")!=0: failures += 1
			if (audio.get("streams") as Dictionary).size()!=starting_streams: failures += 1
			reports.append({"variant":variant,"fixture":fixture,"shifts":model.shifts,"events":audio.get("event_count"),"streams":starting_streams,"telemetry":telemetry})
			audio.free()
			print("LAYER_TRANSITION_CAPTURE: ",variant," ",fixture)
	AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
	var file := FileAccess.open(OUTPUT.path_join("native-capture.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"reports":reports,"failures":failures},"\t"))
	file.close()
	print("LAYER_TRANSITION_NATIVE: failures=",failures)
	quit(1 if failures>0 else 0)
