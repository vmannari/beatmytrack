extends SceneTree
var checks: int = 0
var failures: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var audio := VehicleAudio.new()
	root.add_child(audio)
	audio.configure("compact",VehicleCatalog.config("compact"))
	if AudioServer.get_driver_name()=="Dummy":
		check(audio.windows_impacts.backend==null,"headless/server does not open a Windows output stream")
		audio.begin_physics_feedback()
		audio.collision(Vector2(20,0))
		check(audio.events[0].playing,"ordinary Godot fallback keeps collision playback")
	else:
		var native: RefCounted = audio.windows_impacts.backend
		check(native!=null,"real Windows default output opens native impact adapter")
		if native!=null:
			check(bool(native.call("stats").ready),"raw backend is ready")
			check(int(native.call("stats").voice_limit)==4,"four bounded collision voices replace normal event voices")
			check(int(native.call("stats").queued_period_limit)==1,"no deep silent prebuffer")
			await create_timer(.06).timeout
			check(int(native.call("stats").queued_frames)==0 and not bool(native.call("stats").idle_silence_queued),"idle backend holds no silent packet ahead of a new collision")
			audio.begin_physics_feedback()
			audio.collision(Vector2(20,0))
			check(audio.impact_count==1 and int(native.call("stats").submitted)==1,"physics cue reaches the native output immediately")
			check(not audio.events[0].playing,"no delayed duplicate in the Godot stream")
			await create_timer(.04).timeout
			check(int(native.call("stats").active_voices)>0,"actual native voice has a settling tail")
			var state := VehicleState.new()
			var frame := DriveFrame.new()
			audio.present(state,frame,null,.016,true)
			var submitted: int = int(native.call("stats").submitted)
			audio.collision(Vector2(20,0))
			check(int(native.call("stats").submitted)==submitted,"paused presentation cannot emit another cue")
			audio.reset()
			check(int(native.call("stats").active_voices)==0,"reset/rewind clears every old impact tail")
			check(not bool(native.call("play",4,.5,1.0)),"invalid sample cannot enter render thread")
			for i: int in range(12):
				audio.windows_impacts.play(i%3,.25,1.0)
			check(int(native.call("stats").active_voices)<=4,"overlapping body events stay within the voice cap")
			audio.windows_impacts.reset()
			audio.windows_impacts.play(0,.25,1.0,0)
			audio.event_index = 0
			audio._event("chassis",.12)
			check(int(native.call("stats").active_voices)==1 and not audio.events[0].playing,"chassis replaces the same native body slot without a delayed Godot copy")
			check(int(native.call("stats").clip_count)==4,"all collision/body clips are preloaded for the same fast output")
			audio.reset()
			var impact_bus: int = AudioServer.get_bus_index("Impacts")
			var world: GameSoundtrack = GameSoundtrack.instance()
			world.apply_settings({"vehicle_volume":0.0})
			audio.windows_impacts.sync_output(false)
			check(AudioServer.is_bus_mute(impact_bus),"Vehicle mute reaches the direct path source")
			world.apply_settings({"vehicle_volume":.3})
			audio.windows_impacts.sync_output(false)
			check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(impact_bus)),.3),"Vehicle gain stays data driven")
			world.apply_settings({})
			audio.windows_impacts.close()
			audio.reset()
			audio.begin_physics_feedback()
			audio.collision(Vector2(20,0))
			check(audio.events[0].playing,"unavailable native output immediately falls back to Godot")
			check(not bool(native.call("stats").ready),"close joins the output worker")
	audio.free()
	await create_timer(.15).timeout
	print("WINDOWS_IMPACT_TESTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
