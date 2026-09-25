extends SceneTree
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; print("FAIL: "+label)
func run() -> void:
	if "--stress-exit" in OS.get_cmdline_user_args():
		for i: int in range(64):
			var short_lived := DynamicMusicController.new()
			root.add_child(short_lived)
			short_lived.start(null)
			short_lived.free()
		print("MUSIC_EXIT: 64 immediate create/play/free cycles; no grace delay")
		quit()
		return
	var track := NativeTrack.new()
	track.route = PackedVector2Array([Vector2(0,0),Vector2(0,100),Vector2(20,100),Vector2(20,0)])
	track.route_widths = PackedFloat32Array([9,9,9,9])
	track.metadata = {"theme":"pine"}
	track._build_route_distance()
	var profile := MusicProfile.new()

	var arc := DrivingMusicProgress.new()
	check(arc.intensity==0.0,"calm start")
	for i in range(30): arc.advance(20,0,.1,false,profile)
	check(arc.intensity==0.0,"short speed burst cannot build")
	for i in range(320): arc.advance(20,0,.1,false,profile)
	check(arc.intensity>.95,"sustained clean speed builds fully")
	arc.advance(20,1,.1,false,profile)
	check(arc.intensity==0 and arc.melancholy and arc.recovery_seconds==5,"collision resets into recovery")
	arc.advance(20,1,10,true,profile)
	check(arc.recovery_seconds==5,"pause freezes recovery")
	for i in range(40): arc.advance(20,1,.1,false,profile)
	check(arc.intensity==0,"recovery cannot be bypassed with speed")
	for i in range(360): arc.advance(20,1,.1,false,profile)
	check(arc.intensity>.95 and not arc.melancholy,"clean driving recovers from collision")
	for i in range(300): arc.advance(0,1,.1,false,profile)
	check(arc.intensity==0,"stopping gradually calms music")
	var arc_slow := DrivingMusicProgress.new()
	var arc_fast := DrivingMusicProgress.new()
	for i in range(400): arc_slow.advance(18,0,.05,false,profile)
	for i in range(2400): arc_fast.advance(18,0,1.0/120,false,profile)
	check(absf(arc_slow.intensity-arc_fast.intensity)<.005,"progression stable across display rates")
	arc.reset()
	check(arc.average_speed==0 and not arc.melancholy,"retry clears progression")
	var map := TrackMusicAnalyzer.new()
	map.build(track,profile)
	check(map.states.size()==120,"2m cached sampling")
	check(map.seed_value==TrackMusicAnalyzer.fingerprint(track),"same seed")
	track.metadata["title"] = "Renamed"
	check(map.seed_value==TrackMusicAnalyzer.fingerprint(track),"metadata does not recompose")
	track.route[1].x += 1
	check(map.seed_value!=TrackMusicAnalyzer.fingerprint(track),"geometry changes fingerprint")
	track.route[1].x -= 1
	for d: float in [-481.0,-1.0,0.0,27.5,239.9,482.0]:
		check(map.sample(d).distance_to(map.sample(d+track.route_length))<.00001,"wrap %.2f"%d)
	check(map.sample(50).y < map.sample(99).y,"straight lower tension than bend")
	var current: Vector3 = map.sample(72)
	var future: Vector3 = map.sample(72+12*profile.lookahead_seconds)
	check(current.lerp(future,.6).y>current.y,"lookahead anticipates turn")
	check(map.sample(-.01).distance_to(map.sample(.01))<.01,"continuous seam")
	var once: Vector3 = DynamicMusicController.smooth(Vector3.ZERO,Vector3.ONE,1.0,.8)
	var split: Vector3 = Vector3.ZERO
	for i: int in range(100): split = DynamicMusicController.smooth(split,Vector3.ONE,.01,.8)
	check(once.distance_to(split)<.00001,"frame independent smoothing")
	var clock := BeatClock.new()
	clock.beat_position = 35.5; clock.bpm = 132
	check(clock.current_bar==8 and clock.current_phrase==1 and clock.current_beat==35,"clock divisions")
	check(is_equal_approx(clock.time_to_next_bar,.5*60/132),"next bar")
	check(is_equal_approx(clock.time_to_next_phrase,28.5*60/132),"next phrase")
	var vehicle := VehicleState.new()
	vehicle.position = Vector2(0,50); vehicle.velocity = Vector2(0,10); vehicle.route_index = 0
	var prediction := TrajectoryMusicAnalyzer.new()
	var snapshot: Array = vehicle.snapshot()
	var safe: float = prediction.analyze(vehicle,track,map,2.0)
	check(safe<.1,"normal straight risk low")
	vehicle.position = Vector2(0,82);vehicle.velocity = Vector2(0,40)
	check(prediction.analyze(vehicle,track,map,2.0)>safe+.3,"fast corner entry warns before bend")
	vehicle.position = Vector2(0,50);vehicle.velocity = Vector2(0,10)
	check(snapshot==vehicle.snapshot(),"analyzer never mutates physics")
	check(ClassDB.class_exists("BMTMusicStream"),"native synth registered")
	var controller := DynamicMusicController.new()
	root.add_child(controller)
	controller.start(track)
	await create_timer(.2).timeout
	controller.present(vehicle,TrackSession.new(),.1,false)
	check(controller.player.playing and controller.telemetry.has("beat_position"),"native playback and telemetry")
	check(controller.telemetry.get("engine_version",0) == TrackMusicAnalyzer.MUSIC_ENGINE_VERSION,"native and track fingerprint versions agree")
	check(controller.telemetry.get("layers",0)==1,"race begins with solo instrument only")
	controller.progression.intensity = 1.0
	vehicle.collision_count = 1
	var final_session := TrackSession.new()
	final_session.completed_laps = final_session.target_laps-1
	controller.present(vehicle,final_session,.1,false)
	check(controller.target.x<.2 and controller.context&8,"collision remains calm even on final lap")
	controller.queue_free()
	await process_frame
	await create_timer(.15).timeout
	var retired: Array[WeakRef] = create_retirement_probes()
	await create_timer(.25).timeout
	check(retired.all(func(value: WeakRef) -> bool: return value.get_ref()==null),"audio mixer retires freed playback pools")
	if "--capture-drive" in OS.get_cmdline_user_args():
		var game: Node = load("res://core/game.tscn").instantiate()
		game.initial_track = NativeTrack.read("res://resources/tracks/starter_circuit.json")
		root.size = Vector2i(1280,720)
		root.add_child(game)
		game.ai_enabled = true
		game.music.debug_enabled = true
		game.music.overlay.visible = true
		await create_timer(6.0).timeout
		check(game.music.distance>1.0 and game.music.speed>1.0,"driving integration advances music map")
		check(game.music.clock.beat_position>8.0,"audio clock advances during driving")
		print("MUSIC_DRIVE: ",game.music.telemetry," controller_us=",game.music.controller_us)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../docs/evidence/music-ensemble/music-drive.png")
		game.queue_free()
		await process_frame
		await create_timer(.2).timeout
	print("MUSIC: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)

# End the creating stack frame before inspecting weak references: GDScript can
# retain temporary playback references in the frame containing get_stream_playback.
func create_retirement_probes() -> Array[WeakRef]:
	var retired: Array[WeakRef] = []
	for i: int in range(16):
		var transient := DynamicMusicController.new()
		root.add_child(transient)
		transient.start(null)
		retired.append(weakref(transient.player.get_stream_playback()))
		transient.free()
	return retired
