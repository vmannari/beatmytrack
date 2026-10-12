extends SceneTree
## Sustained actual vehicle presentation through the native mixer; no race writes.
const OUTPUT: String = "res://../docs/evidence/all-audio-loops-2026-10-10"
var failures: int = 0

func _initialize() -> void: call_deferred("run")

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
	for id: String in VehicleCatalog.IDS:
		var audio := VehicleAudio.new()
		root.add_child(audio)
		var config: HandlingConfig = VehicleCatalog.config(id)
		audio.configure(id,config)
		var rpm: float = sqrt(audio.model.anchors.y*audio.model.anchors.z)
		audio.model.rpm = rpm
		audio.model.gear = 1 if id=="kart" else 3
		audio.model.load_amount = 0.65
		var top: float = config.maximum_speed*(1.04 if id=="kart" else 0.71)
		var speed: float = (rpm-audio.model.idle_rpm)/(audio.model.redline_rpm-audio.model.idle_rpm)*top
		var state := VehicleState.new()
		state.velocity = Vector2(0,speed)
		var elapsed: float = 0.0
		var clock_us: int = Time.get_ticks_usec()
		var wraps: Array[int] = [0,0,0,0,0,0]
		var positions: Array[float] = [0,0,0,0,0,0]
		recorder.set_recording_active(true)
		while elapsed<27.0:
			await process_frame
			var now: int = Time.get_ticks_usec()
			var dt: float = float(now-clock_us)/1000000.0
			clock_us = now
			elapsed += dt
			state.tick += 1
			var canonical: Array = state.snapshot()
			audio.present(state,DriveFrame.sample(0,0.65,0),null,dt,elapsed>=26.0)
			if state.snapshot()!=canonical: failures += 1
			var players: Array[AudioStreamPlayer] = audio.engine_load+audio.engine_coast
			for index: int in range(players.size()):
				var position: float = players[index].get_playback_position()
				if position+0.1<positions[index]: wraps[index] += 1
				positions[index] = position
		recorder.set_recording_active(false)
		var recording: AudioStreamWAV = recorder.get_recording()
		if recording==null or recording.get_length()<26.5: failures += 1
		elif recording.save_to_wav(OUTPUT.path_join(id+"-native-mix.wav"))!=OK: failures += 1
		# Both audible neighboring layers crossed multiple real boundaries.
		for index: int in [1,2,4,5]:
			if wraps[index]<2: failures += 1
		reports.append({"car":id,"rpm":audio.model.rpm,"shifts":audio.model.shifts,"wraps":wraps})
		if audio.model.shifts!=0: failures += 1
		audio.free()
		print("NATIVE_LOOP_MIX: ",reports[-1])
	AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
	var file := FileAccess.open(OUTPUT.path_join("native-mixes.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"reports":reports,"failures":failures},"\t"))
	file.close()
	print("ALL_NATIVE_LOOP_MIXES: failures=",failures)
	quit(1 if failures>0 else 0)
