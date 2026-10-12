extends SceneTree
## Synthetic presentation states isolate shift cues from actual road contacts.
const OUTPUT: String = "res://../docs/evidence/acceleration-knock-2026-10-10"
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_warning(message)

func observed_script(path: String) -> GDScript:
	var source: String = FileAccess.get_file_as_string(path)
	source = source.substr(source.find("\n")+1)
	source = source.replace("extends Node\n", "extends Node\nvar knock_trace: Array[Dictionary] = []\n")
	var signature: String = "func _event(clip: String, amplitude: float, pitch: float = 1.0, debris: bool = false) -> void:\n"
	source = source.replace(signature, signature+"\tknock_trace.append({\"clip\":clip,\"pitch\":pitch,\"amplitude\":amplitude,\"tick\":last_tick,\"gear\":model.gear})\n")
	var script := GDScript.new()
	script.source_code = source
	expect(script.reload()==OK,"Observed audio script compiles")
	return script

func make_audio(script: GDScript, car: String) -> Node:
	var audio: Node = script.new()
	# The native Windows body adapter bypasses Godot's recorder. Use the existing
	# fallback for this diagnostic only; production routing remains unchanged.
	audio.set("use_windows_impacts",false)
	root.add_child(audio)
	audio.call("configure",car,VehicleCatalog.config(car))
	return audio

func run() -> void:
	var prior: GDScript = observed_script(OUTPUT.path_join("before/game/vehicle/vehicle_audio.gd"))
	var current: GDScript = observed_script("res://vehicle/vehicle_audio.gd")
	if failures>0:
		quit(1)
		return
	var baseline_only: bool = OS.get_cmdline_user_args().has("--baseline")
	var reports: Array[Dictionary] = []
	for variant: String in ["before"] if baseline_only else ["before","after"]:
		for car: String in ["compact","pickup","classic","formula","kart"]:
			for fixture: String in ["stationary","acceleration"]:
				var audio: Node = make_audio(prior if variant=="before" else current,car)
				var state := VehicleState.new()
				var model: VehicleAudioModel = audio.get("model")
				var positive_shift: bool = false
				for tick: int in range(80):
					state.tick = tick
					state.velocity = Vector2(0,0 if fixture=="stationary" else 46.0*clampf((tick/10.0-1.0)/6.0,0,1))
					var snapshot: Array = state.snapshot()
					audio.call("present",state,DriveFrame.sample(0,1 if tick>=10 else 0,0),null,0.1,false)
					positive_shift = positive_shift or model.shift_remaining>0.0
					expect(state.snapshot()==snapshot,"Audio preserves canonical state")
				var trace: Array = audio.get("knock_trace")
				var expected_body: bool = variant=="before" and fixture=="acceleration" and car!="kart"
				expect((not trace.is_empty())==expected_body,"Only baseline geared acceleration emits body thuds: "+variant+" "+car+" "+fixture)
				if fixture=="acceleration" and car!="kart":
					expect(model.shifts>0 and positive_shift,"Engine RPM shift/cut remains active")
				var report: Dictionary = {"variant":variant,"car":car,"fixture":fixture,"shifts":model.shifts,"events":trace.duplicate(true)}
				# Deceleration should retain the body cue; it accompanies impact deceleration.
				if fixture=="acceleration" and car!="kart":
					trace.clear()
					for tick: int in range(80,160):
						state.tick = tick
						state.velocity = Vector2(0,46.0*(1.0-(tick-80)/80.0))
						audio.call("present",state,DriveFrame.sample(0,0,0),null,0.1,false)
					expect(not trace.is_empty(),"Downshift body cue retained")
					report["downshift_events"] = trace.duplicate(true)
				reports.append(report)
				audio.free()
				await process_frame # Flush freed voices before creating the next bank.
	var file := FileAccess.open(OUTPUT.path_join("baseline.json" if baseline_only else "regression.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"reports":reports},"\t"))
	file.close()
	if not baseline_only and DisplayServer.get_name()!="headless":
		await capture(prior,current)
	print("ACCELERATION_KNOCK: ",checks," checks, ",failures," failures")
	quit(1 if failures>0 else 0)

func capture(prior: GDScript, current: GDScript) -> void:
	var bus: int = AudioServer.get_bus_index("Master")
	var recorder := AudioEffectRecord.new()
	recorder.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(bus,recorder)
	var reports: Array[Dictionary] = []
	for variant: String in ["before","after"]:
		for fixture: String in ["stationary","acceleration"]:
			var audio: Node = make_audio(prior if variant=="before" else current,"compact")
			var state := VehicleState.new()
			await create_timer(0.5).timeout
			var last_us: int = Time.get_ticks_usec()
			var elapsed: float = 0.0
			var telemetry: Array[Dictionary] = []
			recorder.set_recording_active(true)
			while elapsed<9.0:
				await process_frame
				var now_us: int = Time.get_ticks_usec()
				var dt: float = float(now_us-last_us)/1000000.0
				last_us = now_us
				elapsed += dt
				state.tick += 1
				state.velocity = Vector2(0,0 if fixture=="stationary" else 24.0*clampf((elapsed-1.0)/6.0,0,1))
				audio.call("present",state,DriveFrame.sample(0,1 if elapsed>=1.0 else 0,0),null,dt,elapsed>=8.0)
				var model: VehicleAudioModel = audio.get("model")
				telemetry.append({"seconds":elapsed,"tick":state.tick,"speed":state.velocity.length(),"gear":model.gear,"rpm":model.rpm})
			recorder.set_recording_active(false)
			var wav: AudioStreamWAV = recorder.get_recording()
			expect(wav!=null and wav.get_length()>8.5,"Valid native capture duration")
			if wav!=null: expect(wav.save_to_wav(OUTPUT.path_join(variant+"-"+fixture+".wav"))==OK,"Save native capture")
			reports.append({"variant":variant,"fixture":fixture,"events":audio.get("knock_trace"),"telemetry":telemetry})
			audio.free()
			print("ACCELERATION_CAPTURE: ",variant," ",fixture)
	AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
	var file := FileAccess.open(OUTPUT.path_join("native-capture.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"reports":reports,"body_route":"Godot fallback, diagnostic only","failures":failures},"\t"))
	file.close()
