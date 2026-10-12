extends SceneTree
## Event dispatch is synchronous with the collision observer, with all existing guards.
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+description)

func run() -> void:
	var audio := VehicleAudio.new()
	root.add_child(audio)
	audio.configure("compact",VehicleCatalog.config("compact"))
	var state := VehicleState.new()
	var frame := DriveFrame.new()
	audio.collision(Vector2(20,0))
	check(audio.impact_count==0,"fresh/rewound audio cannot replay a stale collision")
	audio.present(state,frame,null,.016,false)
	for magnitude: float in [2.5,9.0,20.0]:
		audio.reset()
		audio.present(state,frame,null,.016,false)
		var snapshot: Array = state.snapshot()
		audio.collision(Vector2(magnitude,0))
		check(audio.impact_count==1 and audio.event_count==1,"collision starts in the observer call, before a render callback: %.1f"%magnitude)
		check(audio.events[0].playing,"event has an active playback immediately: %.1f"%magnitude)
		check(state.snapshot()==snapshot,"immediate playback does not modify simulation state")
		audio.present(state,frame,null,.016,false)
		check(audio.impact_count==1,"render cannot duplicate an already played contact")
		for i: int in range(8): audio.collision(Vector2(magnitude,0))
		check(audio.impact_count==1,"same-step contact burst cannot machine-gun sound")
		for i: int in range(30): audio.present(state,frame,null,1.0/60.0,false)
		audio.collision(Vector2(magnitude,0))
		check(audio.impact_count==2,"new contact after cooldown starts immediately")
	for blocked: String in ["pause","countdown"]:
		audio.reset()
		audio.present(state,frame,null,.016,false)
		audio.present(state,frame,null,.016,blocked=="pause",blocked=="countdown")
		audio.collision(Vector2(20,0))
		check(audio.impact_count==0,"immediate observer obeys "+blocked)
		audio.present(state,frame,null,.016,false)
		check(audio.impact_count==0,"no delayed contact leaks out of "+blocked)
		audio.collision(Vector2(20,0))
		check(audio.impact_count==1,"resumed contact is immediate after "+blocked)
	audio.reset()
	audio.present(state,frame,null,.016,false)
	audio.collision(Vector2(.5,0))
	check(audio.event_count==0,"tiny contacts remain below the body-impact threshold")
	state.tick = 100
	audio.present(state,frame,null,.016,false)
	audio.collision(Vector2(20,0))
	state.tick = 1
	audio.present(state,frame,null,.016,false)
	check(audio.event_count==0 and audio.impact_count==0,"restored history clears body playback and the direct observer")
	for player: AudioStreamPlayer in audio.events+audio.debris_events:
		check(not player.playing,"rewind stops all one-shot voices")
	# Every contact one-shot must put its main transient within one physics tick.
	for clip: String in ["impact_0","impact_1","impact_2","chassis","grit_0","grit_1","grit_2"]:
		var sample: AudioStreamWAV = load(VehicleAudio.BANK+clip+".wav")
		var pcm: PackedByteArray = sample.data
		var peak: int = 0
		var peak_frame: int = -1
		for offset: int in range(0,pcm.size(),2):
			var value: int = absi(pcm.decode_s16(offset))
			if value>peak:
				peak = value
				peak_frame = offset/2
		check(peak>100 and float(peak_frame)/sample.mix_rate<1.0/120.0,"main contact transient is inside 8.33ms: "+clip)
	audio.free()
	await process_frame
	await process_frame
	print("EFFECT_TIMING_TESTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
