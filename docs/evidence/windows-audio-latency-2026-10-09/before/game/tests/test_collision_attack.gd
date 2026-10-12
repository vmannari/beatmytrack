extends SceneTree
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
	var audio := VehicleAudio.new()
	root.add_child(audio)
	audio.configure("compact",VehicleCatalog.config("compact"))
	var state := VehicleState.new()
	var frame := DriveFrame.new()
	for context: String in ["fresh","after-pause","after-countdown"]:
		audio.reset()
		if context!="fresh": audio.present(state,frame,null,.016,context=="after-pause",context=="after-countdown")
		audio.collision(Vector2(20,0))
		check(audio.impact_count==0,"no cue without a running physics/presentation context: "+context)
		audio.begin_physics_feedback()
		audio.collision(Vector2(20,0))
		check(audio.impact_count==1 and audio.events[0].playing,"first actual live collision starts before render: "+context)
		check(not audio.events[0].stream_paused,"old render pause cannot hold the live cue: "+context)
		check(audio.events[0].bus=="Impacts","contact takes the direct protected path: "+context)
	for clip: String in VehicleAudio.IMPACTS:
		var sample: AudioStreamWAV = load(VehicleAudio.BANK+clip+".wav")
		var pcm: PackedByteArray = sample.data
		var peak: int = 0
		for i: int in range(0,pcm.size(),2): peak = maxi(peak,absi(pcm.decode_s16(i)))
		check(absi(pcm.decode_s16(0))>=int(float(peak)*.99),"first PCM sample is the impact transient: "+clip)
		check(pcm.decode_s16(0)!=0,"no leading zero/silence frame: "+clip)
	var impact_bus: int = AudioServer.get_bus_index("Impacts")
	check(impact_bus>=0 and AudioServer.get_bus_send(impact_bus)=="Master","direct route uses the common output ceiling")
	var limiter: AudioEffect = AudioServer.get_bus_effect(impact_bus,0)
	check(limiter is AudioEffectLimiter and is_equal_approx(float(limiter.get("ceiling_db")),-2.0) and is_equal_approx(float(limiter.get("threshold_db")),-2.0),"instant contact ceiling retains -2dB and adds no makeup gain")
	var world: GameSoundtrack = GameSoundtrack.instance()
	world.apply_settings({"vehicle_volume":0.0})
	check(AudioServer.is_bus_mute(impact_bus) and AudioServer.is_bus_mute(AudioServer.get_bus_index("Vehicle")),"Vehicle mute also mutes direct collisions")
	world.apply_settings({"vehicle_volume":.3})
	check(is_equal_approx(AudioServer.get_bus_volume_db(impact_bus),AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Vehicle"))),"direct collisions follow Vehicle volume exactly")
	world.apply_settings({})
	audio.free()
	await create_timer(.15).timeout
	print("COLLISION_ATTACK_TESTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
