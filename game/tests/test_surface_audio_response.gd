extends "res://tests/test_grass_kerb_audio.gd"
## First-physics kerb rolling, unchanged snapshots and app-owned mixed output.
const RESPONSE_OUT: String = "res://../docs/evidence/surface-audio-latency-2026-10-23"

func run() -> void:
	baseline = "--baseline" in OS.get_cmdline_user_args()
	var audio: Node
	if baseline:
		var script := GDScript.new()
		script.source_code = FileAccess.get_file_as_string(RESPONSE_OUT.path_join("before/game/vehicle/vehicle_audio.gd")).replace("class_name VehicleAudio\n","").replace("class_name VehicleAudio\r\n","")
		check(script.reload()==OK,"original mixer compiles")
		audio = script.new()
	else: audio = VehicleAudio.new()
	audio.use_windows_impacts = false
	root.add_child(audio)
	var track: NativeTrack = make_track(true)
	for id: String in VehicleCatalog.IDS:
		var config: HandlingConfig = VehicleCatalog.config(id)
		audio.configure(id,config)
		var state := VehicleState.new()
		state.position = Vector2(0,.4+config.track_width*.5)
		state.heading = PI*.5
		state.velocity = Vector2(18,0)
		var saved: Array = state.snapshot()
		audio.begin_physics_feedback()
		audio.resolved_contact(state,track,state.velocity)
		check(audio.surface_model.kerb>0,"actual wheel contacts touch kerb: "+id)
		check(audio.levels.kerb_roll>.1,"rolling contact is audible in the first physics callback: "+id)
		check(audio.kerb_count==1,"first contact retains exactly one entry bump: "+id)
		check(state.snapshot()==saved,"kerb feedback leaves driving unchanged: "+id)
		state.position.y = 4
		audio.resolved_contact(state,track,state.velocity)
		check(audio.levels.kerb_roll==0,"current clear wheel contacts silence the rolling layer: "+id)
		await process_frame
	audio.free()
	if not baseline: await verify_output()
	print("SURFACE_AUDIO_RESPONSE: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify_output() -> void:
	var output: WindowsAudioOutput = GameSoundtrack.instance().windows_output
	if DisplayServer.get_name()=="headless" or OS.get_name()!="Windows" or AudioServer.get_driver_name()!="WASAPI":
		check(output.backend==null and output.effect==null,"other platforms/headless retain normal output")
		return
	check(output.backend!=null and bool(output.stats().ready),"one app-owned Windows mix output is ready")
	if output.backend==null: return
	var initial_effects: int = AudioServer.get_bus_effect_count(0)
	var original_effect: AudioEffect = output.effect
	output.configure()
	check(output.effect==original_effect and AudioServer.get_bus_effect_count(0)==initial_effects,"repeated configure never duplicates output or effects")
	var recorder := AudioEffectRecord.new()
	var later_recorder := AudioEffectRecord.new()
	AudioServer.add_bus_effect(0,recorder)
	AudioServer.add_bus_effect(0,later_recorder)
	output.sync_output()
	check(AudioServer.get_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)==output.effect,"late recorders stay before the final output transfer")
	check(AudioServer.get_bus_effect(0,initial_effects-1)==recorder and AudioServer.get_bus_effect(0,initial_effects)==later_recorder,"moving the transfer preserves the exact order of other effects")
	check(AudioServer.get_bus_effect(0,0) is AudioEffectHardLimiter,"original mastering limiter stays first")
	for target: AudioEffect in [recorder,later_recorder]:
		for index: int in range(AudioServer.get_bus_effect_count(0)):
			if AudioServer.get_bus_effect(0,index)==target:
				AudioServer.remove_bus_effect(0,index)
				break
	var audio := VehicleAudio.new()
	root.add_child(audio)
	audio.configure("compact",VehicleCatalog.config("compact"))
	(audio.layers.kerb_roll as AudioStreamPlayer).volume_linear = .3
	await create_timer(.3).timeout
	var stats: Dictionary = output.stats()
	check(int(stats.submitted_frames)>0 and int(stats.rendered_frames)>0,"actual stereo bus PCM reaches the output worker")
	check(int(stats.buffer_bytes)==32768 and int(stats.capacity_frames)==4096,"one fixed 32 KiB stereo ring bounds the transfer")
	check(int(stats.overflows)==0 and int(stats.peak_queued_frames)<=4096 and not bool(stats.failed),"normal mixing stays bounded without overflow or degraded fallback")
	var backend: RefCounted = output.backend
	audio.free()
	check(output.backend==backend and output.effect==original_effect,"race teardown retains the app-owned output route")
	output.close()
	check(not bool(backend.call("stats").ready) and AudioServer.get_bus_effect_count(0)==initial_effects-1,"close joins the worker and restores the exact effect count")
	output.configure()
	check(bool(output.stats().ready) and AudioServer.get_bus_effect_count(0)==initial_effects,"reopening installs one clean output transfer")
